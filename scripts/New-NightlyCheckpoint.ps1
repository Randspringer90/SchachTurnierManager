#requires -Version 7.0
<#
.SYNOPSIS
Erzeugt einen SHA-gebundenen, rein lokalen Nightly-/Resume-Checkpoint.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{2,63}$')][string]$RunId,
    [Parameter(Mandatory)][ValidatePattern('^STM-[A-Z]+-[0-9]{3}$')][string]$PackageId,
    [Parameter(Mandatory)][ValidateLength(2, 80)][string]$Phase,
    [Parameter(Mandatory)][ValidateSet('IN_PROGRESS', 'READY_TO_RESUME', 'COMPLETED', 'BLOCKED')][string]$Status,
    [Parameter(Mandatory)][ValidateLength(3, 160)][string]$LastSuccessfulStep,
    [Parameter(Mandatory)][ValidateLength(3, 240)][string]$NextAction,
    [ValidateRange(0, 5)][int]$Attempt = 0,
    [string]$RepositoryRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/NightlyResumeCommon.ps1')

foreach ($entry in @{ RunId=$RunId; PackageId=$PackageId; Phase=$Phase; LastSuccessfulStep=$LastSuccessfulStep; NextAction=$NextAction }.GetEnumerator()) {
    Assert-NightlyDataSafe -Name $entry.Key -Value ([string]$entry.Value)
}

$policy = Get-NightlyPolicy
if ($Attempt -gt [int]$policy.maxResumeAttempts) { throw 'Attempt ueberschreitet die Policy-Grenze.' }
$repo = Resolve-NightlyRepositoryRoot -RepositoryRoot $RepositoryRoot
$gitState = Get-NightlyGitState -RepositoryRoot $repo
if ([bool]$policy.requireExactBranch -and $gitState.Branch -cne [string]$policy.defaultBranch) { throw 'Checkpoint erfordert den kanonischen Branch.' }
if ([bool]$policy.requireCleanWorktree -and -not $gitState.WorktreeClean) { throw 'Checkpoint erfordert einen sauberen Arbeitsbaum.' }

$createdAt = [DateTimeOffset]::UtcNow.ToString('o')
$idSeed = "$RunId`n$PackageId`n$createdAt`n$($gitState.HeadSha)"
$idHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($idSeed))).ToLowerInvariant().Substring(0, 12)
$checkpointId = "nightly-$([DateTimeOffset]::UtcNow.ToString('yyyyMMddHHmmssfff'))-$idHash"
$checkpoint = [ordered]@{
    schemaVersion = 1
    checkpointId = $checkpointId
    runId = $RunId
    projectKey = [string]$policy.projectKey
    packageId = $PackageId
    phase = $Phase
    status = $Status
    createdAt = $createdAt
    repository = [ordered]@{
        branch = $gitState.Branch
        headSha = $gitState.HeadSha
        worktreeClean = [bool]$gitState.WorktreeClean
    }
    progress = [ordered]@{
        attempt = $Attempt
        lastSuccessfulStep = $LastSuccessfulStep
        nextAction = $NextAction
    }
    controls = [ordered]@{
        dataOnly = $true
        command = $null
        networkUsed = $false
        gitWritePerformed = $false
        schedulerMutationPerformed = $false
        externalWritePerformed = $false
    }
    bindingSha256 = ''
}
$checkpoint.bindingSha256 = Get-NightlyCheckpointBinding -Checkpoint $checkpoint
$outputRoot = Resolve-NightlyConfiguredRoot -RepositoryRoot $repo -RelativePath ([string]$policy.checkpointRoot) -Create
$destination = Join-Path $outputRoot "$checkpointId.json"
$written = Write-NightlyAtomicJson -Value $checkpoint -Destination $destination -Boundary $outputRoot

[pscustomobject]@{
    Status = 'CHECKPOINT_CREATED'
    CheckpointId = $checkpointId
    CheckpointPath = $written
    Branch = $gitState.Branch
    HeadSha = $gitState.HeadSha
    ReadyForResume = ($Status -eq 'READY_TO_RESUME')
    SideEffects = 'LOCAL_DATA_WRITE_ONLY'
}
