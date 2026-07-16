# Feature-Matrix – SchachTurnierManager

Stand: 2026-07-16 (development). Reifegrad je Fachbereich. Details/Aufgaben in
[`BACKLOG.md`](BACKLOG.md).

| Bereich | Stand | Reife | Offene Backlog-IDs |
|---------|-------|-------|--------------------|
| Round Robin / Jeder gegen Jeden | vorhanden | stabil | – |
| Schweizer System (Basis) | vorhanden, global-optimales Matching ≤ 20 | teilweise | STM-FACH-002, STM-FACH-003 |
| FIDE-Dutch (vollständig) | Grundlage | offen | STM-FACH-002 |
| Große Felder > 20 | Basis | offen | STM-FACH-003 |
| Kampflose Partien / Freilos | vorhanden, opt-in FIDE-C.07/2026-Modus + Legacy-Default | sichere Adoption aus PR #10 über PR #14 abgeschlossen | – |
| Tie-Breaks (Buchholz/Cut/SB/Performance) | vorhanden | Golden-Adoption aus PR #9 über PR #13 abgeschlossen | – |
| Import/Export (Excel/TRF) | Formatter-Basis | offen | STM-IE-001, STM-IE-002 |
| Swiss-Manager / Chess-Results | – | offen | STM-IE-002 |
| Spielerdaten (DSB/DeWIS, FIDE-Suche) | teilweise (externer Lookup) | offen | STM-IE-003, STM-IE-004 |
| i18n | Fundament (18 Sprachen) | vervollständigen | STM-UX-001 |
| PWA / Offline / Sync | Basis | offen | STM-UX-002 |
| Backup/Restore | vorhanden | UX offen | STM-UX-003 |
| Lokale KI-Hilfe (kanonisch: Frontend-Wissensbasis, offline/providerlos) | vorhanden, konsolidiert | stabil | – |
| BYOK-KI-Provider (später, Infrastructure) | – | offen | STM-UX-004 |
| Installation / Setup-EXE | Kollegenpaket, Klick-Install | härten | STM-REL-001, STM-REL-002, STM-REL-003 |
| Security / Public-Reife | Gates + statische PR-Quarantäne vorhanden | weitere Supply-Chain-/PII-/History-Härtung | STM-SEC-001..005 |
| Sichere PR-Prüfung und Adoption | Base-SHA-static-only, Agent/Skills/Policies/CI/Feedback (STM-SEC-005) | stabil | – |
| KI-Agenten / Skills / Trust / Wissen | kanonische Struktur + Manifeste + Guards (STM-AI-001) | Migration/Wissen/Modellrouting offen | STM-AI-001b, STM-AI-002, STM-AI-003, STM-AI-004 |
| Prompt-Injection-Verteidigung | Trust-Zonen, Allowlist, Guards + Tests (STM-SEC-001, in Arbeit) | härten | STM-SEC-001 |
| Performance / Last | – | offen | STM-INFRA-002 |
| Release Candidate v1.0.0 | – | blockiert | STM-REL-004 |
