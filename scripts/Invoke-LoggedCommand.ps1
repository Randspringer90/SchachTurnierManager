[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RunDirectory,
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$CommandLine,
    [string]$WorkingDirectory = (Get-Location).Path,
    [int]$FailureTailLines = 80
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-SafeFileName([string]$Value) {
    $safe = $Value -replace '[^a-zA-Z0-9_.-]+', '_'
    if ([string]::IsNullOrWhiteSpace($safe)) { return 'command' }
    return $safe.Trim('_')
}

New-Item -ItemType Directory -Force -Path $RunDirectory | Out-Null
$resolvedRunDirectory = (Resolve-Path -LiteralPath $RunDirectory).Path
$resolvedWorkingDirectory = (Resolve-Path -LiteralPath $WorkingDirectory).Path
$safeName = ConvertTo-SafeFileName $Name
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$logPath = Join-Path $resolvedRunDirectory "$safeName`_$timestamp.log"
$metaPath = Join-Path $resolvedRunDirectory "$safeName`_$timestamp.meta.txt"

@(
    "Name: $Name",
    "Start: $(Get-Date -Format o)",
    "WorkingDirectory: $resolvedWorkingDirectory",
    "CommandLine: $CommandLine",
    "LogPath: $logPath"
) | Set-Content -Encoding UTF8 -LiteralPath $metaPath

Write-Host "[$Name] startet. Log: $logPath"

$psi = [System.Diagnostics.ProcessStartInfo]::new()
$psi.FileName = 'pwsh.exe'
$psi.ArgumentList.Add('-NoLogo')
$psi.ArgumentList.Add('-NoProfile')
$psi.ArgumentList.Add('-ExecutionPolicy')
$psi.ArgumentList.Add('Bypass')
$psi.ArgumentList.Add('-Command')
$psi.ArgumentList.Add($CommandLine)
$psi.WorkingDirectory = $resolvedWorkingDirectory
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true

$process = [System.Diagnostics.Process]::new()
$process.StartInfo = $psi
[void]$process.Start()

$stdoutTask = $process.StandardOutput.ReadToEndAsync()
$stderrTask = $process.StandardError.ReadToEndAsync()
$spinner = @('|','/','-','\\')
$index = 0
$started = Get-Date
while (-not $process.WaitForExit(250)) {
    $elapsed = [int]((Get-Date) - $started).TotalSeconds
    Write-Progress -Activity $Name -Status "läuft seit ${elapsed}s" -PercentComplete (($index % 100))
    Write-Host -NoNewline ("`r[$Name] laeuft {0} {1}s" -f $spinner[$index % $spinner.Count], $elapsed)
    $index++
}
Write-Host "`r[$Name] beendet nach $([int]((Get-Date) - $started).TotalSeconds)s.          "
Write-Progress -Activity $Name -Completed

$stdout = $stdoutTask.GetAwaiter().GetResult()
$stderr = $stderrTask.GetAwaiter().GetResult()
@(
    "# STDOUT",
    $stdout,
    "# STDERR",
    $stderr,
    "# ExitCode",
    [string]$process.ExitCode,
    "# End",
    (Get-Date -Format o)
) | Set-Content -Encoding UTF8 -LiteralPath $logPath

if ($process.ExitCode -ne 0) {
    Write-Host "[$Name] FEHLER: ExitCode $($process.ExitCode). Letzte Logzeilen:"
    Get-Content -LiteralPath $logPath -Tail $FailureTailLines
    exit $process.ExitCode
}

Write-Host "[$Name] OK."
exit 0
