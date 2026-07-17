#requires -Version 7.0
# SECURITY-PATTERN-FILE: Statische defensive PR-Klassifikation; PR-Inhalte werden nie ausgefuehrt.
<#
.SYNOPSIS
Prueft einen Pull Request standardmaessig read-only und static-only gegen die STM-Trust-Policies.
.DESCRIPTION
Online werden ausschliesslich Metadaten, Dateiliste und Patch ueber feste gh-Endpunkte gelesen.
Offline wird ein streng validiertes Input-Bundle verwendet. Kein PR-Code wird ausgecheckt,
ausgefuehrt, restauriert, gebaut, getestet, installiert oder gemergt.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$Repository,
    [Parameter(Mandatory)][ValidateRange(1, [int]::MaxValue)][int]$PullRequestNumber,
    [Parameter(Mandatory)][string]$BaseBranch,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [switch]$Offline,
    [switch]$StaticOnly,
    [switch]$PrepareAdoption,
    [switch]$PostFeedback,
    [string]$IntegrationBranchName,
    [switch]$AllowNetworkAfterStaticApproval,
    [switch]$RunDefenderScan,
    [switch]$SkipGitHubComment,
    [string]$InputBundleDirectory,
    [string]$ExpectedHeadSha,
    [string]$ExpectedBaseSha
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
if (-not (Test-Path -LiteralPath (Join-Path $repoRoot 'SchachTurnierManager.sln') -PathType Leaf) -or
    -not (Test-Path -LiteralPath $commonPath -PathType Leaf)) { throw 'Vertrauenswuerdiger SchachTurnierManager-Skriptkontext fehlt.' }
$actualRootLines = @(& git -C $repoRoot rev-parse --show-toplevel 2>$null)
$rootExit = $LASTEXITCODE
$actualRoot = $actualRootLines | Select-Object -First 1
$originLines = @(& git -C $repoRoot remote get-url origin 2>$null)
$originExit = $LASTEXITCODE
$origin = $originLines | Select-Object -First 1
if ($rootExit -ne 0 -or $originExit -ne 0 -or -not $actualRoot -or -not $origin -or
    [IO.Path]::GetFullPath(([string]$actualRoot).Trim()) -cne $repoRoot -or
    ([string]$origin).Trim() -notmatch '(?i)github\.com[:/]Randspringer90/SchachTurnierManager(?:\.git)?$') {
    throw 'Skriptkontext oder origin ist nicht der freigegebene SchachTurnierManager.'
}
if (-not $Offline) {
    $trustedRuntimeRef = if ($ExpectedBaseSha) { $ExpectedBaseSha } else { 'refs/remotes/origin/development' }
    $runtimePaths = @(
        'scripts/Invoke-SafePullRequestReview.ps1','scripts/lib/PullRequestReviewCommon.ps1',
        'config/pull-request-review-policy.json','config/dependency-review-policy.json',
        'config/suspicious-change-patterns.json','config/pr-adoption-policy.json'
    )
    & git -C $repoRoot diff --quiet --no-ext-diff --no-textconv $trustedRuntimeRef -- @runtimePaths
    if ($LASTEXITCODE -ne 0) { throw 'Review-Runtime weicht vom erwarteten vertrauenswuerdigen Base-Stand ab.' }
}
. $commonPath
Assert-ReviewRepositoryIdentifier -Repository $Repository
if (-not $Offline -and $Repository -cne 'Randspringer90/SchachTurnierManager') { throw 'Online prueft dieses Projektskript ausschliesslich das kanonische Repository.' }
$policies = Import-PullRequestReviewPolicies -RepositoryRoot $repoRoot
Assert-ReviewBaseBranch -BaseBranch $BaseBranch -Policy $policies.review
$outputPath = Assert-SafeReviewOutputPath -Path $OutputDirectory -RepositoryRoot $repoRoot
$effectiveStaticOnly = $StaticOnly.IsPresent -or -not $PrepareAdoption.IsPresent

