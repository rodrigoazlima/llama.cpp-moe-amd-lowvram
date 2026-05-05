#Requires -Version 5.1
# benchmark262k.ps1 — Max context window benchmark, ctx=262144 fixed for ALL tests
# Target hardware: RX 7900 XTX 24GB | Ryzen 9 9900X | 128GB DDR5 | ROCm 7.2.1
# Model: Qwen3-Coder-30B-A3B Q4_K_M (17.35 GiB, ~16.25 GB measured VRAM)
#
# DESIGN RULE: all tests target the 262144 token context window.
# llama-bench b2500 has no -c flag — context = pp + n only.
# Each test therefore uses pp + n that fills toward 262144:
#   ladder  — pp varies 8K→262K, n kept small (128 or 32). context = pp+n.
#   stress  — pp=262016 + n=128 = 262144 exactly. true full 262K context.
# VRAM scales with pp+n per test (KV cache not pre-allocated beyond what's needed).
#
# VRAM formula: model(16.25 GB) + KV(57344 elem/tok × bpe × ctx_tokens / 1GB)
#   q4_0 KV: 0.5 bytes/elem — fits 262K ctx at ~23.25 GB total
#   q8_0 KV: 1 byte/elem    — fits ~128K ctx at ~23.25 GB total
#   f16  KV: 2 bytes/elem   — fits ~32K ctx at ~19.75 GB total
#
# Sections:
#   ladder  — pp t/s vs prompt size (8K→262K), q4_0 KV
#   ubatch  — micro-batch sweep at pp=8K/32K/128K (where it dominates)
#   stress  — pp=262016 + n=128 = 262144 exact (full 262K, ~45 min)
#   all     — all sections
#
# Usage:
#   .\benchmark262k.ps1                       # ladder (default, ~30 min)
#   .\benchmark262k.ps1 -Config ubatch        # ubatch sweep (~45 min)
#   .\benchmark262k.ps1 -Config stress -Force # 262K full-context run (~45 min)
#   .\benchmark262k.ps1 -Config all -Force    # everything (~2.5+ hr)

