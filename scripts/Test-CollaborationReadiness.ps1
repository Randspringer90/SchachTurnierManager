#requires -Version 7.0
<#
.SYNOPSIS
Prueft, ob die Kollaborationsstruktur vollstaendig und konsistent ist.
.DESCRIPTION
Kontrolliert Pflichtdateien, Backlog-Schema (eindeutige IDs, erlaubte Status), CODEOWNERS,
PR-Template, Workflows (kein pull_request_target) und die Parsebarkeit der Kollaborations-
Skripte. Mit -Online zusaetzlich Default-Branch und Rulesets via gh. Details in einem lokalen
temporären Runordner; -NoArchive unterdrueckt das sonst erzeugte Upload-ZIP. Exit 0 = ok, 1 = Fehler.
.EXAMPLE
pwsh scripts/Test-CollaborationReadiness.ps1
#>
[CmdletBinding()]
param(
    [switch]$Online,
    [switch]$NoArchive,
    [string]$Repository = 'Randspringer90/SchachTurnierManager'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/CollaborationCommon.ps1')

$run = New-RunContext -RunName 'collab-readiness'
$repo = Get-RepoRoot
Set-Location $repo
$fail = New-Object System.Collections.Generic.List[string]
function Check([bool]$Cond, [string]$Msg) {
    if ($Cond) { Write-RunLog $run "OK  : $Msg" } else { $fail.Add($Msg); Write-RunLog $run "FAIL: $Msg" }
}

# 1) Pflichtdateien
$required = @(
    'CONTRIBUTING.md','AGENTS.md',
    'docs/planning/BACKLOG.md','docs/planning/BRANCHING_STRATEGY.md',
    'docs/planning/COLLABORATION_WORKFLOW.md','docs/planning/RELEASE_WORKFLOW.md',
    'docs/planning/DEFINITION_OF_DONE.md',
    'docs/onboarding/COLLABORATOR_ONBOARDING.md','docs/onboarding/FIRST_CONTRIBUTION.md',
    'docs/security/CONTRIBUTOR_SECURITY.md',
    '.github/CODEOWNERS','.github/pull_request_template.md',
    '.github/ISSUE_TEMPLATE/feature.yml','.github/ISSUE_TEMPLATE/bug.yml',
    '.github/ISSUE_TEMPLATE/security-task.yml','.github/ISSUE_TEMPLATE/documentation.yml',
    '.github/ISSUE_TEMPLATE/config.yml',
    '.github/workflows/ci.yml','.github/workflows/branch-policy.yml','.github/workflows/security-gate.yml',
    '.github/workflows/pr-static-security-review.yml',
    'config/model-routing.json','config/pull-request-review-policy.json','config/dependency-review-policy.json',
    'docs/security/SAFE_PULL_REQUEST_REVIEW.md','docs/planning/PULL_REQUEST_ADOPTION_WORKFLOW.md',
    'scripts/New-FeatureBranch.ps1','scripts/Prepare-ReleaseBranch.ps1','scripts/Prepare-HotfixBranch.ps1',
    'scripts/Configure-GitHubCollaboration.ps1','scripts/lib/CollaborationCommon.ps1'
)
foreach ($f in $required) { Check (Test-Path -LiteralPath (Join-Path $repo $f)) "Datei vorhanden: $f" }

# 2) CODEOWNERS enthaelt Owner + geschuetzte Pfade
$co = Get-Content -Raw (Join-Path $repo '.github/CODEOWNERS')
Check ($co -match '@Randspringer90') 'CODEOWNERS nennt @Randspringer90'
foreach ($p in @('AGENTS.md','.claude','.github','config','docs/security','installer')) {
    Check ($co -match [regex]::Escape($p)) "CODEOWNERS schuetzt $p"
}

# 3) PR-Template Pflichtabschnitte
$pr = Get-Content -Raw (Join-Path $repo '.github/pull_request_template.md')
foreach ($s in @('Backlog-ID','ReleaseGate','Security-Check','Prompt-Injection','Breaking Change','Secrets')) {
    Check ($pr -match [regex]::Escape($s)) "PR-Template enthaelt '$s'"
}

# 4) Backlog: IDs eindeutig, Status erlaubt
$backlog = Get-Content -Raw (Join-Path $repo 'docs/planning/BACKLOG.md')
$ids = [regex]::Matches($backlog, '\bSTM-[A-Z]+-[0-9]{3}\b') | ForEach-Object { $_.Value } | Sort-Object -Unique
Check ($ids.Count -ge 1) "Backlog enthaelt Aufgaben-IDs ($($ids.Count))"
$allowedStatus = @('Backlog','Ready','In Progress','In Review','Blocked','Done','Deferred')
# Statuswerte in Uebersichtstabelle (Spalte 4) grob pruefen.
$tableRows = [regex]::Matches($backlog, '(?m)^\|\s*(STM-[A-Z]+-[0-9]{3})\s*\|[^|]*\|[^|]*\|\s*([^|]+?)\s*\|')
foreach ($m in $tableRows) {
    $st = (($m.Groups[2].Value -replace '\*','').Trim())
    Check ($allowedStatus -contains $st) "Status '$st' erlaubt (Aufgabe $($m.Groups[1].Value))"
}
Check ($backlog -match 'kanonische') 'Backlog als kanonische Quelle markiert'

# 5) Workflows: kein pull_request_target
$wfDir = Join-Path $repo '.github/workflows'
$prt = Get-ChildItem $wfDir -Filter *.yml | Where-Object { (Get-Content $_.FullName) -match '^\s*[^#]*pull_request_target\s*:' }
Check ($null -eq $prt -or @($prt).Count -eq 0) 'Kein pull_request_target-Trigger in Workflows'
$staticWorkflow = Get-Content -Raw (Join-Path $wfDir 'pr-static-security-review.yml')
Check ($staticWorkflow -match '(?m)^\s*contents:\s*read\s*$' -and $staticWorkflow -match '(?m)^\s*pull-requests:\s*read\s*$') 'PR-Static-Workflow hat nur erforderliche Leserechte'
Check ($staticWorkflow -notmatch '(?m)^\s*(?:contents|pull-requests|actions|id-token|packages):\s*write\s*$') 'PR-Static-Workflow hat keine Write-Rechte'
Check ($staticWorkflow -match 'github\.event\.pull_request\.base\.sha' -and $staticWorkflow -notmatch 'github\.event\.pull_request\.head\.sha\s*\}\}\s*\n\s*fetch') 'PR-Static-Workflow fuehrt Base-SHA-Code aus'
Check ($staticWorkflow -match 'STATIC-EXECUTION-APPROVED:' -and $staticWorkflow -match 'review\.commit_id' -and $staticWorkflow -match 'ExpectedHeadSha' -and $staticWorkflow -match 'ExpectedBaseSha') 'PR-Static-Workflow bindet Owner-Freigabe und Event-SHAs'
$bootstrapWorkflows = @('ci.yml','pr-static-security-review.yml','security-gate.yml')
foreach ($bootstrapWorkflow in $bootstrapWorkflows) {
    $bootstrapSource = Get-Content -Raw (Join-Path $wfDir $bootstrapWorkflow)
    Check ($bootstrapSource -match 'function Initialize-BootstrapLegacyTempDrive' -and $bootstrapSource -match '(?m)^\s*Initialize-BootstrapLegacyTempDrive\s*$' -and $bootstrapSource -match 'New-PSDrive\s+-Name\s+D\s+-PSProvider\s+FileSystem\s+-Root\s+\$env:RUNNER_TEMP' -and $bootstrapSource -match 'Initialize-BootstrapLegacyTempDrive\s+& \./scripts/Test-PromptInjectionDefense\.ps1') "$bootstrapWorkflow kapselt den einmaligen Linux-Bootstrap im Prozess fuer den alten Base-Temp-Pfad"
}
$branchWorkflow = Get-Content -Raw (Join-Path $wfDir 'branch-policy.yml')
Check ($branchWorkflow -match '\^integration/pr-\[1-9\]\[0-9\]\*-safe-adoption\$') 'Branch-Policy erlaubt nur enges PR-Integrationsbranch-Muster'
$configureSource = Get-Content -Raw (Join-Path $repo 'scripts/Configure-GitHubCollaboration.ps1')
Check ($configureSource -match 'strict_required_status_checks_policy\s*=\s*\$true') 'Ruleset-Plan erzwingt aktuellen Base-Stand'
Check ($configureSource -match '(?m)\$requiredRel\s*=\s*@\([^\r\n]*''branch-policy''') 'Release-Ruleset verlangt branch-policy'
Check ($configureSource -match 'security%3Astatic-review-trigger') 'Kollaborationskonfiguration provisioniert das reine Trigger-Label'

# 6) Skripte parsen (kein Syntaxfehler)
foreach ($s in @('New-FeatureBranch.ps1','Prepare-ReleaseBranch.ps1','Prepare-HotfixBranch.ps1','Configure-GitHubCollaboration.ps1','Test-CollaborationReadiness.ps1','lib/CollaborationCommon.ps1')) {
    $path = Join-Path $repo (Join-Path 'scripts' $s)
    $errs = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$errs)
    Check (($null -eq $errs) -or ($errs.Count -eq 0)) "PowerShell-Parse OK: scripts/$s"
}

