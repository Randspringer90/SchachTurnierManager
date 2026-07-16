#requires -Version 7.0
<#
.SYNOPSIS
Validiert einen Nightly-Checkpoint und liefert einen nicht ausfuehrenden Resume-Plan.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$CheckpointPath,
    [string]$RepositoryRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/NightlyResumeCommon.ps1')

$policy = Get-NightlyPolicy
$repo = Resolve-NightlyRepositoryRoot -RepositoryRoot $RepositoryRoot
$checkpoint = Read-NightlyCheckpoint -CheckpointPath $CheckpointPath -RepositoryRoot $repo -Policy $policy
$gitState = Get-NightlyGitState -RepositoryRoot $repo

$decision = 'READY_TO_RESUME'
$reason = 'Checkpoint, Branch, Head und Arbeitsbaum stimmen ueberein.'
if ($checkpoint.status -eq 'COMPLETED') {
    $decision = 'NO_RESUME_REQUIRED'
    $reason = 'Checkpoint ist bereits abgeschlossen.'
}
elseif ([int]$checkpoint.progress.attempt -ge [int]$policy.maxResumeAttempts) {
    $decision = 'BLOCKED_ATTEMPT_LIMIT'
    $reason = 'Maximale Resume-Versuche sind erreicht.'
}
elseif ([bool]$policy.requireExactBranch -and $gitState.Branch -cne [string]$checkpoint.repository.branch) {
    $decision = 'BLOCKED_BRANCH_MISMATCH'
    $reason = 'Aktueller Branch weicht vom Checkpoint ab.'
}
elseif ([bool]$policy.requireExactHead -and $gitState.HeadSha -cne [string]$checkpoint.repository.headSha) {
    $decision = 'BLOCKED_HEAD_MISMATCH'
    $reason = 'Aktueller Head weicht vom Checkpoint ab.'
}
elseif ([bool]$policy.requireCleanWorktree -and -not $gitState.WorktreeClean) {
    $decision = 'BLOCKED_DIRTY_WORKTREE'
    $reason = 'Arbeitsbaum ist nicht sauber.'
}

[pscustomobject]@{
    SchemaVersion = 1
    Decision = $decision
    Reason = $reason
    CheckpointId = [string]$checkpoint.checkpointId
    PackageId = [string]$checkpoint.packageId
    Phase = [string]$checkpoint.phase
    NextAction = [string]$checkpoint.progress.nextAction
    Branch = $gitState.Branch
    HeadSha = $gitState.HeadSha
    Command = $null
    InstructionActivated = $false
    NetworkUsed = $false
    GitWritePerformed = $false
    SchedulerMutationPerformed = $false
    ExternalWritePerformed = $false
}
