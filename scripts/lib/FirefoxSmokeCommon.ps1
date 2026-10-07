#requires -Version 7.0
# Firefox smoke support: native hidden children, literal arguments, owned cleanup.
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'BackgroundProcess.ps1')

function Resolve-StmFirefoxSourceAssembly {
    param([string]$Root, [string]$Path)
    $full = [IO.Path]::GetFullPath($Path, $Root)
    $boundary = [IO.Path]::GetFullPath((Join-Path $Root 'tmp/dotnet-bin')).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    $comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    if (-not $full.StartsWith($boundary, $comparison) -or [IO.Path]::GetFileName($full) -cne 'SchachTurnierManager.WebApi.dll') {
        throw 'SourceAssemblyPath must be the WebApi DLL under this repository tmp/dotnet-bin.'
    }
    $pathRoot = [IO.Path]::GetPathRoot($full)
    if ($IsWindows -and $pathRoot -notmatch '^[A-Za-z]:[\\/]+$') { throw 'SourceAssemblyPath must use a local drive.' }
    $cursor = $pathRoot
    $paths = [Collections.Generic.List[string]]::new()
    $paths.Add($cursor)
    foreach ($part in $full.Substring($pathRoot.Length).Split([char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar), [StringSplitOptions]::RemoveEmptyEntries)) {
        if ($part -match '[:*?"<>|\x00-\x1f]' -or $part -match '[. ]$') { throw 'SourceAssemblyPath contains an unsafe component.' }
        $cursor = Join-Path $cursor $part
        $paths.Add($cursor)
    }
    foreach ($candidate in $paths) {
        $item = Get-Item -LiteralPath $candidate -Force -ErrorAction Stop
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'SourceAssemblyPath contains a reparse point.' }
    }
    if (-not [IO.File]::Exists($full)) { throw 'SourceAssemblyPath is not a file.' }
    $directory = [IO.Path]::GetDirectoryName($full)
    foreach ($name in @('SchachTurnierManager.WebApi.runtimeconfig.json', 'SchachTurnierManager.WebApi.deps.json', 'wwwroot/index.html')) {
        $companion = Join-Path $directory $name
        if (-not [IO.File]::Exists($companion)) { throw "Source-only smoke requires its fresh build companion: $name" }
        $item = Get-Item -LiteralPath $companion -Force -ErrorAction Stop
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Source build companion is a reparse point.' }
    }
    $webRoot = Get-Item -LiteralPath (Join-Path $directory 'wwwroot') -Force -ErrorAction Stop
    if (($webRoot.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Source build wwwroot is a reparse point.' }
    return $full
}

function Test-StmFirefoxPortFree {
    param([int]$Port)
    $listeners = [Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners()
    if (@($listeners | Where-Object { $_.Port -eq $Port }).Count -gt 0) { return $false }
    $probe = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $Port)
    try {
        # Permit immediate reuse after an owned backend restart; reject active listeners above.
        $probe.ExclusiveAddressUse = $false
        $probe.Server.SetSocketOption([Net.Sockets.SocketOptionLevel]::Socket, [Net.Sockets.SocketOptionName]::ReuseAddress, $true)
        $probe.Start()
        return $true
    }
    catch [Net.Sockets.SocketException] { return $false }
    finally { $probe.Stop() }
}

function Test-StmFirefoxOwnedDescendant {
    param([psobject]$Handle, [int]$ProcessId)
    if ($Handle.Process.HasExited) { return $false }
    $rootId = $Handle.Process.Id
    $startedAt = $Handle.Process.StartTime.ToUniversalTime()
    $seen = [Collections.Generic.HashSet[int]]::new()
    $currentId = $ProcessId
    $descendantBirth = $null
    for ($depth = 0; $depth -lt 32; $depth++) {
        if ($currentId -eq $rootId) {
            return -not $Handle.Process.HasExited -and ($null -eq $descendantBirth -or $startedAt -le $descendantBirth)
        }
        if ($currentId -le 0 -or -not $seen.Add($currentId)) { return $false }
        # Request ownership metadata only, never process command lines or secrets.
        $child = Get-CimInstance Win32_Process -Filter "ProcessId=$currentId" -Property ProcessId,ParentProcessId,CreationDate -ErrorAction Stop
        if ($null -eq $child -or [int]$child.ProcessId -ne $currentId -or $null -eq $child.CreationDate) { return $false }
        $bornAt = $child.CreationDate.ToUniversalTime()
        if ($bornAt -lt $startedAt -or ($null -ne $descendantBirth -and $bornAt -gt $descendantBirth)) { return $false }
        $descendantBirth = $bornAt
        $currentId = [int]$child.ParentProcessId
    }
    return $false
}

function Test-StmFirefoxPortOwner {
    param([int]$Port, [psobject]$Handle)
    if ($Handle.PSObject.TypeNames -notcontains 'STM.BackgroundProcess' -or $Handle.Closed -or $Handle.Process.HasExited) {
        $exit = if ($Handle.Process.HasExited) { $Handle.Process.ExitCode } else { 'unavailable' }
        throw "The owned smoke child exited before its dedicated port became ready (exit=$exit; stderr=$($Handle.StderrPath); stdout=$($Handle.StdoutPath))."
    }
    if (-not $IsWindows) { throw 'Dedicated smoke port ownership verification currently requires Windows.' }
    $listeners = @(Get-NetTCPConnection -State Listen -ErrorAction Stop |
        Where-Object { $_.LocalPort -eq $Port -and $_.LocalAddress -in @('127.0.0.1', '0.0.0.0', '::1', '::') })
    if ($listeners.Count -eq 0) { return $false }
    foreach ($listener in $listeners) {
        if (-not (Test-StmFirefoxOwnedDescendant -Handle $Handle -ProcessId $listener.OwningProcess)) {
            throw 'Dedicated smoke port belongs to another process; no foreign process will be stopped.'
        }
    }
    return $true
}

function New-StmFirefoxSmokeContext {
    param([string]$Root, [int]$Port, [int]$MarionettePort, [string]$SourceAssemblyPath, [switch]$SkipPack, [switch]$KeepBrowserOpen)
    if ($Port -lt 1024 -or $Port -gt 65535 -or $MarionettePort -lt 1024 -or $MarionettePort -gt 65535 -or $Port -eq $MarionettePort) {
        throw 'Backend and Marionette ports must be distinct TCP ports from 1024 through 65535.'
    }
    if ($SourceAssemblyPath -and -not $SkipPack) { throw 'SourceAssemblyPath requires -SkipPack; no product package is built.' }
    if ($SourceAssemblyPath -and $KeepBrowserOpen) { throw 'SourceAssemblyPath requires a headless smoke; KeepBrowserOpen is forbidden.' }
    $source = if ($SourceAssemblyPath) { Resolve-StmFirefoxSourceAssembly -Root $Root -Path $SourceAssemblyPath } else { $null }
    foreach ($candidate in @($Port, $MarionettePort)) {
        if (-not (Test-StmFirefoxPortFree $candidate)) { throw "Dedicated smoke TCP port is not free: $candidate" }
    }
    return [pscustomobject]@{
        Root = $Root
        Port = $Port
        MarionettePort = $MarionettePort
        BaseUrl = "http://127.0.0.1:$Port"
        SourceAssemblyPath = $source
        DataDirectory = Join-Path ([IO.Path]::GetTempPath()) ('stm-firefox-smoke-' + [Guid]::NewGuid().ToString('N'))
        Handles = [Collections.Generic.List[object]]::new()
        BackendStarts = 0
        BrowserHandle = $null
        UnverifiedStartError = $null
        Failed = $false
        TreeCleanupUnverified = $false
    }
}

function Start-StmFirefoxBackend {
    param([psobject]$Context)
    if (-not (Test-StmFirefoxPortFree $Context.Port)) { throw 'Dedicated backend port is already occupied.' }
    $environment = @{
        ASPNETCORE_URLS = $Context.BaseUrl
        SchachTurnierManager__DataDirectory = $Context.DataDirectory
        SchachTurnierManager__LogDirectory = Join-Path $Context.DataDirectory 'logs'
    }
    if ($Context.SourceAssemblyPath) {
        $file = 'dotnet'
        $arguments = @($Context.SourceAssemblyPath)
        $directory = [IO.Path]::GetDirectoryName($Context.SourceAssemblyPath)
    }
    else {
        $file = Join-Path $Context.Root 'output/portable/app/SchachTurnierManager.WebApi.exe'
        $arguments = @()
        $directory = [IO.Path]::GetDirectoryName($file)
    }
    $Context.BackendStarts++
    $parameters = @{
        FilePath = $file
        ArgumentList = $arguments
        WorkingDirectory = $directory
        LogDirectory = Join-Path $Context.DataDirectory 'process-logs'
        Name = 'backend-' + $Context.BackendStarts
        Environment = $environment
    }
    try { $handle = Start-StmBackgroundProcess @parameters }
    catch { $Context.UnverifiedStartError = $_.Exception.Message; throw }
    $Context.Handles.Add($handle)
    $lastHealthError = 'none'
    for ($i = 0; $i -lt 60; $i++) {
        if (Test-StmFirefoxPortOwner -Port $Context.Port -Handle $handle) {
            try {
                if ((Invoke-WebRequest "$($Context.BaseUrl)/api/health" -NoProxy -MaximumRedirection 0 -UseBasicParsing -TimeoutSec 2).StatusCode -eq 200) { return $handle }
            }
            catch { $lastHealthError = $_.Exception.Message }
        }
        Start-Sleep -Milliseconds 700
    }
    throw "Owned backend on $($Context.BaseUrl) did not become healthy. Last health error: $lastHealthError"
}

function Stop-StmFirefoxBackend {
    param([psobject]$Context, [psobject]$Handle)
    if ($null -eq $Handle) { return }
    Stop-StmBackgroundProcess -Handle $Handle | Out-Null
    for ($i = 0; $i -lt 40; $i++) {
        if (Test-StmFirefoxPortFree $Context.Port) { return }
        Start-Sleep -Milliseconds 250
    }
    throw 'Dedicated backend port did not become free after owned child cleanup.'
}

function Start-StmFirefoxBrowser {
    param([psobject]$Context, [string]$Firefox, [string]$ProfileDirectory, [switch]$KeepBrowserOpen)
    if (-not (Test-StmFirefoxPortFree $Context.MarionettePort)) { throw 'Dedicated Marionette port is already occupied.' }
    $arguments = @('-marionette', '-no-remote', '-profile', $ProfileDirectory, 'about:blank')
    if (-not $KeepBrowserOpen) { $arguments = @('-headless') + $arguments }
    $environment = if ($Context.SourceAssemblyPath) { @{ MOZ_HEADLESS = '1' } } else { @{} }
    $parameters = @{
        FilePath = $Firefox
        ArgumentList = $arguments
        WorkingDirectory = $Context.Root
        LogDirectory = Join-Path $Context.DataDirectory 'process-logs'
        Name = 'firefox'
        Environment = $environment
    }
    try { $handle = Start-StmBackgroundProcess @parameters }
    catch { $Context.UnverifiedStartError = $_.Exception.Message; throw }
    $Context.Handles.Add($handle)
    $Context.BrowserHandle = $handle
    $handle | Add-Member -NotePropertyName RequiresLiveTreeCleanup -NotePropertyValue $true
    for ($i = 0; $i -lt 60; $i++) {
        if (Test-StmFirefoxPortOwner -Port $Context.MarionettePort -Handle $handle) { return $handle }
        Start-Sleep -Milliseconds 500
    }
    throw 'Owned Firefox did not expose its dedicated Marionette port.'
}

function Stop-StmFirefoxSmoke {
    param([psobject]$Context, [switch]$KeepBrowserOpen)
    $failures = [Collections.Generic.List[string]]::new()
    foreach ($handle in $Context.Handles) {
        if ($KeepBrowserOpen -and [Object]::ReferenceEquals($handle, $Context.BrowserHandle)) { continue }
        try {
            if (-not $handle.Closed -and $null -ne $handle.PSObject.Properties['RequiresLiveTreeCleanup'] -and $handle.RequiresLiveTreeCleanup -and $handle.Process.HasExited) {
                $Context.TreeCleanupUnverified = $true
            }
            Stop-StmBackgroundProcess -Handle $handle | Out-Null
            if ($null -eq $handle.Result) { throw 'Owned child cleanup did not produce a verified exit result.' }
            if ($null -ne $handle.PSObject.Properties['RequiresLiveTreeCleanup'] -and $handle.RequiresLiveTreeCleanup -and
                ($null -eq $handle.Result.PSObject.Properties['TreeKillSucceeded'] -or -not $handle.Result.TreeKillSucceeded)) {
                # Also catch root exit between the earlier check and the native stop.
                $Context.TreeCleanupUnverified = $true
            }
        }
        catch { $failures.Add($_.Exception.Message) }
    }
    if ($null -ne $Context.UnverifiedStartError) { $failures.Add('Child start failed before an owned handle was returned: ' + $Context.UnverifiedStartError) }
    if ($Context.TreeCleanupUnverified) {
        $failures.Add('Browser root exited before owned-tree cleanup; descendant exit remains unverified across retries and temp data must be retained.')
    }
    foreach ($port in @($Context.Port, $Context.MarionettePort)) {
        if ($KeepBrowserOpen -and $port -eq $Context.MarionettePort) { continue }
        if (-not (Test-StmFirefoxPortFree $port)) { $failures.Add("Dedicated port remains occupied after owned-handle cleanup: $port") }
    }
    if ($failures.Count -gt 0) { throw ('Owned smoke cleanup failed; temp data retained: ' + ($failures -join ' | ')) }
    if ($Context.Failed) {
        Write-Warning "Failed smoke retains local diagnostic logs after owned-handle cleanup and free-port verification: $($Context.DataDirectory)"
        return
    }
    if ($KeepBrowserOpen -and $null -ne $Context.BrowserHandle) {
        Write-Warning "KeepBrowserOpen retains the owned browser and profile: $($Context.DataDirectory)"
        return
    }
    $full = [IO.Path]::GetFullPath($Context.DataDirectory)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    $comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    if (-not $full.StartsWith($tempRoot, $comparison) -or [IO.Path]::GetFileName($full) -notmatch '^stm-firefox-smoke-[a-f0-9]{32}$') {
        throw 'Smoke cleanup path is not the exact owned GUID temporary directory.'
    }
    if (-not [IO.Directory]::Exists($full)) { return }
    $pending = [Collections.Generic.Stack[string]]::new()
    $pending.Push($full)
    while ($pending.Count -gt 0) {
        $directory = $pending.Pop()
        $item = Get-Item -LiteralPath $directory -Force -ErrorAction Stop
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Smoke cleanup found a reparse point; temp data retained.' }
        foreach ($entry in [IO.Directory]::EnumerateFileSystemEntries($directory)) {
            $item = Get-Item -LiteralPath $entry -Force -ErrorAction Stop
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Smoke cleanup found a reparse point; temp data retained.' }
            if ($item.PSIsContainer) { $pending.Push($entry) }
        }
    }
    Remove-Item -LiteralPath $full -Recurse -Force -ErrorAction Stop
}
