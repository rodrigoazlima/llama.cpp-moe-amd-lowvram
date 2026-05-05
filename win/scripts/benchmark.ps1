#Requires -Version 5.1
# Benchmark: baseline vs optimized config using llama-bench.exe
# Measures prompt processing (pp) and token generation (tg) tokens/sec

# Force UTF-8 so llama-bench's ± character doesn't get mangled
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

param(
    [string]$ModelPath = "D:\opt\models\lmstudio\lmstudio-community\Qwen3-Coder-30B-A3B-Instruct-GGUF\Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf",
    [string]$Config = "both",   # baseline | optimized | both
    [int]$Repetitions = 3,
    [int]$NPrompt = 512,
    [int]$NGen = 128
)

$LlamaDir = "C:\opt\llama-hip-amd721\llama-b8407-windows-rocm-7.2.1-gfx110X-gfx115X-gfx120X-x64"
$LlamaBench = "$LlamaDir\llama-bench.exe"
$env:PATH = "$LlamaDir;" + $env:PATH

if (-not (Test-Path $LlamaBench)) { Write-Error "llama-bench.exe not found at $LlamaBench"; exit 1 }
if (-not (Test-Path $ModelPath))   { Write-Error "Model not found: $ModelPath"; exit 1 }

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$OutFile = "$PSScriptRoot\benchmark_results_$Timestamp.md"

function Run-Bench {
    param([string]$Label, [string[]]$ExtraArgs)
    Write-Host "`n=== $Label ===" -ForegroundColor Cyan
    $args = @(
        "-m", $ModelPath,
        "-r", $Repetitions,
        "-p", $NPrompt,
        "-n", $NGen,
        "--progress",
        "-o", "md"
    ) + $ExtraArgs
    & $LlamaBench @args
}

$Results = @()
$Results += "# Benchmark Results — $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
$Results += "- Model: $ModelPath"
$Results += "- Repetitions: $Repetitions | Prompt tokens: $NPrompt | Gen tokens: $NGen"
$Results += ""

if ($Config -eq "baseline" -or $Config -eq "both") {
    $Results += "## Baseline (GPU only, f16 KV, mmap on)"
    $out = Run-Bench "BASELINE" @("-ngl", "41", "-mmp", "1", "-fa", "1")
    $Results += ($out | Out-String)
}

if ($Config -eq "optimized" -or $Config -eq "both") {
    $Results += "## Optimized (MoE CPU offload, q4_0 KV, no-mmap)"
    $out = Run-Bench "OPTIMIZED" @("-ngl", "41", "-ncmoe", "35", "-ctk", "q4_0", "-ctv", "q4_0", "-mmp", "0", "-fa", "1")
    $Results += ($out | Out-String)
}

$Results | Out-File $OutFile -Encoding UTF8
Write-Host "`nResults saved to: $OutFile" -ForegroundColor Green