if (-not $IntegrationBranchName) { $IntegrationBranchName = "integration/pr-$PullRequestNumber-safe-adoption" }
if ($IntegrationBranchName -cne "integration/pr-$PullRequestNumber-safe-adoption" -or
    $IntegrationBranchName -cnotmatch [string]$policies.review.integrationBranchPattern) {
    throw 'IntegrationBranchName entspricht nicht der sicheren Policy.'
}
if ($PostFeedback -and $SkipGitHubComment) { $PostFeedback = $false }
if ($PostFeedback) { throw 'Der statische Reviewer darf kein GitHub-Feedback posten; validiertes Posting ist dem Pull-Request-Integrator ueber New-PullRequestFeedback.ps1 vorbehalten.' }
if ($RunDefenderScan) { throw 'Defender-Scan erfordert ein separat freigegebenes isoliertes Payload-Verzeichnis und ist in der statischen Phase gesperrt.' }
foreach ($expectedSha in @($ExpectedHeadSha,$ExpectedBaseSha)) {
    if ($expectedSha -and -not (Test-ReviewSha $expectedSha)) { throw 'Erwarteter Event-SHA ist ungueltig.' }
}

function Invoke-TrustedGhJson {
    param([Parameter(Mandatory)][string[]]$Arguments, [Parameter(Mandatory)][string]$Context)
    $raw = & gh @Arguments 2>$null
    if ($LASTEXITCODE -ne 0) { throw "$Context konnte nicht gelesen werden." }
    try { return (($raw -join "`n") | ConvertFrom-Json) } catch { throw "$Context lieferte ungueltiges JSON." }
}

function Get-OnlineReviewInput {
    if (-not (Test-OriginMatchesReviewRepository -Repository $Repository -RepositoryRoot $repoRoot)) {
        throw 'origin stimmt nicht mit dem angeforderten Repository ueberein.'
    }
    $metadata = Invoke-TrustedGhJson -Context 'PR-Metadaten' -Arguments @(
        'pr','view',[string]$PullRequestNumber,'--repo',$Repository,'--json',
        'number,title,body,author,headRefName,headRefOid,baseRefName,baseRefOid,changedFiles,url,state,isDraft'
    )
    $baseRef = Invoke-TrustedGhJson -Context 'aktueller Basebranch' -Arguments @(
        'api',"repos/$Repository/git/ref/heads/$BaseBranch"
    )
    $metadata | Add-Member -NotePropertyName currentTrustedBaseSha -NotePropertyValue ([string]$baseRef.object.sha) -Force
    $pages = Invoke-TrustedGhJson -Context 'PR-Dateiliste' -Arguments @(
        'api',"repos/$Repository/pulls/$PullRequestNumber/files",'--paginate','--slurp'
    )
    $apiFiles = @()
    foreach ($page in @($pages)) { $apiFiles += @($page) }
    $headTree = Invoke-TrustedGhJson -Context 'PR-Head-Git-Tree' -Arguments @('api',"repos/$Repository/git/trees/$([string]$metadata.headRefOid)?recursive=1")
    $baseTree = Invoke-TrustedGhJson -Context 'PR-Base-Git-Tree' -Arguments @('api',"repos/$Repository/git/trees/$([string]$metadata.baseRefOid)?recursive=1")
    $converted = ConvertFrom-GitHubPullRequestReviewData -ApiFiles $apiFiles -HeadTree $headTree -BaseTree $baseTree
    $metadata | Add-Member -NotePropertyName gitTreeMetadataComplete -NotePropertyValue ([bool]$converted.treeMetadataComplete) -Force
    return [pscustomobject]@{ metadata=$metadata; files=$converted.files; patch=$converted.patch }
}

