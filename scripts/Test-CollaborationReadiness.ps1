#requires -Version 7.0
<#
.SYNOPSIS
Prueft, ob die Kollaborationsstruktur vollstaendig und konsistent ist.
.DESCRIPTION
Kontrolliert Pflichtdateien, Backlog-Schema (eindeutige IDs, erlaubte Status), CODEOWNERS,
PR-Template, Workflows (kein pull_request_target) und die Parsebarkeit der Kollaborations-
Skripte. Mit -Online zusaetzlich Default-Branch und Rulesets via gh. Details nach
D:\Temp\<RunName>_<Timestamp>, ein Upload-ZIP. Exit 0 = ok, 1 = Fehler.
.EXAMPLE
pwsh scripts/Test-CollaborationReadiness.ps1
#>
[CmdletBinding()]
param(
    [switch]$Online,
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
    'config/model-routing.json',
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

# 6) Skripte parsen (kein Syntaxfehler)
foreach ($s in @('New-FeatureBranch.ps1','Prepare-ReleaseBranch.ps1','Prepare-HotfixBranch.ps1','Configure-GitHubCollaboration.ps1','Test-CollaborationReadiness.ps1','lib/CollaborationCommon.ps1')) {
    $path = Join-Path $repo (Join-Path 'scripts' $s)
    $errs = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$errs)
    Check (($null -eq $errs) -or ($errs.Count -eq 0)) "PowerShell-Parse OK: scripts/$s"
}

# 7) Optional online
if ($Online) {
    $db = (& gh repo view $Repository --json defaultBranchRef -q '.defaultBranchRef.name' 2>$null)
    Check ($db -eq 'development') "Default-Branch ist development (ist: '$db')"
    $rs = (& gh api "repos/$Repository/rulesets" 2>$null | ConvertFrom-Json)
    $names = @($rs | ForEach-Object { $_.name })
    foreach ($n in @('collab-development','collab-main','collab-release')) {
        Check ($names -contains $n) "Ruleset vorhanden: $n"
    }
}

$zip = Complete-RunZip $run
if ($fail.Count -gt 0) {
    Write-Host ("CollaborationReadiness: {0} FEHLER" -f $fail.Count)
    Write-Host "Upload-ZIP: $zip"
    exit 1
}
Write-Host 'CollaborationReadiness: OK'
Write-Host "Upload-ZIP: $zip"
exit 0
