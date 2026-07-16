# Lessons Learned — SchachTurnierManager

Kumulativ, neueste zuerst. Jeder Eintrag: Datum, Kontext, Lesson, Konsequenz. Das Projekt
persistiert seine Lessons eigenständig in diesem Repository; externe lokale Wissenspfade sind
keine Voraussetzung.

## 2026-07-16 — Pull-Request-Vertrauen ist an Herkunft und SHA gebunden

- Kontext: STM-SEC-005, unabhängiger Security-Review der statischen PR-Pipeline.
- Lesson: Ein sicher wirkender Zielpfad macht PR-Inhalt nicht vertrauenswürdig. Auch Reports,
  Ausgabepfade und Base-/Head-SHAs brauchen fail-closed Bindung; statische Freigabe ist keine
  Merge-Freigabe.
- Konsequenz: Base-SHA-Code prüft vor jeder Ausführung; T4-Dateipfade werden nie automatisch
  als erlaubter Integrationsscope übernommen; Artefakte sind SHA-/Policy-/Hash-gebunden und
  WhatIf/StaticOnly werden durch Negativtests gegen Mutationen abgesichert.

## 2026-07-10 — Public-nahe Testdaten und KI-Laufprotokolle

- Kontext: Stabilisierung, Public-Gate und Runtime-Logging.
- Lesson: Auch alte Offline-Fixtures, Handoff-Texte und KI-Promptlogs koennen personenbezogene oder lokale Details in den aktuellen Arbeitsstand tragen.
- Konsequenz: Public-nahe Repos verwenden synthetische Fixtures; echte Live-IDs werden nur bewusst per Parameter oder Environment gesetzt. KI-Laufprotokolle werden vor dem Commit bereinigt.
