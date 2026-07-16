# Dependency-Map – Aufgaben-Abhängigkeiten

Gerichtete Abhängigkeiten zwischen Backlog-Aufgaben (`A → B` = B braucht A zuerst).
Details in [`BACKLOG.md`](BACKLOG.md), Reihenfolge in [`EXECUTION_WAVES.md`](EXECUTION_WAVES.md).

## Fachlich (Pairing/Wertung)
```
STM-FACH-001 (kampflose Partien) ──► STM-FACH-002 (FIDE-Dutch) ──► STM-FACH-003 (große Felder)
STM-TB-001 (Tie-Break-Golden-Tests) ──► STM-FACH-001   (Absicherung vor Wertungsänderung)
```

## Import/Export & Spielerdaten
```
STM-IE-001 (TRF/Excel) ──► STM-IE-002 (Swiss-Manager/Chess-Results)
STM-IE-004 (FIDE-Namenssuche) ──► STM-IE-003 (DSB/DeWIS)
```

## KI / Agenten / Wissen
```
STM-AI-001 (Agenten-/Skill-Standard) ──► STM-AI-002 (Wissensmanagement, Done)
STM-AI-001 ──► STM-SEC-001 (Prompt-Injection-Verteidigung)
STM-AI-001 ──► STM-SEC-005 (Done: sichere PR-Prüfung/Adoption) ──► kontrollierte Fremd-PR-Integration
STM-AI-003 (Modellrouting, Done) ── unabhängig, config/model-routing.json operationalisiert
STM-AI-001 ──► STM-AI-004 (Nightly/Resume, Done)
```

## Security / Release (kritischer Pfad zu v1.0.0)
```
STM-SEC-001, STM-SEC-002, STM-SEC-003 ──► STM-SEC-004 (Public Snapshot/History, P0); STM-SEC-005 ist Done
STM-REL-001 (Setup-EXE) ──► STM-REL-002 (Signierung/Update) ──► STM-REL-003 (Kollegen-PC-Test)
alle P0/P1 ──► STM-REL-004 (Release Candidate) ──► Release v1.0.0
```

## Integration
```
STM-INT-001 (v0.41-Reconcile) ── unabhängig; Quelle: backup/pre-development-bootstrap-2026-07-12
```

## Ohne Abhängigkeiten (jederzeit startbar)
- STM-DOC-001, STM-TB-001, STM-IE-001, STM-INT-001, STM-INFRA-001, STM-UX-001.
