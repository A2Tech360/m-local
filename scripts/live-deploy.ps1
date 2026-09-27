# Shared deployment operations. Dot-source this file; it starts no processes.
function Invoke-DeployCommand([string]$Program, [string[]]$Arguments, [int]$TimeoutSeconds = 60) {
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = (Get-Command $Program -ErrorAction Stop).Source
    # Native argv quoting, not shell evaluation. Also works in Windows PowerShell 5.
    $info.Arguments = ($Arguments | ForEach-Object {
        if ($_ -and $_ -notmatch '[\s"]') { $_ }
        else { '"' + [regex]::Replace([regex]::Replace($_, '(\\*)"', '$1$1\"'), '(\\+)$', '$1$1') + '"' }
    }) -join ' '
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $info
    try {
        $process.Start() | Out-Null
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (!$process.WaitForExit($TimeoutSeconds * 1000)) {
            if ($env:OS -eq 'Windows_NT') { & taskkill.exe /PID $process.Id /T /F 2>&1 | Out-Null }
            else { $process.Kill($true) }
            throw "$Program timed out after $TimeoutSeconds seconds."
        }
        $output = $stdout.GetAwaiter().GetResult()
        $errorText = $stderr.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0) { throw "$Program failed ($($process.ExitCode)): $errorText" }
        return $output.Trim()
    } finally { $process.Dispose() }
}
function Assert-DeploymentCheckout([string]$Checkout) {
    $dirty = Invoke-DeployCommand git @('-C',$Checkout,'status','--porcelain','--untracked-files=normal')
    if ($dirty) { throw 'Deployment checkout has uncommitted changes; automatic updates are suspended.' }
}
function Get-RemoteMain([string]$Checkout, [string]$ExpectedRemote) {
    Assert-DeploymentCheckout $Checkout
    $remote = Invoke-DeployCommand git @('-C',$Checkout,'remote','get-url','origin')
    if ($remote -ne $ExpectedRemote) { throw 'Deployment remote differs from the configured repository.' }
    Invoke-DeployCommand git @('-C',$Checkout,'fetch','--quiet','--no-tags','origin','refs/heads/main:refs/remotes/origin/main') | Out-Null
    return Invoke-DeployCommand git @('-C',$Checkout,'rev-parse','refs/remotes/origin/main')
}
function Test-DeploymentChecks($Run, [string]$Revision) {
    return $null -ne $Run -and $Run.headSha -eq $Revision -and $Run.status -eq 'completed' -and $Run.conclusion -eq 'success'
}
function Invoke-CodeDeployment(
    [string]$Checkout, [string]$Revision,
    [scriptblock]$Prepare, [scriptblock]$StopApp, [scriptblock]$StartApp
) {
    if ($Revision -notmatch '^[a-f0-9]{40}$') { throw 'Invalid deployment revision.' }
    Assert-DeploymentCheckout $Checkout
    $previous = Invoke-DeployCommand git @('-C',$Checkout,'rev-parse','HEAD')
    # Preparation does not alter the serving checkout or stop the current app.
    & $Prepare $Revision
    Assert-DeploymentCheckout $Checkout
    if ((Invoke-DeployCommand git @('-C',$Checkout,'rev-parse','HEAD')) -ne $previous) {
        throw 'Deployment checkout moved during preparation; update cancelled.'
    }
    try {
        & $StopApp
        Invoke-DeployCommand git @('-C',$Checkout,'checkout','--quiet','--detach',$Revision) | Out-Null
        & $StartApp
    } catch {
        $failure = $_.Exception.Message
        try {
            & $StopApp
            Assert-DeploymentCheckout $Checkout
            Invoke-DeployCommand git @('-C',$Checkout,'checkout','--quiet','--detach',$previous) | Out-Null
            & $StartApp
        } catch { throw "Deployment failed: $failure. Recovery also failed: $($_.Exception.Message)" }
        throw "Deployment failed; previous revision restored: $failure"
    }
}
