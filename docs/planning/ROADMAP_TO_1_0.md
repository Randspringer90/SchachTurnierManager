# Roadmap bis v1.0.0 – SchachTurnierManager

Ziel: erste stabile, für den Vereinseinsatz und die gemeinsame Entwicklung geeignete
Version. Aufgaben-Detail in [`BACKLOG.md`](BACKLOG.md); Reihenfolge in
[`EXECUTION_WAVES.md`](EXECUTION_WAVES.md).

## Meilenstein `v1.0.0 – First Stable Release`

### Muss (P0/P1)
- Fachlich: kampflose Partien (STM-FACH-001), FIDE-Dutch (STM-FACH-002), große Felder (STM-FACH-003).
- Import/Export: TRF/Excel (STM-IE-001).
- Release: Setup-EXE (STM-REL-001), Signierung/Update (STM-REL-002), Kollegen-PC-Test (STM-REL-003).
- Security: Prompt-Injection (STM-SEC-001), Supply-Chain/Lizenz (STM-SEC-002),
  PII-Minimierung (STM-SEC-003), **Public Snapshot & History-Abnahme (STM-SEC-004, P0-Blocker)**.
- Abschluss: Release Candidate (STM-REL-004).

### Soll (P2)
- Tie-Break-Absicherung (STM-TB-001), Swiss-Manager/Chess-Results (STM-IE-002),
  FIDE-Namenssuche (STM-IE-004), i18n (STM-UX-001), PWA/Sync (STM-UX-002),
  Backup/Restore-UX (STM-UX-003), Performance/Last (STM-INFRA-002),
  Skript-/Agenten-/Wissens-Konsolidierung (STM-INFRA-001, STM-AI-001..003).

### Kann / post-1.0 (P3)
- Nightly/Resume (STM-AI-004), BYOK-Provider (STM-UX-004), DSB/DeWIS (STM-IE-003).

## Release-Gate zu v1.0.0
Alle Muss-Aufgaben `Done`, alle Gates grün, DoD erfüllt, Release-Workflow
([`RELEASE_WORKFLOW.md`](RELEASE_WORKFLOW.md)) durchlaufen, Tag `v1.0.0` durch Owner.
