param([switch]$Stop, [switch]$NoBrowser, [switch]$NoAutoUpdate, [switch]$RedeployCurrent, [string]$AppCheckout, [string]$Distribution = 'Ubuntu')
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'live-deploy.ps1')
$stateDir = Join-Path $repo '.jac\stable-link'
New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
$configPath = Join-Path $stateDir 'config.json'
$launcherStop = Join-Path $stateDir 'stop'
if (!$AppCheckout -and (Test-Path -LiteralPath $configPath)) {
    $AppCheckout = (Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json).AppCheckout
}
if (!$AppCheckout) { $AppCheckout = $repo }
$AppCheckout = (Resolve-Path -LiteralPath $AppCheckout).Path
if ($Stop) {
    Set-Content -LiteralPath $launcherStop -Value 'stop'
    & wsl.exe -d $Distribution --cd $repo --exec bash scripts/stable-link.sh stop
    exit $LASTEXITCODE
}
if (!$NoAutoUpdate -and $AppCheckout -eq $repo) {
    throw 'Automatic updates require a separate clean app checkout. Set AppCheckout in .jac\stable-link\config.json; keep the hosting helpers in this checkout.'
}
$mutex = New-Object Threading.Mutex($false, 'Local\MLocalStableDemo')
try { $locked = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $locked = $true }
if (!$locked) { Write-Host 'Stable hosting is already running.'; $mutex.Dispose(); exit 0 }
if (Test-Path -LiteralPath $launcherStop) { Remove-Item -LiteralPath $launcherStop }
$appProcess = $null
$linkProcess = $null
$appState = Join-Path $AppCheckout '.jac\phone-share'
function Test-App {
    try {
        $response = Invoke-RestMethod -Uri 'http://127.0.0.1:8200/function/list_offers' -Method Post -ContentType 'application/json' -Body '{}' -TimeoutSec 10
        return $response.ok -and ($response.data.result -is [array])
    } catch { return $false }
}
function Start-Helper($name, $checkout, $script) {
    $child = Start-Process -FilePath 'wsl.exe' -ArgumentList "-d $Distribution --cd `"$checkout`" --exec bash $script" -WindowStyle Hidden -PassThru `
      -RedirectStandardOutput (Join-Path $stateDir "$name.log") -RedirectStandardError (Join-Path $stateDir "$name.err.log")
    # PowerShell 5 loses ExitCode after an asynchronous child exits unless its
    # native handle was retained while the child was still running.
    $null = $child.Handle
    return $child
}
function Start-HostedApp {
    New-Item -ItemType Directory -Force -Path $appState | Out-Null
    foreach ($name in @('stop','ready')) {
        $file = Join-Path $appState $name
        if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file }
    }
    $linuxCheckout = Invoke-DeployCommand wsl.exe @('-d',$Distribution,'--exec','wslpath','-u',$AppCheckout)
    $startedRevision = Invoke-DeployCommand git @('-C',$AppCheckout,'rev-parse','HEAD')
    $script:appProcess = Start-Helper 'app' $repo ('scripts/run-live-backend.sh "' + $linuxCheckout + '" ' + $startedRevision)
    $deadline = (Get-Date).AddMinutes(8)
    while (!(Test-App)) {
        $script:appProcess.Refresh()
        if ($script:appProcess.HasExited -or (Get-Date) -gt $deadline) { throw 'App startup failed. Check .jac\stable-link\app logs.' }
        Start-Sleep -Seconds 2
    }
}
function Stop-HostedApp {
    Set-Content -LiteralPath (Join-Path $appState 'stop') -Value 'stop'
    # Wait for the real WSL listening socket, including a backend started earlier.
    $deadline = (Get-Date).AddSeconds(60)
    do {
        & wsl.exe -d $Distribution --exec python3 -c 'import socket; s=socket.socket(); s.settimeout(1); result=s.connect_ex((socket.inet_ntoa(bytes([127,0,0,1])),8200)); s.close(); raise SystemExit(1 if result==0 else 0)' 2>$null
        if ($LASTEXITCODE -eq 0) {
            if ($script:appProcess -and !$script:appProcess.WaitForExit(30000)) { throw 'Backend supervisor has not exited yet.' }
            $script:appProcess = $null
            return
        }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    throw 'Backend did not stop within 60 seconds; no replacement process was started.'
}
function Prepare-Candidate([string]$Revision) {
    $archive = Join-Path $stateDir 'candidate.tar'
    Invoke-DeployCommand git @('-C',$AppCheckout,'archive','--format=tar',"--output=$archive",$Revision) | Out-Null
    $linuxArchive = Invoke-DeployCommand wsl.exe @('-d',$Distribution,'--exec','wslpath','-u',$archive)
    $check = Start-Helper 'candidate' $repo ('scripts/check-deployment.sh "' + $linuxArchive + '"')
    if (!$check.WaitForExit(600000)) { throw 'Candidate build exceeded ten minutes; the live app was left unchanged.' }
    $check.Refresh()
    if ($check.ExitCode -ne 0) { throw 'Candidate check/build failed. See .jac\stable-link\candidate logs.' }
    if (Test-Path -LiteralPath $launcherStop) { throw 'Hosting stop requested during candidate build.' }
}
$deploymentPath = Join-Path $stateDir 'deployment.json'
$deployment = @{activeRevision=(Invoke-DeployCommand git @('-C',$AppCheckout,'rev-parse','HEAD'));failedRevision='';status='running'}
if (Test-Path -LiteralPath $deploymentPath) {
    $saved = Get-Content -LiteralPath $deploymentPath -Raw | ConvertFrom-Json
    $deployment.failedRevision = $saved.failedRevision
}
function Save-Deployment([string]$Status) {
    $deployment.status = $Status
    $deployment.checkedAt = (Get-Date).ToUniversalTime().ToString('o')
    $deployment | ConvertTo-Json | Set-Content -LiteralPath $deploymentPath
}
function Update-LiveApp([bool]$Force = $false) {
    try {
        $revision = Get-RemoteMain -Checkout $AppCheckout -ExpectedRemote 'https://github.com/CosmonautJones/m-local.git'
        if (!$Force -and $revision -eq $deployment.activeRevision) { Save-Deployment 'up-to-date'; return }
        if (!$Force -and $revision -eq $deployment.failedRevision) { Save-Deployment 'failed-revision-skipped'; return }
        $runs = @(ConvertFrom-Json (Invoke-DeployCommand gh @('run','list','--repo','CosmonautJones/m-local','--workflow','check.yml','--branch','main','--event','push','--commit',$revision,'--limit','1','--json','headSha,status,conclusion')))
        if (!$runs.Count -or !(Test-DeploymentChecks -Run $runs[0] -Revision $revision)) {
            Save-Deployment 'waiting-for-passing-checks'; return
        }
        Write-Host "Updating from main: $($revision.Substring(0,7)). Checking and building while the current app stays online..."
        Save-Deployment 'preparing'
        try {
            Invoke-CodeDeployment -Checkout $AppCheckout -Revision $revision -Prepare { param($sha) Prepare-Candidate $sha } -StopApp { Stop-HostedApp } -StartApp { Start-HostedApp }
        } catch {
            $deployment.failedRevision = $revision
            Save-Deployment 'deployment-failed'
            throw
        }
        $deployment.activeRevision = $revision
        $deployment.failedRevision = ''
        Save-Deployment 'running'
        Write-Host "Live update ready: $($revision.Substring(0,7)). Refresh the page on each phone." -ForegroundColor Green
    } catch {
        Write-Warning "Automatic update: $($_.Exception.Message)"
        if ($deployment.status -ne 'deployment-failed') { Save-Deployment 'update-paused' }
    }
}
try {
    # Temporary, process-scoped sleep prevention; restored when this launcher exits.
    Add-Type -TypeDefinition 'using System.Runtime.InteropServices; public static class MLocalAwake { [DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint flags); }'
    [MLocalAwake]::SetThreadExecutionState([uint32]2147483649) | Out-Null
    if (!(Test-App)) {
        if (Get-NetTCPConnection -LocalPort 8200 -State Listen -ErrorAction SilentlyContinue) { throw 'Port 8200 belongs to an unavailable app. Stop that app before starting this launcher.' }
        Start-HostedApp
    } else {
        $linuxCheckout = Invoke-DeployCommand wsl.exe @('-d',$Distribution,'--exec','wslpath','-u',$AppCheckout)
        $runningRevision = Invoke-DeployCommand wsl.exe @('-d',$Distribution,'--cd',$repo,'--exec','python3','scripts/backend-owner.py',$linuxCheckout)
        if ($runningRevision -eq 'legacy' -and $RedeployCurrent) {
            Write-Host 'Verified the existing demo backend; rebuilding it with revision tracking.'
        } elseif ($runningRevision -ne $deployment.activeRevision) {
            throw 'The running backend revision does not match the deployment checkout. Use -RedeployCurrent once for a verified legacy backend.'
        }
    }
    if (!(Get-NetTCPConnection -LocalPort 8765 -State Listen -ErrorAction SilentlyContinue)) {
        $linkProcess = Start-Helper 'link' $repo 'scripts/stable-link.sh start'
        Start-Sleep -Seconds 3
        $linkProcess.Refresh()
        if ($linkProcess.HasExited) {
            if ($linkProcess.ExitCode -ne 0) { throw 'Stable link startup failed. Check the link logs.' }
            $linkProcess = $null
        }
    }
    $link = (& wsl.exe -d $Distribution --cd $repo --exec bash scripts/stable-link.sh address | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Tailscale needs its one-time sign-in. Run the stable-link login command in the hosting guide.' }
    & wsl.exe -d $Distribution --cd $repo --exec bash scripts/stable-link.sh publish
    if ($LASTEXITCODE -ne 0) { throw 'Public sharing is not enabled yet. Finish the Tailscale approval.' }
    Write-Host 'Waiting for the public HTTPS connection to be ready...'
    $publicReady = $false
    $publicDeadline = (Get-Date).AddMinutes(3)
    do {
        try {
            $health = Invoke-RestMethod -Uri "$link/healthz" -TimeoutSec 5
            $publicReady = $health.ready -eq $true
        } catch { $publicReady = $false }
        if (!$publicReady) { Start-Sleep -Seconds 2 }
    } while (!$publicReady -and (Get-Date) -lt $publicDeadline)
    if (!$publicReady) { throw 'The local app is ready, but the public connection did not recover within three minutes. Check your internet connection, then start hosting again.' }
    Set-Content -LiteralPath (Join-Path $stateDir 'link.txt') -Value $link
    Write-Host "`nOPEN ON ALL PHONES: $link`n" -ForegroundColor Green
    Write-Host 'Keep this window open and the laptop plugged in with its lid open.'
    Write-Host 'The address and data persist when you stop and start hosting.'
    if (!$NoAutoUpdate) { Write-Host 'Automatic updates: checks main every 60 seconds and deploys after CI passes.' }
    if (!$NoBrowser) { Start-Process $link }
    if ($RedeployCurrent) { Update-LiveApp -Force $true }
    $nextUpdate = Get-Date
    while (!(Test-Path -LiteralPath $launcherStop)) {
        if ($appProcess) { $appProcess.Refresh(); if ($appProcess.HasExited) { throw 'The backend stopped. Check the app logs.' } }
        if ($linkProcess) { $linkProcess.Refresh(); if ($linkProcess.HasExited) { break } }
        else {
            if (!(Get-NetTCPConnection -LocalPort 8765 -State Listen -ErrorAction SilentlyContinue)) { break }
        }
        if ((Get-Date) -ge $nextUpdate) {
            if (!(Test-App)) { throw 'The backend is unavailable. Check the app logs and restart hosting.' }
            if (!$NoAutoUpdate) { Update-LiveApp }
            $nextUpdate = (Get-Date).AddSeconds(60)
        }
        Start-Sleep -Seconds 3
    }
} finally {
    if ($linkProcess) { & wsl.exe -d $Distribution --cd $repo --exec bash scripts/stable-link.sh stop }
    if ($appProcess) { Set-Content -LiteralPath (Join-Path $appState 'stop') -Value 'stop' }
    if ('MLocalAwake' -as [type]) { [MLocalAwake]::SetThreadExecutionState([uint32]2147483648) | Out-Null }
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}
