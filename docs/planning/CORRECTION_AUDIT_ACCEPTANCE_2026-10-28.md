# Ergebniskorrektur: aktueller Befund für STM-FACH-007

Die Aufgabe bleibt dem trusted-collaborator zugewiesen. Work hat keine neue
exklusiv zugewiesene Umsetzung übernommen. Die folgende Prüfung verwendet nur
ein isoliertes synthetisches Turnier und dessen eigene SQLite-Datenbank.

Native API-Folge auf dem aktuellen Kandidaten: Runde erzeugen, Brett1 von offen
auf Weißsieg setzen, anschließend mit erwarteten Vorwert Weißsieg auf Schwarzsieg
korrigieren. Der neue Wert bleibt gespeichert; Paketexporte ändern ihn nicht.
Das Journal enthält zwei `ResultRecorded`-Einträge mit Runden-/Brettbezug. Details
sind jeweils `WhiteWin` beziehungsweise `BlackWin`; `reason` ist jeweils null.

Im einzelnen Korrekturereignis fehlen damit ein ausdrücklich gebundenes Alt/Neu-
Paar und ein vom Bediener angegebener Grund. Das ist eine bestätigte Lücke gegenüber
vollständig begründeter auditierter Ergebniskorrektur, keine Behauptung beschädigter
Wertungen. Der vorhandene erwartete Vorwert schützt bereits gegen bestimmte
konkurrierende Änderungen. Die Offline-Queue ergänzt strengere Ziel-/Zeitstempel-
und Epochenbindung, ersetzt aber die Elternanforderung nicht.

Offen beim zuständigen Contributor: Akzeptanz des vollständigen Korrekturwegs,
Alt/Neu-/Grundnachweis, Auswirkungen auf nachfolgende Runden und dynamische
Wertungen, SQLite-/Backup-Roundtrip und unabhängiger Fachreview. Keine Doppelzählung
mit Queue-, Undo- oder allgemeinen Audit-Tests.

## Nachtrag 2026-11-24: Umsetzung im lokalen Kandidaten

Der Befund oben beschreibt den Stand vom 2026-10-28 und gilt für den Kandidaten
`integration/stm-completion-20261124` nicht mehr. Der Owner hat die Aufgabe am 2026-11-24 für den
interaktiven Owner-Lauf neu zugewiesen (siehe Backlog-Zeile).

- Eine Änderung eines bereits eingetragenen Ergebnisses erzeugt genau ein Ereignis `ResultCorrected`
  mit `previous=<alt>; new=<neu>` und optionalem Bedienergrund; der Ersteintrag bleibt `ResultRecorded`.
- Sind Folgerunden bereits gepaart, hat das Ereignis die Stufe Warnung und nennt diese Runden. Die
  Paarungen bleiben unverändert; Tabelle und Feinwertungen werden aus dem neuen Ergebnis berechnet.
- Die Korrektur prüft den erwarteten Vorwert und optional den Änderungszeitstempel des Bretts
  (erkennt auch eine zwischenzeitlich zurückgenommene Änderung).
- Der Freitext-Grund wird nur online an den Turnierrechner gesendet und nie in der Browser-Warteschlange
  gespeichert.

Weiter offen: Browser-End-to-End-Nachweis, SQLite-/Backup-Roundtrip mit Korrekturereignis als eigener
Test, unabhängiger Fachreview.