param(
    [string]$ModelPath  = "D:\opt\models\lmstudio\lmstudio-community\Qwen3-Coder-30B-A3B-Instruct-GGUF\Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf",
    [string]$Config     = "ladder",  # ladder | ubatch | stress | all
    [int]$Repetitions   = 2,         # auto-reduced to 1 for pp >= 128K
    [int]$NGen          = 128,       # auto-reduced to 32 for pp >= 64K
    [switch]$Force                   # bypass VRAM guard (>23.0 GB est.)
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8

$LlamaDir   = "C:\opt\llama-hip-amd721\llama-b8407-windows-rocm-7.2.1-gfx110X-gfx115X-gfx120X-x64"
$LlamaBench = "$LlamaDir\llama-bench.exe"
$env:PATH   = "$LlamaDir;" + $env:PATH
$env:HSA_ENABLE_SDMA = "0"

if (-not (Test-Path $LlamaBench)) { Write-Error "llama-bench.exe not found: $LlamaBench"; exit 1 }
if (-not (Test-Path $ModelPath))  { Write-Error "Model not found: $ModelPath"; exit 1 }

$Timestamp   = Get-Date -Format "yyyyMMdd_HHmmss"
$OutFile     = "$PSScriptRoot\benchmark262k_$Timestamp.md"
$LadderStats = [System.Collections.Generic.List[hashtable]]::new()

# --- Constants ---
$FIXED_CTX     = 262144   # Qwen3 model max context — target for all tests
$MODEL_VRAM_GB = 16.25    # measured GPU baseline (model weights, no context)
$VRAM_TOTAL_GB = 24.0     # RX 7900 XTX
$VRAM_GUARD_GB = 23.25     # warn + need -Force above this
$VRAM_BLOCK_GB = 23.8     # always blocked — likely OOM

# KV cache: 2(K+V) x 8_kvheads x 128_headdim x 28_layers = 57344 elements/token
# Context = pp + n (b2500 has no -c flag)
function Get-KVCacheSizeGB {
    param([int]$Tokens, [string]$KVType = "q4_0")
    $bpe = switch ($KVType) { "f16" { 2.0 } "q8_0" { 1.0 } "q4_0" { 0.5 } default { 2.0 } }
    return [math]::Round(57344 * $bpe * $Tokens / 1GB, 2)
}

function Get-EstVRAMGB {
    param([int]$Tokens, [string]$KVType = "q4_0")
    return [math]::Round($MODEL_VRAM_GB + (Get-KVCacheSizeGB $Tokens $KVType), 2)
}

function Get-EstRuntime {
    param([int]$PP, [int]$TG, [int]$Reps)
    $ppTps = if     ($PP -le 8192)   { 900 }
             elseif ($PP -le 32768)  { 330 }
             elseif ($PP -le 65536)  { 220 }
             elseif ($PP -le 131072) { 160 }
             elseif ($PP -le 196608) { 120 }
             else                    { 90  }
    $secsPerRep = [math]::Ceiling([double]$PP / $ppTps + [double]$TG / 60.0)
    $total = $secsPerRep * $Reps
    if ($total -lt 60)   { return "${total}s" }
    if ($total -lt 3600) { return "$([math]::Round($total / 60, 0)) min" }
    return "$([math]::Round($total / 3600, 1)) hr"
}

function Test-VRAMFeasible {
    param([string]$Label, [int]$Tokens, [string]$KVType = "q4_0")
    $est = Get-EstVRAMGB $Tokens $KVType
    if ($est -ge $VRAM_BLOCK_GB) {
        Write-Warning "BLOCKED [${Label}]: est. $est GB >= $VRAM_BLOCK_GB GB hard limit."
        return $false
    }
    if ($est -ge $VRAM_GUARD_GB -and -not $Force) {
        Write-Warning "GUARDED [${Label}]: est. $est GB >= $VRAM_GUARD_GB GB. Run with -Force to enable."
        return $false
    }
    if ($est -ge $VRAM_GUARD_GB) {
        Write-Host "  [FORCE] ${Label}: est. $est GB — proceeding at risk ($VRAM_TOTAL_GB GB limit)." -ForegroundColor Yellow
    }
    return $true
}

# --- System snapshot ---

function Get-SystemSnapshot {
    $snap = [ordered]@{}
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $snap.RAMUsedGB  = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB, 1)
        $snap.RAMTotalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
    } catch { $snap.RAMUsedGB = $null; $snap.RAMTotalGB = $null }
    try {
        $snap.CPUPercent = [int](Get-CimInstance Win32_Processor -ErrorAction Stop |
                           Measure-Object -Property LoadPercentage -Average |
                           Select-Object -ExpandProperty Average)
    } catch { $snap.CPUPercent = $null }
    try {
        $vram = (Get-Counter '\GPU Adapter Memory(*)\Dedicated Usage' -ErrorAction Stop).CounterSamples |
                Measure-Object -Property CookedValue -Sum | Select-Object -ExpandProperty Sum
        $snap.VRAMUsedGB = [math]::Round($vram / 1GB, 2)
    } catch { $snap.VRAMUsedGB = $null }
    try {
        $util = (Get-Counter '\GPU Engine(*engtype_3D*)\Utilization Percentage' -ErrorAction Stop).CounterSamples |
                Measure-Object -Property CookedValue -Maximum | Select-Object -ExpandProperty Maximum
        $snap.GPUPercent = [math]::Round($util, 1)
    } catch { $snap.GPUPercent = $null }
    return $snap
}

function Format-SnapshotMD {
    param($snap)
    $lines = @()
    if ($null -ne $snap.VRAMUsedGB) { $lines += "- VRAM: $($snap.VRAMUsedGB) GB" }
    if ($null -ne $snap.RAMUsedGB)  { $lines += "- RAM:  $($snap.RAMUsedGB) / $($snap.RAMTotalGB) GB" }
    if ($null -ne $snap.CPUPercent) { $lines += "- CPU:  $($snap.CPUPercent)%" }
    if ($null -ne $snap.GPUPercent) { $lines += "- GPU:  $($snap.GPUPercent)% (3D)" }
    return $lines
}

# --- VRAM poller ---

function Start-VRAMPoller {
    return Start-Job -ScriptBlock {
        while ($true) {
            try {
                $v = (Get-Counter '\GPU Adapter Memory(*)\Dedicated Usage').CounterSamples |
                     Measure-Object CookedValue -Sum | Select-Object -ExpandProperty Sum
                [math]::Round($v / 1GB, 2)
            } catch {}
            Start-Sleep -Milliseconds 500
        }
    }
}

function Stop-VRAMPoller {
    param($job)
    Stop-Job  $job -ErrorAction SilentlyContinue
    $samples = Receive-Job $job -ErrorAction SilentlyContinue
    Remove-Job $job -ErrorAction SilentlyContinue
    if ($samples -and $samples.Count -gt 0) { return ($samples | Measure-Object -Maximum).Maximum }
    return $null
}

# --- Bench runner ---
# All calls add -c $FIXED_CTX so KV cache is always 262144 tokens regardless of pp/n.

