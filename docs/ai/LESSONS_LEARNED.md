# Lessons Learned — SchachTurnierManager

Kumulativ, neueste zuerst. Jeder Eintrag: Datum, Kontext, Lesson, Konsequenz. Das Projekt
persistiert seine Lessons eigenständig in diesem Repository; externe lokale Wissenspfade sind
keine Voraussetzung.

## 2026-07-18 — Dateiinventare brauchen dieselbe Pfadnormalisierung wie der Git-Index

- Kontext: Read-only Repository-Hygiene-Audit vor der Build-Week-Integration.
- Lesson: Git liefert kanonische Pfade mit `/`, während eine Windows-Dateisysteminventur zunächst
  `\` verwendet. Ein Mengenvergleich ohne Normalisierung kann tausende getrackte Dateien
  fälschlich als ungetrackte Quellen klassifizieren, obwohl `git ls-files --others` leer ist.
- Konsequenz: Beide Pfadmengen werden vor der Klassifizierung auf `/` normalisiert; Summen werden
  zusätzlich gegen Git-untracked und Git-ignored abgeglichen. Fehlerhafte Zwischenklassifizierungen
  werden verworfen und nicht als Evidence persistiert.

## 2026-07-18 — Erwartungswerte schützen nur innerhalb einer atomaren Schreibgrenze

- Kontext: Unabhängiger Technik-Review der bestätigten Desktop-/Companion-Ergebniseingabe.
- Lesson: Ein `expectedPreviousResult` verhindert sequenziell veraltete Änderungen, ist allein aber
  kein Compare-and-Swap. Zwei parallele Requests können denselben Snapshot lesen und beide eine
  scheinbar gültige Ganzzustands-Speicherung beginnen.
- Konsequenz: Prüfung, Audit und Speichern laufen für Ergebnisänderungen unter derselben
  Store-Operation; in-memory per Lock und in SQLite per serialisierter Transaktion. Ein
  deterministisch zuvor roter Test und ein echter SQLite-Parallelitätstest verlangen genau einen
  erfolgreichen Schreiber.

## 2026-07-18 — Vollständige SHAs werden von Git aufgelöst, nie von Hand ergänzt

- Kontext: Unabhängiger Competition-Audit der Build-Week-Queue und des UX-Freeze.
- Lesson: Eine plausible manuelle Erweiterung eines kurzen Commit-SHAs kann auf einen nicht
  existierenden Commit zeigen und dennoch in mehreren Dokumenten konsistent aussehen. Formale
  40-Zeichen-Prüfung allein beweist weder Existenz noch geeignete Herkunft als Arbeitsbasis.
- Konsequenz: Dokumentierte SHAs werden mit `git rev-parse` ermittelt. Der Contributor-Generator
  prüft Commit-Existenz und erlaubt startbare Prompts nur exakt vom aktuellen `development`;
  ungemergte Feature-SHAs bleiben Planning-only.

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
