# Execution-Waves – Reihenfolge der Umsetzung

Empfohlene Wellen bis v1.0.0. Details in [`BACKLOG.md`](BACKLOG.md),
Abhängigkeiten in [`DEPENDENCY_MAP.md`](DEPENDENCY_MAP.md).

## Welle 0 – Fundament (dieser Bootstrap-Lauf, erledigt)
- development-Branch, Merge des lokalen v0.41-Stands, Kollaborationsdoku, Backlog,
  GitHub-Templates/Labels/Milestone/Rulesets, CI/Branch-Policy/Security-Gate.

## Welle 1 – Sichere Zusammenarbeit einspielen (parallel möglich)
- **friend-geeignet, low-risk:** STM-TB-001, STM-DOC-001, STM-IE-001.
- **owner:** STM-INT-001 (v0.41-Reconcile), STM-SEC-001 (Prompt-Injection-Basis).

## Welle 2 – Fachliche Kernreife
- STM-FACH-001 → STM-FACH-002 → STM-FACH-003 (Pairing-Kette).
- STM-IE-002, STM-IE-004, STM-UX-001.

## Welle 3 – Betrieb & Distribution
- STM-REL-001 → STM-REL-002 → STM-REL-003.
- STM-UX-002, STM-UX-003, STM-INFRA-002.

## Welle 4 – Public- & Release-Abnahme
- STM-SEC-002, STM-SEC-003, **STM-SEC-004 (History-Abnahme, P0-Blocker)**.
- STM-REL-004 (Release Candidate) → Release v1.0.0.

## post-1.0
- STM-AI-004, STM-UX-004, STM-IE-003.
