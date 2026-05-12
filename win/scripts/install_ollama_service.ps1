#Requires -Version 5.1
#Requires -RunAsAdministrator
# Install and register Ollama as a Windows service via NSSM

param(
    [string]$OllamaExe    = "C:\Program Files\Ollama\ollama.exe",
    [string]$ServiceName  = "Ollama",
    [string]$DisplayName  = "Ollama LLM Service",
    [string]$NssmPath     = "C:\tools\nssm\nssm.exe",
    [string]$LogDir        = "C:\ProgramData\Ollama\logs",
    [string]$OllamaHost   = "0.0.0.0",
    [int]$OllamaPort      = 11434,
    [switch]$Uninstall
)

# --- helpers -----------------------------------------------------------------

function Ensure-Nssm {
    if (Test-Path $NssmPath) { return }
    Write-Host "NSSM not found at $NssmPath — downloading..."
    $NssmDir = Split-Path $NssmPath
    New-Item -ItemType Directory -Force $NssmDir | Out-Null
    $zip = "$env:TEMP\nssm.zip"
    Invoke-WebRequest "https://nssm.cc/release/nssm-2.24.zip" -OutFile $zip
    Expand-Archive $zip -DestinationPath "$env:TEMP\nssm_extract" -Force
    $exe = Get-ChildItem "$env:TEMP\nssm_extract" -Recurse -Filter "nssm.exe" |
           Where-Object { $_.DirectoryName -match "win64" } |
           Select-Object -First 1
    if (-not $exe) { $exe = Get-ChildItem "$env:TEMP\nssm_extract" -Recurse -Filter "nssm.exe" | Select-Object -First 1 }
    Copy-Item $exe.FullName $NssmPath -Force
    Write-Host "NSSM installed: $NssmPath"
}

function Service-Exists([string]$Name) {
    return [bool](Get-Service -Name $Name -ErrorAction SilentlyContinue)
}

# --- uninstall path ----------------------------------------------------------

if ($Uninstall) {
    if (-not (Service-Exists $ServiceName)) {
        Write-Host "Service '$ServiceName' not found — nothing to remove."
        exit 0
    }
    Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
    & $NssmPath remove $ServiceName confirm
    Write-Host "Service '$ServiceName' removed."
    exit 0
}

# --- preflight ---------------------------------------------------------------

if (-not (Test-Path $OllamaExe)) {
    Write-Error "ollama.exe not found: $OllamaExe`nInstall from https://ollama.com/download"
    exit 1
}

Ensure-Nssm

New-Item -ItemType Directory -Force $LogDir | Out-Null

# --- install / update service ------------------------------------------------

if (Service-Exists $ServiceName) {
    Write-Host "Service '$ServiceName' exists — updating..."
    Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
} else {
    Write-Host "Installing service '$ServiceName'..."
    & $NssmPath install $ServiceName $OllamaExe serve
}

& $NssmPath set $ServiceName DisplayName  $DisplayName
& $NssmPath set $ServiceName Description  "Ollama local LLM inference server"
& $NssmPath set $ServiceName Start        SERVICE_AUTO_START
& $NssmPath set $ServiceName AppStdout    "$LogDir\ollama.log"
& $NssmPath set $ServiceName AppStderr    "$LogDir\ollama-err.log"
& $NssmPath set $ServiceName AppRotateFiles 1
& $NssmPath set $ServiceName AppRotateOnline 1
& $NssmPath set $ServiceName AppRotateSeconds 86400
& $NssmPath set $ServiceName AppEnvironmentExtra "OLLAMA_HOST=${OllamaHost}:${OllamaPort}"

# --- start -------------------------------------------------------------------

Start-Service -Name $ServiceName
$svc = Get-Service -Name $ServiceName
Write-Host ""
Write-Host "Service : $ServiceName"
Write-Host "Status  : $($svc.Status)"
Write-Host "Endpoint: http://${OllamaHost}:${OllamaPort}"
Write-Host "Logs    : $LogDir"
Write-Host ""
Write-Host "Test: Invoke-RestMethod http://localhost:${OllamaPort}/api/tags"
