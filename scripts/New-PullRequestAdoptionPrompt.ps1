#requires -Version 7.0
<#
.SYNOPSIS
Erzeugt einen SHA-gebundenen Adoption-Prompt mit strikter Trust-Trennung.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$Repository,
    [Parameter(Mandatory)][ValidateRange(1, [int]::MaxValue)][int]$PullRequestNumber,
    [Parameter(Mandatory)][string]$ReviewReport,
    [Parameter(Mandatory)][string]$OutputDirectory
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
    'scripts/New-PullRequestAdoptionPrompt.ps1','scripts/Invoke-SafePullRequestReview.ps1','scripts/lib/PullRequestReviewCommon.ps1',
    'config/pull-request-review-policy.json','config/dependency-review-policy.json','config/suspicious-change-patterns.json','config/pr-adoption-policy.json',
    'config/trusted-instruction-paths.json','docs/ai/templates/SAFE_PULL_REQUEST_ADOPTION.md'
)
& git -C $repoRoot diff --quiet --no-ext-diff --no-textconv refs/remotes/origin/development -- @runtimePaths
if ($LASTEXITCODE -ne 0) { throw 'Adoption-Runtime weicht vom aktuellen vertrauenswuerdigen development-Stand ab.' }
. $commonPath
Assert-ReviewRepositoryIdentifier $Repository
if ($Repository -cne 'Randspringer90/SchachTurnierManager') { throw 'Nur das kanonische Repository ist erlaubt.' }
$reportPath = Assert-SafeReviewArtifactPath -Path $ReviewReport -RepositoryRoot $repoRoot
if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) { throw 'ReviewReport fehlt.' }
try { $report = Get-Content -Raw -LiteralPath $reportPath | ConvertFrom-Json } catch { throw 'ReviewReport ist ungueltig.' }
$policies = Import-PullRequestReviewPolicies -RepositoryRoot $repoRoot
if (-not (Test-PullRequestReviewReportBinding -Report $report -Repository $Repository -PullRequestNumber $PullRequestNumber -Policies $policies)) { throw 'ReviewReport-Bindung oder Policy-Bindung ist ungueltig.' }
$originDevelopment = (& git -C $repoRoot rev-parse refs/remotes/origin/development 2>$null | Select-Object -First 1)
if ($LASTEXITCODE -ne 0 -or [string]$originDevelopment -cne [string]$report.baseSha) { throw 'origin/development ist nicht mehr der gepruefte Base-SHA; statisches Review wiederholen.' }
$currentRaw = & gh pr view $PullRequestNumber --repo $Repository --json headRefOid,baseRefOid,baseRefName,state 2>$null
if ($LASTEXITCODE -ne 0) { throw 'Aktueller PR-Stand konnte nicht validiert werden.' }
try { $current = $currentRaw | ConvertFrom-Json } catch { throw 'Aktueller PR-Stand ist ungueltig.' }
if ([string]$current.state -ne 'OPEN' -or [string]$current.headRefOid -cne [string]$report.headSha -or
    [string]$current.baseRefOid -cne [string]$report.baseSha -or [string]$current.baseRefName -cne 'development') {
    throw 'PR-Status, Zielbranch oder Head-/Base-SHA hat sich seit dem Review geaendert.'
}
$outputPath = Assert-SafeReviewOutputPath -Path $OutputDirectory -RepositoryRoot $repoRoot -AllowBoundReviewDirectory -ExpectedReviewId ([string]$report.reviewId)
$metadataPath = Join-Path (Split-Path -Parent $reportPath) 'metadata.json'
$filesPath = Join-Path (Split-Path -Parent $reportPath) 'changed-files.json'
try { $metadataRaw = Get-Content -Raw -LiteralPath $metadataPath; $metadata = $metadataRaw | ConvertFrom-Json } catch { throw 'Gebundene metadata.json fehlt oder ist ungueltig.' }
try { $filesRaw = Get-Content -Raw -LiteralPath $filesPath; $files = $filesRaw | ConvertFrom-Json } catch { throw 'Gebundene changed-files.json fehlt oder ist ungueltig.' }
foreach ($bound in $metadata,$files) {
    if ([string](Get-ReviewPropertyValue $bound 'reviewId' '') -cne [string]$report.reviewId) { throw 'Review-Artefakte haben unterschiedliche Review-IDs.' }
}
$boundHashes = Get-ReviewPropertyValue $report 'boundArtifactHashes' $null
if ($null -eq $boundHashes -or
    -not (Test-BoundReviewArtifact -Artifact $metadata -StaticReport $report -ExpectedHash ([string]$boundHashes.metadata) -RawText $metadataRaw) -or
    -not (Test-BoundReviewArtifact -Artifact $files -StaticReport $report -ExpectedHash ([string]$boundHashes.changedFiles) -RawText $filesRaw)) {
    throw 'Gebundene Review-Artefakte wurden veraendert oder sind unvollstaendig.'
}
$fresh = Invoke-TrustedLiveReviewReanalysis -Repository $Repository -PullRequestNumber $PullRequestNumber -Report $report -RepositoryRoot $repoRoot
$metadata = $fresh.metadata
$files = $fresh.files
$integrationBranch = "integration/pr-$PullRequestNumber-safe-adoption"
if ($integrationBranch -cnotmatch [string]$policies.adoption.integrationBranchPattern) { throw 'Integrationsbranch verletzt die Adoption-Policy.' }
$template = Get-Content -Raw -LiteralPath (Join-Path $repoRoot 'docs/ai/templates/SAFE_PULL_REQUEST_ADOPTION.md')
$decision = [string]$report.decision
$allowed = 'keine automatische Dateifreigabe; nur nach expliziter Owner-Freigabe im Integrationsplan'
$forbidden = if ($decision -eq 'SAFE_FOR_ISOLATED_BUILD') { 'alle nicht im Review genannten Dateien sowie Binär-/Archiv-/Symlink-/Submodule-Inhalte' } else { 'alle nicht explizit durch den Owner genehmigten Dateien' }
$categories = @($report.findings.category | Sort-Object -Unique)
$values = [ordered]@{
    '{{REPOSITORY}}' = $Repository
    '{{PR_NUMBER}}' = [string]$PullRequestNumber
    '{{BASE_SHA}}' = [string]$report.baseSha
    '{{HEAD_SHA}}' = [string]$report.headSha
    '{{INTEGRATION_BRANCH}}' = $integrationBranch
    '{{ALLOWED_FILES}}' = $allowed
    '{{FORBIDDEN_FILES}}' = $forbidden
    '{{REQUIRED_TESTS}}' = 'gezielte Contract-Tests, Security-Gates, dotnet build/test, Frontend-Typecheck/-Build, git diff --check, ReleaseGate'
    '{{PR_TITLE}}' = ConvertTo-SafeReviewMarkdown ([string]$metadata.title) 160
    '{{CONTRIBUTOR}}' = ConvertTo-SafeReviewMarkdown ([string]$metadata.author) 80
    '{{DECISION}}' = $decision
    '{{RISK_CLASS}}' = [string]$report.riskClass
    '{{DIFF_SUMMARY}}' = "$($files.count) redigierte Dateipfade; keine rohe Patch-Payload persistiert"
    '{{RISK_CATEGORIES}}' = if($categories){$categories -join ', '}else{'keine statischen Findings'}
}
foreach ($entry in $values.GetEnumerator()) { $template = $template.Replace($entry.Key, [string]$entry.Value) }
if ($template -match '\{\{[A-Z_]+\}\}') { throw 'Adoption-Prompt enthaelt nicht ersetzte Platzhalter.' }
if ($WhatIfPreference) { Write-Host "ADOPTION_PROMPT_WHATIF=OK PR=$PullRequestNumber"; exit 0 }
if (-not (Test-Path -LiteralPath $outputPath -PathType Container)) { New-Item -ItemType Directory -Path $outputPath | Out-Null }
[void](Assert-NoReviewReparseAncestor -Path $outputPath -Context 'Adoption-Prompt-Ausgabeverzeichnis')
$target = Join-Path $outputPath "pr-$PullRequestNumber-adoption-prompt.md"
[void](Write-ReviewUtf8FileCreateNew -Path $target -Content $template)
Write-Host "ADOPTION_PROMPT=OK"
exit 0
