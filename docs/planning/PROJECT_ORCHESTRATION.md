# Projekt-Orchestrierung

> **Kollaboration (2026-07-12):** Standardbranch ist `development`, `main` = letzter Release.
> Kanonische Aufgabenquelle: [`BACKLOG.md`](BACKLOG.md). Zusammenarbeit/Branches:
> [`COLLABORATION_WORKFLOW.md`](COLLABORATION_WORKFLOW.md),
> [`BRANCHING_STRATEGY.md`](BRANCHING_STRATEGY.md), [`../../CONTRIBUTING.md`](../../CONTRIBUTING.md).

Stand: 0.38.7. Welche Aufgabe läuft über welches Skript, welchen Skill, welchen Agenten.

## Aufgaben → Werkzeuge

| Aufgabe | Werkzeug | Hinweise |
|---|---|---|
| Entwicklung starten | `scripts/Start-Dev.ps1`, `scripts/Run-Backend.ps1`, `scripts/Run-WebApp.ps1` | Backend `:5088`, Frontend `:5173` |
| Tests | `scripts/Test-All.ps1`, `scripts/Run-ExternalLookupSmoke.ps1` | Lookup-Details: `docs/architecture/EXTERNAL_PLAYER_LOOKUP_TESTING.md` |
| Build/Test/Release-Gate | `scripts/Invoke-ReleaseGate.ps1` | restore, build, test, npm install/build, Pack-Portable |
| Paketierung | `scripts/Pack-Portable.ps1`, `scripts/Start-Portable.bat` | Ausgabe unter `output/portable` |
| Commit | `scripts/Commit-If-Green.ps1` | CommitGuard, siehe unten |
| Commit-Sicherheitsprüfung | `scripts/Test-GitCommitSafety.ps1` | wird vom CommitGuard automatisch aufgerufen |
| Open-Source-Sicherheitsprüfung | `scripts/Test-RepositoryOpenSourceSafety.ps1` | Reports unter `output/repo-open-source-safety/` |
| Open-Source-Clean-Snapshot | `scripts/New-OpenSourceSnapshot.ps1` | Snapshot + Report unter `output/open-source-snapshot/` |
| PR initial statisch prüfen | `scripts/Invoke-SafePullRequestReview.ps1` | nur Metadaten/Dateiliste/Patch; kein Checkout, Restore, Build oder Test |
| Dependency-Delta prüfen | `scripts/Test-PullRequestDependencyDelta.ps1` | Offline-Contract ohne Paketmanager/Lifecycle-Skripte |
| PR-Adoption planen | `scripts/New-PullRequestAdoptionPrompt.ps1` | SHA-/Policy-gebundener Trust-Handoff; Integration vom aktuellen development |
| Contributor-Feedback | `scripts/New-PullRequestFeedback.ps1` | standardmäßig Draft; explizites Posting nach SHA-Recheck |
| PR-Review-System abnehmen | `scripts/Test-PullRequestReviewReadiness.ps1` | synthetische Security-/Tamper-/WhatIf-Fälle |
| Nightly-Checkpoint erzeugen | `scripts/New-NightlyCheckpoint.ps1` | nur auf sauberem `development`, lokale T3-Daten unter `output/` |
| Resume sicher planen | `scripts/Get-NightlyResumePlan.ps1` | read-only Plan; Branch-/SHA-/Worktree-Drift blockiert |
| Nightly-Registrierung vorbereiten | `scripts/New-NightlyRegistrationPlan.ps1` | nur `READY_FOR_ACTIVATION`, keine externe Aktivierung |
| Nightly-/Resume-Unterbau abnehmen | `scripts/Test-NightlyReadiness.ps1` | synthetisches isoliertes Git-Repository unter `output/` |
| Routed Execution (Taskgraph validieren/ausführen/fortsetzen) | `scripts/New-RoutedTaskGraph.ps1`, `scripts/Invoke-RoutedTaskGraph.ps1`, `scripts/Resume-RoutedTaskGraph.ps1` | Children read-only, T3-Quarantäne, SHA-Checkpoints; Abnahme `scripts/Test-RoutedExecutionReadiness.ps1` |
| Nightly-Projektlauf (lokal) | `scripts/Invoke-NightlyProjectRun.ps1`, `scripts/Resume-NightlyProjectRun.ps1` | friend-/Blocked-Aufgaben ausgeschlossen; kein main/Release/History/Secrets; Abnahme `scripts/Test-NightlyExecutionReadiness.ps1` |
| Zentrale Nightly-Registrierung | `scripts/Register-NightlyProject.ps1` | nur Override-Flip in vorhandener zentraler Registry (Pfad als Parameter); seit 2026-07-16 ACTIVE; nie eigene Scheduled Task |
| Aufräumen | `scripts/Clean-Generated.ps1` | generierte Artefakte |

