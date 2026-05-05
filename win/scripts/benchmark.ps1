#Requires -Version 5.1
# Benchmark: measure prompt processing (pp) and token generation (tg) tokens/sec
# Uses llama-bench.exe directly — not llama-server

param(
    [string]$ModelPath   = "D:\opt\models\lmstudio\lmstudio-community\Qwen3-Coder-30B-A3B-Instruct-GGUF\Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf",
    [string]$Config      = "both",   # baseline | optimized | kv-only | ubatch | highctx | q8kv | largectx | maxvram | all | server
    [int]$Repetitions    = 3,
    [int]$NPrompt        = 512,
    [int]$NGen           = 128,
    [int]$ServerPort     = 0  # 0 means auto-find random available port
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8

$LlamaDir   = "C:\opt\llama-hip-amd721\llama-b8407-windows-rocm-7.2.1-gfx110X-gfx115X-gfx120X-x64"
$LlamaBench = "$LlamaDir\llama-bench.exe"
$LlamaServer = "$LlamaDir\llama-server.exe"
$env:PATH   = "$LlamaDir;" + $env:PATH

# Reduces DMA overhead on RDNA3 — +5-15% throughput
$env:HSA_ENABLE_SDMA = "0"

if (-not (Test-Path $LlamaBench)) { Write-Error "llama-bench.exe not found: $LlamaBench"; exit 1 }
if (-not (Test-Path $ModelPath))  { Write-Error "Model not found: $ModelPath"; exit 1 }

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$OutFile   = "$PSScriptRoot\benchmark_results_$Timestamp.md"

# --- System resource helpers ---

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
    if ($snap.VRAMUsedGB -ne $null) { $lines += "- VRAM: $($snap.VRAMUsedGB) GB" }
    if ($snap.RAMUsedGB  -ne $null) { $lines += "- RAM:  $($snap.RAMUsedGB) / $($snap.RAMTotalGB) GB" }
    if ($snap.CPUPercent -ne $null) { $lines += "- CPU:  $($snap.CPUPercent)%" }
    if ($snap.GPUPercent -ne $null) { $lines += "- GPU:  $($snap.GPUPercent)% (3D)" }
    return $lines
}

# Polls VRAM in a background job every 500ms; returns job handle
function Start-VRAMPoller {
    $job = Start-Job -ScriptBlock {
        while ($true) {
            try {
                $v = (Get-Counter '\GPU Adapter Memory(*)\Dedicated Usage').CounterSamples |
                     Measure-Object CookedValue -Sum | Select-Object -ExpandProperty Sum
                [math]::Round($v / 1GB, 2)
            } catch {}
            Start-Sleep -Milliseconds 500
        }
    }
    return $job
}

function Stop-VRAMPoller {
    param($job)
    Stop-Job  $job -ErrorAction SilentlyContinue
    $samples = Receive-Job $job -ErrorAction SilentlyContinue
    Remove-Job $job -ErrorAction SilentlyContinue
    if ($samples -and $samples.Count -gt 0) {
        return ($samples | Measure-Object -Maximum).Maximum
    }
    return $null
}

# Theoretical KV cache size — Qwen3-30B-A3B: 28 layers, 8 KV heads (GQA), 128 head_dim
function Get-KVCacheSizeGB {
    param([int]$ContextTokens, [string]$KVType = "f16")
    $bytesPerElement = switch ($KVType) {
        "f16"  { 2.0 } "q8_0" { 1.0 } "q4_0" { 0.5 } default { 2.0 }
    }
    $elementsPerToken = 2 * 8 * 128 * 28  # K+V x kvHeads x headDim x layers
    return [math]::Round($elementsPerToken * $bytesPerElement * $ContextTokens / 1GB, 2)
}

function Run-Bench {
    param(
        [string]$Label,
        [string[]]$ExtraArgs,
        [int]$OverridePrompt = 0,
        [int]$OverrideGen    = 0,
        [string]$KVNote      = ""
    )
    Write-Host "`n=== $Label ===" -ForegroundColor Cyan

    $p = if ($OverridePrompt -gt 0) { $OverridePrompt } else { $NPrompt }
    $n = if ($OverrideGen    -gt 0) { $OverrideGen    } else { $NGen    }

    $pollerJob = Start-VRAMPoller

    $benchArgs = @(
        "-m", $ModelPath,
        "-r", $Repetitions,
        "-p", $p,
        "-n", $n,
        "--progress",
        "-o", "md"
    ) + $ExtraArgs
    $out = & $LlamaBench @benchArgs

    $peakVRAM = Stop-VRAMPoller $pollerJob

    $metaLines = @()
    if ($peakVRAM -ne $null) { $metaLines += "### **Peak VRAM (measured):** $peakVRAM GB" }
    if ($KVNote)              { $metaLines += "### **Est. KV cache:** $KVNote" }

    return @{ Out = $out; Meta = $metaLines }
}