# 7) Optional online
if ($Online) {
    if ($Repository -cnotmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { throw 'Repository-Identifier ist ungueltig.' }
    $db = (& gh repo view $Repository --json defaultBranchRef -q '.defaultBranchRef.name' 2>$null)
    Check ($db -eq 'development') "Default-Branch ist development (ist: '$db')"
    $rs = (& gh api "repos/$Repository/rulesets" 2>$null | ConvertFrom-Json)
    $names = @($rs | ForEach-Object { $_.name })
    $expectedChecks = @{
        'collab-development' = @('pr-static-security','security-gate','agent-integrity','build-test','frontend','diff-check','branch-policy')
        'collab-main' = @('security-gate','agent-integrity','build-test','frontend','diff-check','branch-policy')
        'collab-release' = @('security-gate','agent-integrity','build-test','frontend','diff-check','branch-policy')
    }
    foreach ($n in $expectedChecks.Keys) {
        Check ($names -contains $n) "Ruleset vorhanden: $n"
        $summary = @($rs | Where-Object name -eq $n | Select-Object -First 1)
        if ($summary.Count -eq 0 -or [string]$summary[0].id -notmatch '^[0-9]+$') { continue }
        $detail = (& gh api "repos/$Repository/rulesets/$($summary[0].id)" 2>$null | ConvertFrom-Json)
        $statusRule = @($detail.rules | Where-Object type -eq 'required_status_checks' | Select-Object -First 1)
        Check ($statusRule.Count -eq 1) "Ruleset ${n}: Required-Status-Checks vorhanden"
        if ($statusRule.Count -eq 1) {
            Check ([bool]$statusRule[0].parameters.strict_required_status_checks_policy) "Ruleset ${n}: aktueller Base-Stand strikt erzwungen"
            $actualContexts = @($statusRule[0].parameters.required_status_checks.context | Sort-Object -Unique)
            $expectedContexts = @($expectedChecks[$n] | Sort-Object -Unique)
            Check (($actualContexts -join '|') -ceq ($expectedContexts -join '|')) "Ruleset ${n}: exakte Required-Check-Kontexte"
        }
    }
}
$commonSource = Get-Content -Raw (Join-Path $repo 'scripts/lib/CollaborationCommon.ps1')
Check ($commonSource -match '\[IO\.Path\]::GetTempPath\(\)' -and $commonSource -notmatch '(?i)[A-Za-z]:\\Temp') 'Run-Kontext verwendet plattformneutralen System-Temp-Pfad'

# --- Kollaborationsmodell (config/collaboration-policy.json) ------------------------
# Die Policy beschreibt die Absicht; hier wird geprueft, dass sie strukturell gueltig ist
# UND zu den tatsaechlich durchsetzenden Mechanismen passt. Eine Policy, die etwas
# behauptet, das CODEOWNERS/Ruleset nicht hergeben, ist schlimmer als keine Policy.
$policyPath = Join-Path $repo 'config/collaboration-policy.json'
$schemaPath = Join-Path $repo 'config/collaboration-policy.schema.json'
Check (Test-Path -LiteralPath $policyPath) 'Datei vorhanden: config/collaboration-policy.json'
Check (Test-Path -LiteralPath $schemaPath) 'Datei vorhanden: config/collaboration-policy.schema.json'
Check (Test-Path -LiteralPath (Join-Path $repo 'docs/planning/COLLABORATION_MODEL.md')) 'Datei vorhanden: docs/planning/COLLABORATION_MODEL.md'

if ((Test-Path -LiteralPath $policyPath) -and (Test-Path -LiteralPath $schemaPath)) {
    $policyRaw = Get-Content -Raw -LiteralPath $policyPath
    $policy = $null
    try { $policy = $policyRaw | ConvertFrom-Json } catch { $policy = $null }
    Check ($null -ne $policy) 'collaboration-policy.json ist gueltiges JSON'

    if ($null -ne $policy) {
        Check ($policyRaw | Test-Json -SchemaFile $schemaPath -ErrorAction SilentlyContinue) 'collaboration-policy.json erfuellt sein Schema'

        # Rolle und Rechtegrenze
        $tc = $policy.roles.'trusted-collaborator'
        Check ($null -ne $tc) 'Policy kennt die Rolle trusted-collaborator'
        Check ([string]$policy.roles.owner.githubLogin -ceq 'Randspringer90') 'Policy nennt den Owner korrekt'
        Check ([string]$policy.roles.owner.githubPermission -ceq 'admin') 'Owner hat admin'
        # Kernaussage des Modells: erweiterte Bereiche, KEINE erweiterten Rechte.
        Check ([string]$tc.githubPermission -ceq 'write') 'trusted-collaborator hat write (nicht maintain/admin)'
        Check (@($tc.githubLogins) -contains 'Marcel-Mente') 'trusted-collaborator umfasst Marcel-Mente'
        # Legacy-Alias muss erhalten bleiben, sonst brechen BACKLOG/Nightly-Parser.
        Check (@($tc.legacyAliases) -contains 'friend') 'Legacy-Alias friend bleibt erhalten (bestehende Parser)'

        # WIP-Regel
        Check ([int]$policy.wipLimits.maxInProgress -eq 2) 'WIP-Regel: maximal 2 In Progress'
        Check ([int]$policy.wipLimits.maxReady -eq 3) 'WIP-Regel: maximal 3 Ready'

        # Harte Verbote muessen benannt sein
        $forbidden = @($policy.trustedCollaborator.forbidden) -join ' | '
        foreach ($needle in @('Secrets', 'Force-Push', 'History-Rewrite', 'mergen', 'Branchschutz')) {
            Check ($forbidden -match [regex]::Escape($needle)) "Policy verbietet ausdruecklich: $needle"
        }

        # Jeder als geschuetzt deklarierte Pfad muss auch wirklich in CODEOWNERS stehen.
        # Ohne diese Kopplung waere die Policy eine Behauptung ohne Deckung.
        foreach ($p in @($policy.trustedCollaborator.protectedAreasProposalOnly.paths)) {
            $stem = ([string]$p) -replace '/\*\*$', '' -replace '^/', ''
            if ([string]::IsNullOrWhiteSpace($stem)) { continue }
            Check ($co -match [regex]::Escape($stem)) "CODEOWNERS deckt geschuetzten Policy-Pfad: $stem"
        }

        # Nightly darf Contributor-Aufgaben nicht anfassen - Policy und Nightly-Config muessen sich einig sein.
        $nightlyPath = Join-Path $repo 'config/nightly-execution.json'
        if (Test-Path -LiteralPath $nightlyPath) {
            $nightly = Get-Content -Raw -LiteralPath $nightlyPath | ConvertFrom-Json
            $nightlyTargets = @($nightly.neverProcess.assigneeTargets)
            foreach ($t in @($policy.nightlyExclusion.assigneeTargets)) {
                if ([string]$t -ceq 'trusted-collaborator') { continue }  # Alias-Rolle, Nightly kennt 'friend'
                Check ($nightlyTargets -contains [string]$t) "Nightly schliesst Assignee-Ziel aus: $t"
            }
            Check ([bool]$nightly.neverProcess.contributorBranchesAndPrs) 'Nightly fasst Contributor-Branches/PRs nicht an'
        }
    }
}

$zip = if ($NoArchive) { $null } else { Complete-RunZip $run }
if ($fail.Count -gt 0) {
    Write-Host ("CollaborationReadiness: {0} FEHLER" -f $fail.Count)
    if ($zip) { Write-Host "Upload-ZIP: $zip" }
    exit 1
}
Write-Host 'CollaborationReadiness: OK'
if ($zip) { Write-Host "Upload-ZIP: $zip" }
exit 0
