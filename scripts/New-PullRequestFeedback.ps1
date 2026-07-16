#requires -Version 7.0
<#
.SYNOPSIS
Erzeugt redigiertes Contributor-Feedback und postet es nur nach expliziter, SHA-gebundener Freigabe.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$Repository,
    [Parameter(Mandatory)][ValidateRange(1, [int]::MaxValue)][int]$PullRequestNumber,
    [Parameter(Mandatory)][string]$ReviewReport,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [switch]$Post
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$commonPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'lib/PullRequestReviewCommon.ps1'))
foreach ($trustedPath in @($PSCommandPath,$PSScriptRoot,$repoRoot,$commonPath,(Join-Path $repoRoot 'SchachTurnierManager.sln'))) {
    $cursor = [IO.Path]::GetFullPath($trustedPath)
    while ($cursor) {
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue
        if ($item -and (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) { throw 'Vertrauenswuerdiger Skriptpfad enthaelt einen Reparse-Point.' }
        $parent = Split-Path -Parent $cursor
        if (-not $parent -or $parent -eq $cursor) { break }
        $cursor = $parent
    }
}
if (-not (Test-Path -LiteralPath (Join-Path $repoRoot 'SchachTurnierManager.sln') -PathType Leaf) -or -not (Test-Path -LiteralPath $commonPath -PathType Leaf)) { throw 'Vertrauenswuerdiger Projektkontext fehlt.' }
$actualRootLines = @(& git -C $repoRoot rev-parse --show-toplevel 2>$null)
$rootExit = $LASTEXITCODE
$actualRoot = $actualRootLines | Select-Object -First 1
$originLines = @(& git -C $repoRoot remote get-url origin 2>$null)
$originExit = $LASTEXITCODE
$origin = $originLines | Select-Object -First 1
if ($rootExit -ne 0 -or $originExit -ne 0 -or -not $actualRoot -or -not $origin -or [IO.Path]::GetFullPath(([string]$actualRoot).Trim()) -cne $repoRoot -or ([string]$origin).Trim() -notmatch '(?i)github\.com[:/]Randspringer90/SchachTurnierManager(?:\.git)?$') { throw 'Skriptkontext oder origin ist nicht freigegeben.' }
$runtimePaths = @(
    'scripts/New-PullRequestFeedback.ps1','scripts/Invoke-SafePullRequestReview.ps1','scripts/lib/PullRequestReviewCommon.ps1',
    'config/pull-request-review-policy.json','config/dependency-review-policy.json','config/suspicious-change-patterns.json','config/pr-adoption-policy.json',
    'docs/ai/templates/PULL_REQUEST_ADOPTION_FEEDBACK.md'
)
& git -C $repoRoot diff --quiet --no-ext-diff --no-textconv refs/remotes/origin/development -- @runtimePaths
if ($LASTEXITCODE -ne 0) { throw 'Feedback-Runtime weicht vom aktuellen vertrauenswuerdigen development-Stand ab.' }
. $commonPath
Assert-ReviewRepositoryIdentifier $Repository
if ($Repository -cne 'Randspringer90/SchachTurnierManager') { throw 'Nur das kanonische Repository ist erlaubt.' }
$reportPath = Assert-SafeReviewArtifactPath -Path $ReviewReport -RepositoryRoot $repoRoot
try { $report = Get-Content -Raw -LiteralPath $reportPath | ConvertFrom-Json } catch { throw 'ReviewReport fehlt oder ist ungueltig.' }
$policies = Import-PullRequestReviewPolicies -RepositoryRoot $repoRoot
if (-not (Test-PullRequestReviewReportBinding -Report $report -Repository $Repository -PullRequestNumber $PullRequestNumber -Policies $policies)) { throw 'ReviewReport-Bindung oder Policy-Bindung ist ungueltig.' }
$artifactRoot = Split-Path -Parent $reportPath
function Read-BoundJson([string]$Name) {
    try { $raw = Get-Content -Raw -LiteralPath (Join-Path $artifactRoot $Name); $value = $raw | ConvertFrom-Json } catch { throw "Gebundenes Artefakt fehlt oder ist ungueltig: $Name" }
    if ([string](Get-ReviewPropertyValue $value 'reviewId' '') -cne [string]$report.reviewId) { throw "Review-ID stimmt nicht: $Name" }
    return [pscustomobject]@{ Value=$value; Raw=$raw }
}
$metadataBound = Read-BoundJson 'metadata.json'; $metadata = $metadataBound.Value
$dependencyBound = Read-BoundJson 'dependency-delta.json'; $dependency = $dependencyBound.Value
$malwareBound = Read-BoundJson 'malware-risk-review.json'; $malware = $malwareBound.Value
$logicBound = Read-BoundJson 'logic-overlap.json'; $logic = $logicBound.Value
[void](Assert-PullRequestFeedbackArtifacts -Report $report -Metadata $metadata -MetadataRaw $metadataBound.Raw `
    -Dependency $dependency -DependencyRaw $dependencyBound.Raw -Malware $malware -MalwareRaw $malwareBound.Raw `
    -Logic $logic -LogicRaw $logicBound.Raw)
$fresh = Invoke-TrustedLiveReviewReanalysis -Repository $Repository -PullRequestNumber $PullRequestNumber -Report $report -RepositoryRoot $repoRoot
$metadata = $fresh.metadata
$dependency = $fresh.dependency
$malware = $fresh.malware
$logic = $fresh.logic
$outputPath = Assert-SafeReviewOutputPath -Path $OutputDirectory -RepositoryRoot $repoRoot -AllowBoundReviewDirectory -ExpectedReviewId ([string]$report.reviewId)
$template = Get-Content -Raw -LiteralPath (Join-Path $repoRoot 'docs/ai/templates/PULL_REQUEST_ADOPTION_FEEDBACK.md')
$template = New-PullRequestFeedbackText -Template $template -Report $report -Metadata $metadata -Dependency $dependency -Malware $malware -Logic $logic -Repository $Repository -PullRequestNumber $PullRequestNumber
if ($WhatIfPreference) { Write-Host "PR_FEEDBACK_WHATIF=OK PR=$PullRequestNumber"; exit 0 }
if (-not (Test-Path -LiteralPath $outputPath -PathType Container)) { New-Item -ItemType Directory -Path $outputPath | Out-Null }
[void](Assert-NoReviewReparseAncestor -Path $outputPath -Context 'Feedback-Ausgabeverzeichnis')
$target = Join-Path $outputPath "pr-$PullRequestNumber-feedback.md"
[void](Write-ReviewUtf8FileCreateNew -Path $target -Content $template)
if ($Post) {
    $currentRaw = & gh pr view $PullRequestNumber --repo $Repository --json headRefOid,baseRefOid,baseRefName,state 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'Aktueller PR-Head konnte nicht validiert werden.' }
    try { $current = $currentRaw | ConvertFrom-Json } catch { throw 'Aktueller PR-Status ist ungueltig.' }
    $baseRaw = & gh api "repos/$Repository/git/ref/heads/development" 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'Aktueller development-Stand konnte nicht validiert werden.' }
    try { $currentBase = $baseRaw | ConvertFrom-Json } catch { throw 'Aktueller development-Stand ist ungueltig.' }
    [void](Assert-PullRequestLiveStateBinding -CurrentPullRequest $current -CurrentBaseRef $currentBase -Report $report)
    & gh pr comment $PullRequestNumber --repo $Repository --body-file $target 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'Validiertes Feedback konnte nicht gepostet werden.' }
    Write-Host 'PR_FEEDBACK_POSTED=OK'
}
else { Write-Host 'PR_FEEDBACK_DRAFT=OK' }
exit 0
