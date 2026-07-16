# Contributing – SchachTurnierManager

Willkommen! Dieses Repository wird von **der Owner** (Owner) und eingeladenen Mitwirkenden
gemeinsam entwickelt. Diese Datei ist der Einstieg; die verbindlichen Details stehen in den
verlinkten kanonischen Dokumenten.

## TL;DR

- **`development`** ist der Standardbranch und die aktive Entwicklungsquelle.
- **`main`** enthält nur den letzten **freigegebenen Release-Stand**.
- Mitwirkende (außer der Owner) arbeiten **ausschließlich** über Feature-Branches und Pull
  Requests nach `development`. Direktes Pushen nach `development`/`main` ist technisch gesperrt.
- Aufgaben kommen aus der **einzigen kanonischen Quelle**: [`docs/planning/BACKLOG.md`](docs/planning/BACKLOG.md).
  `PLANS.md` ist historische Planung.

## Kanonische Dokumente

| Thema                        | Datei |
|------------------------------|-------|
| Branch-Modell                | [`docs/planning/BRANCHING_STRATEGY.md`](docs/planning/BRANCHING_STRATEGY.md) |
| Zusammenarbeit / PR-Ablauf   | [`docs/planning/COLLABORATION_WORKFLOW.md`](docs/planning/COLLABORATION_WORKFLOW.md) |
| Release & Hotfix             | [`docs/planning/RELEASE_WORKFLOW.md`](docs/planning/RELEASE_WORKFLOW.md) |
| Aufgaben-Backlog (kanonisch) | [`docs/planning/BACKLOG.md`](docs/planning/BACKLOG.md) |
| Definition of Done           | [`docs/planning/DEFINITION_OF_DONE.md`](docs/planning/DEFINITION_OF_DONE.md) |
| Onboarding                   | [`docs/onboarding/COLLABORATOR_ONBOARDING.md`](docs/onboarding/COLLABORATOR_ONBOARDING.md) |
| Erster Beitrag               | [`docs/onboarding/FIRST_CONTRIBUTION.md`](docs/onboarding/FIRST_CONTRIBUTION.md) |
| Codex-Schach-Contributor     | [`docs/onboarding/CODEX_CHESS_CONTRIBUTOR.md`](docs/onboarding/CODEX_CHESS_CONTRIBUTOR.md) (nicht-technisch, mit Codex) |
| Security & Prompt-Injection  | [`docs/security/CONTRIBUTOR_SECURITY.md`](docs/security/CONTRIBUTOR_SECURITY.md) |
| Sichere PR-Prüfung           | [`docs/security/SAFE_PULL_REQUEST_REVIEW.md`](docs/security/SAFE_PULL_REQUEST_REVIEW.md) |
| Kontrollierte PR-Übernahme   | [`docs/planning/PULL_REQUEST_ADOPTION_WORKFLOW.md`](docs/planning/PULL_REQUEST_ADOPTION_WORKFLOW.md) |
| KI-Agenten-Regeln            | [`AGENTS.md`](AGENTS.md) |

## Ablauf in Kürze

1. `Ready`-Aufgabe aus dem Backlog + zugehöriges Issue wählen.
2. `pwsh scripts/New-FeatureBranch.ps1 -BacklogId STM-… -Name kurz-name`.
3. Umsetzen: Code + Tests + Doku, lokal grün (`scripts/Test-All.ps1`, `scripts/Invoke-ReleaseGate.ps1`).
4. Vor dem PR `development` einmergen.
5. PR nach `development`, PR-Template vollständig ausfüllen; der statische Security-Check
   untersucht Base-gebunden Metadaten, Dateiliste und Patch vor der normalen CI-Ausführung.
6. Review durch den Owner, CI grün, Konversationen gelöst → Squash-Merge beziehungsweise bei
   notwendiger Anpassung kontrollierte Owner-Übernahme mit Attribution.
7. Backlog- und Changelog-Status pflegen.

## Nicht-Verhandelbares

- Keine Secrets, Logs, Datenbanken, ZIPs, Dumps oder lokale Konfiguration committen.
- Kein `git add .` / `git add --all` ohne Safety-Check.
- Kein Force-Push / History-Rewrite auf `development` oder `main`.
- Keine personenbezogenen Daten in Backlog, Issues oder PRs.
- Das Projekt bleibt **self-contained** – keine Abhängigkeit auf andere lokale Projekte.
- KI-Agenten befolgen exakt dieselben Regeln wie Menschen (siehe `AGENTS.md`).

## Qualität

Vor jedem PR müssen Build und Tests grün sein. Fachliche Algorithmusänderungen (Pairing,
Wertungen) brauchen zuerst Tests; Pairing-Entscheidungen müssen auditierbar bleiben.
