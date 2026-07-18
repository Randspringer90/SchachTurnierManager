# Lessons Learned — SchachTurnierManager

Kumulativ, neueste zuerst. Jeder Eintrag: Datum, Kontext, Lesson, Konsequenz. Das Projekt
persistiert seine Lessons eigenständig in diesem Repository; externe lokale Wissenspfade sind
keine Voraussetzung.

## 2026-07-18 — Submission-Qualität entsteht durch Fokus und beweisbare Grenzen

- Kontext: OpenAI Build Week finalization, STM-FACH-012, synthetischer Jury-Pfad und
  STM-INFRA-008.
- Lesson: Eine breite Funktionsliste wird nicht automatisch zu einer verständlichen
  Produkterfahrung. Hauptaktionen brauchen eine klare Hierarchie; Expertendetails bleiben
  erreichbar, dürfen aber den Einstieg nicht dominieren. Evidence ist ebenso ein Produktteil:
  ein fehlender Browser-/Gerätetest bleibt offen und wird nicht durch Quellinspektion oder alte
  Screenshots ersetzt.
- Konsequenz: Fünf Primärbereiche, explizites synthetisches Demo-Preset, bestätigte/umkehrbare
  Ergebniswrites und progressive Tie-Break-/Pairing-Optionen. Finale visuelle und Galaxy-Evidence
  bleibt SHA-gebundene Owner-Aufgabe.

## 2026-07-18 — Öffentliche Diagnoseverträge dürfen lokale Pfade nicht voraussetzen

- Kontext: Public-Health-Härtung und vollständiger ReleaseGate.
- Lesson: Ein statischer Test, der ein absolutes Logverzeichnis im Health-JSON erwartet, schützt
  zwar Observability, koppelt sie aber fälschlich an eine öffentliche Pfadoffenlegung. Eine
  Sicherheitskorrektur muss den Testvertrag präzisieren, nicht das lokale Logging entfernen.
- Konsequenz: File-Logging, Begrenzung und Querystring-Redaktion bleiben geprüft; der öffentliche
  Vertrag meldet nur `storage = local` und Negativtests verbieten Datenbank-/Logpfadfelder.

## 2026-07-16 — FIDE-Modi brauchen Versions-, Format- und Policy-Grenzen

- Kontext: STM-FACH-001, sichere Adoption von PR #10 gegen FIDE C.07/03-2026.
- Lesson: Ein „virtueller Gegner mit eigener Punktzahl“ reicht nicht als belastbare
  FIDE-Implementierung. Seit 2026 gehören angepasste Gegnerstände, Obergrenzen und
  VUR-Streicher dazu; zugleich gilt Art. 16 für Schweizer Turniere und darf eine
  vorhandene, ausdrücklich konfigurierte Forfeit-Policy nicht still überschreiben.
- Konsequenz: Eine kanonische Buchholz-Beitragsliste trägt VUR-Metadaten bis zu
  Cut/Median, reale Gegner werden vor Dummys entschieden, offene Runden bleiben
  ausgeschlossen und nicht modellierbare Bye-Kategorien werden offen dokumentiert.

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
