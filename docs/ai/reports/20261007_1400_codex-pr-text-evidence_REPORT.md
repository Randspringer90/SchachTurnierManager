# STM-SEC-005: statische Text-Evidenz und begrenzte Musterpruefung

Der grosse Integrationsstand bleibt separat als PR #114 erhalten. Dieser kleine
vorgeschaltete Fix ist vom aktuellen development entstanden und kann den eigenen
Online-Scan nicht durch eine Kandidaten-Runtime freigeben.

## Aenderungen

- Vollstaendige GitHub-Dateipagination, aktueller Base/Head, Vergleichsbasis,
  Commit-/Tree-/Blob-IDs, Modi, UTF-8 und komplette Hunkstatistik werden gebunden.
- Fehlende Textpatches werden aus unveraenderten Blobbytes rekonstruiert.
  Diffprozesse haben feste inerte Pfade, begrenzte zwei Pipes und Deadline;
  Git-Konfiguration, externe Diff-/Textconv-Helfer und CRLF-Normalisierung
  beeinflussen den Nachweis nicht.
- Provenienz bleibt auf numerische Werte, Methodenkennung und Hashes begrenzt.
  Kein PR-Inhalt erhaelt Instruktionstrust oder Ausfuehrungsrechte.
- Die Prompt-Regel nutzt eine semantisch gleiche kompilierte Regex. Die exakt
  gebundene ASCII-Run-Regel prueft linear; geaenderte Literale verwenden die
  urspruengliche Regex. Laufzeitgrenze und Schweregrade bleiben unveraendert.
- Gecachte Prueftypen werden bei vertrauenswuerdigem Reload neu erstellt und
  gebunden. Event-SHAs werden vor dem ersten nativen Git-Aufruf validiert.
- Ein explizites `Commit-If-Green -SkipPack` vermeidet Produktpakete beim
  vollstaendigen Quell-Gate. Tests und Sicherheitspruefungen bleiben erhalten.

## Belegte gezielte Pruefung

106 Text-Evidenz-Assertions, darunter komplette zwei Pipes, Ausgabeueberlauf,
Deadline samt beendetem eigenen Kindprozess, falsche Hashes, unvollstaendige
Inventur, unsichere Pfade, Modi und erhaltene CRLF-Zeilenenden. 285 Engine-
Assertions decken Boolean-Aequivalenz, Unicode, Literalwechsel, fremden Typecache,
vollen Eingabebudget-Rand und erhaltene Critical-Timeout-Befunde ab. Der
bisherige Readiness-Gate mit 44 synthetischen Risikofaellen bestand ebenfalls.
Die beiden neuen Regressionen sind in dessen normalen Lauf eingebunden.

Der unabhaengige Abschlussreview fand anschliessend einen Fehler im
Standardaufruf: dessen temporaerer Reportordner lag ausserhalb der erlaubten
projektlokalen Prozess-Scratch-Grenze. Die fokussierten Prozessfixtures
erhalten jetzt einen eigenen, geprueften output-Pfad unabhaengig vom
Reportziel. Nur das leere eigene Scratch-Verzeichnis wird entfernt.
Die Beschreibung unterscheidet PR-Daten von eigenen Prozess-Stressfixtures.
Der bisherige READY-Zustand gilt fuer diesen geaenderten Diff nicht weiter;
Standardaufruf und finaler unabhaengiger Review werden erneut ausgefuehrt.

Der separate finale Code-Review und die vollstaendigen Quell-/Sicherheits-Gates
werden vor dem Commit auf dem tatsaechlichen Diff ausgefuehrt. Die SHA-gebundenen
abschliessenden Ergebnisse stehen in der redigierten Owner-Abschluss-ZIP.

## Offene verbindliche Gates

Die sechs globalen Critical-Klassen in PR #114 bleiben unter der aktuellen
Policy blockierend, obwohl alle 13 konkreten Treffer semantisch auf legitime
Tests/Datenverarbeitung/Dokumentation beziehungsweise eine entfernte Zeile
zurueckgefuehrt wurden. Keine Ausnahme, Attestation oder menschliche Freigabe
wurde erfunden. Der vorgeschaltete Fix braucht einen echten Owner-/CODEOWNER-
Review und den regulaeren Merge nach development; erst danach kann der Carrier
gegen die neue Base erneut geprueft werden. Main-Nachweis und Altcheckout-Cleanup
bleiben offen. Keine Produkt-/Release-/Deployment- oder Kostenaktion.
