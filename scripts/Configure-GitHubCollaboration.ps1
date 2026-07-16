#requires -Version 7.0
<#
.SYNOPSIS
Konfiguriert idempotent die GitHub-Kollaborationsregeln (Rulesets + Repo-Einstellungen).
.DESCRIPTION
Bereitet Branch-Rulesets fuer development, main und release/* sowie Repo-Einstellungen vor.
Ohne -Apply werden KEINE Aenderungen vorgenommen (Plan-/WhatIf-Ausgabe). Actor-/API-Strukturen
werden nicht geraten: bestehende Rulesets werden per REST-API gelesen und bei gleichem Namen
aktualisiert statt dupliziert. der Owner (Repository-Admin) ist bewusster Bypass-Akteur
(RepositoryRole Admin), damit er direkt auf development arbeiten kann; andere Collaborators
muessen ueber Pull Requests gehen. Details in einem lokalen temporären Runordner; -NoArchive
unterdrueckt das sonst erzeugte Upload-ZIP.
.PARAMETER Repository
owner/name, z. B. Randspringer90/SchachTurnierManager.
.PARAMETER Apply
Fuehrt Aenderungen tatsaechlich aus. Ohne -Apply nur Plan.
.PARAMETER WhatIf
Erzwingt reinen Plan-Modus (Default-Verhalten ohne -Apply); dient der Explizitheit.
.EXAMPLE
pwsh scripts/Configure-GitHubCollaboration.ps1 -Repository Randspringer90/SchachTurnierManager -WhatIf
.EXAMPLE
pwsh scripts/Configure-GitHubCollaboration.ps1 -Repository Randspringer90/SchachTurnierManager -Apply
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Repository,
    [switch]$Apply,
    [switch]$WhatIf,
    [switch]$NoArchive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/CollaborationCommon.ps1')

if ($Repository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') {
    throw "Repository '$Repository' ist ungueltig (erwartet owner/name)."
}
$doApply = $Apply.IsPresent -and -not $WhatIf.IsPresent
$mode = if ($doApply) { 'APPLY' } else { 'PLAN (keine Aenderungen)' }

$run = New-RunContext -RunName 'configure-github-collab'
Write-RunLog $run "Repository: $Repository  Modus: $mode"

# Erforderliche Statuschecks (Namen = Job-'name' der Workflows).
$requiredDev  = @('pr-static-security','security-gate','agent-integrity','build-test','frontend','diff-check','branch-policy')
$requiredMain = @('security-gate','agent-integrity','build-test','frontend','diff-check','branch-policy')
$requiredRel  = @('security-gate','agent-integrity','build-test','frontend','diff-check','branch-policy')

function New-PrRule {
    param([int]$Approvals = 1)
    @{ type = 'pull_request'; parameters = @{
        required_approving_review_count      = $Approvals
        dismiss_stale_reviews_on_push        = $true
        require_code_owner_review            = $true
        require_last_push_approval           = $false
        required_review_thread_resolution    = $true
    } }
}
function New-ChecksRule {
    param([string[]]$Contexts)
    @{ type = 'required_status_checks'; parameters = @{
        strict_required_status_checks_policy = $true
        do_not_enforce_on_create             = $false
        required_status_checks               = @($Contexts | ForEach-Object { @{ context = $_ } })
    } }
}
# Bypass: Repository-Admin (built-in RepositoryRole 'admin'). der Owner arbeitet damit direkt auf
# development; die Trennung "Admin direkt / Collaborator nur PR" ist so abbildbar.
$adminBypass = @(@{ actor_id = 5; actor_type = 'RepositoryRole'; bypass_mode = 'always' })

function New-RulesetPayload {
    param([string]$Name, [string[]]$IncludeRefs, [array]$Rules)
    return @{
        name          = $Name
        target        = 'branch'
        enforcement   = 'active'
        bypass_actors = $adminBypass
        conditions    = @{ ref_name = @{ include = @($IncludeRefs); exclude = @() } }
        rules         = $Rules
    }
}

$rulesets = @(
    (New-RulesetPayload -Name 'collab-development' -IncludeRefs @('refs/heads/development') -Rules @(
        @{ type = 'deletion' }, @{ type = 'non_fast_forward' },
        (New-PrRule -Approvals 1), (New-ChecksRule -Contexts $requiredDev)
    )),
    (New-RulesetPayload -Name 'collab-main' -IncludeRefs @('refs/heads/main') -Rules @(
        @{ type = 'deletion' }, @{ type = 'non_fast_forward' },
        (New-PrRule -Approvals 1), (New-ChecksRule -Contexts $requiredMain)
    )),
    (New-RulesetPayload -Name 'collab-release' -IncludeRefs @('refs/heads/release/*') -Rules @(
        @{ type = 'deletion' }, @{ type = 'non_fast_forward' },
        (New-PrRule -Approvals 1), (New-ChecksRule -Contexts $requiredRel)
    ))
)

function Invoke-GhApi {
    param([string]$Method, [string]$Path, [string]$BodyJson)
    $ghArgs = @('api','--method',$Method,'-H','Accept: application/vnd.github+json',$Path)
    if ($BodyJson) {
        $ghArgs += @('--input','-')
        $out = $BodyJson | & gh @ghArgs 2>&1
    } else {
        $out = & gh @ghArgs 2>&1
    }
    return [pscustomobject]@{ Ok = ($LASTEXITCODE -eq 0); Output = ($out -join "`n") }
}

# Bestehende Rulesets lesen (Idempotenz).
$existing = @{}
$listRes = Invoke-GhApi -Method GET -Path "repos/$Repository/rulesets"
if ($listRes.Ok) {
    try { ($listRes.Output | ConvertFrom-Json) | ForEach-Object { $existing[$_.name] = $_.id } } catch {}
    Write-RunLog $run ("Vorhandene Rulesets: " + (($existing.Keys) -join ', '))
} else {
    Write-RunLog $run "Konnte Rulesets nicht lesen (evtl. fehlende Rechte): $($listRes.Output)"
}

$planFile = Join-Path $run.Dir 'ruleset-plan.json'
$rulesets | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $planFile -Encoding utf8
Write-RunLog $run "Ruleset-Plan geschrieben: $planFile"

$applied = @(); $blockers = @()
foreach ($rs in $rulesets) {
    $name = $rs.name
    $json = ($rs | ConvertTo-Json -Depth 12)
    if (-not $doApply) {
        $action = if ($existing.ContainsKey($name)) { "UPDATE (id $($existing[$name]))" } else { 'CREATE' }
        Write-RunLog $run "[PLAN] Ruleset '$name' -> $action"
        continue
    }
    if ($existing.ContainsKey($name)) {
        $res = Invoke-GhApi -Method PUT -Path "repos/$Repository/rulesets/$($existing[$name])" -BodyJson $json
    } else {
        $res = Invoke-GhApi -Method POST -Path "repos/$Repository/rulesets" -BodyJson $json
    }
    if ($res.Ok) { $applied += $name; Write-RunLog $run "[APPLY] Ruleset '$name' OK." }
    else { $blockers += "Ruleset '$name': $($res.Output)"; Write-RunLog $run "[APPLY] Ruleset '$name' FEHLER: $($res.Output)" }
}

# Das feste Label ist der explizite, Owner-seitig gesetzte Nachweis einer unabhängigen
# statischen Ausführungsfreigabe. Seine Existenz erteilt noch keine Freigabe an einen PR.
$approvalLabelPath = "repos/$Repository/labels/security%3Astatic-review-trigger"
$approvalLabel = @{ name='security:static-review-trigger'; color='fbca04'; description='Loest Static-Review erneut aus; ist selbst keine Freigabe und nicht sicherheitsentscheidend' }
$labelStatus = Invoke-GhApi -Method GET -Path $approvalLabelPath
if ($doApply -and -not $labelStatus.Ok) {
    $labelResult = Invoke-GhApi -Method POST -Path "repos/$Repository/labels" -BodyJson ($approvalLabel | ConvertTo-Json -Depth 4)
    if ($labelResult.Ok) { Write-RunLog $run '[APPLY] Trigger-Label security:static-review-trigger angelegt.' }
    else { $blockers += "Trigger-Label: $($labelResult.Output)"; Write-RunLog $run "[APPLY] Trigger-Label FEHLER: $($labelResult.Output)" }
}
elseif ($doApply) { Write-RunLog $run '[APPLY] Trigger-Label security:static-review-trigger bereits vorhanden.' }
else { Write-RunLog $run '[PLAN] Trigger-Label security:static-review-trigger vorhanden oder idempotent anzulegen.' }

# Repo-Einstellungen: Default-Branch development, Merge-Strategien, Auto-Delete.
$repoSettings = @{
    default_branch          = 'development'
    delete_branch_on_merge  = $true
    allow_squash_merge      = $true
    allow_merge_commit      = $true
    allow_rebase_merge      = $false
    allow_auto_merge        = $true
}
$settingsJson = $repoSettings | ConvertTo-Json -Depth 5
Set-Content -LiteralPath (Join-Path $run.Dir 'repo-settings.json') -Value $settingsJson -Encoding utf8
if ($doApply) {
    $res = Invoke-GhApi -Method PATCH -Path "repos/$Repository" -BodyJson $settingsJson
    if ($res.Ok) { Write-RunLog $run '[APPLY] Repo-Einstellungen OK (default_branch=development, auto-delete, squash+merge, rebase off).' }
    else { $blockers += "Repo-Settings: $($res.Output)"; Write-RunLog $run "[APPLY] Repo-Einstellungen FEHLER: $($res.Output)" }
} else {
    Write-RunLog $run '[PLAN] Repo-Einstellungen: default_branch=development, delete_branch_on_merge=true, squash+merge on, rebase off.'
}

if ($blockers.Count -gt 0) {
    Write-RunLog $run ("BLOCKER (" + $blockers.Count + "):`n" + ($blockers -join "`n"))
}
$zip = if ($NoArchive) { $null } else { Complete-RunZip $run }
Write-Host "Modus: $mode"
if ($doApply) { Write-Host ("Angewendet: " + ($applied -join ', ')) }
if ($blockers.Count -gt 0) { Write-Host ("Blocker: " + $blockers.Count + " (siehe $($run.Log))"); if ($zip) { Write-Host "Upload-ZIP: $zip" }; exit 2 }
if ($zip) { Write-Host "Upload-ZIP: $zip" }
exit 0
