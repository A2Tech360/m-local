param([switch]$Stop, [switch]$NoBrowser, [string]$Distribution = 'Ubuntu')
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$stateDir = Join-Path $repo '.jac\phone-share'
New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
$stateFile = Join-Path $stateDir 'processes.json'
$stopFile = Join-Path $stateDir 'stop'
$readyFile = Join-Path $stateDir 'ready'
$linkFile = Join-Path $stateDir 'link.txt'

function Read-State {
    if (Test-Path -LiteralPath $stateFile) { return Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json }
    return $null
}
function Find-OwnedProcess($entry) {
    if (!$entry) { return $null }
    $process = Get-Process -Id $entry.id -ErrorAction SilentlyContinue
    if ($process -and $process.StartTime.ToUniversalTime().Ticks.ToString() -eq $entry.started) { return $process }
    return $null
}
function Stop-Demo {
    Set-Content -LiteralPath $stopFile -Value 'stop'
    $saved = Read-State
    if ($saved) {
        foreach ($name in @('tunnel', 'proxy')) {
            $process = Find-OwnedProcess $saved.$name
            if ($process) { Stop-Process -Id $process.Id }
        }
    }
    if (Test-Path -LiteralPath $linkFile) { Remove-Item -LiteralPath $linkFile }
}
if ($Stop) { Stop-Demo; Write-Host 'Phone sharing stopped. Jac shuts down within a few seconds.'; exit 0 }

