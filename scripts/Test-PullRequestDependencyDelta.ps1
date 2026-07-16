#requires -Version 7.0
# SECURITY-PATTERN-FILE: Defensive Dependency-Delta-Muster; keine Paketmanager werden ausgefuehrt.
<#
.SYNOPSIS
Prueft ein lokales, untrusted Offline-Bundle ausschliesslich statisch auf Dependency-Deltas.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$InputBundleDirectory,
    [Parameter(Mandatory)][string]$OutputFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$RepositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$commonPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'lib/PullRequestReviewCommon.ps1'))
if (-not (Test-Path -LiteralPath $commonPath -PathType Leaf)) {
    throw 'Vertrauenswuerdige Review-Bibliothek fehlt oder ist ein Reparse-Point.'
}
foreach ($trustedPath in @($PSCommandPath,$PSScriptRoot,$RepositoryRoot,$commonPath,(Join-Path $RepositoryRoot 'SchachTurnierManager.sln'))) {
    $cursor = [IO.Path]::GetFullPath($trustedPath)
    while ($cursor) {
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue
        if ($item -and (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) { throw 'Vertrauenswuerdiger Repositorypfad enthaelt einen Reparse-Point.' }
        $parent = Split-Path -Parent $cursor
        if (-not $parent -or $parent -eq $cursor) { break }
        $cursor = $parent
    }
}
if (-not (Test-Path -LiteralPath (Join-Path $RepositoryRoot 'SchachTurnierManager.sln') -PathType Leaf)) { throw 'Projektidentitaet fehlt.' }
$actualRootLines = @(& git -C $RepositoryRoot rev-parse --show-toplevel 2>$null)
$rootExit = $LASTEXITCODE
$actualRoot = $actualRootLines | Select-Object -First 1
$originLines = @(& git -C $RepositoryRoot remote get-url origin 2>$null)
$originExit = $LASTEXITCODE
$origin = $originLines | Select-Object -First 1
if ($rootExit -ne 0 -or $originExit -ne 0 -or -not $actualRoot -or -not $origin -or [IO.Path]::GetFullPath(([string]$actualRoot).Trim()) -cne $RepositoryRoot -or ([string]$origin).Trim() -notmatch '(?i)github\.com[:/]Randspringer90/SchachTurnierManager(?:\.git)?$') { throw 'Skriptkontext oder origin ist nicht freigegeben.' }
. $commonPath
$bundle = Resolve-SafeReviewInputBundle -Path $InputBundleDirectory -RepositoryRoot $RepositoryRoot
$policies = Import-PullRequestReviewPolicies -RepositoryRoot $RepositoryRoot
$output = Assert-SafeReviewOutputPath -Path $OutputFile -RepositoryRoot $RepositoryRoot -TargetType File
try { $files = @(Get-Content -Raw -LiteralPath (Join-Path $bundle 'changed-files.json') | ConvertFrom-Json) } catch { throw 'changed-files.json ist ungueltig.' }
$patch = Get-Content -Raw -LiteralPath (Join-Path $bundle 'patch.diff')
if ([Text.Encoding]::UTF8.GetByteCount($patch) -gt [int]$policies.review.maxPatchBytes) { throw 'Patch ist fuer die statische Dependency-Pruefung zu gross.' }
$findings = [Collections.Generic.List[object]]::new()
$delta = Get-PullRequestDependencyDelta -ChangedFiles $files -PatchText $patch -Policy $policies.dependency -Findings $findings
$report = [pscustomobject]@{
    schemaVersion = 1
    sourceZone = 'T4'
    foreignCodeExecuted = $false
    packageManagerExecuted = $false
    secretAccess = 'denied'
    status = $delta.status
    result = $delta
    findings = @($findings | Sort-Object code, evidenceHash -Unique)
}
if ($WhatIfPreference) {
    Write-Host "DEPENDENCY_DELTA_WHATIF=OK STATUS=$($delta.status) FINDINGS=$($findings.Count)"
    exit 0
}
$parent = Split-Path -Parent $output
if (-not (Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Path $parent | Out-Null }
[void](Assert-NoReviewReparseAncestor -Path $parent -Context 'Dependency-Review-Ausgabeverzeichnis')
[void](Write-ReviewUtf8FileCreateNew -Path $output -Content ($report | ConvertTo-Json -Depth 12))
Write-Host "DEPENDENCY_DELTA=$($delta.status)"
exit 0