function Get-OfflineReviewInput {
    if (-not $InputBundleDirectory) { throw 'Offline erfordert -InputBundleDirectory.' }
    $bundle = Resolve-SafeReviewInputBundle -Path $InputBundleDirectory -RepositoryRoot $repoRoot
    foreach ($name in 'metadata.json','changed-files.json','patch.diff') {
        $length = (Get-Item -LiteralPath (Join-Path $bundle $name)).Length
        if ($length -gt [int64]$policies.review.maxPatchBytes) { throw "Offline-Input ist zu gross: $name" }
    }
    try { $metadata = Get-Content -Raw -LiteralPath (Join-Path $bundle 'metadata.json') | ConvertFrom-Json } catch { throw 'Offline metadata.json ist ungueltig.' }
    try { $rawFiles = @(Get-Content -Raw -LiteralPath (Join-Path $bundle 'changed-files.json') | ConvertFrom-Json) } catch { throw 'Offline changed-files.json ist ungueltig.' }
    # T4-Bundles koennen Gitmodus, Tree-Vollstaendigkeit und Patchvollstaendigkeit nicht selbst
    # attestieren. Offline bleibt deshalb ein Findings-/Planungsmodus und immer fail-closed.
    $metadata | Add-Member -NotePropertyName gitTreeMetadataComplete -NotePropertyValue $false -Force
    $files = @($rawFiles | ForEach-Object {
        [pscustomobject]@{
            path = [string](Get-ReviewPropertyValue $_ 'path' (Get-ReviewPropertyValue $_ 'filename' ''))
            previousPath = [string](Get-ReviewPropertyValue $_ 'previousPath' (Get-ReviewPropertyValue $_ 'previous_filename' ''))
            status = [string](Get-ReviewPropertyValue $_ 'status' 'unknown')
            mode = ''
            modeAvailable = $false
            previousMode = ''
            previousModeAvailable = $false
            patchAvailable = [bool](Get-ReviewPropertyValue $_ 'patchAvailable' $false)
            patchComplete = $false
        }
    })
    $patch = Get-Content -Raw -LiteralPath (Join-Path $bundle 'patch.diff')
    return [pscustomobject]@{ metadata=$metadata; files=$files; patch=$patch }
}

# Bewusst NICHT $input: das ist in PowerShell die automatische Variable fuer den
# Pipeline-/stdin-Enumerator. Eine eigene Zuweisung darauf laesst das Skript bei
# offenem stdin (interaktive Shell, Agenten-Harness, CI ohne Redirect) blockieren.
$reviewInput = if ($Offline) { Get-OfflineReviewInput } else { Get-OnlineReviewInput }
$metadata = $reviewInput.metadata
if ([int](Get-ReviewPropertyValue $metadata 'number' 0) -ne $PullRequestNumber) { throw 'PR-Nummer im Input stimmt nicht mit dem Auftrag ueberein.' }
if ([string](Get-ReviewPropertyValue $metadata 'baseRefName' '') -cne $BaseBranch) { throw 'PR-Zielbranch stimmt nicht mit der Policy ueberein.' }
$headSha = [string](Get-ReviewPropertyValue $metadata 'headSha' (Get-ReviewPropertyValue $metadata 'headRefOid' ''))
$baseSha = [string](Get-ReviewPropertyValue $metadata 'baseSha' (Get-ReviewPropertyValue $metadata 'baseRefOid' ''))
if (-not (Test-ReviewSha $headSha) -or -not (Test-ReviewSha $baseSha)) { throw 'PR-Head/Base-SHA ist ungueltig.' }
if (($ExpectedHeadSha -and $headSha -cne $ExpectedHeadSha) -or ($ExpectedBaseSha -and $baseSha -cne $ExpectedBaseSha)) {
    throw 'Live PR-Head/Base entspricht nicht dem ausloesenden Event-SHA.'
}
$metadata | Add-Member -NotePropertyName headSha -NotePropertyValue $headSha -Force
$metadata | Add-Member -NotePropertyName baseSha -NotePropertyValue $baseSha -Force
$metadata | Add-Member -NotePropertyName currentTrustedBaseSha -NotePropertyValue ([string](Get-ReviewPropertyValue $metadata 'currentTrustedBaseSha' $baseSha)) -Force
$metadata | Add-Member -NotePropertyName headRefName -NotePropertyValue ([string](Get-ReviewPropertyValue $metadata 'headRefName' '')) -Force

