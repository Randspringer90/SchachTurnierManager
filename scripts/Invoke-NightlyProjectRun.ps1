#requires -Version 7.0
<#
.SYNOPSIS
Projektlokale Ausfuehrungsebene fuer den zentralen Nightly-Lauf (STM-AI-006).

.DESCRIPTION
Reale, aber konservative Nightly-Schritte dieses Projekts: Repository-Lock,
Vorbedingungen (Branch, sauberer Worktree), kanonische Queue aus BACKLOG.md,
Auswahl der naechsten Owner-/AI-Aufgabe unter strikter Ausklammerung von
Contributor-/Marcel-Aufgaben, Emission von Plan + Masterprompt fuer die
Routed Execution sowie optional Gate-Ausfuehrung. Dieses Skript merged nie nach
main, erzeugt nie Scheduled Tasks, fuehrt keinen History-Rewrite aus und greift
nie auf Secrets zu. Modi:
  Health  – read-only Selbsttest der Vorbedingungen (Default).
  Plan    – Aufgabe auswaehlen, Plan + Masterprompt unter output/ schreiben.
  Run     – Plan + Ausfuehrungs-Gates laufen lassen (weiterhin ohne Git-Mutation).
Exitcodes: 0=ok, 2=nichts zu tun, 3=Vorbedingung verletzt/gesperrt.
#>
[CmdletBinding()]
param(
    [ValidateSet('Health', 'Plan', 'Run')]
    [string]$Mode = 'Health',

    [string]$ConfigPath,

    [string]$BacklogPath,

    [switch]$IncludeAuditOnly,

    [switch]$SkipGates
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (& git rev-parse --show-toplevel).Trim()
if (-not $ConfigPath) { $ConfigPath = Join-Path $repoRoot 'config/nightly-execution.json' }
if (-not $BacklogPath) { $BacklogPath = Join-Path $repoRoot 'docs/planning/BACKLOG.md' }

$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
foreach ($key in @('projectKey', 'requireBranch', 'requireCleanWorktree', 'runRoot', 'ownerTaskQueue', 'neverProcess', 'forbiddenActions', 'executionGates')) {
    if ($config.PSObject.Properties.Name -notcontains $key) { throw "nightly-execution.json unvollstaendig: '$key' fehlt." }
}

$runRoot = Join-Path $repoRoot ([string]$config.runRoot)
if (-not (Test-Path -LiteralPath $runRoot)) { New-Item -ItemType Directory -Force -Path $runRoot | Out-Null }

# Repository-Lock (gegen parallele Nightly-/Interaktivlaeufe dieses Layers).
$lockPath = Join-Path $runRoot '.project-lock'
if ($Mode -ne 'Health') {
    if (Test-Path -LiteralPath $lockPath) {
        $lockAge = (Get-Date) - (Get-Item -LiteralPath $lockPath).LastWriteTime
        if ($lockAge.TotalMinutes -lt [int]$config.maxRunMinutes) {
            [pscustomobject]@{ status = 'BLOCKED_LOCKED'; lock = $lockPath } | ConvertTo-Json
            exit 3
        }
    }
    Set-Content -LiteralPath $lockPath -Value ([DateTime]::UtcNow.ToString('o') + ' ' + $PID) -Encoding utf8NoBOM
}

try {
    $checks = [System.Collections.Generic.List[object]]::new()
    function Add-Check([string]$Name, [bool]$Ok, [string]$Detail = '') {
        $checks.Add([pscustomobject]@{ name = $Name; ok = $Ok; detail = $Detail })
        return $Ok
    }

    $branch = (& git -C $repoRoot rev-parse --abbrev-ref HEAD).Trim()
    $dirty = @(& git -C $repoRoot status --porcelain)
    $head = (& git -C $repoRoot rev-parse HEAD).Trim()

    $ok = $true
    $ok = (Add-Check 'branch' ($branch -eq [string]$config.requireBranch) "ist=$branch soll=$($config.requireBranch)") -and $ok
    $ok = (Add-Check 'worktree-sauber' ($dirty.Count -eq 0) "dirty=$($dirty.Count)") -and $ok
    $ok = (Add-Check 'kein-main' ($branch -ne 'main') $branch) -and $ok
    $ok = (Add-Check 'kein-release-branch' (-not $branch.StartsWith('release/')) $branch) -and $ok

    if ($Mode -eq 'Health') {
        [pscustomobject]@{
            status = if ($ok) { 'HEALTH_OK' } else { 'HEALTH_FAIL' }
            head   = $head
            checks = @($checks)
        } | ConvertTo-Json -Depth 6
        exit ([int](-not $ok) * 3)
    }

    if (-not $ok) {
        [pscustomobject]@{ status = 'BLOCKED_PRECONDITIONS'; checks = @($checks) } | ConvertTo-Json -Depth 6
        exit 3
    }

    # Kanonische Queue: BACKLOG-Uebersichtstabelle parsen.
    $backlogRows = @{}
    foreach ($line in (Get-Content -LiteralPath $BacklogPath)) {
        if ($line -match '^\|\s*(STM-[A-Z0-9-]+[a-z]?)\s*\|') {
            $cells = @($line -split '\|' | ForEach-Object { $_.Trim() })
            # Zellen: [0]='' [1]=ID [2]=Titel [3]=Prio [4]=Status [5]=Kategorie [6]=Ziel-Bearb. ...
            if ($cells.Count -ge 7) {
                $backlogRows[$cells[1]] = [pscustomobject]@{
                    id     = $cells[1]
                    title  = $cells[2]
                    prio   = $cells[3]
                    status = ($cells[4] -replace '\*', '').Trim()
                    target = $cells[6]
                }
            }
        }
    }

    $blockedStatuses = @($config.neverProcess.statuses)
    $blockedTargets = @($config.neverProcess.assigneeTargets)
    $auditOnly = @($config.auditOnlyTasks)

    $selection = $null
    $skipped = [System.Collections.Generic.List[object]]::new()
    foreach ($taskId in @($config.ownerTaskQueue)) {
        if (-not $backlogRows.ContainsKey($taskId)) {
            $skipped.Add([pscustomobject]@{ id = $taskId; reason = 'nicht im Backlog' }); continue
        }
        $row = $backlogRows[$taskId]
        if ($row.target -in $blockedTargets) {
            $skipped.Add([pscustomobject]@{ id = $taskId; reason = "Contributor-Aufgabe (Ziel=$($row.target)) – ausgeschlossen" }); continue
        }
        if ($row.status -in $blockedStatuses) {
            $skipped.Add([pscustomobject]@{ id = $taskId; reason = "Status $($row.status)" }); continue
        }
        if (($taskId -in $auditOnly) -and -not $IncludeAuditOnly) {
            $skipped.Add([pscustomobject]@{ id = $taskId; reason = 'nur Audit erlaubt' }); continue
        }
        $selection = $row
        break
    }

    if ($null -eq $selection) {
        [pscustomobject]@{ status = 'NO_ELIGIBLE_TASK'; skipped = @($skipped) } | ConvertTo-Json -Depth 6
        exit 2
    }

    $runDir = Join-Path $runRoot ('run-' + [DateTime]::Now.ToString('yyyyMMdd_HHmmss'))
    New-Item -ItemType Directory -Force -Path $runDir | Out-Null

    $masterprompt = @(
        "# Nightly-Masterprompt $($config.projectKey)",
        '',
        "Aufgabe: $($selection.id) – $($selection.title) (Prio $($selection.prio))",
        "Basis: Branch $branch @ $head",
        '',
        'Regeln (bindend):',
        '- AGENTS.md, docs/planning/DEFINITION_OF_DONE.md und docs/planning/MARCEL_WORK_QUEUE.md gelten vollstaendig.',
        '- Keine Aufgaben mit Ziel-Bearbeiter friend; keine Marcel-Branches/-PRs anfassen.',
        '- Kein main-Merge, kein Release, kein History-Rewrite, kein Secret-Zugriff, keine Scheduler-Aenderung.',
        '- Eigener Paketbranch vom aktuellen origin/development; Commit nur ueber scripts/Commit-If-Green.ps1.',
        '- Grosse Arbeit ueber Routed Execution zerlegen (docs/operations/ROUTED_EXECUTION.md); kritische Kategorien nie herabstufen.',
        '- Bei Limit/Blocker: Checkpoint + NEXT_PROMPT erzeugen, nichts Unfertiges committen.',
        '',
        "Backlog-Detail: docs/planning/BACKLOG.md, Abschnitt $($selection.id)."
    ) -join "`n"
    Set-Content -LiteralPath (Join-Path $runDir 'masterprompt.md') -Value $masterprompt -Encoding utf8NoBOM

    $plan = [ordered]@{
        kind        = 'nightly-project-plan'
        createdUtc  = [DateTime]::UtcNow.ToString('o')
        projectKey  = [string]$config.projectKey
        branch      = $branch
        head        = $head
        selectedTask = $selection
        skipped     = @($skipped)
        masterpromptFile = (Join-Path $runDir 'masterprompt.md')
        gates       = @($config.executionGates)
        mode        = $Mode
    }
    ($plan | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath (Join-Path $runDir 'plan.json') -Encoding utf8NoBOM

    $gateResults = @()
    if ($Mode -eq 'Run' -and -not $SkipGates) {
        foreach ($gate in @($config.executionGates)) {
            $gatePath = Join-Path $repoRoot $gate
            if ($gatePath -eq $PSCommandPath -or $gate -like '*Test-NightlyExecutionReadiness*') { continue }
            & pwsh -NoProfile -File $gatePath *> (Join-Path $runDir (([IO.Path]::GetFileNameWithoutExtension($gate)) + '.log'))
            $gateResults += [pscustomobject]@{ gate = $gate; exitCode = $LASTEXITCODE }
        }
    }

    $failedGates = @($gateResults | Where-Object { $_.exitCode -ne 0 })
    [pscustomobject]@{
        status       = if ($failedGates.Count -gt 0) { 'PLAN_READY_GATES_RED' } else { 'PLAN_READY' }
        selectedTask = $selection.id
        runDir       = $runDir
        gateResults  = $gateResults
    } | ConvertTo-Json -Depth 6
    exit ([int]($failedGates.Count -gt 0) * 3)
}
finally {
    if ($Mode -ne 'Health') { Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue }
}
