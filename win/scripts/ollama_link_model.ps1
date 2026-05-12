#Requires -Version 5.1
# Register existing GGUF with Ollama via hardlink + OCI manifest — zero data copy.
# Both GGUF and OLLAMA_MODELS must be on the same partition (hardlink requirement).

param(
    [string]$ModelPath    = "D:\opt\models\lmstudio\lmstudio-community\Qwen3-Coder-30B-A3B-Instruct-GGUF\Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf",
    [string]$ModelName    = "qwen3-coder-30b",
    [string]$OllamaModels = "D:\opt\ollama-models",
    [switch]$Remove
)

$ollamaExe = (Get-Command ollama -ErrorAction SilentlyContinue)?.Source
if (-not $ollamaExe) { $ollamaExe = "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe" }

# --- remove ------------------------------------------------------------------

if ($Remove) {
    $manifest = "$OllamaModels\manifests\registry.ollama.ai\library\$ModelName\latest"
    if (Test-Path $manifest) { Remove-Item $manifest -Force; Write-Host "Manifest removed." }
    Write-Host "Note: blob hardlink left in place (shares data with original GGUF)."
    exit 0
}

# --- preflight ---------------------------------------------------------------

if (-not (Test-Path $ModelPath)) { Write-Error "GGUF not found: $ModelPath"; exit 1 }

$ggufDrive  = (Split-Path -Qualifier $ModelPath).TrimEnd(':')
$modelsDrive = (Split-Path -Qualifier $OllamaModels).TrimEnd(':')
if ($ggufDrive -ne $modelsDrive) {
    Write-Error "Hardlink requires same partition. GGUF on ${ggufDrive}: but OLLAMA_MODELS on ${modelsDrive}:. Change -OllamaModels to same drive."
    exit 1
}

# --- compute sha256 ----------------------------------------------------------

Write-Host "Computing SHA256 of GGUF (may take ~30s for large files)..."
$hash = (Get-FileHash $ModelPath -Algorithm SHA256).Hash.ToLower()
Write-Host "SHA256: $hash"

$modelSize = (Get-Item $ModelPath).Length

# --- create blob via hardlink ------------------------------------------------

$blobDir  = "$OllamaModels\blobs"
$blobPath = "$blobDir\sha256-$hash"
New-Item -ItemType Directory -Force $blobDir | Out-Null

if (Test-Path $blobPath) {
    Write-Host "Blob already exists: $blobPath"
} else {
    Write-Host "Creating hardlink (zero copy)..."
    # cmd mklink /H is the most reliable cross-PowerShell way
    $result = cmd /c "mklink /H `"$blobPath`" `"$ModelPath`"" 2>&1
    if (-not (Test-Path $blobPath)) {
        Write-Error "Hardlink failed: $result`nFallback: ensure GGUF and OLLAMA_MODELS are on the same partition."
        exit 1
    }
    Write-Host "Hardlink created: $blobPath"
}

# --- create minimal config blob ----------------------------------------------

$config = @{
    architecture    = "gguf"
    format          = "gguf"
    parameter_size  = "30B"
    quantization    = "Q4_K_M"
} | ConvertTo-Json -Compress

$configBytes  = [System.Text.Encoding]::UTF8.GetBytes($config)
$configHash   = [System.BitConverter]::ToString(
    [System.Security.Cryptography.SHA256]::Create().ComputeHash($configBytes)
).Replace("-","").ToLower()
$configPath   = "$blobDir\sha256-$configHash"

[System.IO.File]::WriteAllBytes($configPath, $configBytes)

# --- write OCI manifest ------------------------------------------------------

$manifestDir = "$OllamaModels\manifests\registry.ollama.ai\library\$ModelName"
New-Item -ItemType Directory -Force $manifestDir | Out-Null

$manifest = [ordered]@{
    schemaVersion = 2
    mediaType     = "application/vnd.docker.distribution.manifest.v2+json"
    config        = [ordered]@{
        digest    = "sha256:$configHash"
        mediaType = "application/vnd.ollama.image.config.v1"
        size      = $configBytes.Length
    }
    layers        = @(
        [ordered]@{
            digest    = "sha256:$hash"
            mediaType = "application/vnd.ollama.image.model"
            size      = $modelSize
        }
    )
} | ConvertTo-Json -Depth 5 -Compress

$manifestPath = "$manifestDir\latest"
Set-Content -Path $manifestPath -Value $manifest -Encoding UTF8 -NoNewline
Write-Host "Manifest written: $manifestPath"

# --- restart ollama so it picks up new manifest ------------------------------

Write-Host "Restarting Ollama to register model..."
Get-Process -Name "ollama" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2
$env:OLLAMA_MODELS = $OllamaModels
Start-Process -FilePath $ollamaExe -ArgumentList "serve" -WindowStyle Hidden
Start-Sleep -Seconds 5

# --- validate ----------------------------------------------------------------

try {
    $tags = Invoke-RestMethod http://localhost:11434/api/tags
    $found = $tags.models | Where-Object { $_.name -like "*$ModelName*" }
    if ($found) {
        Write-Host ""
        Write-Host "Model registered:"
        $found | ForEach-Object { Write-Host "  $($_.name)  ($([math]::Round($_.size/1GB,2)) GB)" }
    } else {
        Write-Warning "Model not visible in api/tags yet. Try: Invoke-RestMethod http://localhost:11434/api/tags"
        Write-Host "Registered models:"
        $tags.models | ForEach-Object { Write-Host "  $($_.name)" }
    }
} catch {
    Write-Warning "API not responding: $_"
}