function Invoke-Bench {
    param(
        [string]$Label,
        [string[]]$ExtraArgs,
        [int]$PP,
        [int]$TG        = -1,
        [int]$Reps      = -1,
        [string]$KVType = "q4_0",
        [switch]$Ladder
    )

    $gen  = if ($TG   -ge 0) { $TG   } else { $NGen }
    $reps = if ($Reps -ge 0) { $Reps } else { $Repetitions }

    # Auto-scale for large pp to keep runtimes manageable
    if ($PP -ge 131072 -and $Reps -lt 0) { $reps = [math]::Min($reps, 1) }
    if ($PP -ge 65536  -and $TG   -lt 0) { $gen  = [math]::Min($gen, 32) }

    $totalCtx = $PP + $gen
    $kvGB     = Get-KVCacheSizeGB $totalCtx $KVType
    $estVRAM  = Get-EstVRAMGB $totalCtx $KVType
    $eta      = Get-EstRuntime $PP $gen $reps

    Write-Host "`n=== $Label ===" -ForegroundColor Cyan
    Write-Host "    pp=$PP  n=$gen  reps=$reps  ctx=$totalCtx  KV=$KVType ($kvGB GB)  est.VRAM=$estVRAM GB  ETA=$eta" -ForegroundColor DarkGray

    $pollerJob = Start-VRAMPoller

    # b2500 has no -c flag — context = pp + n
    $benchArgs = @(
        "-m", $ModelPath,
        "-r", $reps,
        "-p", $PP,
        "-n", $gen,
        "--progress",
        "-o", "md"
    ) + $ExtraArgs

    $out = & $LlamaBench @benchArgs 2>&1
    $peakVRAM = Stop-VRAMPoller $pollerJob

    # Print bench table to console (pipe-delimited rows only — skip build/device lines)
    $out | Where-Object { $_ -match '^\|' } | ForEach-Object { Write-Host $_ -ForegroundColor White }
    if ($null -ne $peakVRAM) { Write-Host "    Peak VRAM: $peakVRAM GB" -ForegroundColor Green }

    $metaLines = @()
    if ($null -ne $peakVRAM) { $metaLines += "### **Peak VRAM (measured):** $peakVRAM GB" }
    $metaLines += "### **Context:** $totalCtx tokens (pp+n)  |  **KV ($KVType):** $kvGB GB  |  **Est. VRAM:** $estVRAM GB"

    if ($Ladder) {
        $ppTps = $null
        foreach ($line in $out) {
            if ($line -match "pp$PP\s*\|" -and $line -match '\|\s*([\d]+\.[\d]+)\s*±') {
                $ppTps = [double]$Matches[1]; break
            }
        }
        $script:LadderStats.Add(@{
            Label    = $Label
            PP       = $PP
            Gen      = $gen
            Reps     = $reps
            KVType   = $KVType
            EstVRAM  = $estVRAM
            PeakVRAM = $peakVRAM
            PPTps    = $ppTps
        })
    }

    return @{ Out = $out; Meta = $metaLines }
}

# =============================================================================
# HEADER
# =============================================================================

$sysBaseline = Get-SystemSnapshot

# VRAM at max context — reference for what fits at 262K
$kvQ4   = Get-KVCacheSizeGB $FIXED_CTX "q4_0"
$kvQ8   = Get-KVCacheSizeGB $FIXED_CTX "q8_0"
$kvF16  = Get-KVCacheSizeGB $FIXED_CTX "f16"
$estQ4  = Get-EstVRAMGB $FIXED_CTX "q4_0"
$estQ8  = Get-EstVRAMGB $FIXED_CTX "q8_0"
$estF16 = Get-EstVRAMGB $FIXED_CTX "f16"