$baseFiles = @()
$baseTreeAvailable = $false
& git -C $repoRoot cat-file -e "$baseSha^{commit}" 2>$null
if ($LASTEXITCODE -eq 0) {
    $baseFiles = @(& git -C $repoRoot ls-tree -r --name-only $baseSha 2>$null | Where-Object { $_ })
    $baseTreeAvailable = ($LASTEXITCODE -eq 0)
}
$metadata | Add-Member -NotePropertyName baseTreeAvailable -NotePropertyValue $baseTreeAvailable -Force
$analysis = Invoke-PullRequestStaticAnalysis -Metadata $metadata -ChangedFiles @($reviewInput.files) -PatchText $reviewInput.patch -Policies $policies -BaseFiles $baseFiles
if (-not $Offline) {
    $finalState = Invoke-TrustedGhJson -Context 'abschliessender PR-SHA-Recheck' -Arguments @(
        'pr','view',[string]$PullRequestNumber,'--repo',$Repository,'--json','headRefOid,baseRefOid,baseRefName,state'
    )
    $finalBaseRef = Invoke-TrustedGhJson -Context 'abschliessender Basebranch-Recheck' -Arguments @(
        'api',"repos/$Repository/git/ref/heads/$BaseBranch"
    )
    if ([string]$finalState.headRefOid -cne $headSha -or [string]$finalState.baseRefOid -cne $baseSha -or
        [string]$finalState.baseRefName -cne $BaseBranch -or [string]$finalBaseRef.object.sha -cne [string]$metadata.currentTrustedBaseSha -or
        ($ExpectedHeadSha -and [string]$finalState.headRefOid -cne $ExpectedHeadSha) -or
        ($ExpectedBaseSha -and [string]$finalState.baseRefOid -cne $ExpectedBaseSha)) {
        throw 'PR-Head oder Basebranch hat sich waehrend der statischen Pruefung geaendert; Review neu starten.'
    }
}
$reviewId = Get-ReviewSha256 ("$Repository|$PullRequestNumber|$baseSha|$headSha|" + ($policies.hashes | ConvertTo-Json -Compress))
$generatedAt = (Get-Date).ToUniversalTime().ToString('o')
$title = [string](Get-ReviewPropertyValue $metadata 'title' '')
$authorObject = Get-ReviewPropertyValue $metadata 'author' $null
$author = if ($authorObject -is [string]) { $authorObject } else { [string](Get-ReviewPropertyValue $authorObject 'login' 'unknown') }
$safeTitle = ConvertTo-SafeReviewLabel $title 160
$safeAuthor = ConvertTo-SafeReviewLabel $author 80
$safeHeadRef = ConvertTo-SafeReviewLabel ([string](Get-ReviewPropertyValue $metadata 'headRefName' '')) 200

if ($WhatIfPreference) {
    Write-Host "PR_REVIEW_WHATIF=OK PR=$PullRequestNumber DECISION=$($analysis.decision) FINDINGS=$(@($analysis.findings).Count)"
    exit 0
}

New-Item -ItemType Directory -Path $outputPath | Out-Null
[void](Assert-NoReviewReparseAncestor -Path $outputPath -Context 'Neu erzeugtes Review-Ausgabeverzeichnis')
$binding = [ordered]@{
    schemaVersion=1; reviewId=$reviewId; generatedAt=$generatedAt; repository=$Repository;
    pullRequestNumber=$PullRequestNumber; baseBranch=$BaseBranch; baseSha=$baseSha; headSha=$headSha;
    sourceZone='T4'; foreignCodeExecuted=$false; networkByForeignCode=$false; secretAccess='denied'
}
$metadataReport = [ordered]@{} + $binding
$metadataReport.title = $safeTitle
$metadataReport.titleHash = Get-ReviewSha256 $title
$metadataReport.bodyHash = Get-ReviewSha256 ([string](Get-ReviewPropertyValue $metadata 'body' ''))
$metadataReport.bodyLength = ([string](Get-ReviewPropertyValue $metadata 'body' '')).Length
$metadataReport.author = $safeAuthor
$metadataReport.headRefName = $safeHeadRef
$metadataReport.gitTreeMetadataComplete = [bool](Get-ReviewPropertyValue $metadata 'gitTreeMetadataComplete' $true)
$metadataReport.state = ConvertTo-SafeReviewLabel ([string](Get-ReviewPropertyValue $metadata 'state' 'UNKNOWN')) 30
$metadataReport.isDraft = [bool](Get-ReviewPropertyValue $metadata 'isDraft' $false)

