#Requires -Version 5.1
# Baseline launch: GPU-only, no MoE offload, default context

param(
    [string]$ModelPath = "D:\opt\models\lmstudio\lmstudio-community\Qwen3-Coder-30B-A3B-Instruct-GGUF\Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf",
    [int]$GpuLayers = 41,
    [int]$ContextSize = 32768,
    [int]$Port = 8081
)

$LlamaDir = "C:\opt\llama-hip-amd721\llama-b8407-windows-rocm-7.2.1-gfx110X-gfx115X-gfx120X-x64"
$LlamaServer = "$LlamaDir\llama-server.exe"

$env:PATH = "$LlamaDir;" + $env:PATH
$env:HSA_ENABLE_SDMA = "0"   # Reduces DMA overhead on RDNA3, +5-15% throughput

if (-not (Test-Path $LlamaServer)) {
    Write-Error "llama-server.exe not found at $LlamaServer"; exit 1
}
if (-not (Test-Path $ModelPath)) {
    Write-Error "Model not found: $ModelPath"; exit 1
}

Write-Host "llama-server: $LlamaServer"
Write-Host "Model:        $ModelPath"
Write-Host "GPU layers:   $GpuLayers"
Write-Host "Context:      $ContextSize tokens"
Write-Host "Port:         $Port"
Write-Host ""

& $LlamaServer `
    -m $ModelPath `
    --n-gpu-layers $GpuLayers `
    --flash-attn `
    -c $ContextSize `
    --port $Port `
    --verbose