# A per-checkout mutex prevents two double-clicks starting overlapping processes.
$mutexName = 'Local\MLocalPhoneShare-' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($repo)).Replace('\', '_')
$mutex = New-Object Threading.Mutex($false, $mutexName)
try { $locked = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $locked = $true }
if (!$locked) {
    if (Test-Path -LiteralPath $linkFile) {
        $link = (Get-Content -LiteralPath $linkFile -Raw).Trim()
        Write-Host "Already running: $link"
        if (!$NoBrowser) { Start-Process $link }
    } else { Write-Host 'M-Local is already starting. Check its launcher window.' }
    $mutex.Dispose()
    exit 0
}
$owned = @{}
function Start-Owned($name, $file, $arguments) {
    $process = Start-Process -FilePath $file -ArgumentList $arguments -WorkingDirectory $repo -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $stateDir "$name.log") -RedirectStandardError (Join-Path $stateDir "$name.err.log")
    $owned[$name] = @{ id = $process.Id; started = $process.StartTime.ToUniversalTime().Ticks.ToString() }
    $owned | ConvertTo-Json | Set-Content -LiteralPath $stateFile
    return $process
}
try {
    $existing = Read-State
    if ($existing -and (Find-OwnedProcess $existing.server)) { throw 'A prior demo is still running. Use Stop Phone Demo, wait a few seconds, then start again.' }
    foreach ($port in @(8200, 8280)) {
        $busy = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
        if ($busy) { throw "Port $port is already in use. Stop that preview first. Other processes were left alone." }
    }
    $node = (Get-Command node.exe -ErrorAction Stop).Source
    if ([int]((& $node --version).TrimStart('v').Split('.')[0]) -lt 22) { throw 'Install Node.js 22 or newer, then retry.' }
    Get-Command wsl.exe -ErrorAction Stop | Out-Null
    Write-Host 'Starting M-Local phone demo. First launch can take several minutes.'
    Write-Host 'The laptop must stay awake and online. Use fictional demo data.'
    Write-Host "Logs: $stateDir"
    & wsl.exe -d $Distribution --cd $repo --exec bash -lc 'source scripts/runtime.sh'
    if ($LASTEXITCODE -ne 0) { throw 'Jac runtime unavailable. In WSL run bash scripts/setup.sh, then retry.' }

    # Official pinned Cloudflare release; verify bytes on every launch.
    $cloudflared = Join-Path $stateDir 'cloudflared-2026.9.3.exe'
    $expected = 'f096265ec2fcbe9bb6e2d64268db167ced3fcbb83d894bdb9e2fcdb26f2ea7e2'
    if (!(Test-Path -LiteralPath $cloudflared)) {
        Write-Host 'Downloading the verified Cloudflare phone-link helper...'
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/cloudflare/cloudflared/releases/download/2026.9.3/cloudflared-windows-amd64.exe' -OutFile "$cloudflared.download"
        if ((Get-FileHash -LiteralPath "$cloudflared.download" -Algorithm SHA256).Hash.ToLower() -ne $expected) { throw 'Cloudflare download checksum mismatch.' }
        Move-Item -LiteralPath "$cloudflared.download" -Destination $cloudflared
    }
    if ((Get-FileHash -LiteralPath $cloudflared -Algorithm SHA256).Hash.ToLower() -ne $expected) { throw 'Cloudflare helper checksum mismatch. Remove that helper file and retry.' }
    foreach ($path in @($stopFile, $readyFile, $linkFile)) { if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path } }
    $server = Start-Owned 'server' 'wsl.exe' "-d $Distribution --cd `"$repo`" --exec bash scripts/phone-server.sh"
    $deadline = (Get-Date).AddMinutes(12)
    while (!(Test-Path -LiteralPath $readyFile)) {
        if ($server.HasExited) { throw "App startup failed. Read $stateDir\server.err.log and server.log." }
        if ((Get-Date) -gt $deadline) { throw 'Startup timed out. Check the server logs.' }
        if (Test-Path -LiteralPath $stopFile) { exit 0 }
        Start-Sleep -Seconds 2
        $server.Refresh()
    }
    $proxy = Start-Owned 'proxy' $node 'scripts/phone-share-proxy.mjs'
    Start-Sleep -Seconds 1
    $response = Invoke-WebRequest -UseBasicParsing 'http://127.0.0.1:8280/' -TimeoutSec 15
    if ($response.StatusCode -ne 200 -or $response.Content -match '/@vite/|/@react-refresh') { throw 'Expected the compiled app, but gateway readiness failed.' }
    $bundle = Invoke-WebRequest -UseBasicParsing 'http://127.0.0.1:8280/static/client.js' -TimeoutSec 30
    if ($bundle.StatusCode -ne 200 -or $bundle.RawContentLength -lt 1000) { throw 'The compiled client bundle did not load through the gateway.' }
    $tunnel = Start-Owned 'tunnel' $cloudflared 'tunnel --no-autoupdate --url http://127.0.0.1:8280 --protocol http2'
    $deadline = (Get-Date).AddMinutes(2)
    $link = $null
    while (!$link) {
        if ($tunnel.HasExited) { throw "Tunnel failed. Read $stateDir\tunnel.err.log." }
        $log = Get-Content -LiteralPath (Join-Path $stateDir 'tunnel.err.log') -Raw -ErrorAction SilentlyContinue
        if ($log -match 'https://[a-z0-9-]+\.trycloudflare\.com') { $link = $Matches[0]; break }
        if ((Get-Date) -gt $deadline) { throw 'Cloudflare did not return a phone link. Check the network and tunnel log.' }
        Start-Sleep -Seconds 1
        $tunnel.Refresh()
    }
    Set-Content -LiteralPath $linkFile -Value $link
    Write-Host "`nOPEN ON YOUR PHONES: $link`n" -ForegroundColor Green
    Write-Host "Private demo logins: $stateDir\accounts.json"
    Write-Host 'Share the link and assign each tester a separate demo login.'
    Write-Host 'Keep this window open. Stop Phone Demo closes the link. A restart creates a new link.'
    if (!$NoBrowser) { Start-Process $link }
    while (!(Test-Path -LiteralPath $stopFile)) {
        foreach ($process in @($server, $proxy, $tunnel)) {
            $process.Refresh()
            if ($process.HasExited) { throw 'A demo process stopped. Check the logs and restart the launcher.' }
        }
        Start-Sleep -Seconds 2
    }
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
} finally {
    if ($owned.Count -gt 0) { Stop-Demo }
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}
