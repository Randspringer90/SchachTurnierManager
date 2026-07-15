# Lessons Learned — SchachTurnierManager

Kumulativ, neueste zuerst. Jeder Eintrag: Datum, Kontext, Lesson, Konsequenz.
Projektuebergreifende Lessons zusaetzlich in der Zentrale
(`D:\KFM\KI-Projekte\docs\ai\LESSONS_LEARNED.md` bzw. `C:\KFM\Codex`).

## 2026-07-15 - KFM-FLEET-CORRECTION-CODEX-SOL-FINALIZE-20260715

- Ein grüner Arbeitsbaumscan ersetzt keine offene Public-History-Entscheidung.

## 2026-07-10 — Public-nahe Testdaten und KI-Laufprotokolle

- Kontext: Stabilisierung, Public-Gate und Runtime-Logging.
- Lesson: Auch alte Offline-Fixtures, Handoff-Texte und KI-Promptlogs koennen personenbezogene oder lokale Details in den aktuellen Arbeitsstand tragen.
- Konsequenz: Public-nahe Repos verwenden synthetische Fixtures; echte Live-IDs werden nur bewusst per Parameter oder Environment gesetzt. KI-Laufprotokolle werden vor dem Commit bereinigt.
