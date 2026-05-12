#Requires -Version 5.1
# Quick token-rate benchmark against Ollama API
# Configs: short (default), longctx (64k prompt), all

param(
    [string]$Model   = "qwen3-coder-30b",
    [string]$ApiBase = "http://localhost:11434",
    [int]$Runs       = 3,
    [ValidateSet("short","longctx","all")]
    [string]$Config  = "short"
)

# --- prompts -----------------------------------------------------------------

$shortPrompt = "Write a quicksort implementation in Python with comments explaining each step."

function Make-LongPrompt([int]$TargetTokens = 64000) {
    # ~4 chars per token; repeat a code block to fill context
    $block = @'
# Fibonacci with memoization
def fib(n, memo={}):
    if n in memo: return memo[n]
    if n <= 1: return n
    memo[n] = fib(n-1, memo) + fib(n-2, memo)
    return memo[n]

'@
    $targetChars = $TargetTokens * 4
    $sb = [System.Text.StringBuilder]::new($targetChars + 1000)
    $sb.Append("Below is a large codebase. Summarize what it does in one sentence.`n`n") | Out-Null
    while ($sb.Length -lt $targetChars) { $sb.Append($block) | Out-Null }
    return $sb.ToString().Substring(0, $targetChars)
}

# --- runner ------------------------------------------------------------------

function Invoke-Run([string]$label, [int]$n, [string]$prompt) {
    $body = @{
        model    = $Model
        messages = @(@{ role = "user"; content = $prompt })
        stream   = $false
        options  = @{ num_predict = 128 }   # cap generation for long-ctx test
    } | ConvertTo-Json -Compress -Depth 5

    $start = Get-Date
    try {
        $r = Invoke-RestMethod -Uri "$ApiBase/api/chat" -Method POST `
             -ContentType "application/json" -Body $body -TimeoutSec 600
    } catch {
        Write-Warning "[$label] Run $n failed: $_"
        return $null
    }
    $wall = ((Get-Date) - $start).TotalSeconds

    return [PSCustomObject]@{
        Config = $label
        Run    = $n
        pp     = [math]::Round($r.prompt_eval_count / ($r.prompt_eval_duration / 1e9), 1)
        tg     = [math]::Round($r.eval_count        / ($r.eval_duration        / 1e9), 1)
        pp_tok = $r.prompt_eval_count
        tg_tok = $r.eval_count
        wall   = [math]::Round($wall, 1)
    }
}

function Run-Config([string]$label, [string]$prompt, [int]$runs) {
    $chars = $prompt.Length
    $estTok = [math]::Round($chars / 4)
    Write-Host ""
    Write-Host "--- $label  (~$estTok prompt tokens) ---"
    $res = @()
    foreach ($i in 1..$runs) {
        Write-Host -NoNewline "  Run $i/$runs ... "
        $r = Invoke-Run $label $i $prompt
        if ($r) {
            $res += $r
            Write-Host "pp=$($r.pp) t/s  tg=$($r.tg) t/s  tg_tok=$($r.tg_tok)  wall=$($r.wall)s"
        }
    }
    return $res
}

function Print-Summary([object[]]$results) {
    if (-not $results) { return }
    $groups = $results | Group-Object Config
    foreach ($g in $groups) {
        $avg_pp = [math]::Round(($g.Group.pp | Measure-Object -Average).Average, 1)
        $avg_tg = [math]::Round(($g.Group.tg | Measure-Object -Average).Average, 1)
        $min_tg = ($g.Group.tg | Measure-Object -Minimum).Minimum
        $max_tg = ($g.Group.tg | Measure-Object -Maximum).Maximum
        Write-Host "$($g.Name.PadRight(10))  avg pp: $avg_pp t/s   avg tg: $avg_tg t/s  (min $min_tg  max $max_tg)"
    }
}

# --- preflight ---------------------------------------------------------------

try { Invoke-RestMethod "$ApiBase/api/tags" -ErrorAction Stop | Out-Null }
catch { Write-Error "Ollama not reachable at $ApiBase"; exit 1 }

Write-Host ""
Write-Host "Model  : $Model"
Write-Host "Config : $Config"
Write-Host "Runs   : $Runs"

# --- run configs -------------------------------------------------------------

$all = @()

if ($Config -in "short","all") {
    $all += Run-Config "short" $shortPrompt $Runs
}

if ($Config -in "longctx","all") {
    Write-Host ""
    Write-Host "Building 64k-token prompt..."
    $longPrompt = Make-LongPrompt 64000
    $all += Run-Config "longctx-64k" $longPrompt $Runs
}

# --- summary -----------------------------------------------------------------

Write-Host ""
Write-Host "=== $Model — summary ==="
$all | Format-Table Config, Run, pp, tg, pp_tok, tg_tok, wall -AutoSize
Print-Summary $all