$changedReport = [ordered]@{} + $binding
$changedReport.count = @($analysis.safeChangedFiles).Count
$changedReport.files = @($analysis.safeChangedFiles)

$staticReport = [ordered]@{} + $binding
$staticReport.decision = $analysis.decision
$staticReport.riskClass = $analysis.riskClass
$staticReport.statesCompleted = $analysis.statesCompleted
$staticReport.findingCount = @($analysis.findings).Count
$staticReport.findings = @($analysis.findings)
$staticReport.command = $null
$staticReport.policyHashes = $analysis.policyHashes
$staticReport.staticSafeIsMergeApproval = $false
$staticReport.mergeEligible = Test-PullRequestMergeEligibility -StaticApproved ($analysis.decision -eq 'SAFE_FOR_ISOLATED_BUILD') -TrustedBaseCurrent ($baseSha -ceq [string]$metadata.currentTrustedBaseSha) -IntegrationStartsFromTrustedBase $false -TestsGreen $false -CiGreen $false -OwnerReviewComplete $false -OpenReviewConversationsAbsent $false -DirectForeignMerge $false
$staticReport.prepareAdoptionRequested = $PrepareAdoption.IsPresent
$staticReport.staticOnly = $effectiveStaticOnly

$dependencyReport = [ordered]@{} + $binding
$dependencyReport.status = $analysis.dependencyDelta.status
$dependencyReport.result = $analysis.dependencyDelta
$dependencyReport.findings = @($analysis.findings | Where-Object category -eq 'dependency')

$malwareReport = [ordered]@{} + $binding
$malwareReport.status = $analysis.malwareRisk.status
$malwareReport.disclaimer = $analysis.malwareRisk.disclaimer
$malwareReport.defenderScan = 'NOT_REQUESTED'
$malwareReport.findings = $analysis.malwareRisk.findings

$logicReport = [ordered]@{} + $binding
$logicReport.status = $analysis.logicOverlap.status
$logicReport.semanticComparisonCompleted = $false
$logicReport.preliminaryAdoptionCategory = 'OWNER_DECISION_REQUIRED'
$logicReport.supportedAdoptionCategories = @($policies.adoption.logicCategories)
$logicReport.candidates = $analysis.logicOverlap.candidates
$logicReport.note = 'Pfadueberschneidungen sind nur Kandidaten; semantische Gleichheit wurde nicht behauptet.'
$metadataJson = $metadataReport | ConvertTo-Json -Depth 15
$changedJson = $changedReport | ConvertTo-Json -Depth 15
$dependencyJson = $dependencyReport | ConvertTo-Json -Depth 15
$malwareJson = $malwareReport | ConvertTo-Json -Depth 15
$logicJson = $logicReport | ConvertTo-Json -Depth 15
$staticReport.boundArtifactHashes = [ordered]@{
    metadata = Get-ReviewSha256 $metadataJson.TrimEnd()
    changedFiles = Get-ReviewSha256 $changedJson.TrimEnd()
    dependencyDelta = Get-ReviewSha256 $dependencyJson.TrimEnd()
    malwareRisk = Get-ReviewSha256 $malwareJson.TrimEnd()
    logicOverlap = Get-ReviewSha256 $logicJson.TrimEnd()
}

function Write-ReviewJson([string]$Name, [string]$JsonText) {
    [void](Write-ReviewUtf8FileCreateNew -Path (Join-Path $outputPath $Name) -Content $JsonText)
}
Write-ReviewJson 'metadata.json' $metadataJson
Write-ReviewJson 'changed-files.json' $changedJson
Write-ReviewJson 'static-review.json' ($staticReport | ConvertTo-Json -Depth 15)
Write-ReviewJson 'dependency-delta.json' $dependencyJson
Write-ReviewJson 'malware-risk-review.json' $malwareJson
Write-ReviewJson 'logic-overlap.json' $logicJson

