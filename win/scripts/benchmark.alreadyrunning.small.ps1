#Requires -Version 5.1
# Quick token-rate benchmark against Ollama API

param(
    [string]$Model   = "qwen3-coder-30b",
    [string]$ApiBase = "http://localhost:11434",
    [int]$Runs       = 3,
    [string]$Prompt  = "Write a quicksort implementation in Python with comments explaining each step."
)

function Invoke-Run([int]$n) {
    $body = @{
        model    = $Model
        messages = @(@{ role = "user"; content = $Prompt })
        stream   = $false
    } | ConvertTo-Json -Compress

    $start = Get-Date
    try {
        $r = Invoke-RestMethod -Uri "$ApiBase/api/chat" -Method POST `
             -ContentType "application/json" -Body $body -TimeoutSec 300
    } catch {
        Write-Warning "Run $n failed: $_"
        return $null
    }
    $wall = ((Get-Date) - $start).TotalSeconds

    return [PSCustomObject]@{
        Run    = $n
        pp     = [math]::Round($r.prompt_eval_count  / ($r.prompt_eval_duration  / 1e9), 1)
        tg     = [math]::Round($r.eval_count         / ($r.eval_duration         / 1e9), 1)
        pp_tok = $r.prompt_eval_count
        tg_tok = $r.eval_count
        wall   = [math]::Round($wall, 1)
    }
}

# --- preflight ---------------------------------------------------------------

try { Invoke-RestMethod "$ApiBase/api/tags" -ErrorAction Stop | Out-Null }
catch { Write-Error "Ollama not reachable at $ApiBase"; exit 1 }

Write-Host ""
Write-Host "Model : $Model"
Write-Host "Runs  : $Runs"
Write-Host "Prompt: $($Prompt.Substring(0,[math]::Min(60,$Prompt.Length)))..."
Write-Host ""

# --- runs --------------------------------------------------------------------

$results = @()
foreach ($i in 1..$Runs) {
    Write-Host -NoNewline "Run $i/$Runs ... "
    $r = Invoke-Run $i
    if ($r) {
        $results += $r
        Write-Host "pp=$($r.pp) t/s  tg=$($r.tg) t/s  tokens=$($r.tg_tok)  wall=$($r.wall)s"
    }
}

# --- summary -----------------------------------------------------------------

if (-not $results) { Write-Error "All runs failed."; exit 1 }

$avg_pp = [math]::Round(($results.pp | Measure-Object -Average).Average, 1)
$avg_tg = [math]::Round(($results.tg | Measure-Object -Average).Average, 1)
$min_tg = ($results.tg | Measure-Object -Minimum).Minimum
$max_tg = ($results.tg | Measure-Object -Maximum).Maximum

Write-Host ""
Write-Host "=== $Model — $Runs run summary ==="
$results | Format-Table Run, pp, tg, pp_tok, tg_tok, wall -AutoSize
Write-Host "Avg  pp : $avg_pp t/s"
Write-Host "Avg  tg : $avg_tg t/s  (min $min_tg  max $max_tg)"