# Function to find a random available port
function Get-RandomAvailablePort {
    param([int]$StartPort = 49152, [int]$EndPort = 65535)
    for ($i = 0; $i -lt 20; $i++) {
        $port = Get-Random -Minimum $StartPort -Maximum $EndPort
        try {
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $tcpClient.BeginConnect("127.0.0.1", $port, $null, $null).AsyncWaitHandle.WaitOne(100, $false) | Out-Null
            $tcpClient.Close()
        } catch {
            try {
                $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $port)
                $listener.Start()
                $listener.Stop()
                return $port
            } catch { }
        }
    }
    return Get-Random -Minimum 49152 -Maximum 65535
}

# Function to start llama-server on a specific port
function Start-LlamaServer {
    param([string]$ModelPath, [int]$Port, [string[]]$ExtraArgs)
    $srvArgs = @("-m", $ModelPath, "--port", $Port) + $ExtraArgs
    Write-Host "Starting llama-server on port $Port..." -ForegroundColor Yellow
    $process = Start-Process -FilePath $LlamaServer -ArgumentList $srvArgs -PassThru -WindowStyle Hidden
    $maxWait = 30
    $waited = 0
    do {
        Start-Sleep -Seconds 1
        $waited++
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:$Port/health" -TimeoutSec 2 -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) {
                Write-Host "Server ready on port $Port" -ForegroundColor Green
                return $process
            }
        } catch { }
    } while ($waited -lt $maxWait)
    Write-Error "Server failed to start within $maxWait seconds"
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    return $null
}

# Function to run server-based benchmark
function Run-ServerBench {
    param([string]$Label, [int]$Port, [string[]]$ExtraArgs)
    Write-Host "`n=== $Label (Server on port $Port) ===" -ForegroundColor Cyan
    $results = @()
    $results += "### $Label (Port: $Port)"
    $results += ""
    for ($r = 1; $r -le $Repetitions; $r++) {
        Write-Host "  Repetition $r/$Repetitions..." -ForegroundColor Gray
        $payload = @{
            prompt      = "The quick brown fox jumps over the lazy dog. This is a test of the inference system."
            n_predict   = $NGen
            temperature = 0.7
        } | ConvertTo-Json
        $startTime = Get-Date
        try {
            $response = Invoke-RestMethod -Uri "http://localhost:$Port/completion" `
                -Method Post `
                -Body $payload `
                -ContentType "application/json" `
                -TimeoutSec 60
            $endTime = Get-Date
            $duration = ($endTime - $startTime).TotalSeconds
            $tps = if ($duration -gt 0) { [math]::Round($NGen / $duration, 2) } else { 0 }
            $results += "- Rep $r`: $tps tokens/sec"
        } catch {
            $results += "- Rep $r`: ERROR - $_"
        }
    }
    return $results -join "`n"
}

# --- Capture baseline system state before any bench loads the model ---
$sysBaseline = Get-SystemSnapshot
$Results  = @()
$Results += "# Benchmark Results -- $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
$Results += "- Model: $ModelPath"
$Results += "- Repetitions: $Repetitions | Prompt tokens: $NPrompt | Gen tokens: $NGen"
$Results += "- llama.cpp build: b2500 | ROCm 7.2.1 | HSA_ENABLE_SDMA=0"
$Results += ""
$Results += "## System Resources (pre-benchmark, model not loaded)"
$Results += (Format-SnapshotMD $sysBaseline)
$Results += ""
$Results += "## All Tests Run with MAX CONTEXT = 262,144 tokens"
$Results += ""

# --- Baseline: full GPU, f16 KV, mmap on -- fastest for 24GB+ VRAM ---
if ($Config -eq "baseline" -or $Config -eq "both" -or $Config -eq "all") {
    $ctxToks = 262144  # Max context window for benchmark
    $kvGB = Get-KVCacheSizeGB -ContextTokens $ctxToks -KVType "f16"
    $Results += "## Baseline (GPU full, f16 KV, mmap on, FA) -- MAX CONTEXT 262K"
    $r = Run-Bench "BASELINE-MAXCTX" @("-ngl", "41", "-mmp", "1", "-fa", "1") `
         -OverridePrompt 262144 -OverrideGen 128 `
         -KVNote "f16 @ $ctxToks tokens = ~$kvGB GB (model 17.35 + KV ~$kvGB = ~$([math]::Round(17.35+$kvGB,1)) GB total)"
    $Results += $r.Meta
    $Results += ($r.Out | Out-String)
}

