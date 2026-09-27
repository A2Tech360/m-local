$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$module = Join-Path $repo 'scripts/live-deploy.ps1'
if (!(Test-Path -LiteralPath $module)) { throw 'Live deployment controller is missing.' }
. $module
function Assert($condition, $message) { if (!$condition) { throw $message } }
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('mlocal-deploy-' + [guid]::NewGuid().ToString('N'))
$origin = Join-Path $fixture 'origin'
$checkout = Join-Path $fixture 'checkout'
New-Item -ItemType Directory -Path $origin -Force | Out-Null
Invoke-DeployCommand git @('init','--quiet','--initial-branch=main',$origin) | Out-Null
Invoke-DeployCommand git @('-C',$origin,'config','user.name','Deployment Test') | Out-Null
Invoke-DeployCommand git @('-C',$origin,'config','user.email','deploy@example.test') | Out-Null
Set-Content (Join-Path $origin '.gitignore') 'private/'
Set-Content (Join-Path $origin 'version.txt') 'one'
Invoke-DeployCommand git @('-C',$origin,'add','.') | Out-Null
Invoke-DeployCommand git @('-C',$origin,'commit','--quiet','-m','first') | Out-Null
Invoke-DeployCommand git @('clone','--quiet',$origin,$checkout) | Out-Null
$first = Invoke-DeployCommand git @('-C',$checkout,'rev-parse','HEAD')
New-Item -ItemType Directory (Join-Path $checkout 'private') | Out-Null
Set-Content (Join-Path $checkout 'private/data.txt') 'keep accounts'
Set-Content (Join-Path $origin 'version.txt') 'two'
Invoke-DeployCommand git @('-C',$origin,'commit','--quiet','-am','second') | Out-Null
$second = Get-RemoteMain -Checkout $checkout -ExpectedRemote $origin
Assert ($second -ne $first) 'A new main commit was not discovered.'
foreach ($case in @(
    @{headSha=$second;status='completed';conclusion='success';want=$true},
    @{headSha=$first;status='completed';conclusion='success';want=$false},
    @{headSha=$second;status='in_progress';conclusion='';want=$false},
    @{headSha=$second;status='completed';conclusion='failure';want=$false},
    @{headSha=$second;status='completed';conclusion='cancelled';want=$false}
)) {
    Assert ((Test-DeploymentChecks -Run ([pscustomobject]$case) -Revision $second) -eq $case.want) 'Unsafe CI result accepted.'
}
Assert (!(Test-DeploymentChecks -Run $null -Revision $second)) 'Missing CI must block deployment.'
$timedOut = $false
try { Invoke-DeployCommand -Program node -Arguments @('-e','setTimeout(() => {}, 5000)') -TimeoutSeconds 1 | Out-Null } catch { $timedOut = $_.Exception.Message -like '*timed out*' }
Assert $timedOut 'A stalled polling command was not bounded.'
if ($env:OS -eq 'Windows_NT' -and (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
    $tokens = $null
    $parseErrors = $null
    $tree = [Management.Automation.Language.Parser]::ParseFile((Join-Path $repo 'scripts/stable-demo.ps1'),[ref]$tokens,[ref]$parseErrors)
    Assert (!$parseErrors.Count) 'Hosting launcher has syntax errors.'
    $helper = $tree.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Start-Helper'},$true)
    . ([scriptblock]::Create($helper.Extent.Text))
    $stateDir = $fixture
    $Distribution = 'Ubuntu'
    $child = Start-Helper 'exit-status' $repo '-c "exit 7"'
    Assert ($child.WaitForExit(10000)) 'Helper failed to exit.'
    Assert ($child.ExitCode -eq 7) 'Windows helper lost its real exit status.'
    $child.Dispose()
}
$activate = { Set-Content (Join-Path $checkout 'private/served.txt') (Get-Content (Join-Path $checkout 'version.txt')) }.GetNewClosure()
Invoke-CodeDeployment -Checkout $checkout -Revision $second -Prepare {} -StopApp {} -StartApp $activate
Assert ((Get-Content (Join-Path $checkout 'private/served.txt')) -eq 'two') 'New code was not activated.'
Assert ((Get-Content (Join-Path $checkout 'private/data.txt')) -eq 'keep accounts') 'Deployment changed persistent data.'
# Dirty sources must remain untouched, and no lifecycle callback may run.
Set-Content (Join-Path $checkout 'version.txt') 'human edit'
$blocked = $false
try { Invoke-CodeDeployment -Checkout $checkout -Revision $first -Prepare { throw 'callback ran' } -StopApp {} -StartApp {} } catch { $blocked = $_.Exception.Message -like '*uncommitted*' }
Assert $blocked 'Dirty checkout was not protected.'
Assert ((Get-Content (Join-Path $checkout 'version.txt')) -eq 'human edit') 'Human edit was overwritten.'
Invoke-DeployCommand git @('-C',$checkout,'restore','version.txt') | Out-Null
# A preparation failure must leave the live revision unchanged.
$failed = $false
try { Invoke-CodeDeployment -Checkout $checkout -Revision $first -Prepare { throw 'bad build' } -StopApp {} -StartApp {} } catch { $failed = $true }
Assert $failed 'A failed preflight was accepted.'
Assert ((Invoke-DeployCommand git @('-C',$checkout,'rev-parse','HEAD')) -eq $second) 'Preflight failure changed live code.'
# Simulate startup failure only for version one; rollback must reactivate two.
$start = {
    $version = (Get-Content (Join-Path $checkout 'version.txt')).Trim()
    if ($version -eq 'one') { throw 'candidate cannot start' }
    Set-Content (Join-Path $checkout 'private/served.txt') $version
}.GetNewClosure()
$failed = $false
try { Invoke-CodeDeployment -Checkout $checkout -Revision $first -Prepare {} -StopApp {} -StartApp $start } catch { $failed = $_.Exception.Message -like '*previous revision restored*' }
Assert $failed 'Failed activation did not report rollback.'
Assert ((Invoke-DeployCommand git @('-C',$checkout,'rev-parse','HEAD')) -eq $second) 'Previous revision was not restored.'
Assert ((Get-Content (Join-Path $checkout 'private/served.txt')) -eq 'two') 'Previous version was not restarted.'
Assert ((Get-Content (Join-Path $checkout 'private/data.txt')) -eq 'keep accounts') 'Rollback changed persistent data.'
Write-Output 'PASS: main discovery, exact-commit CI gate, dirty checkout protection, preflight isolation, deployment and rollback.'
# Retain the small fixture for debugging instead of recursively deleting paths.
