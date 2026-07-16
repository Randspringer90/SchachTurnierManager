---
name: ai-run-logging
description: Jeder KI-Lauf protokolliert Prompt, Abschlussbericht und Lessons Learned unter docs/ai und checkt sie mit ein. LLM-neutral fuer Claude Code, Codex und aehnliche Tools.
---

# Skill: AI-Run-Logging

## Regeln

1. Vor Arbeitsbeginn: urspruenglichen Auftrag/Prompt als
   `docs/ai/prompts/<YYYYMMDD_HHmm>_<slug>.md` speichern (Quelle: Claude Code, Codex, ...).
2. Nach Abschluss: Abschlussbericht als `docs/ai/reports/<YYYYMMDD_HHmm>_<slug>_REPORT.md`
   (TL;DR, Aenderungen, Checks, offene Punkte).
3. Beides in `docs/ai/PROMPTS.md` (Tabelle) eintragen.
4. Neue Erkenntnisse nach `docs/ai/LESSONS_LEARNED.md` (neueste zuerst);
   projektuebergreifende Lessons optional zusaetzlich melden (nur beim Owner, kein Gate).
5. Alles zusammen mit der fachlichen Aenderung lokal committen
   (Safety-Gates des Projekts beachten). Keine Secrets/PII in Prompts oder Reports.
6. Optionale Handoff-/Run-Kopien bleiben lokal ausserhalb des Repos (kein fester Fremdpfad,
   keine Projektabhaengigkeit); Details siehe `docs/knowledge/INDEX.md`.