# --- Optimized: MoE CPU offload -- for low-VRAM GPUs (<20GB), HURTS on 24GB ---
if ($Config -eq "optimized" -or $Config -eq "both" -or $Config -eq "all") {
    $ctxToks = 262144  # Max context window for benchmark
    $kvGB = Get-KVCacheSizeGB -ContextTokens $ctxToks -KVType "q4_0"
    $Results += "## Optimized (MoE CPU offload, q4_0 KV, no-mmap) -- MAX CONTEXT 262K [low-VRAM only]"
    $r = Run-Bench "OPTIMIZED-MAXCTX" @("-ngl", "41", "-ncmoe", "35", "-ctk", "q4_0", "-ctv", "q4_0", "-mmp", "0", "-fa", "1") `
         -OverridePrompt 262144 -OverrideGen 128 `
         -KVNote "q4_0 @ $ctxToks tokens = ~$kvGB GB"
    $Results += $r.Meta
    $Results += ($r.Out | Out-String)
}

# --- KV-quant only: full GPU + q4_0 KV, no CPU offload -- baseline for highctx configs ---
if ($Config -eq "kv-only" -or $Config -eq "all") {
    $ctxToks = 262144  # Max context window for benchmark
    $kvGB = Get-KVCacheSizeGB -ContextTokens $ctxToks -KVType "q4_0"
    $Results += "## KV-quant only (GPU full, q4_0 KV, no-mmap, FA) -- MAX CONTEXT 262K"
    $r = Run-Bench "KV-ONLY-MAXCTX" @("-ngl", "41", "-ctk", "q4_0", "-ctv", "q4_0", "-mmp", "0", "-fa", "1") `
         -OverridePrompt 262144 -OverrideGen 128 `
         -KVNote "q4_0 @ $ctxToks tokens = ~$kvGB GB"
    $Results += $r.Meta
    $Results += ($r.Out | Out-String)
}

# --- q8kv: near-lossless KV -- quality reference, ~2x context vs f16 ---
if ($Config -eq "q8kv" -or $Config -eq "all") {
    $ctxToks = 262144  # Max context window for benchmark
    $kvGB = Get-KVCacheSizeGB -ContextTokens $ctxToks -KVType "q8_0"
    $Results += "## q8kv (GPU full, q8_0 KV, no-mmap, FA) -- near-lossless, MAX CONTEXT 262K"
    $r = Run-Bench "Q8KV-MAXCTX" @("-ngl", "41", "-ctk", "q8_0", "-ctv", "q8_0", "-mmp", "0", "-fa", "1") `
         -OverridePrompt 262144 -OverrideGen 128 `
         -KVNote "q8_0 @ $ctxToks tokens = ~$kvGB GB"
    $Results += $r.Meta
    $Results += ($r.Out | Out-String)
}

# --- highctx: q4_0 KV at 8K context -- tests large-context throughput with low KV footprint ---
if ($Config -eq "highctx" -or $Config -eq "all") {
    $ctxToks = 262144  # Max context window for benchmark
    $kvGB = Get-KVCacheSizeGB -ContextTokens $ctxToks -KVType "q4_0"
    $Results += "## highctx (GPU full, q4_0 KV, no-mmap, FA) -- MAX CONTEXT 262K throughput"
    $r = Run-Bench "HIGHCTX-MAXCTX" @("-ngl", "41", "-ctk", "q4_0", "-ctv", "q4_0", "-mmp", "0", "-fa", "1") `
         -OverridePrompt 262144 -OverrideGen 128 `
         -KVNote "q4_0 @ $ctxToks tokens = ~$kvGB GB (model 17.35 + KV ~$kvGB = ~$([math]::Round(17.35+$kvGB,1)) GB total)"
    $Results += $r.Meta
    $Results += ($r.Out | Out-String)
}

