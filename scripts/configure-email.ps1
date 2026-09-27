param(
    [ValidateSet('gmail', 'resend', 'custom')]
    [string]$Provider = 'gmail',
    [switch]$Check
)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
$linuxPath = & wsl.exe --exec wslpath -u $projectPath
if ($LASTEXITCODE -ne 0) { throw 'WSL could not resolve this checkout.' }
$setupArgs = @('scripts/configure-email.py', '--provider', $Provider)
if ($Check) { $setupArgs += '--check' }
& wsl.exe --cd $linuxPath.Trim() --exec python3 @setupArgs
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Email setup did not finish. Check the details above before trying again.' -ForegroundColor Red
    exit 1
}
if (-not $Check) {
    Write-Host 'Next: restart M-Local, then request a verification code from the app.'
    Write-Host 'The phone demo shortcuts create a fresh phone link when restarted.'
}
