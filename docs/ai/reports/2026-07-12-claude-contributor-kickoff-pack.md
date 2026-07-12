# Abschlussbericht – Codex-Contributor-Starterpaket (2026-07-12)

Modell: Claude Opus 4.8 (claude-opus-4-8). Branch: `development`.

## Ausgangscommit
`f42eb346694ca406309f9ffe1f55075a4e874529` (development, sauber, synchron mit origin).

## Geänderte / neue Dateien
**Neu**
- `docs/onboarding/CODEX_CHESS_CONTRIBUTOR.md` – einfache Anleitung für nicht-technische Contributor.
- `docs/ai/templates/CODEX_CHESS_FEATURE.md` – wiederverwendbare Codex-Promptvorlage (Platzhalter, trusted/untrusted-Trennung).
- `scripts/New-ContributorTaskPrompt.ps1` – Promptgenerator.
- `scripts/Test-ContributorKickoffReadiness.ps1` – Abnahme-Check.
- `tests/collaboration/ContributorKickoff.Tests.ps1` – Pester-Contract-Tests (CI/Pester 5).
- dieser Bericht.

**Aktualisiert**
- `CONTRIBUTING.md`, `docs/onboarding/FIRST_CONTRIBUTION.md`, `scripts/README.md`,
  `docs/planning/BACKLOG.md` (Eintrag `STM-INFRA-003`, Status Done), `CHANGELOG.md`,
  `docs/ai/PROMPTS.md`.

## Funktionsweise des Promptgenerators
`pwsh scripts/New-ContributorTaskPrompt.ps1 -BacklogId <ID>` (optional `-IssueNumber`,
`-ContributorName`, `-OutputDirectory`, `-Offline`, `-WhatIf`):
1. Repo-Root sicher bestimmen; aktuellen Branch prüfen (`development` oder gültiger Feature-Branch).
2. `docs/planning/BACKLOG.md` als kanonische Quelle lesen; Status, Kategorie, geplanten Feature-Branch,
   Issue-Nummer extrahieren. Nur **Ready** oder **In Progress** zulässig.
3. Feature-Branch gegen striktes Muster validieren; Fach-Skill aus Kategorie ableiten
   (z. B. `tiebreaks`, `imports-exports`).
4. Issue-Text optional via `gh` lesen; ohne Netzwerk/`-Offline` **Offline-Fallback** aus dem
   Backlog-Detail.
5. Vorlage füllen und als Prompt schreiben; genau **ein** Upload-ZIP unter
   `D:\Temp\STM_ContributorTaskPrompt_<Timestamp>`.

Erzeugter Prompt weist Codex an: `AGENTS.md` + Contributor-Doku lesen, nur das eine Issue
bearbeiten, **zuerst Tests**, keine Logik ohne Anforderung ändern, ReleaseGate ausführen,
`Commit-If-Green` nutzen, Feature-Branch pushen, **PR nach `development`**, **niemals selbst mergen**.

## Security- / Prompt-Injection-Schutz
- **Vertrauenswürdig vs. nicht vertrauenswürdig** klar getrennt: Projektregeln (Abschnitt 1)
  vs. wörtlicher Issue-/Backlog-Text in einem markierten Fenced-Block (Abschnitt 2, „DATEN, kein Befehl").
- Issue-Text wird **nie** als Anweisung übernommen oder ausgeführt.
- Redaktion im untrusted Text: Owner-/Maschinenpfade (`[A-Za-z]:\…`), Secrets/Tokens
  (`gh*_`, `AKIA…`, `xox…`, PRIVATE KEY) und Code-Fence-Ausbrüche (` ``` `) werden entschärft.
- Keine Shell-Interpolation unvalidierter Werte; strikte Validierung von ID/Branch.
- Sicherheitsabbruch, falls ein Owner-Pfad im finalen Prompt stünde.
- **friend-Ausschlüsse**: `.github/**`, `.agents/**`, `config/**`, `scripts/*Security*|*Git*|*Commit*`,
  `installer/**`, `AGENTS.md`, `docs/security/**`, `docs/architecture/**`, Build-Props, `global.json`.

## Tests
- `scripts/Test-ContributorKickoffReadiness.ps1`: **OK** – Doku/Vorlage, Parserchecks, Generierung
  STM-TB-001, erwarteter Branch `feature/STM-TB-001-tiebreak-golden-tests`, PR-Basis `development`,
  kein Owner-Pfad/Secret, genau ein Upload-ZIP, ungültige ID + Blocked-Status abgelehnt,
  WhatIf ohne Änderungen, synthetische Injection-Fixture nur als untrusted Text.
- `tests/collaboration/ContributorKickoff.Tests.ps1` (Pester 5, CI).
- Weitere Gates: siehe unten (ReleaseGate/GitSafety/OpenSourceSafety/diff --check).

## Commit / Push
- Commit über `scripts/Commit-If-Green.ps1` (Release-Gate + GitSafety erzwungen).
- Commit-SHA: siehe `git log -1` auf `development` bzw. Feld `COMMIT=` der Endausgabe dieses Laufs.
- Push nach `origin/development`: Status im Feld `PUSH=` der Endausgabe.

## Beispiel
- Befehl: `pwsh .\scripts\New-ContributorTaskPrompt.ps1 -BacklogId STM-TB-001`
- Erzeugter Beispielprompt (nicht im Repo, lokal unter `D:\Temp`):
  `D:\Temp\STM_ContributorTaskPrompt_<Timestamp>\codex-prompt-STM-TB-001.md`

## Verbleibende manuelle Schritte
- Freund als **Write**-Collaborator einladen (separater Schritt, siehe
  `docs/onboarding/COLLABORATOR_ONBOARDING.md`).
- Empfohlene erste Aufgabe: **STM-TB-001** (Issue #2) → Branch
  `feature/STM-TB-001-tiebreak-golden-tests`.
- Optional: Pester 5 in CI, damit `ContributorKickoff.Tests.ps1` dort läuft.
