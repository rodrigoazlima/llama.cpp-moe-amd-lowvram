#Requires -Version 5.1
# Benchmark: measure prompt processing (pp) and token generation (tg) tokens/sec
# Uses llama-bench.exe directly — not llama-server

param(
    [string]$ModelPath   = "D:\opt\models\lmstudio\lmstudio-community\Qwen3-Coder-30B-A3B-Instruct-GGUF\Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf",
    [string]$Config      = "both",   # baseline | optimized | kv-only | ubatch | highctx | q8kv | all
    [int]$Repetitions    = 3,
    [int]$NPrompt        = 512,
    [int]$NGen           = 128
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8

$LlamaDir   = "C:\opt\llama-hip-amd721\llama-b8407-windows-rocm-7.2.1-gfx110X-gfx115X-gfx120X-x64"
$LlamaBench = "$LlamaDir\llama-bench.exe"
$env:PATH   = "$LlamaDir;" + $env:PATH

# Reduces DMA overhead on RDNA3 — +5-15% throughput
$env:HSA_ENABLE_SDMA = "0"

if (-not (Test-Path $LlamaBench)) { Write-Error "llama-bench.exe not found: $LlamaBench"; exit 1 }
if (-not (Test-Path $ModelPath))  { Write-Error "Model not found: $ModelPath"; exit 1 }

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$OutFile   = "$PSScriptRoot\benchmark_results_$Timestamp.md"

function Run-Bench {
    param([string]$Label, [string[]]$ExtraArgs)
    Write-Host "`n=== $Label ===" -ForegroundColor Cyan
    $benchArgs = @(
        "-m", $ModelPath,
        "-r", $Repetitions,
        "-p", $NPrompt,
        "-n", $NGen,
        "--progress",
        "-o", "md"
    ) + $ExtraArgs
    & $LlamaBench @benchArgs
}

$Results  = @()
$Results += "# Benchmark Results — $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
$Results += "- Model: $ModelPath"
$Results += "- Repetitions: $Repetitions | Prompt tokens: $NPrompt | Gen tokens: $NGen"
$Results += ""

# --- Baseline: full GPU, f16 KV, mmap on — fastest for 24GB+ VRAM ---
if ($Config -eq "baseline" -or $Config -eq "both" -or $Config -eq "all") {
    $Results += "## Baseline (GPU full, f16 KV, mmap on, FA)"
    $out = Run-Bench "BASELINE" @("-ngl", "41", "-mmp", "1", "-fa", "1")
    $Results += ($out | Out-String)
}

# --- Optimized: MoE CPU offload — for low-VRAM GPUs (<20GB), HURTS on 24GB ---
if ($Config -eq "optimized" -or $Config -eq "both" -or $Config -eq "all") {
    $Results += "## Optimized (MoE CPU offload, q4_0 KV, no-mmap) [low-VRAM only]"
    $out = Run-Bench "OPTIMIZED" @("-ngl", "41", "-ncmoe", "35", "-ctk", "q4_0", "-ctv", "q4_0", "-mmp", "0", "-fa", "1")
    $Results += ($out | Out-String)
}

# --- KV-quant only: full GPU + q4_0 KV, no CPU offload — baseline for highctx configs ---
if ($Config -eq "kv-only" -or $Config -eq "all") {
    $Results += "## KV-quant only (GPU full, q4_0 KV, no-mmap, FA)"
    $out = Run-Bench "KV-ONLY" @("-ngl", "41", "-ctk", "q4_0", "-ctv", "q4_0", "-mmp", "0", "-fa", "1")
    $Results += ($out | Out-String)
}

# --- q8kv: near-lossless KV — quality reference, ~2x context vs f16 ---
if ($Config -eq "q8kv" -or $Config -eq "all") {
    $Results += "## q8kv (GPU full, q8_0 KV, no-mmap, FA) — near-lossless, 2x context vs f16"
    $out = Run-Bench "Q8KV" @("-ngl", "41", "-ctk", "q8_0", "-ctv", "q8_0", "-mmp", "0", "-fa", "1")
    $Results += ($out | Out-String)
}

# --- highctx: max context config — q4_0 KV + mlock stability, recommended for 128K+ sessions ---
# Same tg speed as kv-only but paired with mlock in launch_highctx.ps1 for multi-hour stability
if ($Config -eq "highctx" -or $Config -eq "all") {
    $Results += "## highctx (GPU full, q4_0 KV, no-mmap, FA, c=32768) — proxy for 128K context perf"
    $out = Run-Bench "HIGHCTX" @("-ngl", "41", "-ctk", "q4_0", "-ctv", "q4_0", "-mmp", "0", "-fa", "1", "-c", "32768")
    $Results += ($out | Out-String)
}

# --- ubatch sweep: find optimal micro-batch for this GPU ---
if ($Config -eq "ubatch" -or $Config -eq "all") {
    $Results += "## ubatch 512 (default)"
    $out = Run-Bench "UBATCH-512" @("-ngl", "41", "-mmp", "1", "-fa", "1", "-ub", "512")
    $Results += ($out | Out-String)

    $Results += "## ubatch 1024"
    $out = Run-Bench "UBATCH-1024" @("-ngl", "41", "-mmp", "1", "-fa", "1", "-ub", "1024")
    $Results += ($out | Out-String)

    $Results += "## ubatch 2048"
    $out = Run-Bench "UBATCH-2048" @("-ngl", "41", "-mmp", "1", "-fa", "1", "-ub", "2048")
    $Results += ($out | Out-String)
}

$Results | Out-File $OutFile -Encoding UTF8
Write-Host "`nResults saved to: $OutFile" -ForegroundColor Green
