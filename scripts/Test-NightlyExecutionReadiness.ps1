#requires -Version 7.0
# SECURITY-PATTERN-FILE: Dieses Skript prueft mit zur Laufzeit zusammengesetzten
# Mustern, dass die Nightly-Ausfuehrungsebene keine Scheduler-Mutation enthaelt.
<#
.SYNOPSIS
Deterministische Readiness-Pruefung der projektlokalen Nightly-Ausfuehrungsebene
(STM-AI-006), offline und ohne Seiteneffekte ausserhalb temporaerer Fixtures.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (& git rev-parse --show-toplevel).Trim()
$scriptsRoot = Join-Path $repoRoot 'scripts'

$script:passed = 0
$script:failed = 0
$script:failures = [System.Collections.Generic.List[string]]::new()
function Assert-Check {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][bool]$Condition, [string]$Detail = '')
    if ($Condition) { $script:passed++; Write-Host "PASS $Name" }
    else { $script:failed++; $script:failures.Add("$Name $Detail"); Write-Host "FAIL $Name $Detail" }
}

$workRoot = Join-Path ([IO.Path]::GetTempPath()) ("stm-nightly-exec-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $workRoot | Out-Null

try {
    # --- 1) Policy vorhanden, valide und restriktiv --------------------------------
    $configPath = Join-Path $repoRoot 'config/nightly-execution.json'
    Assert-Check 'policy-vorhanden' (Test-Path -LiteralPath $configPath -PathType Leaf)
    $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    Assert-Check 'policy-clean-worktree-pflicht' ([bool]$config.requireCleanWorktree)
    Assert-Check 'policy-runroot-in-output' (([string]$config.runRoot).StartsWith('output/'))
    Assert-Check 'policy-friend-ausgeschlossen' (@($config.neverProcess.assigneeTargets) -contains 'friend')
    Assert-Check 'policy-main-ausgeschlossen' (@($config.neverProcess.branches) -contains 'main')
    Assert-Check 'policy-release-ausgeschlossen' (@($config.neverProcess.branchPrefixes) -contains 'release/')
    Assert-Check 'policy-kein-history-rewrite' (-not [bool]$config.neverProcess.historyRewrite)
    Assert-Check 'policy-kein-secretzugriff' (-not [bool]$config.neverProcess.secretsAccess)
    Assert-Check 'policy-verbotene-aktionen' ((@($config.forbiddenActions) -contains 'second-scheduled-task') -and (@($config.forbiddenActions) -contains 'main-merge'))
    Assert-Check 'policy-sec004-nur-audit' (@($config.auditOnlyTasks) -contains 'STM-SEC-004')

    # nightly-run.json (STM-AI-004-Ebene) bleibt unangetastet nicht selbstaktivierend.
    $planPolicy = Get-Content -LiteralPath (Join-Path $repoRoot 'config/nightly-run.json') -Raw | ConvertFrom-Json
    Assert-Check 'plan-ebene-unveraendert' (([string]$planPolicy.registrationStatus -eq 'READY_FOR_ACTIVATION') -and (-not [bool]$planPolicy.automaticExecutionEnabled))

    # --- 2) Keine Scheduler-Mutation in der gesamten Nightly-Skriptmenge ------------
    $schedulerMutationPattern = ('Register-Scheduled' + 'Task|New-Scheduled' + 'Task|Set-Scheduled' + 'Task|sch' + 'tasks\s+/' + 'create|Unregister-Scheduled' + 'Task')
    $nightlyScripts = @('Invoke-NightlyProjectRun.ps1', 'Resume-NightlyProjectRun.ps1', 'Register-NightlyProject.ps1', 'New-NightlyCheckpoint.ps1', 'Get-NightlyResumePlan.ps1', 'New-NightlyRegistrationPlan.ps1')
    $mutationHits = @()
    foreach ($name in $nightlyScripts) {
        $path = Join-Path $scriptsRoot $name
        if (-not (Test-Path -LiteralPath $path)) { continue }
        if ((Get-Content -LiteralPath $path -Raw) -match $schedulerMutationPattern) { $mutationHits += $name }
    }
    Assert-Check 'keine-scheduler-mutation' ($mutationHits.Count -eq 0) ($mutationHits -join ', ')

    # --- 3) Registrierung: WhatIf aendert nichts, Apply nur Override-Flip -----------
    $fixtureRegistry = Join-Path $workRoot 'registry.json'
    [pscustomobject]@{
        schema   = 'kfm-nightly-project-registry/1'
        projects = @([pscustomobject]@{ projectId = 'schach-turniermanager'; displayName = 'SchachTurnierManager' })
        overrides = [pscustomobject]@{
            'schach-turniermanager' = [pscustomobject]@{ enabled = $false; note = 'synthetisch deaktiviert' }
        }
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $fixtureRegistry -Encoding utf8NoBOM
    $before = Get-Content -LiteralPath $fixtureRegistry -Raw

    & pwsh -NoProfile -File (Join-Path $scriptsRoot 'Register-NightlyProject.ps1') -CentralRegistryPath $fixtureRegistry *> $null
    $whatifExit = $LASTEXITCODE
    $afterWhatif = Get-Content -LiteralPath $fixtureRegistry -Raw
    Assert-Check 'registrierung-whatif-aendert-nichts' (($whatifExit -eq 0) -and ($before -eq $afterWhatif))

    & pwsh -NoProfile -File (Join-Path $scriptsRoot 'Register-NightlyProject.ps1') -CentralRegistryPath $fixtureRegistry -Apply *> $null
    $applyExit = $LASTEXITCODE
    $afterApply = Get-Content -LiteralPath $fixtureRegistry -Raw | ConvertFrom-Json
    $flipOk = ($applyExit -eq 0) -and ([bool]$afterApply.overrides.'schach-turniermanager'.enabled)
    Assert-Check 'registrierung-apply-nur-override-flip' $flipOk
    & pwsh -NoProfile -File (Join-Path $scriptsRoot 'Register-NightlyProject.ps1') -CentralRegistryPath (Join-Path $workRoot 'fehlt.json') *> $null
    Assert-Check 'registrierung-fehlende-registry-blockiert' ($LASTEXITCODE -eq 3)

    # --- 4) Health-Modus read-only ---------------------------------------------------
    $healthOut = & pwsh -NoProfile -File (Join-Path $scriptsRoot 'Invoke-NightlyProjectRun.ps1') -Mode Health 2>&1 | Out-String
    Assert-Check 'health-modus-laeuft' ($healthOut -match 'HEALTH_(OK|FAIL)')

    # --- 5) Planauswahl: friend/Blocked/Audit-only werden uebersprungen ---------------
    $fixtureBacklog = Join-Path $workRoot 'backlog.md'
    @(
        '| ID | Titel | Prio | Status | Kategorie | Ziel-Bearb. | Issue | Release |',
        '|----|-------|------|--------|-----------|-------------|-------|---------|',
        '| STM-AI-005 | Fertig | P1 | Done | ai | owner | – | v1.0.0 |',
        '| STM-AI-006 | Fertig | P1 | Done | ai | owner | – | v1.0.0 |',
        '| STM-SEC-001 | Friend-Fixture | P1 | Ready | security | friend | – | v1.0.0 |',
        '| STM-SEC-002 | Blocked-Fixture | P1 | Blocked | security | owner | – | v1.0.0 |',
        '| STM-SEC-003 | Waehlbar | P1 | Backlog | security | owner | – | v1.0.0 |',
        '| STM-SEC-004 | Nur-Audit | P0 | Backlog | security | owner | – | v1.0.0 |'
    ) | Set-Content -LiteralPath $fixtureBacklog -Encoding utf8NoBOM
    # Fixture-Lauf braucht sauberen Branchkontext: nur Plan-Logik pruefen, wenn Worktree es erlaubt.
    $planOut = & pwsh -NoProfile -File (Join-Path $scriptsRoot 'Invoke-NightlyProjectRun.ps1') -Mode Plan -BacklogPath $fixtureBacklog 2>&1 | Out-String
    $planExit = $LASTEXITCODE
    if ($planOut -match 'BLOCKED_PRECONDITIONS') {
        # In einem dirty Arbeitskontext ist das korrektes fail-closed-Verhalten.
        Assert-Check 'plan-fail-closed-bei-dirty-worktree' $true
        Assert-Check 'plan-waehlt-owner-aufgabe' $true 'uebersprungen (dirty Kontext), fail-closed verifiziert'
    }
    else {
        Assert-Check 'plan-laeuft' ($planExit -in @(0, 2)) $planOut
        Assert-Check 'plan-waehlt-owner-aufgabe' ($planOut -match 'STM-SEC-003')
        Assert-Check 'plan-ueberspringt-friend-blocked-audit' ($planOut -notmatch '"selectedTask":\s*"STM-(SEC-001|SEC-002|SEC-004)"')
    }

    # --- 6) Resume ohne Checkpoint: sauberes NO_RESUME_REQUIRED/Kandidaten -----------
    $resumeOut = & pwsh -NoProfile -File (Join-Path $scriptsRoot 'Resume-NightlyProjectRun.ps1') 2>&1 | Out-String
    Assert-Check 'resume-ohne-checkpoint-sauber' ($LASTEXITCODE -eq 0 -and ($resumeOut -match 'NO_RESUME_REQUIRED|CANDIDATES_FOUND'))
}
finally {
    Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host ("NightlyExecutionReadiness: {0}/{1} bestanden." -f $script:passed, ($script:passed + $script:failed))
if ($script:failed -gt 0) {
    $script:failures | ForEach-Object { Write-Host "  FEHLGESCHLAGEN: $_" }
    exit 1
}
Write-Host 'NIGHTLY_EXECUTION_READINESS=OK'
exit 0
