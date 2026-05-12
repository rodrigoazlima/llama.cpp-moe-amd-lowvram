#Requires -Version 5.1
# Import existing GGUF into Ollama via Modelfile (no re-download)
# OLLAMA_MODELS points to D: so Ollama stores blobs there, not C:

param(
    [string]$ModelPath    = "D:\opt\models\lmstudio\lmstudio-community\Qwen3-Coder-30B-A3B-Instruct-GGUF\Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf",
    [string]$ModelName    = "qwen3-coder-30b",
    [string]$SystemPrompt = "",
    [switch]$Remove
)

# OLLAMA_MODELS must be set system-wide (by install_ollama_service.ps1).
# The server controls blob storage — client env var has no effect.
$sysMod = [System.Environment]::GetEnvironmentVariable("OLLAMA_MODELS", "Machine")
if (-not $sysMod) {
    Write-Warning "OLLAMA_MODELS not set system-wide. Run install_ollama_service.ps1 first or blobs will land on C:."
}
$env:OLLAMA_MODELS = if ($sysMod) { $sysMod } else { "D:\opt\models\ollama" }

if ($Remove) {
    Write-Host "Removing model '$ModelName' from Ollama..."
    ollama rm $ModelName
    exit 0
}

if (-not (Test-Path $ModelPath)) {
    Write-Error "GGUF not found: $ModelPath"
    exit 1
}

$modelfile = "$env:TEMP\Modelfile_$ModelName"

$content = "FROM `"$ModelPath`""
if ($SystemPrompt) {
    $content += "`nSYSTEM `"$SystemPrompt`""
}

Set-Content -Path $modelfile -Value $content -Encoding UTF8

Write-Host "Modelfile:     $modelfile"
Write-Host "Model:         $ModelPath"
Write-Host "Name:          $ModelName"
Write-Host "OLLAMA_MODELS: $([System.Environment]::GetEnvironmentVariable('OLLAMA_MODELS','Machine') ?? '(not set — blobs go to C:)')"
Write-Host ""

ollama create $ModelName -f $modelfile

Write-Host ""
Write-Host "Done. Test:"
Write-Host "  ollama run $ModelName"
Write-Host "  Invoke-RestMethod http://localhost:11434/api/tags"
