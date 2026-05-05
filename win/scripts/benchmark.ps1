#Requires -Version 5.1
# Benchmark: baseline vs optimized config using llama-bench.exe and llama-server.exe
# Measures prompt processing (pp) and token generation (tg) tokens/sec
# Now supports random available port for server-based benchmarking

param(
    [string]$ModelPath = "D:\opt\models\lmstudio\lmstudio-community\Qwen3-Coder-30B-A3B-Instruct-GGUF\Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf",
    [string]$Config = "both",   # baseline | optimized | kv-only | ubatch | all | server
    [int]$Repetitions = 3,
    [int]$NPrompt = 512,
    [int]$NGen = 128,
    [int]$ServerPort = 0  # 0 means auto-find random available port
)

# Force UTF-8 so llama-bench's ± character doesn't get mangled
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$LlamaDir = "C:\opt\llama-hip-amd721\llama-b8407-windows-rocm-7.2.1-gfx110X-gfx115X-gfx120X-x64"
$LlamaBench = "$LlamaDir\llama-bench.exe"
$LlamaServer = "$LlamaDir\llama-server.exe"
$env:PATH = "$LlamaDir;" + $env:PATH

if (-not (Test-Path $LlamaBench)) { Write-Error "llama-bench.exe not found at $LlamaBench"; exit 1 }
if (-not (Test-Path $ModelPath))   { Write-Error "Model not found: $ModelPath"; exit 1 }

# Reduces DMA overhead on AMD RDNA3 — often +5-15% throughput
$env:HSA_ENABLE_SDMA = "0"

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$OutFile = "$PSScriptRoot\benchmark_results_$Timestamp.md"

# Function to find a random available port
function Get-RandomAvailablePort {
    param([int]$StartPort = 49152, [int]$EndPort = 65535)

    # Try up to 20 random ports
    for ($i = 0; $i -lt 20; $i++) {
        $port = Get-Random -Minimum $StartPort -Maximum $EndPort

        # Check if port is available (not in use)
        try {
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $tcpClient.BeginConnect("127.0.0.1", $port, $null, $null).AsyncWaitHandle.WaitOne(100, $false) | Out-Null
            $tcpClient.Close()
            # If we can connect, port is in use, try another
        } catch {
            # If we can't connect, port might be available
            try {
                $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $port)
                $listener.Start()
                $listener.Stop()
                return $port
            } catch {
                # Port is likely in use, continue to next
            }
        }
    }

    # Fallback: return a default random port
    return Get-Random -Minimum 49152 -Maximum 65535
}

# Function to start llama-server on a specific port
function Start-LlamaServer {
    param([string]$ModelPath, [int]$Port, [string[]]$ExtraArgs)

    $args = @(
        "-m", $ModelPath,
        "--port", $Port
    ) + $ExtraArgs

    Write-Host "Starting llama-server on port $Port..." -ForegroundColor Yellow
    $process = Start-Process -FilePath $LlamaServer -ArgumentList $args -PassThru -WindowStyle Hidden

    # Wait for server to be ready
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
        } catch {
            # Still waiting
        }
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
            prompt = "The quick brown fox jumps over the lazy dog. This is a test of the inference system."
            n_predict = $NGen
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
            $tokensPerSec = if ($duration -gt 0) { $NGen / $duration } else { 0 }

            $results += "- Rep $r: $($tokensPerSec.ToString('F2')) tokens/sec"
        } catch {
            $results += "- Rep $r: ERROR - $($_.ToString())"
        }
    }
    
    return $results -join "`n"
}

# Main execution logic
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

if ($Config -eq "optimized" -or $Config -eq "both" -or $Config -eq "all") {
    $Results += "## Optimized (MoE CPU offload, q4_0 KV, no-mmap)"
    $out = Run-Bench "OPTIMIZED" @("-ngl", "41", "-ncmoe", "35", "-ctk", "q4_0", "-ctv", "q4_0", "-mmp", "0", "-fa", "1")
    $Results += ($out | Out-String)
}

# KV quant only — no CPU offload. Saves VRAM for larger context, minimal speed hit.
if ($Config -eq "kv-only" -or $Config -eq "all") {
    $Results += "## KV-quant only (GPU full, q4_0 KV, no-mmap)"
    $out = Run-Bench "KV-ONLY" @("-ngl", "41", "-ctk", "q4_0", "-ctv", "q4_0", "-mmp", "0", "-fa", "1")
    $Results += ($out | Out-String)
}

# Larger ubatch — helps prompt processing throughput on 24GB GPU.
if ($Config -eq "ubatch" -or $Config -eq "all") {
    $Results += "## Baseline + ubatch 2048"
    $out = Run-Bench "UBATCH" @("-ngl", "41", "-mmp", "1", "-fa", "1", "-ub", "2048")
    $Results += ($out | Out-String)
}

# Server-based benchmark using random available port
if ($Config -eq "server" -or $Config -eq "all") {
    # Use specified port or find random available port
    if ($ServerPort -eq 0) {
        $ServerPort = Get-RandomAvailablePort
        Write-Host "Using random available port: $ServerPort" -ForegroundColor Green
    }
    
    # Start server
    $serverProcess = Start-LlamaServer -ModelPath $ModelPath -Port $ServerPort @("-ngl", "41")
    
    if ($serverProcess) {
        try {
            $serverResults = Run-ServerBench "SERVER" $ServerPort
            $Results += $serverResults
        } finally {
            # Cleanup server process
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
