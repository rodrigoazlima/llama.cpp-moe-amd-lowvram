#Requires -Version 5.1
# High-context launch: full GPU, q4_0 KV (4x context vs f16), stability flags
# For 24GB+ VRAM — model fits entirely in VRAM, no CPU MoE offload needed
# q4_0 KV: ~4x VRAM savings vs f16, frees headroom for 131072+ context
# Asymmetric KV not needed here: q4_0/q4_0 is the proven stable combo (see benchmarks)
# TurboQuant (turbo4/turbo3) is higher quality at same compression — test if your build supports it

param(
    [string]$ModelPath = "D:\opt\models\lmstudio\lmstudio-community\Qwen3-Coder-30B-A3B-Instruct-GGUF\Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf",
    [int]$GpuLayers    = 41,
    [int]$ContextSize  = 131072,
    [int]$Port         = 8081,
    [switch]$TurboQuant   # Use turbo4/turbo3 KV if your llama.cpp build supports it
)

$LlamaDir    = "C:\opt\llama-hip-amd721\llama-b8407-windows-rocm-7.2.1-gfx110X-gfx115X-gfx120X-x64"
$LlamaServer = "$LlamaDir\llama-server.exe"
$env:PATH    = "$LlamaDir;" + $env:PATH
$env:HSA_ENABLE_SDMA = "0"   # Reduces DMA overhead on RDNA3, +5-15% throughput

if (-not (Test-Path $LlamaServer)) { Write-Error "llama-server.exe not found: $LlamaServer"; exit 1 }
if (-not (Test-Path $ModelPath))   { Write-Error "Model not found: $ModelPath"; exit 1 }

$KvTypeK = if ($TurboQuant) { "turbo4" } else { "q4_0" }
$KvTypeV = if ($TurboQuant) { "turbo3" } else { "q4_0" }

Write-Host "llama-server: $LlamaServer"
Write-Host "Model:        $ModelPath"
Write-Host "GPU layers:   $GpuLayers (full — no CPU MoE offload)"
Write-Host "Context:      $ContextSize tokens"
Write-Host "KV cache:     k=$KvTypeK  v=$KvTypeV"
Write-Host "Port:         $Port"
Write-Host ""

& $LlamaServer `
    -m $ModelPath `
    --n-gpu-layers $GpuLayers `
    --cache-type-k $KvTypeK `
    --cache-type-v $KvTypeV `
    --flash-attn `
    --no-mmap `
    --mlock `
    -c $ContextSize `
    --port $Port `
    --verbose
