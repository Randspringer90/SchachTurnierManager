#requires -Version 7.0
# Native CLI children only. No shell association, GUI launcher or permission changes.
Set-StrictMode -Version Latest

function New-StmBackgroundStartInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string[]]$ArgumentList = @(),
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [hashtable]$Environment = @{}
    )

    $command = Get-Command -Name $FilePath -CommandType Application -ErrorAction Stop | Select-Object -First 1
    $executable = $command.Source
    if ($IsWindows -and [IO.Path]::GetExtension($executable) -ine '.exe') {
        throw 'Background children on Windows must be native executables, not shell scripts or associations.'
    }
    $directory = (Resolve-Path -LiteralPath $WorkingDirectory -ErrorAction Stop).Path
    if (-not [IO.Directory]::Exists($directory)) { throw 'The working directory must be a directory.' }

    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $executable
    $startInfo.WorkingDirectory = $directory
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in $ArgumentList) {
        if ($null -eq $argument) { throw 'A process argument must not be null.' }
        $startInfo.ArgumentList.Add($argument)
    }
    foreach ($key in $Environment.Keys) {
        if ($null -eq $Environment[$key]) { [void]$startInfo.Environment.Remove([string]$key) }
        else { $startInfo.Environment[[string]$key] = [string]$Environment[$key] }
    }
    return $startInfo
}

function Start-StmBackgroundProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string[]]$ArgumentList = @(),
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string]$LogDirectory,
        [Parameter(Mandatory)][ValidatePattern('^[a-zA-Z0-9_-]+$')][string]$Name,
        [hashtable]$Environment = @{}
    )

    $startInfo = New-StmBackgroundStartInfo -FilePath $FilePath -ArgumentList $ArgumentList `
        -WorkingDirectory $WorkingDirectory -Environment $Environment
    $logRoot = [IO.Path]::GetFullPath($LogDirectory)
    [void][IO.Directory]::CreateDirectory($logRoot)
    $stdoutPath = Join-Path $logRoot "$Name.stdout.log"
    $stderrPath = Join-Path $logRoot "$Name.stderr.log"
    $stdout = $null
    $stderr = $null
    $process = [Diagnostics.Process]::new()
    $started = $false
    try {
        # Exclusive new logs: never silently overwrite an earlier run's evidence.
        $stdout = [IO.FileStream]::new($stdoutPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::Read)
        $stderr = [IO.FileStream]::new($stderrPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::Read)
        $process.StartInfo = $startInfo
        $started = $process.Start()
        if (-not $started) { throw 'The background child did not start.' }
        # Drain BOTH pipes concurrently to files, not unbounded in-memory strings.
        $stdoutTask = $process.StandardOutput.BaseStream.CopyToAsync($stdout)
        $stderrTask = $process.StandardError.BaseStream.CopyToAsync($stderr)
        $process.StandardInput.Close()
        return [pscustomobject]@{
            PSTypeName = 'STM.BackgroundProcess'
            Process = $process
            StdoutTask = $stdoutTask
            StderrTask = $stderrTask
            StdoutStream = $stdout
            StderrStream = $stderr
            StdoutPath = $stdoutPath
            StderrPath = $stderrPath
            Closed = $false
            Result = $null
        }
    }
    catch {
        if ($started -and -not $process.HasExited) {
            try { $process.Kill($true); [void]$process.WaitForExit(10000) } catch { Write-Warning 'Child cleanup failed after a start error.' }
        }
        if ($null -ne $stdout) { $stdout.Dispose() }
        if ($null -ne $stderr) { $stderr.Dispose() }
        $process.Dispose()
        throw
    }
}

function Stop-StmBackgroundProcess {
    [CmdletBinding()]
    param([Parameter(Mandatory)][psobject]$Handle)

    if ($Handle.PSObject.TypeNames -notcontains 'STM.BackgroundProcess') { throw 'An owned background-process handle is required.' }
    if ($Handle.Closed) { return $Handle.Result }
    $process = $Handle.Process
    $requestedStop = $false
    $treeKillSucceeded = $false
    $failure = $null
    try {
        if (-not $process.HasExited) {
            $requestedStop = $true
            try { $process.Kill($true); $treeKillSucceeded = $true }
            catch { if (-not $process.HasExited) { throw } }
        }
        if (-not $process.WaitForExit(10000)) { throw 'The owned child did not exit within the cleanup deadline.' }
        foreach ($task in @($Handle.StdoutTask, $Handle.StderrTask)) {
            if (-not $task.Wait(10000)) { throw 'A child output pipe did not drain within the cleanup deadline.' }
            [void]$task.GetAwaiter().GetResult()
        }
        $Handle.Result = [pscustomobject]@{
            ExitCode = $process.ExitCode
            RequestedStop = $requestedStop
            TreeKillSucceeded = $treeKillSucceeded
            StdoutPath = $Handle.StdoutPath
            StderrPath = $Handle.StderrPath
        }
    }
    catch { $failure = $_ }
    finally {
        # Closing the process streams also releases an inherited pipe on failure.
        $process.Dispose()
        $Handle.StdoutStream.Dispose()
        $Handle.StderrStream.Dispose()
        $Handle.Closed = $true
    }
    if ($null -ne $failure) { throw $failure }
    return $Handle.Result
}