$riskCategories = @($analysis.findings | ForEach-Object { $_.category } | Sort-Object -Unique)
$allowedText = 'keine automatische Dateifreigabe; Owner-Integrationsplan erforderlich'
$forbiddenText = 'alle nicht explizit durch den Owner genehmigten Dateien'
$adoptionLines = @(
    '# Adoption-Plan', '', "- Review-ID: ``$reviewId``", "- Entscheidung: ``$($analysis.decision)``",
    "- Gepruefter Base-SHA: ``$baseSha``", "- Gepruefter Head-SHA: ``$headSha``",
    "- Integrationsbranch: ``$IntegrationBranchName``", '- Startpunkt: aktueller `origin/development` (vor Brancherstellung erneut abrufen).',
    "- Automatisch erlaubte Dateien: $allowedText", "- Gesperrt: $forbiddenText", '',
    'Der Review erzeugt nur diesen Plan. Er erstellt keinen Branch, checkt keinen PR-Head aus und fuehrt keinen fremden Code aus.',
    'Vor Adoption: Base-/Head-SHA und Policy-Hashes erneut pruefen; bestehende Implementierung semantisch vergleichen; Tests zuerst ergaenzen.',
    "Netzwerk nach Static Approval angefordert: $($AllowNetworkAfterStaticApproval.IsPresent). Diese Freigabe gilt nicht fuer PR-Code."
)
[void](Write-ReviewUtf8FileCreateNew -Path (Join-Path $outputPath 'adoption-plan.md') -Content ($adoptionLines -join "`n"))

$feedbackLines = @(
    'Vielen Dank für den Beitrag.', '',
    "Das Ziel wurde anhand des redigierten Titels **$(ConvertTo-SafeReviewMarkdown $safeTitle 160)** geprüft; PR-Daten blieben dabei Daten und keine Anweisungen.", '',
    '## Prüfergebnis', '',
    "- Prompt-Injection: $(@($analysis.findings | Where-Object category -eq 'prompt-injection').Count) Befund(e)",
    "- Dependencies: ``$($analysis.dependencyDelta.status)``", "- Schadcode-Risiko: ``$($analysis.malwareRisk.status)``",
    "- Architektur/Logik: ``$($analysis.logicOverlap.status)``", '- Tests: in der statischen Phase nicht ausgeführt', '',
    '## Übernahmeentscheidung', '', "``$($analysis.decision)``", '',
    "Contributor **$(ConvertTo-SafeReviewMarkdown $safeAuthor 80)** und Original-PR **#$PullRequestNumber** bleiben für Attribution und Feedback gebunden.",
    "Geplanter Integrationsbranch: ``$IntegrationBranchName``; Zielbranch: ``development``.",
    'Der Beitrag wird nicht pauschal abgelehnt. Unsichere oder unvollständig verifizierte Teile warten auf eine Owner-Entscheidung.'
)
[void](Write-ReviewUtf8FileCreateNew -Path (Join-Path $outputPath 'feedback-draft.md') -Content ($feedbackLines -join "`n"))

$summaryLines = @(
    '# Safe Pull Request Review', '', "- Review-ID: ``$reviewId``", "- Repository/PR: ``$Repository#$PullRequestNumber``",
    "- Base/Head: ``$baseSha`` / ``$headSha``", "- Entscheidung: ``$($analysis.decision)``", "- Risikoklasse: ``$($analysis.riskClass)``",
    "- Findings: $(@($analysis.findings).Count)", "- Kategorien: $(if($riskCategories){$riskCategories -join ', '}else{'keine'})", '',
    '## Garantien dieser Phase', '', '- PR-Code ausgeführt: nein', '- Restore/Build/Test/Installer ausgeführt: nein',
    '- Secretzugriff: verweigert', '- Netzwerk durch PR-Code: nein', '- Merge-/Push-Aktion: nein', '',
    '> `SAFE_FOR_ISOLATED_BUILD` ist keine Merge-Freigabe. Ein statischer Scan garantiert keine Schadcodefreiheit.'
)
[void](Write-ReviewUtf8FileCreateNew -Path (Join-Path $outputPath 'review-summary.md') -Content ($summaryLines -join "`n"))

Write-Host "PR_REVIEW_DECISION=$($analysis.decision)"
Write-Host "PR_REVIEW_FINDINGS=$(@($analysis.findings).Count)"
Write-Host 'FOREIGN_CODE_EXECUTED=false'
exit 0
