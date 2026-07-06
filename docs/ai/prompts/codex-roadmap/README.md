# Codex-Roadmap-Prompts – SchachTurnierManager

Ein Prompt pro Arbeitspaket. So startest du einen Lauf (Codex, Claude Code o. Ä.):

> „Arbeite am SchachTurnierManager weiter. Führe **RUN-XX** aus:
> `docs/ai/prompts/codex-roadmap/RUN-XX-….md`. Halte dich strikt an
> `docs/ai/prompts/codex-roadmap/PROMPT_BASE.md`."

Regeln: **ein Lauf = ein Arbeitspaket**, nicht mehrere RUNs mischen. Reihenfolge ist
Empfehlung; Abhängigkeiten stehen im jeweiligen Prompt.

## Status (Stand 2026-07-06)

| RUN | Thema | Status |
|---|---|---|
| 01 | Vollständiger Audit | ✅ erledigt (Fable-Lauf 2026-07-06, wiederholbar vor jedem Meilenstein) |
| 02 | Release-Reife MVP prüfen | offen |
| 03 | Portable ZIP produktionsreif | teils (Pack-Portable + Release-Gate vorhanden; Frischordner-Test offen) |
| 04 | Self-contained Desktop-App | ✅ Grundpaket erledigt (`scripts/Publish-DesktopApp.ps1`); Feinschliff offen |
| 05 | Installer-EXE (Inno Setup) | teils (`installer/SchachTurnierManager.iss` + `scripts/Build-Installer.ps1` fertig; Kompilieren/Testen offen, Inno Setup lokal installieren) |
| 06 | Open-Source-Clean-Snapshot | teils (Skripte vorhanden; Lizenzwahl + frischer Klon-Test offen) |
| 07 | Vereinswebsite-Paket | offen |
| 08 | PWA / Handy | offen |
| 09 | Cloud-/Hosting-Konzept | offen (nur Konzept, keine Kostenaktionen) |
| 10 | KI-Chatbot / Turnierassistent | offen |
| 11 | Wissensbasis für Chatbot | offen |
| 12 | FIDE-Dutch-Strategie | offen |
| 13 | Große Schweizer Turniere (>20) | offen |
| 14 | Tie-Breaks / Wertungen | offen |
| 15 | Import/Export (CSV/TRF) | offen |
| 16 | Weitere Turnierformate | offen |
| 17 | Turnierassistent im UI | offen |
| 18 | QA und Testdaten | offen |
| 19 | Dokumentation | offen |
| 20 | Finaler Release Candidate | offen (zuletzt ausführen) |
| 21 | i18n vervollständigen (18 Sprachen) | in Arbeit (Fundament fertig: `src/SchachTurnierManager.WebApp/src/i18n/`) |

RUN-21 (Mehrsprachigkeit) ist mehrfach ausführbar: pro Lauf ein UI-Bereich extrahieren
bzw. ein Sprachpaket füllen, bis alles übersetzt ist.
