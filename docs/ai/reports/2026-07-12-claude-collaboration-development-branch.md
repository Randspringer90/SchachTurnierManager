# Abschlussbericht – Kollaborations-Bootstrap & development-Branch (2026-07-12)

## Modell
Claude Opus 4.8 (claude-opus-4-8), Fortsetzung einer durch Nutzungslimit unterbrochenen
Fabel-Planungssession.

## Ausgangslage
- **Projektpfad im Auftrag** `D:\KFM\KI-Projekte\schach\SchachTurnierManager` existiert **nicht**;
  reales Repo unter `D:\Schach\SchachTurnierManager` mit korrektem Remote
  `Randspringer90/SchachTurnierManager` (Abweichung dokumentiert, kein Blocker).
- **Ausgangscommits:** `origin/main` = `5c66c48` (v0.53, kanonisch, „known base"); lokaler
  `main` = `97d75f9`.
- **Lokaler Dirty-/Branch-Stand:** Arbeitsbaum **sauber** (nichts uncommitted). `main` war
  jedoch **divergiert**: *ahead 5 / behind 25* gegenüber `origin/main` (Merge-Base `a6e7381`).
  Zusätzlich eine **gesperrte Fabel-Worktree** (`planning/2026-07-12-fabel-run1`, Session-Pfad),
  die unangetastet blieb.

## Umgang mit der unterbrochenen Fabel-Arbeit
- Fabels Arbeit lag bereits **kohärent committet auf `origin/main`** (25 Commits bis v0.53:
  Installer/Klick-Installation, i18n, PWA-Basis, lokale Chat-Hilfe, Wissensbasis, DPAPI,
  Public-Gate-Härtung, `.agents/skills/**`, `.claude/CLAUDE.md`, `docs/ai/**`,
  `Commit-If-Green.ps1` u. a.) – kein Haufen leerer Platzhalter.
- Die **5 lokalen `main`-Commits** (v0.41-Ära: Portable-Härtung, lokales AI-Help-Modul,
  Operator-Dashboard, Export-Formatter; ~3.600 Zeilen) waren **nicht** auf origin (`git cherry`
  alle `+`). Nach Rückfrage entschied der Owner **„voll mergen"**.
- **Nichts verworfen:** lokaler Stand zusätzlich in Backup-Branch
  `backup/pre-development-bootstrap-2026-07-12` (`97d75f9`) gesichert; gesperrte Worktree nicht
  berührt. Offene Reconcile-Arbeit als **STM-INT-001** im Backlog.

## development-Branch
- `development` von `origin/main` erzeugt, lokalen `main` per `--no-ff` gemergt.
- **13 Konflikte** zugunsten der kanonisch neueren origin-Version aufgelöst
  (`main.tsx`, `styles.css`, `Program.cs`, `package*.json`, 5 Skripte, `CHANGELOG/PLANS/README`);
  lokal **einzigartige, additive** Dateien (`Application.Ai`-Modul + Tests, Export-Formatter)
  übernommen. Build **grün**, Tests **grün**.
- **Commits:**
  - `5d64d12` merge (integriert lokalen v0.41-Stand)
  - `ff882aa` security: `.env.example` (vom Merge eingeschleppter verbotener `.env*`-Pfad) entfernt
  - `1c4818a` collab: Kollaborationsstruktur (dieser Lauf)

## Push-Status
- `git push origin development` **erfolgreich** (`origin/development` bis `1c4818a`).
- **`main` unverändert** (kein Push nach `main`), kein Force-Push, kein Tag, kein Release.

## Standardbranch & Repo-Einstellungen
- **Neuer Standardbranch:** `development` (Remote-HEAD → `origin/development`).
- `delete_branch_on_merge = true`; Squash-Merge + Merge-Commit an, **Rebase aus**.

## Rulesets (aktiv)
| Ruleset | Ref | Regeln | Bypass |
|---------|-----|--------|--------|
| collab-development | `refs/heads/development` | deletion, non-FF, PR (1 Approval, CODEOWNERS, Stale-Dismiss, Thread-Resolution), Status-Checks | RepositoryRole **Admin** (Owner direkt) |
| collab-main | `refs/heads/main` | wie oben + Status-Checks (inkl. security-gate) | RepositoryRole Admin (Notfall) |
| collab-release | `refs/heads/release/*` | deletion, non-FF, PR, Status-Checks (ReleaseGate/Security) | RepositoryRole Admin |

**Grenze:** Native Rulesets können „nur `release/*`+`hotfix/*` → `main`" nicht direkt ausdrücken;
das erzwingt der **required Status-Check `branch-policy`** (Workflow). Späterer Write-Collaborator
erhält ausschließlich **Write** → kann `development`/`main` nicht direkt pushen (Admin-Bypass gilt
nur für den Owner).

## Konfigurierte Statuschecks (required)
- development: `build-test`, `frontend`, `diff-check`, `branch-policy`
- main: zusätzlich `security-gate`
- release/*: `build-test`, `frontend`, `diff-check`, `security-gate`

## Erstellte/aktualisierte Dokumente
- Neu: `CONTRIBUTING.md`; `docs/planning/{BACKLOG,BRANCHING_STRATEGY,COLLABORATION_WORKFLOW,RELEASE_WORKFLOW,DEFINITION_OF_DONE,FEATURE_MATRIX,ROADMAP_TO_1_0,EXECUTION_WAVES,DEPENDENCY_MAP,MASTER_COMPLETION_PLAN}.md`; `docs/onboarding/{COLLABORATOR_ONBOARDING,FIRST_CONTRIBUTION}.md`; `docs/security/CONTRIBUTOR_SECURITY.md`; `config/model-routing.json`.
- Aktualisiert: `AGENTS.md` (Sichtbarkeit privat→**public**, externe `CORE-KFM`-Abhängigkeit entfernt, Branch-Modell), `README.md`, `PLANS.md` (→ BACKLOG kanonisch), `.claude/CLAUDE.md`, `docs/planning/PROJECT_ORCHESTRATION.md`, `docs/architecture/AI_AGENT_ARCHITECTURE.md`, `docs/ai/PROMPTS.md`.
- GitHub: `.github/CODEOWNERS`, `.github/pull_request_template.md`, `.github/ISSUE_TEMPLATE/{feature,bug,security-task,documentation,config}.yml` (alte `bug_report`/`feature_request` ersetzt), `.github/workflows/{ci,branch-policy,security-gate}.yml`.

## Erstellte Skripte + Tests
- `scripts/Configure-GitHubCollaboration.ps1` (`-Repository -Apply -WhatIf`, idempotent),
  `scripts/Test-CollaborationReadiness.ps1`, `scripts/New-FeatureBranch.ps1`,
  `scripts/Prepare-ReleaseBranch.ps1`, `scripts/Prepare-HotfixBranch.ps1`,
  `scripts/lib/CollaborationCommon.ps1`.
- Tests: `tests/collaboration/Collaboration.Tests.ps1` (Pester v5 Contract-Tests).

## Backlog
- **Offene Aufgaben gesamt: 28** (alle im Auftrag genannten Ziele überführt).
- **Ready: 4** (STM-FACH-001, STM-TB-001, STM-IE-001, STM-DOC-001).

## GitHub-Objekte
- **Labels: 24** (priority/status/type/area) idempotent angelegt.
- **Milestone:** `v1.0.0 - First Stable Release` (#1).
- **Issues: 4** – [#1](https://github.com/Randspringer90/SchachTurnierManager/issues/1) STM-FACH-001,
  [#2](https://github.com/Randspringer90/SchachTurnierManager/issues/2) STM-TB-001,
  [#3](https://github.com/Randspringer90/SchachTurnierManager/issues/3) STM-IE-001,
  [#4](https://github.com/Randspringer90/SchachTurnierManager/issues/4) STM-DOC-001. URLs im Backlog zurückgeschrieben.

## Tests & Gates (real ausgeführt)
| Gate | Ergebnis |
|------|----------|
| `dotnet build` (Merge) | grün (0/0) |
| `dotnet test` | **190 grün** (Domain 79, Application 93, Infrastructure 17, Golden 1) |
| Release-Gate (via Commit-If-Green) | grün |
| Test-GitCommitSafety (pre + `-Staged`) | grün (nach PII-/`.env.example`-Bereinigung) |
| Test-RepositoryOpenSourceSafety | grün (EXIT 0, keine Blocker) |
| Test-CollaborationReadiness (`-Online`) | OK |
| PowerShell-Parserchecks (alle neuen Skripte) | OK |
| `git diff --check` | sauber |

## Verbliebene Blocker / Hinweise
1. **PII in gepushter Historie (STM-SEC-004, P0):** Merge-Commit `5d64d12` enthielt in
   `TournamentServiceTests.cs` personenbezogene Test-Fixtures (Owner-Name/FIDE-ID) und eine
   `.env.example`. In `development`-HEAD **vorwärts bereinigt** (Testdatei auf origins redigierte
   Version zurückgesetzt, `.env.example` entfernt), aber in der **öffentlichen Historie**
   verbleibend. Bereinigung nur durch Owner (History-Purge/Clean-Snapshot) – **kein Force-Push in
   diesem Lauf** (verboten).
2. **Pester 5 nicht installiert** (lokal nur 3.4.0): die v5-Contract-Tests laufen in CI/Pester-5;
   der ausführbare lokale Gate ist `Test-CollaborationReadiness.ps1`.
3. **`.env.example` re-Add** braucht Owner-reviewte Anpassung von `Test-GitCommitSafety.ps1`
   (blockt `.env*`, obwohl `.gitignore` `.env.example` whitelistet) – Teil von STM-INT-001.
4. **Merge-Reconcile (STM-INT-001):** lokales `Application.Ai`-Modul vs. origins Chat-Hilfe (0.47)
   und Export-Doppelungen fachlich zusammenführen; 3 lokale PII-behaftete Tests entfielen dabei.
5. Ruleset erzwingt Quell-Restriktion nach `main` über den `branch-policy`-Check, nicht nativ.

## Manuelle Schritte: Freund später als Write-Collaborator einladen
1. Einladen mit Rolle **Write** (niemals Maintain/Admin):
   ```bash
   gh api -X PUT repos/Randspringer90/SchachTurnierManager/collaborators/<github-user> -f permission=push
   ```
2. `pwsh scripts/Test-CollaborationReadiness.ps1 -Online` (Rulesets/Default-Branch grün).
3. Freund Links geben: `docs/onboarding/COLLABORATOR_ONBOARDING.md` + `FIRST_CONTRIBUTION.md`.
4. **Keine** lokalen Secrets / `.secrets/local/` / Diagnose-ZIPs weitergeben.

## Empfehlung erste Aufgabe (Freund)
- **Aufgabe:** **STM-TB-001** – „Buchholz / Cut / Sonneborn-Berger – Golden-Tests"
  ([Issue #2](https://github.com/Randspringer90/SchachTurnierManager/issues/2)). Additiv, kein
  Risiko an Kernlogik, lehrt den Codebereich.
- **Erster Feature-Branchname:** `feature/STM-TB-001-tiebreak-golden-tests`
  (`pwsh scripts/New-FeatureBranch.ps1 -BacklogId STM-TB-001 -Name tiebreak-golden-tests`).