Zugehörige Skills: `.agents/skills/repository-security.md` (vor Commit/Push/Snapshot verbindlich),
die fünf manifestierten PR-Review-Skills (`pull-request-security-review`,
`dependency-delta-review`, `malware-risk-review`, `safe-pr-adoption`,
`contributor-feedback`) sowie fachliche Skills (`pairing-engine`, `tiebreaks`,
`rating-performance`, `imports-exports`, `installer-packaging`, `ui-dashboard`,
`external-player-lookup`) vor Arbeit am jeweiligen Thema.

## Release-Gate

`scripts/Invoke-ReleaseGate.ps1` ist das Pflicht-Gate vor jedem Commit: `dotnet restore` → `dotnet build` → `dotnet test` → `npm install` + `npm run build` (WebApp) → `Pack-Portable`. Schaltbare Abkürzungen (`-SkipPack`, `-NoNpmInstall`, `-NoDotnetTest`) sind nur für lokale Iteration gedacht, nicht für Commits.

## CommitGuard

`scripts/Commit-If-Green.ps1 -Message "..." [-Push]`:

1. Release-Gate komplett ausführen.
2. `Test-GitCommitSafety.ps1` vor dem Staging (Arbeitsbaum + getrackte Inhalte).
3. Geänderte Dateien anzeigen und nur diese explizit stagen – kein `git add .`, kein `git add --all`.
4. `Test-GitCommitSafety.ps1 -Staged` nach dem Staging (Pfade + neu hinzugefügte Zeilen).
5. Staging anzeigen, dann Commit; Push nur mit explizitem `-Push` und nur nach Freigabe.

Der Guard blockiert Artefakte (`output/`, `bin/`, `obj/`, `dist/`, `node_modules/`, Logs, Dumps, ZIPs, Datenbanken), lokale Audits/Backups, `.codex`, `.vs`, interne Registry-/TFS-Referenzen und typische Zugangsdaten-Muster. Bei Arbeits-/TFS-Remotes bricht er hart ab.

## Clean Snapshot (Public Release)

Das Repository ist bereits öffentlich; der Clean-Snapshot-Ablauf ist eine optionale,
manuell freizugebende Remediation für die dokumentierte alte Historie:

1. Arbeitsbaum clean committen.
2. Optional `scripts/Test-RepositoryOpenSourceSafety.ps1` (mit `-AllHistory` für Historien-Scan) und Report prüfen.
3. `scripts/New-OpenSourceSnapshot.ps1` erzeugt Snapshot ohne `.git`-Historie unter `output/open-source-snapshot/`; ausgeschlossen sind u. a. `docs/handoffs/`, `scripts/archive/`, lokale Artefakte und Zugangsdaten-Muster.
4. Snapshot-Report manuell abnehmen; offener Punkt laut `PLANS.md`: Prüfung auf frischem Klon vor echtem Release.

## Handoff-Erzeugung

Die frühere Praxis (pro Version `docs/HANDOFF_x_y_z.md` + `scripts/After-Apply-V*.ps1`) ist beendet; Bestände liegen archiviert unter `docs/handoffs/` und `scripts/archive/after-apply/`. Übergaben laufen heute über `BACKLOG.md` (kanonische offene Punkte), `CHANGELOG.md` (was wurde getan) und die Laufberichte unter `docs/ai/reports/` – ohne begleitende Patch-Skripte.

## Zielstruktur scripts/ (dokumentiert, noch nicht migriert)

Geplante Gliederung, sobald eine Migration inklusive Anpassung aller Pfadverweise gefahrlos möglich ist:

```text
scripts/
  dev/          Start-Dev, Run-Backend, Run-WebApp
  test/         Test-All, Run-ExternalLookupSmoke
  release/      Invoke-ReleaseGate, Pack-Portable, Start-Portable.bat
  git/          Commit-If-Green, Commit-Checkpoint
  security/     Test-GitCommitSafety, Test-RepositoryOpenSourceSafety, New-OpenSourceSnapshot
  maintenance/  Clean-Generated
  archive/      after-apply/ (bereits umgesetzt)
```

Bis dahin bleiben die aktiven Skripte bewusst flach unter `scripts/`, weil `Commit-If-Green.ps1`, `Invoke-ReleaseGate.ps1` und die Safety-Skripte sich gegenseitig über feste Pfade aufrufen und in README/Doku so referenziert sind. Eine Migration muss in einem eigenen Lauf alle Aufrufe, Doku-Verweise und Regex-Pfadmuster (`patternSourceRegex`, Snapshot-Excludes) gleichzeitig aktualisieren und über das Release-Gate abgesichert werden.
