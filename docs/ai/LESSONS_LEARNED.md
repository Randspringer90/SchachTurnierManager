# Lessons Learned — SchachTurnierManager

Kumulativ, neueste zuerst. Jeder Eintrag: Datum, Kontext, Lesson, Konsequenz. Das Projekt
persistiert seine Lessons eigenständig in diesem Repository; externe lokale Wissenspfade sind
keine Voraussetzung.

## 2026-10-07 — Statische PR-Evidenz muss vollstaendig und effizient bleiben

- Kontext: GitHub lieferte fuer eine grosse App-Verschiebung keine kompletten
  Textpatches; eine generische Regex erreichte das unveraenderte Zeitlimit.
- Lesson: Ein fehlender API-Patch ist keine fehlende Datei. Vollstaendige
  Blob-/Tree-/Hunk-Bindung kann die Evidenz ergaenzen, ohne Kandidaten auszufuehren.
  Eine pauschal kompilierte Regex kann andere Regeln verlangsamen; jede Optimierung
  braucht ihren eigenen semantischen Beweis und unveraenderte Fehlergrenzen.
- Konsequenz: Exakter Textfallback mit negativen Tests und begrenzten Prozessen;
  gezielte Engine-Optimierung, frische vertrauenswuerdige Typebindung pro Reload.
  Generierte Patches vor Anwendung komplett parsen: JavaScript-Ersetzungen mit
  Regex-Ankern benoetigen Literal-Callbacks, damit Ersetzungsmetazeichen nicht
  die Vorlage veraendern. Ein eigener Kandidat darf keine neue Runtime aktivieren.

## 2026-10-04 — Modellpflege braucht eine einzige Variantenquelle

- Kontext: Versionsvorgaben in Runtime-Policy und historischen Lauftexten drifteten auseinander.
- Lesson: Stabile Aufgabenprofile und konkrete Anbieter-IDs getrennt halten. Profilnamen
  sind keine Modellfamilien; ein effizientes Modell darf grosse Implementierung nicht herabstufen.
- Konsequenz: Ein zentraler, offiziell verifizierter Katalog; Schema-/Provider-Grenzen,
  versionsneutrale Dokumentation und ein Vertragstest fuer Updates an genau einer Stelle.
  Relative PowerShell-Pfade ueber die PowerShell-Path-API statt Prozess-CWD aufloesen.

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

## 2026-07-15 - KFM-FLEET-CORRECTION-CODEX-SOL-FINALIZE-20260715

- Ein grüner Arbeitsbaumscan ersetzt keine offene Public-History-Entscheidung.

## 2026-07-10 — Public-nahe Testdaten und KI-Laufprotokolle

- Kontext: Stabilisierung, Public-Gate und Runtime-Logging.
- Lesson: Auch alte Offline-Fixtures, Handoff-Texte und KI-Promptlogs koennen personenbezogene oder lokale Details in den aktuellen Arbeitsstand tragen.
- Konsequenz: Public-nahe Repos verwenden synthetische Fixtures; echte Live-IDs werden nur bewusst per Parameter oder Environment gesetzt. KI-Laufprotokolle werden vor dem Commit bereinigt.
