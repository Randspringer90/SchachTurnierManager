#requires -Version 7.0
<#
.SYNOPSIS
Exportiert eine lokale, nicht aktivierende Registrierungsplanung fuer einen Owner-Orchestrator.
#>
[CmdletBinding()]
param([string]$RepositoryRoot)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/NightlyResumeCommon.ps1')

$policy = Get-NightlyPolicy
$repo = Resolve-NightlyRepositoryRoot -RepositoryRoot $RepositoryRoot
$gitState = Get-NightlyGitState -RepositoryRoot $repo
if ($gitState.Branch -cne [string]$policy.defaultBranch -or -not $gitState.WorktreeClean) {
    throw 'Registrierungsplanung erfordert sauberes development.'
}
$outputRoot = Resolve-NightlyConfiguredRoot -RepositoryRoot $repo -RelativePath ([string]$policy.registrationOutputRoot) -Create
$generatedAt = [DateTimeOffset]::UtcNow.ToString('o')
$planId = "registration-$([DateTimeOffset]::UtcNow.ToString('yyyyMMddHHmmssfff'))-$([Guid]::NewGuid().ToString('N').Substring(0, 8))"
$plan = [ordered]@{
    schemaVersion = 1
    registrationId = $planId
    generatedAt = $generatedAt
    status = [string]$policy.registrationStatus
    projectKey = [string]$policy.projectKey
    defaultBranch = [string]$policy.defaultBranch
    checkpointRoot = [string]$policy.checkpointRoot
    consumerContract = 'project-local-nightly-v1'
    source = [ordered]@{
        branch = $gitState.Branch
        headSha = $gitState.HeadSha
        worktreeClean = [bool]$gitState.WorktreeClean
    }
    activationRequiresExplicitOwnerAction = $true
    automaticExecutionEnabled = $false
    activationCommand = $null
    controls = [ordered]@{
        gitMutationAllowed = $false
        networkMutationAllowed = $false
        schedulerMutationAllowed = $false
        externalWriteAllowed = $false
        automaticInstructionActivationAllowed = $false
    }
    bindingSha256 = ''
}
$plan.bindingSha256 = Get-NightlyRegistrationBinding -Plan $plan
$destination = Join-Path $outputRoot "$planId.json"
$written = Write-NightlyAtomicJson -Value $plan -Destination $destination -Boundary $outputRoot

[pscustomobject]@{
    Status = [string]$plan.status
    RegistrationId = $planId
    PlanPath = $written
    ActivationPerformed = $false
    SideEffects = 'LOCAL_DATA_WRITE_ONLY'
}
