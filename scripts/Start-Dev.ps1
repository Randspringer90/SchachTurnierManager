#requires -Version 7.0
[CmdletBinding()]
param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$LogRoot,
    [ValidateRange(1, 600)][int]$StartupTimeoutSeconds = 60,
    [ValidateRange(0, 86400)][int]$RunSeconds = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/BackgroundProcess.ps1')

$Root = (Resolve-Path -LiteralPath $Root).Path
$backend = Join-Path $Root 'src/SchachTurnierManager.WebApi'
$frontend = Join-Path $Root 'src/SchachTurnierManager.WebApp'
$backendProject = Join-Path $backend 'SchachTurnierManager.WebApi.csproj'
$backendUrl = 'http://127.0.0.1:5088'
$frontendUrl = 'http://127.0.0.1:5173'
$vite = Join-Path $frontend 'node_modules/vite/bin/vite.js'
if (-not (Test-Path -LiteralPath $vite -PathType Leaf)) {
    throw 'Vite is not installed. Perform the reviewed dependency restore first; Start-Dev does not run npm install.'
}
$dotnet = (Get-Command dotnet -CommandType Application -ErrorAction Stop).Source
$node = (Get-Command node -CommandType Application -ErrorAction Stop).Source

function Assert-DevPortFree([int]$Port) {
    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $Port)
    $listener.Server.ExclusiveAddressUse = $true
    try { $listener.Start() }
    catch { throw "Port $Port is not available. No existing process will be reused or stopped." }
    finally { $listener.Stop() }
}

function Wait-DevHttp([string]$Url, [psobject]$Handle, [switch]$Health) {
    $timer = [Diagnostics.Stopwatch]::StartNew()
    do {
        if ($Handle.Process.HasExited) { throw "Child exited with $($Handle.Process.ExitCode). See $($Handle.StderrPath)." }
        try {
            $reply = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 2 -MaximumRedirection 0
            if ($reply.StatusCode -eq 200) {
                if (-not $Health) { return }
                $body = $reply.Content | ConvertFrom-Json
                if ($body.app -eq 'SchachTurnierManager' -and $body.status -eq 'ok') { return }
            }
        }
        catch { }
        Start-Sleep -Milliseconds 300
    } while ($timer.Elapsed.TotalSeconds -lt $StartupTimeoutSeconds)
    throw "Startup timed out for $Url. See $($Handle.StderrPath)."
}

function Invoke-DevDotnet([string[]]$Arguments, [string]$Name) {
    $handle = Start-StmBackgroundProcess -FilePath $dotnet -ArgumentList $Arguments `
        -WorkingDirectory $backend -LogDirectory $runDirectory -Name $Name `
        -Environment @{ DOTNET_NOLOGO = '1'; MSBUILDDISABLENODEREUSE = '1' }
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $nextHeartbeat = 30
    try {
        while (-not $handle.Process.WaitForExit(500)) {
            if ($timer.Elapsed.TotalSeconds -ge 300) { throw "Step $Name timed out. See $($handle.StderrPath)." }
            if ($timer.Elapsed.TotalSeconds -ge $nextHeartbeat) {
                Write-Host "[Start-Dev] $Name is running. Logs=$runDirectory"
                $nextHeartbeat += 30
            }
        }
    }
    finally { $result = Stop-StmBackgroundProcess $handle }
    if ($result.ExitCode -ne 0) { throw "Step $Name failed ($($result.ExitCode)). See $($result.StderrPath)." }
    return $result
}

Assert-DevPortFree 5088
Assert-DevPortFree 5173
if (-not $LogRoot) { $LogRoot = Join-Path $Root 'logs/dev' }
$runDirectory = Join-Path $LogRoot ("run-$(Get-Date -Format yyyyMMdd-HHmmss)-$([guid]::NewGuid().ToString('N').Substring(0, 8))")
$children = [Collections.Generic.List[object]]::new()
try {
    Write-Host "[Start-Dev] Building the already-restored backend. Logs=$runDirectory"
    Invoke-DevDotnet -Arguments @('build', $backendProject, '--configuration', 'Debug', '--no-restore', '--nologo', '--disable-build-servers') -Name backend-build | Out-Null
    $pathResult = Invoke-DevDotnet -Arguments @('msbuild', $backendProject, '-nologo', '-getProperty:TargetPath', '-property:Configuration=Debug') -Name backend-path
    $assembly = (Get-Content -LiteralPath $pathResult.StdoutPath -Raw).Trim()
    if (-not [IO.Path]::IsPathFullyQualified($assembly) -or [IO.Path]::GetExtension($assembly) -ine '.dll' -or
        -not (Test-Path -LiteralPath $assembly -PathType Leaf)) {
        throw 'MSBuild did not return one existing backend assembly path. No executable is guessed.'
    }
    # Direct DLL hosting avoids an additional dotnet-run launcher/launch profile.
    $backendHandle = Start-StmBackgroundProcess -FilePath $dotnet `
        -ArgumentList @($assembly, '--urls', $backendUrl) `
        -WorkingDirectory $backend -LogDirectory $runDirectory -Name backend `
        -Environment @{ ASPNETCORE_ENVIRONMENT = 'Development' }
    $children.Add($backendHandle)
    Wait-DevHttp -Url "$backendUrl/api/health" -Handle $backendHandle -Health

    # Start the existing Vite package directly; no npm shell shim or new terminal.
    # Preserve LAN development access. StrictPort prevents silently moving elsewhere.
    $frontendHandle = Start-StmBackgroundProcess -FilePath $node `
        -ArgumentList @($vite, '--host', '0.0.0.0', '--port', '5173', '--strictPort') `
        -WorkingDirectory $frontend -LogDirectory $runDirectory -Name frontend
    $children.Add($frontendHandle)
    Wait-DevHttp -Url $frontendUrl -Handle $frontendHandle

    Write-Host "[Start-Dev] Ready. Backend=$backendUrl Frontend=$frontendUrl Logs=$runDirectory"
    Write-Host '[Start-Dev] No browser or additional terminal is opened. Stop this supervisor to stop its children.'
    $session = [Diagnostics.Stopwatch]::StartNew()
    $nextHeartbeat = 30
    while ($RunSeconds -eq 0 -or $session.Elapsed.TotalSeconds -lt $RunSeconds) {
        foreach ($child in $children) {
            if ($child.Process.HasExited) { throw "Development child exited with $($child.Process.ExitCode). See $($child.StderrPath)." }
        }
        if ($session.Elapsed.TotalSeconds -ge $nextHeartbeat) {
            Write-Host "[Start-Dev] Running. Logs=$runDirectory"
            $nextHeartbeat += 30
        }
        Start-Sleep -Milliseconds 500
    }
}
finally {
    $cleanupFailure = $null
    foreach ($child in $children) {
        try { Stop-StmBackgroundProcess -Handle $child | Out-Null }
        catch { $cleanupFailure = $_; Write-Warning 'A development child could not be fully cleaned up.' }
    }
    if ($null -ne $cleanupFailure) { throw $cleanupFailure }
}