# --- largectx: f16 KV at 8K context -- uses ~18.3 GB VRAM, quality KV at real context depth ---
if ($Config -eq "largectx" -or $Config -eq "all") {
    $ctxToks = 262144  # Max context window for benchmark
    $kvGB = Get-KVCacheSizeGB -ContextTokens $ctxToks -KVType "f16"
    $Results += "## largectx (GPU full, f16 KV, no-mmap, FA) -- MAX CONTEXT 262K, f16 KV"
    $r = Run-Bench "LARGECTX-MAXCTX" @("-ngl", "41", "-mmp", "0", "-fa", "1") `
         -OverridePrompt 262144 -OverrideGen 128 `
         -KVNote "f16 @ $ctxToks tokens = ~$kvGB GB (model 17.35 + KV ~$kvGB = ~$([math]::Round(17.35+$kvGB,1)) GB total)"
    $Results += $r.Meta
    $Results += ($r.Out | Out-String)
}

# --- maxvram: f16 KV at 262K context -- uses ~21 GB VRAM, exercises remaining VRAM headroom ---
if ($Config -eq "maxvram" -or $Config -eq "all") {
    $ctxToks = 262144 + 128
    $kvGB = Get-KVCacheSizeGB -ContextTokens $ctxToks -KVType "f16"
    $Results += "## maxvram (GPU full, f16 KV, no-mmap, FA) -- MAX CONTEXT 262K, ~21 GB VRAM"
    $r = Run-Bench "MAXVRAM-MAXCTX" @("-ngl", "41", "-mmp", "0", "-fa", "1") `
         -OverridePrompt 262144 -OverrideGen 128 `
         -KVNote "f16 @ $ctxToks tokens = ~$kvGB GB (model 17.35 + KV ~$kvGB = ~$([math]::Round(17.35+$kvGB,1)) GB total)"
    $Results += $r.Meta
    $Results += ($r.Out | Out-String)
}

# --- ubatch sweep: find optimal micro-batch for this GPU ---
if ($Config -eq "ubatch" -or $Config -eq "all") {
    $ctxToks = 262144  # Max context window for benchmark
    $kvGB = Get-KVCacheSizeGB -ContextTokens $ctxToks -KVType "f16"

    $Results += "## ubatch 512 (default) -- MAX CONTEXT 262K"
    $r = Run-Bench "UBATCH-512-MAXCTX" @("-ngl", "41", "-mmp", "1", "-fa", "1", "-ub", "512") `
         -OverridePrompt 262144 -OverrideGen 128 `
         -KVNote "f16 @ $ctxToks tokens = ~$kvGB GB"
    $Results += $r.Meta
    $Results += ($r.Out | Out-String)

    $Results += "## ubatch 1024 -- MAX CONTEXT 262K"
    $r = Run-Bench "UBATCH-1024-MAXCTX" @("-ngl", "41", "-mmp", "1", "-fa", "1", "-ub", "1024") `
         -OverridePrompt 262144 -OverrideGen 128 `
         -KVNote "f16 @ $ctxToks tokens = ~$kvGB GB"
    $Results += $r.Meta
    $Results += ($r.Out | Out-String)

    $Results += "## ubatch 2048 -- MAX CONTEXT 262K"
    $r = Run-Bench "UBATCH-2048-MAXCTX" @("-ngl", "41", "-mmp", "1", "-fa", "1", "-ub", "2048") `
         -OverridePrompt 262144 -OverrideGen 128 `
         -KVNote "f16 @ $ctxToks tokens = ~$kvGB GB"
    $Results += $r.Meta
    $Results += ($r.Out | Out-String)
}

# --- Server-based benchmark using random available port ---
if ($Config -eq "server" -or $Config -eq "all") {
    if ($ServerPort -eq 0) {
        $ServerPort = Get-RandomAvailablePort
        Write-Host "Using random available port: $ServerPort" -ForegroundColor Green
    }
    $serverProcess = Start-LlamaServer -ModelPath $ModelPath -Port $ServerPort @("-ngl", "41")
    if ($serverProcess) {
        try {
            $serverResults = Run-ServerBench "SERVER" $ServerPort
            $Results += $serverResults
        } finally {
            if ($serverProcess -and !$serverProcess.HasExited) {
                Stop-Process -Id $serverProcess.Id -Force -ErrorAction SilentlyContinue
                Write-Host "Server process stopped." -ForegroundColor Yellow
            }
        }
    } else {
        $Results += "## SERVER (Failed to start)"
        $Results += "Could not start llama-server on port $ServerPort"
    }
}

$Results | Out-File $OutFile -Encoding UTF8
Write-Host "`nResults saved to: $OutFile" -ForegroundColor Green