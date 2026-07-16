# Master-Completion-Plan – Weg zu v1.0.0

> Dach-Dokument über [`BACKLOG.md`](BACKLOG.md), [`ROADMAP_TO_1_0.md`](ROADMAP_TO_1_0.md),
> [`EXECUTION_WAVES.md`](EXECUTION_WAVES.md) und [`DEPENDENCY_MAP.md`](DEPENDENCY_MAP.md).
> Konsolidiert die früheren Fabel-/Codex-Planungen (`docs/ai/prompts/codex-roadmap/**`,
> `PLANS.md`, alte Roadmaps) in eine kohärente Sicht.

## Zielbild
Eine stabile v1.0.0, die im Verein einsetzbar ist und vom Owner + einem Write-Collaborator
gemeinsam (Feature-Branch → PR → Review → `development`) weiterentwickelt wird.

## Arbeitsmodell
- Standardbranch `development`; Releases über `release/*` → `main` + Tag.
- Einzige Aufgabenquelle: `BACKLOG.md`. Jede Aufgabe hat ID, Tests, Security-Bewertung, DoD.
- Gates (Build, Tests, Frontend, Safety, ReleaseGate) müssen grün sein; CI erzwingt dies je PR.

## Phasen (aggregiert aus Execution-Waves)
1. **Fundament (erledigt):** Kollaborationsstruktur, Branch-Modell, CI, Backlog.
2. **Sichere Zusammenarbeit:** erste friend-Aufgaben (Ready) + Owner-Reconcile/Security-Basis.
3. **Fachliche Kernreife:** Pairing-Kette, Import/Export, i18n.
4. **Betrieb & Distribution:** Setup-EXE, Signierung, Kollegen-PC-Test, PWA/Backup.
5. **Public- & Release-Abnahme:** Supply-Chain, PII, **History-Abnahme (P0-Blocker)**, RC → Release.

## Offene Fabel-/Codex-Arbeiten (überführt, nicht verworfen)
- Skill-Zielstandard & Migration → STM-AI-001.
- Wissensmanagement-Struktur (repo-intern) → STM-AI-002, abgeschlossen über PR #19.
- Modellrouting → STM-AI-003, abgeschlossen über PR #17.
- Nightly-/Resume-Unterbau & Configs → STM-AI-004, abgeschlossen über PR #21;
  zentrale Registrierung ist sicher vorbereitet, aber nicht aktiviert.
- Prompt-/Report-Governance & Templates, Codex-Prompts, Guards/Gates → STM-SEC-001 + STM-AI-001.
- Unfertige, nicht zugängliche Arbeit lag in einer **gesperrten Session-Worktree**
  (`planning/2026-07-12-fabel-run1`) und wurde bewusst nicht angetastet.

## Kritischer Pfad
`STM-SEC-004` (Git-History-Abnahme) ist **P0-Blocker** für einen sauberen Public-Stand und
für `STM-REL-004` (Release Candidate). Frühzeitig durch Owner entscheiden.
