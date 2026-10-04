#requires -Version 7.0
[CmdletBinding()]
param([string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $Root 'scripts/lib/BackgroundProcess.ps1')
$runDirectory = Join-Path ([IO.Path]::GetTempPath()) ("stm-background-test-$([guid]::NewGuid().ToString('N'))")
[void][IO.Directory]::CreateDirectory($runDirectory)
$checks = 0
function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
    $script:checks++
}
$handles = [Collections.Generic.List[object]]::new()
try {
    $pwsh = (Get-Process -Id $PID).Path
    $scriptPath = Join-Path $runDirectory 'synthetic child.ps1'
    @'
param([string]$Value, [int]$ExitCode = 0, [switch]$LargeOutput, [switch]$Wait)
$ErrorActionPreference = 'Stop'
if ($Wait) { Start-Sleep -Seconds 120; exit 0 }
if ($LargeOutput) {
    [Console]::Out.Write(('O' * 262144))
    [Console]::Error.Write(('E' * 262144))
    exit $ExitCode
}
$consoleHandle = 'NOT_APPLICABLE'
if ($IsWindows) {
    Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public static class StmConsoleProbe { [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow(); }'
    $consoleHandle = [StmConsoleProbe]::GetConsoleWindow().ToInt64().ToString()
}
[Console]::Out.WriteLine(($Value, $env:STM_BACKGROUND_TEST, [Console]::In.ReadToEnd(), $consoleHandle | ConvertTo-Json -Compress))
[Console]::Error.WriteLine('synthetic-stderr')
exit $ExitCode
'@ | Set-Content -LiteralPath $scriptPath -Encoding utf8NoBOM

    $originalEnvironment = [Environment]::GetEnvironmentVariable('STM_BACKGROUND_TEST', 'Process')
    $argument = 'spaces "quotes" $literal & semicolon; end\'
    $handle = Start-StmBackgroundProcess -FilePath $pwsh `
        -ArgumentList @('-NoLogo', '-NoProfile', '-NonInteractive', '-File', $scriptPath, '-Value', $argument) `
        -WorkingDirectory $runDirectory -LogDirectory $runDirectory -Name normal `
        -Environment @{ STM_BACKGROUND_TEST = 'child-only' }
    $handles.Add($handle)
    $info = $handle.Process.StartInfo
    Assert-True ($info.CreateNoWindow -and -not $info.UseShellExecute) 'Native child is not configured without a console.'
    Assert-True ($info.WindowStyle -eq [Diagnostics.ProcessWindowStyle]::Hidden) 'Hidden window style missing.'
    Assert-True ($handle.Process.WaitForExit(30000)) 'EOF/input handling or normal exit timed out.'
    $result = Stop-StmBackgroundProcess $handle
    Assert-True ($result.ExitCode -eq 0 -and -not $result.RequestedStop) 'Normal exit was not preserved.'
    $reply = Get-Content -LiteralPath $result.StdoutPath -Raw | ConvertFrom-Json
    Assert-True ($reply[0] -ceq $argument) 'Arguments changed or were interpreted by a shell.'
    Assert-True ($reply[1] -ceq 'child-only' -and $reply[2] -ceq '') 'Child environment or closed stdin is wrong.'
    if ($IsWindows) { Assert-True ($reply[3] -eq '0') 'A real console window was allocated to the synthetic child.' }
    Assert-True ([Environment]::GetEnvironmentVariable('STM_BACKGROUND_TEST', 'Process') -ceq $originalEnvironment) 'Parent environment was modified.'
    Assert-True ((Get-Content -LiteralPath $result.StderrPath -Raw).Contains('synthetic-stderr')) 'Stderr was discarded.'
    Assert-True ((Stop-StmBackgroundProcess $handle).ExitCode -eq 0) 'Cleanup is not idempotent.'

    $handle = Start-StmBackgroundProcess -FilePath $pwsh `
        -ArgumentList @('-NoLogo', '-NoProfile', '-NonInteractive', '-File', $scriptPath, '-LargeOutput', '-ExitCode', '7') `
        -WorkingDirectory $runDirectory -LogDirectory $runDirectory -Name output
    $handles.Add($handle)
    Assert-True ($handle.Process.WaitForExit(30000)) 'Concurrent stdout/stderr draining deadlocked.'
    $result = Stop-StmBackgroundProcess $handle
    Assert-True ($result.ExitCode -eq 7) 'A failed child exit was hidden.'
    Assert-True ((Get-Item -LiteralPath $result.StdoutPath).Length -eq 262144) 'Stdout was truncated.'
    Assert-True ((Get-Item -LiteralPath $result.StderrPath).Length -eq 262144) 'Stderr was truncated.'

    $handle = Start-StmBackgroundProcess -FilePath $pwsh `
        -ArgumentList @('-NoLogo', '-NoProfile', '-NonInteractive', '-File', $scriptPath, '-Wait') `
        -WorkingDirectory $runDirectory -LogDirectory $runDirectory -Name waiting
    $handles.Add($handle)
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $result = Stop-StmBackgroundProcess $handle
    Assert-True ($result.RequestedStop -and $watch.Elapsed.TotalSeconds -lt 30) 'Owned child cleanup did not finish in time.'

    $rejected = $false
    try { New-StmBackgroundStartInfo -FilePath 'stm-nonexistent-executable-836734' -WorkingDirectory $runDirectory | Out-Null }
    catch { $rejected = $true }
    Assert-True $rejected 'An unavailable executable was not rejected.'
    $rejected = $false
    try { Stop-StmBackgroundProcess ([pscustomobject]@{ ProcessId = 1 }) | Out-Null }
    catch { $rejected = $true }
    Assert-True $rejected 'A bare process ID was accepted as an owned handle.'

    # The two modified callers must not restore shell/browser window launches.
    foreach ($relativePath in @('scripts/Start-Dev.ps1', 'scripts/Invoke-ClickInstallReadiness.ps1')) {
        $parseErrors = $null
        $tokens = $null
        $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $Root $relativePath), [ref]$tokens, [ref]$parseErrors)
        Assert-True ($parseErrors.Count -eq 0) "Parse failure in $relativePath."
        $commands = $ast.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] }, $true)
        $bad = @($commands | Where-Object { $_.GetCommandName() -in @('Start-Process', 'Invoke-Item') })
        Assert-True ($bad.Count -eq 0) "Unexpected shell/window launch in $relativePath."
    }
    Write-Output "BACKGROUND_PROCESS_TEST=PASS assertions=$checks windowsConsoleProbe=$IsWindows"
}
finally {
    $cleanupError = $null
    foreach ($handle in $handles) {
        try { Stop-StmBackgroundProcess $handle | Out-Null }
        catch { $cleanupError = $_ }
    }
    # This is the unique synthetic test folder just created by this invocation.
    Remove-Item -LiteralPath $runDirectory -Recurse -Force
    if ($null -ne $cleanupError) { throw $cleanupError }
}
