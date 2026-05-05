#Requires -Version 5.1
# Download Qwen3.6 35B-A3B GGUF model from Hugging Face
# Default: UD-Q4_K_M (22.1 GB) — best quality/size balance for 24GB VRAM

param(
    [string]$Quant = "UD-Q4_K_M",
    [string]$OutputDir = "D:\opt\models\ollama"
)

$ValidQuants = @("UD-Q4_K_M", "UD-Q5_K_M", "Q8_0", "UD-Q3_K_M", "UD-IQ4_NL")
if ($Quant -notin $ValidQuants) {
    Write-Error "Invalid quant '$Quant'. Valid options: $($ValidQuants -join ', ')"; exit 1
}

$Filename = "Qwen3.6-35B-A3B-$Quant.gguf"
$RepoId = "unsloth/Qwen3.6-35B-A3B-GGUF"

Write-Host "Downloading $Filename from $RepoId"
Write-Host "Output dir: $OutputDir"
Write-Host ""

huggingface-cli download $RepoId $Filename --local-dir $OutputDir

Write-Host ""
Write-Host "Model saved to: $OutputDir\$Filename"
