#requires -Version 7.0
[CmdletBinding()]
param([string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $Root 'scripts/lib/FirefoxSmokeCommon.ps1')

# All process, CIM and port collaborators below are synthetic. No child is started,
# no PID is terminated, and no environment is mutated or secret accessed.
$script:checks = 0
$script:records = @{}
$script:cimQueries = [Collections.Generic.List[int]]::new()
$script:knownHandles = [Collections.Generic.List[object]]::new()
$script:stopCalls = [Collections.Generic.List[object]]::new()
$fixtures = [Collections.Generic.List[string]]::new()
$originalStop = (Get-Item Function:\Stop-StmBackgroundProcess).ScriptBlock
$originalPortFree = (Get-Item Function:\Test-StmFirefoxPortFree).ScriptBlock

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
    $script:checks++
}
function Assert-Rejects([scriptblock]$Action, [string]$MessagePattern) {
    try { & $Action | Out-Null }
    catch {
        if ($_.Exception.Message -notmatch $MessagePattern) { throw }
        $script:checks++
        return
    }
    throw "Expected rejection did not occur: $MessagePattern"
}
function Get-CimInstance {
    [CmdletBinding()]
    param([Parameter(Position = 0)][string]$ClassName, [string]$Filter, [string[]]$Property)
    if ($ClassName -cne 'Win32_Process' -or $Filter -notmatch '^ProcessId=(\d+)$') { throw 'Unexpected synthetic CIM request.' }
    if ((@($Property | Sort-Object) -join ',') -cne 'CreationDate,ParentProcessId,ProcessId') {
        throw 'Ownership probes must request only PID, parent PID and creation date.'
    }
    $id = [int]$Filter.Substring(10)
    $script:cimQueries.Add($id)
    return $script:records[$id]
}
function Test-StmFirefoxPortFree {
    param([int]$Port)
    return $true
}
function Stop-StmBackgroundProcess {
    [CmdletBinding()]
    param([Parameter(Mandatory)][psobject]$Handle)
    $known = @($script:knownHandles | Where-Object { [Object]::ReferenceEquals($_, $Handle) }).Count -eq 1
    if (-not $known) { throw 'Attempt to stop a foreign synthetic handle.' }
    $script:stopCalls.Add($Handle)
    if (-not $Handle.Closed) {
        if ($null -ne $Handle.PSObject.Properties['ExitBeforeStop'] -and $Handle.ExitBeforeStop) { $Handle.Process.HasExited = $true }
        $Handle.Result = [pscustomobject]@{ ExitCode = 0; RequestedStop = -not $Handle.Process.HasExited; TreeKillSucceeded = -not $Handle.Process.HasExited }
        $Handle.Process.HasExited = $true
        $Handle.Closed = $true
    }
    return $Handle.Result
}
function New-FakeHandle([int]$Id, [datetime]$StartedAt, [bool]$HasExited = $false) {
    $handle = [pscustomobject]@{
        PSTypeName = 'STM.BackgroundProcess'
        Process = [pscustomobject]@{ Id = $Id; StartTime = $StartedAt; HasExited = $HasExited; ExitCode = 0 }
        Closed = $false
        Result = $null
        StdoutPath = 'synthetic.stdout'
        StderrPath = 'synthetic.stderr'
    }
    $script:knownHandles.Add($handle)
    return $handle
}
function Set-FakeRecord([int]$Id, [int]$ParentId, $BornAt) {
    $script:records[$Id] = [pscustomobject]@{ ProcessId = $Id; ParentProcessId = $ParentId; CreationDate = $BornAt }
}
function New-CleanupFixture {
    $context = New-StmFirefoxSmokeContext -Root $Root -Port 15093 -MarionettePort 12829 -SkipPack
    $full = [IO.Path]::GetFullPath($context.DataDirectory)
    $parent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($parent, [StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($full) -notmatch '^stm-firefox-smoke-[a-f0-9]{32}$') {
        throw 'Synthetic fixture is not an exact owned temporary directory.'
    }
    if ([IO.Directory]::Exists($full) -or [IO.File]::Exists($full)) { throw 'Synthetic fixture already exists.' }
    [void][IO.Directory]::CreateDirectory($full)
    $fixtures.Add($full)
    [IO.File]::WriteAllText((Join-Path $full 'retained-sentinel.txt'), 'synthetic retention sentinel')
    return $context
}

$started = [datetime]::SpecifyKind([datetime]'2026-10-07T00:00:00', [DateTimeKind]::Utc)
try {
    $rootHandle = New-FakeHandle 1001 $started
    Set-FakeRecord 1002 1001 ($started.AddSeconds(1))
    Set-FakeRecord 1003 1002 ($started.AddSeconds(2))
    Assert-True (Test-StmFirefoxOwnedDescendant -Handle $rootHandle -ProcessId 1001) 'The live original root must be accepted.'
    Assert-True (Test-StmFirefoxOwnedDescendant -Handle $rootHandle -ProcessId 1003) 'A valid monotone child chain must be accepted.'

    Set-FakeRecord 2001 0 ($started.AddSeconds(3))
    Assert-True (-not (Test-StmFirefoxOwnedDescendant -Handle $rootHandle -ProcessId 2001)) 'A foreign process must not be accepted.'
    Set-FakeRecord 2002 2001 ($started.AddSeconds(4))
    Assert-True (-not (Test-StmFirefoxOwnedDescendant -Handle $rootHandle -ProcessId 2002)) 'A foreign descendant must not become owned.'

    # Borrowed/reused intermediate parent PID: its current birth is AFTER the child's birth.
    Set-FakeRecord 1002 1001 ($started.AddSeconds(5))
    Set-FakeRecord 1003 1002 ($started.AddSeconds(2))
    Assert-True (-not (Test-StmFirefoxOwnedDescendant -Handle $rootHandle -ProcessId 1003)) 'Reused younger parent PID must be rejected.'
    Set-FakeRecord 1002 1001 ($started.AddSeconds(-1))
    Assert-True (-not (Test-StmFirefoxOwnedDescendant -Handle $rootHandle -ProcessId 1002)) 'A process older than the root must be rejected.'
    Set-FakeRecord 1002 1001 $null
    Assert-True (-not (Test-StmFirefoxOwnedDescendant -Handle $rootHandle -ProcessId 1002)) 'Missing process birth must be rejected.'
    Set-FakeRecord 1002 1001 ($started.AddSeconds(1))
    $script:records[1002].ProcessId = 9999
    Assert-True (-not (Test-StmFirefoxOwnedDescendant -Handle $rootHandle -ProcessId 1002)) 'A returned PID mismatch must be rejected.'
    $script:records.Remove(1002)
    Assert-True (-not (Test-StmFirefoxOwnedDescendant -Handle $rootHandle -ProcessId 1002)) 'A vanished process record must be rejected.'

    Set-FakeRecord 3001 3002 ($started.AddSeconds(1))
    Set-FakeRecord 3002 3001 ($started.AddSeconds(1))
    $script:cimQueries.Clear()
    Assert-True (-not (Test-StmFirefoxOwnedDescendant -Handle $rootHandle -ProcessId 3001)) 'A cyclic parent chain must be rejected.'
    Assert-True ($script:cimQueries.Count -eq 2) 'A cycle must terminate without repeated queries.'
    $script:records = @{}
    for ($i = 0; $i -lt 40; $i++) { Set-FakeRecord (4000 + $i) (4001 + $i) ($started.AddSeconds(1)) }
    Set-FakeRecord 4040 1001 ($started.AddSeconds(1))
    $script:cimQueries.Clear()
    Assert-True (-not (Test-StmFirefoxOwnedDescendant -Handle $rootHandle -ProcessId 4000)) 'A chain deeper than the bound must be rejected.'
    Assert-True ($script:cimQueries.Count -eq 32) 'Depth rejection must use at most 32 metadata queries.'
    $rootHandle.Process.HasExited = $true
    $script:cimQueries.Clear()
    Assert-True (-not (Test-StmFirefoxOwnedDescendant -Handle $rootHandle -ProcessId 1001)) 'An exited original root must be rejected.'
    Assert-True ($script:cimQueries.Count -eq 0) 'An exited root must not follow candidate PID chains.'

    # Even with free ports and a successful root-only drain, early root exit cannot prove tree exit.
    $context = New-CleanupFixture
    $browser = New-FakeHandle 5001 $started $true
    $browser | Add-Member -NotePropertyName RequiresLiveTreeCleanup -NotePropertyValue $true
    $backend = New-FakeHandle 5002 $started
    $context.Handles.Add($browser)
    $context.Handles.Add($backend)
    $context.BrowserHandle = $browser
    $beforeStops = $script:stopCalls.Count
    Assert-Rejects { Stop-StmFirefoxSmoke -Context $context } '(?i)(root exited|descendant exit is unverified|unverified.*tree|tree.*unverified)'
    Assert-True ($script:stopCalls.Count -eq $beforeStops + 2) 'Cleanup must still attempt both owned synthetic handles.'
    Assert-True ($browser.Closed -and $backend.Closed) 'Root pipe drain and other owned child cleanup must still complete.'
    Assert-True ([IO.File]::Exists((Join-Path $context.DataDirectory 'retained-sentinel.txt'))) 'Unverified early root exit must retain temp data.'
    Assert-Rejects { Stop-StmFirefoxSmoke -Context $context } '(?i)(root exited|descendant exit is unverified|unverified.*tree|tree.*unverified)'
    Assert-True ([IO.File]::Exists((Join-Path $context.DataDirectory 'retained-sentinel.txt'))) 'Repeated cleanup must not clear the unverified tree state or delete temp data.'

    $racingContext = New-CleanupFixture
    $racingBrowser = New-FakeHandle 5501 $started
    $racingBrowser | Add-Member -NotePropertyName RequiresLiveTreeCleanup -NotePropertyValue $true
    $racingBrowser | Add-Member -NotePropertyName ExitBeforeStop -NotePropertyValue $true
    $racingContext.Handles.Add($racingBrowser)
    Assert-Rejects { Stop-StmFirefoxSmoke -Context $racingContext } '(?i)(root exited|unverified.*tree|tree.*unverified)'
    Assert-True ($racingBrowser.Closed -and -not $racingBrowser.Result.TreeKillSucceeded) 'A root exit racing with stop must not become tree termination evidence.'
    Assert-Rejects { Stop-StmFirefoxSmoke -Context $racingContext } '(?i)(root exited|unverified.*tree|tree.*unverified)'
    Assert-True ([IO.File]::Exists((Join-Path $racingContext.DataDirectory 'retained-sentinel.txt'))) 'The racing root exit must retain its sentinel across retries.'

    $failedContext = New-CleanupFixture
    $failedContext.Failed = $true
    $failedBackend = New-FakeHandle 6001 $started
    $failedContext.Handles.Add($failedBackend)
    Stop-StmFirefoxSmoke -Context $failedContext 3>$null
    Assert-True ($failedBackend.Closed) 'A failed smoke must still stop its owned child.'
    Assert-True ([IO.File]::Exists((Join-Path $failedContext.DataDirectory 'retained-sentinel.txt'))) 'Failed smoke diagnostic retention must preserve its temp data.'

    $foreignHandle = [pscustomobject]@{ Process = [pscustomobject]@{ Id = 99999 } }
    Assert-Rejects { Stop-StmBackgroundProcess -Handle $foreignHandle } 'foreign synthetic handle'
    Write-Output "FIREFOX_SMOKE_SAFETY=PASS assertions=$checks PROCESS_EXECUTION=NONE PID_KILL=NONE ENV_MUTATION=NONE"
}
finally {
    Set-Item Function:\Stop-StmBackgroundProcess -Value $originalStop
    Set-Item Function:\Test-StmFirefoxPortFree -Value $originalPortFree
    Remove-Item Function:\Get-CimInstance -ErrorAction SilentlyContinue
    # Exact self-created fixtures only; delete one known inert file and an empty directory.
    foreach ($fixture in $fixtures) {
        $full = [IO.Path]::GetFullPath($fixture)
        $parent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
        if (-not $full.StartsWith($parent, [StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($full) -notmatch '^stm-firefox-smoke-[a-f0-9]{32}$') {
            throw 'Synthetic fixture cleanup leaves its exact owned temporary directory.'
        }
        if (-not [IO.Directory]::Exists($full)) { continue }
        $item = Get-Item -LiteralPath $full -Force -ErrorAction Stop
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Synthetic fixture root is a reparse point.' }
        $sentinel = Join-Path $full 'retained-sentinel.txt'
        if ([IO.File]::Exists($sentinel)) {
            $item = Get-Item -LiteralPath $sentinel -Force -ErrorAction Stop
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Synthetic sentinel is a reparse point.' }
            [IO.File]::Delete($sentinel)
        }
        [IO.Directory]::Delete($full, $false)
    }
}