$Results  = @()
$Results += "# Benchmark 262K — $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
$Results += "- Model: $(Split-Path $ModelPath -Leaf)"
$Results += "- Config: $Config | Repetitions: $Repetitions (auto-1 for pp≥128K) | NGen: $NGen (auto-32 for pp≥64K)"
$Results += "- Target context: $FIXED_CTX tokens | b2500 has no -c flag — context = pp+n per test"
$Results += "- llama.cpp build: b8407 | ROCm 7.2.1 | HSA_ENABLE_SDMA=0 | Force: $($Force.IsPresent)"
$Results += "- Hardware: RX 7900 XTX ${VRAM_TOTAL_GB}GB | Ryzen 9 9900X | 128GB DDR5"
$Results += ""
$Results += "## System Resources (pre-benchmark)"
$Results += (Format-SnapshotMD $sysBaseline)
$Results += ""
$Results += "## VRAM Budget at ctx=$FIXED_CTX (max context reference)"
$Results += ""
$Results += "| KV Type | KV Cache GB | Model GB | **Total Est. GB** | Fits 24GB? |"
$Results += "|---------|------------:|---------:|------------------:|:----------:|"
$Results += "| q4_0    | $kvQ4       | $MODEL_VRAM_GB | **$estQ4**   | ✅ Yes (~23.3 GB) |"
$Results += "| q8_0    | $kvQ8       | $MODEL_VRAM_GB | **$estQ8**   | ❌ OOM (~30.3 GB) |"
$Results += "| f16     | $kvF16      | $MODEL_VRAM_GB | **$estF16**  | ❌ OOM (~44.3 GB) |"
$Results += ""
$Results += "> q4_0 is the only viable KV type at 262K context on 24GB VRAM."
$Results += "> Tests use context = pp + n (b2500 has no -c flag). Stress test: pp=262016 + n=128 = 262144 exactly."
$Results += "> All tests: -ngl 41 -fa 1 -mmp 0 -ctk q4_0 -ctv q4_0"
$Results += ""

# =============================================================================
# LADDER: q4_0 KV, ctx=262144 fixed, pp varies 8K → 262K
# Goal: pp throughput degradation as prompt fills toward the 262K window
# VRAM stays ~23.25 GB throughout (KV pre-allocated for 262K tokens always)
# =============================================================================
if ($Config -eq "ladder" -or $Config -eq "all") {
    # Guard against worst-case ladder step: 262016pp + 32n = 262048 tokens
    if (-not (Test-VRAMFeasible "ladder" (262016 + 32) "q4_0")) {
        Write-Warning "Ladder skipped — q4_0 at max step exceeds VRAM guard."
    } else {
        $Results += "---"
        $Results += "## Section 1: Context Scaling Ladder (q4_0 KV)"
        $Results += ""
        $Results += "> **Goal:** measure pp t/s as prompt size grows 8K → 262K tokens."
        $Results += "> Context = pp + n per test (b2500 has no -c flag). VRAM grows with pp."
        $Results += "> pp≥64K: n auto-reduces to 32. pp≥128K: reps auto-reduces to 1."
        $Results += ""

        $ladderSteps = @(
            @{ PP = 8192;   Label = "8K prompt" }
            @{ PP = 32768;  Label = "32K prompt" }
            @{ PP = 65536;  Label = "64K prompt" }
            @{ PP = 131072; Label = "128K prompt" }
            @{ PP = 196608; Label = "192K prompt" }
            @{ PP = 262016; Label = "262K prompt (max)" }
        )

        foreach ($step in $ladderSteps) {
            $r = Invoke-Bench $step.Label `
                 @("-ngl", "41", "-ctk", "q4_0", "-ctv", "q4_0", "-mmp", "0", "-fa", "1") `
                 -PP $step.PP -KVType "q4_0" -Ladder
            $Results += "### $($step.Label)"
            $Results += $r.Meta
            $Results += ($r.Out | Out-String)
        }

        if ($LadderStats.Count -gt 0) {
            $Results += "### Ladder Summary — pp Throughput vs Prompt Size"
            $Results += ""
            $Results += "| Prompt Size | pp tokens | n tokens | reps | Est. VRAM | Peak VRAM | pp t/s |"
            $Results += "|-------------|----------:|---------:|-----:|----------:|----------:|-------:|"
            foreach ($s in $LadderStats) {
                $tpsStr  = if ($null -ne $s.PPTps)    { $s.PPTps }           else { "—" }
                $peakStr = if ($null -ne $s.PeakVRAM) { "$($s.PeakVRAM) GB" } else { "—" }
                $Results += "| $($s.Label) | $($s.PP) | $($s.Gen) | $($s.Reps) | $($s.EstVRAM) GB | $peakStr | $tpsStr |"
            }
            $Results += ""
        }
    }
}

