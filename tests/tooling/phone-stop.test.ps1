# Run with Windows PowerShell; only the extracted shutdown function is executed.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$tokens = $null
$parseErrors = $null
$tree = [System.Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $repoRoot 'scripts/phone-share.ps1'), [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw 'Launcher has syntax errors.' }
$stopFunction = $tree.Find({ param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Stop-Demo'
}, $true)
if (-not $stopFunction) { throw 'Shutdown function is missing.' }
. ([scriptblock]::Create($stopFunction.Extent.Text))

$fixture = Join-Path $repoRoot ('.jac/stop-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture | Out-Null
$stopFile = Join-Path $fixture 'stop'
$linkFile = Join-Path $fixture 'link.txt'
$script:stopCalls = 0
$script:failureId = 'NoProcessFoundForGivenId'
function Read-State { @{tunnel=1;proxy=2} }
function Find-OwnedProcess($entry) { [pscustomobject]@{Id=$entry} }
# This mock prevents the test from terminating any real process.
function Stop-Process($Id) {
    $script:stopCalls++
    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
        [System.InvalidOperationException]::new('simulated shutdown race'),
        $script:failureId, [System.Management.Automation.ErrorCategory]::ObjectNotFound, $Id)
    throw $errorRecord
}
try {
    Set-Content -LiteralPath $linkFile -Value 'https://fixture.invalid'
    Stop-Demo
    if ($script:stopCalls -ne 2 -or -not (Test-Path -LiteralPath $stopFile) -or (Test-Path -LiteralPath $linkFile)) {
        throw 'An already-exited process interrupted shutdown cleanup.'
    }
    $script:failureId = 'AccessDenied'
    $denied = $false
    try { Stop-Demo } catch { $denied = $_.FullyQualifiedErrorId -like 'AccessDenied*' }
    if (-not $denied) { throw 'Shutdown suppressed a non-race error.' }
    Write-Output 'PASS: concurrent exit is harmless and unexpected shutdown errors still propagate.'
} finally {
    foreach ($fixtureFile in @($stopFile, $linkFile)) {
        if (Test-Path -LiteralPath $fixtureFile) { Remove-Item -LiteralPath $fixtureFile }
    }
    Remove-Item -LiteralPath $fixture
}
