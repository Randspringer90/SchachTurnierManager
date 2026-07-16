# STM-AI-001 Agenten-, Skill- und Security-Grundlage

- Zeit: 2026-07-12
- Quelle: Claude Code
- Datenschutz: Rekonstruierte, bereinigte Auftragsfassung ohne lokale Pfade, Secrets,
  personenbezogene Daten oder externe Payloads.

## Auftrag

Eine providerneutrale und maschinell pruefbare Agenten-/Skill-Grundlage fuer den
SchachTurnierManager schaffen:

- kanonische Rollen unter `agents/**` und nur duenne Provider-Adapter;
- Agent-, Skill-, Routing-, Trust- und Toolpermission-Manifeste;
- eine explizite Instruction-Allowlist und Trust-Zonen fuer untrusted Inhalte;
- lokale Guards und synthetische Contract-Tests fuer Instruction Integrity,
  Prompt-Injection, Skill Readiness und sichere Wissenspersistenz;
- projektlokales Wissensmanagement ohne Fremdprojektabhaengigkeit;
- CI-Anbindung des plattformneutralen Integrity-Gates;
- Aktualisierung von Backlog, Feature-Matrix, Architektur-, Security- und KI-Dokumentation.

Keine Schachlogik, Secrets, PII, lokalen Workstation-Pfade oder externen
Runtime-/Build-Abhaengigkeiten einfuehren. Verbleibende Legacy-Skill-Migration und die
vollstaendige Consumer-/CI-Integration als getrennte Folgepakete dokumentieren.