# =============================================================================
# UBATCH: micro-batch sweep at pp=8K, 32K, and 128K (q4_0, ctx=262144)
# Goal: find optimal ubatch for pp throughput at real long-context prompt sizes
# At pp=512 ubatch was flat (existing data). At pp=32K+ it becomes critical.
# ubatch controls how prefill is chunked — larger = fewer kernel launches.
# =============================================================================
if ($Config -eq "ubatch" -or $Config -eq "all") {
    # Worst-case ubatch step: 131072pp + 32n = 131104 tokens
    if (-not (Test-VRAMFeasible "ubatch" (131072 + 32) "q4_0")) {
        Write-Warning "ubatch skipped — q4_0 at pp=128K exceeds VRAM guard."
    } else {
        $Results += "---"
        $Results += "## Section 2: ubatch Sweep (q4_0 KV)"
        $Results += ""
        $Results += "> **Goal:** optimal micro-batch size for prefill at production prompt depths."
        $Results += "> ubatch is the kernel chunk size for prompt processing."
        $Results += "> Prior data: 512/1024/2048 flat at pp=512. Testing where it matters: pp=8K, 32K, 128K."
        $Results += ""

        foreach ($pp in @(8192, 32768, 131072)) {
            $ppLabel = switch ($pp) { 8192 { "8K" } 32768 { "32K" } 131072 { "128K" } default { "${pp}" } }
            $Results += "### ubatch @ pp=$ppLabel (q4_0 KV)"
            foreach ($ub in @(512, 1024, 2048, 4096)) {
                $r = Invoke-Bench "ubatch $ub @ pp=$ppLabel" `
                     @("-ngl", "41", "-ctk", "q4_0", "-ctv", "q4_0", "-mmp", "0", "-fa", "1", "-ub", "$ub") `
                     -PP $pp -KVType "q4_0"
                $Results += "#### ubatch $ub — pp=$ppLabel"
                $Results += $r.Meta
                $Results += ($r.Out | Out-String)
            }
        }
    }
}

# =============================================================================
# STRESS: pp=262016, n=32, reps=1, q4_0 KV, ctx=262144
# Goal: validate full 262K context fits and capture real max-context throughput
# pp + n = 262048, within model max ctx of 262144
# WARNING: ~45-60 min runtime. Est. VRAM: ~23.25 GB.
# =============================================================================
if ($Config -eq "stress" -or $Config -eq "all") {
    $stressPP  = 262016
    $stressTG  = 128   # pp+n = 262144 exactly (model max)
    $stressCtx = $stressPP + $stressTG
    $stressEst = Get-EstVRAMGB $stressCtx "q4_0"

    $Results += "---"
    $Results += "## Section 3: 262K Stress Test (q4_0 KV, pp=$stressPP, n=$stressTG)"
    $Results += ""
    $Results += "> **Goal:** validate full 262144-token context fits and measure max-context pp throughput."
    $Results += "> pp=$stressPP + n=$stressTG = $stressCtx tokens — Qwen3 model max ($FIXED_CTX)."
    $Results += "> Est. VRAM: ~$stressEst GB. Runtime: ~45-60 min. Requires -Force."
    $Results += ""

    if (Test-VRAMFeasible "262K-stress" $stressCtx "q4_0") {
        Write-Host ""
        Write-Host "WARNING: 262K stress test — est. runtime 45-60 min, est. VRAM $stressEst GB" -ForegroundColor Yellow
        Write-Host "         Press Ctrl+C to abort" -ForegroundColor Yellow

        $r = Invoke-Bench "262K STRESS (pp=$stressPP, n=$stressTG, reps=1)" `
             @("-ngl", "41", "-ctk", "q4_0", "-ctv", "q4_0", "-mmp", "0", "-fa", "1") `
             -PP $stressPP -TG $stressTG -Reps 1 -KVType "q4_0" -Ladder

        $Results += "### Result"
        $Results += $r.Meta
        $Results += ($r.Out | Out-String)
    }

    $Results += "> **If OOM:** retry with `-ncmoe 5` to offload 5 MoE layers to CPU (~1-2 GB less VRAM, ~5% slower pp)."
}

# =============================================================================
# OUTPUT
# =============================================================================

$Results | Out-File $OutFile -Encoding UTF8
Write-Host ""
Write-Host "Results saved to: $OutFile" -ForegroundColor Green

if ($LadderStats.Count -gt 0) {
    Write-Host ""
    Write-Host "Ladder Summary (target ctx=$FIXED_CTX, q4_0 KV):" -ForegroundColor Cyan
    Write-Host ("{0,-24} {1,10} {2,8} {3,10} {4,12}" -f "Config", "pp tokens", "KV", "Peak VRAM", "pp t/s")
    Write-Host ("-" * 70)
    foreach ($s in $LadderStats) {
        $tpsStr  = if ($null -ne $s.PPTps)    { "{0,12:F1}" -f $s.PPTps }        else { "           —" }
        $peakStr = if ($null -ne $s.PeakVRAM) { "{0,8:F2} GB" -f $s.PeakVRAM }  else { "       —" }
        Write-Host ("{0,-24} {1,10} {2,8} {3,12} {4}" -f $s.Label, $s.PP, $s.KVType, $peakStr, $tpsStr)
    }
}
