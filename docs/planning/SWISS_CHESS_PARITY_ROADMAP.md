# Swiss-Chess-Parität und Funktions-Roadmap

Stand: v0.19.0

Ziel dieses Dokuments ist eine belastbare Funktionsmatrix für den SchachTurnierManager. Der Anspruch lautet: Alles, was klassische Turnierverwaltungsprogramme wie Swiss-Chess/Swiss-Manager/Vega für Vereins-, Open-, Mannschafts- und Wertungsturniere leisten, soll langfristig entweder vollständig unterstützt oder bewusst als „nicht geplant“ dokumentiert werden.

> Hinweis: Für Swiss-Chess liegt im Projekt aktuell kein vollständiges offizielles Handbuch als Referenzdatei vor. Die Matrix ist daher zunächst eine produktorientierte Paritätsliste aus typischen Funktionen solcher Programme und aus FIDE-/Turnierpraxis. Sobald ein Swiss-Chess-Handbuch, Screenshots oder ein konkreter Funktionskatalog vorliegt, wird die Matrix präzise gegen diese Quelle abgeglichen.

## Statuslegende

- ✅ umgesetzt / nutzbar
- 🟡 teilweise umgesetzt
- 🔴 offen
- ⛔ bewusst nicht geplant oder nur extern sinnvoll

## 1. Turnierarten und Modi

| Funktion | Status | Bemerkung |
|---|---:|---|
| Schweizer System Einzelturnier | 🟡 | Grundfunktion vorhanden; FIDE-Dutch-Nähe und Golden Tests fehlen noch. |
| Rundenturnier / Jeder gegen Jeden | 🟡 | Grundmodus vorhanden; Feinschliff bei doppelrundig, Farben, Drucklisten offen. |
| Doppelrundiges Rundenturnier | 🔴 | Eigener Modus oder Option erforderlich. |
| Mannschaftsturnier Schweizer System | 🔴 | Matchpunkte, Brettpunkte, Brettreihenfolge, Aufstellungen, Ersatzspieler. |
| Mannschaft Rundenturnier / Liga | 🔴 | Mannschaftstabellen, Brettwertungen, Heim/Auswärts. |
| Scheveningen-System | 🔴 | Team/Gruppe A gegen Gruppe B. |
| KO-System | 🔴 | Turnierbaum, Setzliste, Freilose. |
| Doppel-KO / Double Elimination | 🔴 | Loser Bracket, Finale/Reset-Regel. |
| Rutschsystem / Keizer / Sonderformate | 🔴 | Für Vereinsabende und Schnellschachserien relevant. |
| Arena-/Online-ähnliche Wertung | 🔴 | Später möglich; nicht Kern für Offline-Turnierleitung. |
| Armageddon-/Norway-Punktesystem | 🟡 | Punktesystem-Basis vorhanden; vollständiger Ablauf/Bietverfahren offen. |
| Mehrere Gruppen/Altersklassen in einem Turnier | 🟡 | Kategorien vorhanden; getrennte Gruppen/Sections noch offen. |

## 2. Teilnehmerverwaltung

| Funktion | Status | Bemerkung |
|---|---:|---|
| Teilnehmer anlegen/bearbeiten/löschen | ✅ | Vorhanden. |
| Rückzug/Pause nach Paarungen | ✅ | Löschen wird bei vorhandenen Paarungen verhindert/umgewandelt. |
| Startnummern/Startrang | ✅ | Vorhanden. |
| Verein, Verband, Land | ✅ | Vorhanden. |
| Geburtsjahr/Geschlecht/Kategorien | 🟡 | Grunddaten und Kategorien vorhanden; flexible Kategorie-Definitionen offen. |
| Titel, FIDE-ID, nationale ID | ✅ | Vorhanden. |
| DWZ, DWZ-Index, Elo Standard/Rapid/Blitz, manuelle TWZ | ✅ | Vorhanden. |
| Import aus CSV mit Vorschau | ✅ | Inkl. Dubletten/Warnungen/Bestätigung. |
| Excel-Import | 🔴 | Wichtig für Turnierleiter. |
| Spieler aus offizieller Datenbank importieren | 🟡 | FIDE-ID aktiv; DSB/DeWIS/ThSB noch offen. |
| Spieler-Dublettenprüfung | ✅ | FIDE-ID, DSB-ID/National-ID, Name+Geburtsjahr. |
| Teilnehmergebühren/Bezahlung | 🔴 | Optional, aber Swiss-Chess-artige Vollfunktion. |
| Nachmeldungen während Turnier | 🟡 | Teilnehmer können ergänzt werden; Pairing-Folgen/Startpunkt noch nicht sauber modelliert. |

## 3. Auslosung / Pairing

| Funktion | Status | Bemerkung |
|---|---:|---|
| Scoregruppen-Auslosung | 🟡 | Optimales Minimum-Penalty-Matching (V2, ≤ 20 Spieler); Punktdifferenz dominiert die Strafgewichte. |
| Rematch-Vermeidung | ✅ | Seit v0.41.0 global optimal: Rematch nur, wenn keine rematchfreie Gesamtauslosung existiert (`docs/SWISS_PAIRING_ENGINE.md`). |
| Farbpräferenzen/Farbbalance | 🟡 | Vorhanden inkl. dritter gleicher Farbe als Penalty. |
| Floater-Erkennung | 🟡 | Audit vorhanden; FIDE-Dutch-Floater-Regeln offen. |
| Bye-Vergabe | 🟡 | Grundregel vorhanden; feinere Buchungs-/Punktregeln offen. |
| Manuelle Paarungskorrektur | ✅ | Vorhanden mit Audit. |
| Sperren/Prüfen von Runden | ✅ | Vorhanden. |
| Pairing-Audit | 🟡 | Vorhanden; Qualitätsbericht in v0.18.1 sichtbar. |
| Pairing-Qualitätswert 0–100 | ✅ | v0.17/v0.18.1. |
| FIDE-Dutch-konforme Auslosung | 🔴 | Größter offener Kernblock. |
| Alternative Schweizer Systeme (Dubov/Burstein/Lim/Monrad) | 🔴 | Später als Pairing-Engine-Strategien. |
| Beschleunigtes Schweizer System | 🔴 | Wichtig für große Opens. |
| Pairing nach Ratinggruppen / Sections | 🔴 | Relevanz für Jugend/Ratingpreise. |
| Sitzplan/Brettnummern/Raumplanung | 🔴 | Druck-/Aushangfunktion nötig. |

## 4. Ergebnisse und Sonderfälle

| Funktion | Status | Bemerkung |
|---|---:|---|
| 1-0, ½-½, 0-1 | ✅ | Vorhanden. |
| Kampflos +/-, -/+, -/- | ✅ | Vorhanden. |
| Bye | ✅ | Vorhanden. |
| Armageddon-Ergebnisse | 🟡 | Ergebnisarten vorhanden; vollständige Matchlogik offen. |
| Ergebnisprüfung pro Runde | ✅ | RoundDiagnostics vorhanden. |
| Nachträgliche Korrektur mit Audit | 🟡 | Manuell möglich; vollständige Historie/Undo offen. |
| Partie-Notizen | 🟡 | Grundnotizen vorhanden; PGN/Partiedaten offen. |
| PGN-Erfassung/Import | 🔴 | Relevant für starke Turniere und Veröffentlichung. |

## 5. Tabellen, Wertungen, Preise

| Funktion | Status | Bemerkung |
|---|---:|---|
| Tabelle nach Punkten und Wertungskette | ✅ | Vorhanden. |
| Direkter Vergleich | ✅ | In Wertungskette vorhanden. |
| Anzahl Siege | ✅ | Vorhanden. |
| Buchholz | ✅ | Vorhanden. |
| Buchholz Cut-1 | ✅ | Vorhanden. |
| Sonneborn-Berger | ✅ | Vorhanden. |
| Gegnerschnitt | ✅ | Vorhanden. |
| Turnierleistung | ✅ | Vorhanden. |
| Buchholz Cut-2 / Median-Buchholz | 🔴 | Noch offen. |
| Progressive/Cumulative Score | 🔴 | Noch offen. |
| Koya | 🔴 | Noch offen. |
| Schwarzsiege / Anzahl Schwarzpartien | 🔴 | Noch offen. |
| Rating-Performance nach FIDE-Logik | 🟡 | TPR vorhanden, exakte FIDE-Normenlogik offen. |
| Preisgruppen/Ratingpreise/Jugendpreise/Seniorenpreise | 🟡 | Kategorien vorhanden, Preislogik offen. |
| Geteilte Preise / Hort-System | 🔴 | Wichtig für Opens. |

## 6. Druck, Export, Veröffentlichung

| Funktion | Status | Bemerkung |
|---|---:|---|
| Tabellen-CSV | ✅ | Vorhanden. |
| Paarungen-CSV | ✅ | Vorhanden. |
| Teilnehmer-CSV | ✅ | Import/Export vorhanden. |
| Turnier-Druckansicht HTML | ✅ | Vorhanden. |
| Runden-Druckansicht HTML | ✅ | Vorhanden. |
| JSON-Backup | ✅ | Vorhanden. |
| PDF-Export | 🔴 | Sehr sinnvoll für Aushänge/Archiv. |
| Excel-Export | 🔴 | Wichtig für Vereine. |
| TRF/FIDE-Report | 🔴 | Wichtig für FIDE-Auswertung. |
| DWZ-/DSB-Auswertungsdateien | 🔴 | Wichtig für Deutschland. |
| Swiss-Chess-/Swiss-Manager-kompatibler Import/Export | 🔴 | Ziel für Migration/Koexistenz. |
| Chess-Results-Workflow | 🔴 | Wahrscheinlich Export/Upload-Unterstützung, keine fragile Direktintegration ohne Klärung. |
| HTML-Live-Seite/Zuschaueransicht | 🔴 | Für Vereinswebseite und Saalbildschirm. |

## 7. Rating- und Verbandsanbindung

| Funktion | Status | Bemerkung |
|---|---:|---|
| FIDE-ID-Lookup | ✅ | Aktiv. |
| FIDE-Namenssuche | 🔴 | Offen. |
| DSB/DeWIS | 🔴 | Schnittstelle klären. |
| ThSB/Regionalfilter | 🔴 | Voraussichtlich auf DSB-Datenbasis. |
| DWZ-Prognose | 🔴 | Komplex, aber für deutsche Vereine sehr relevant. |
| Elo-Prognose | 🔴 | Später. |
| Normen/Performance-Bericht | 🔴 | Später. |
| Daten-Cache/Offline-Modus für Spielerdaten | 🔴 | Wichtig für Turniersaal ohne Internet. |

## 8. Bedienung, Sicherheit, Betrieb

| Funktion | Status | Bemerkung |
|---|---:|---|
| Lokale Portable-App | ✅ | Vorhanden. |
| SQLite-Persistenz | ✅ | Vorhanden. |
| Backup/Restore | ✅ | JSON-Backup vorhanden. |
| Undo/Historie | 🔴 | Sehr wichtig für Turnierleiter. |
| Rollen/Rechte | 🔴 | Arbiter, Ergebnis-Erfasser, Zuschauer. |
| LAN-/Mehrbenutzerbetrieb | 🔴 | Später. |
| Tablet-/Mobile-Optimierung | 🔴 | Später. |
| Installer/Updater | 🔴 | Später. |
| GitHub Releases/Checksummen | 🔴 | Später. |
| In-App-Problembericht | 🔴 | Issue-Templates vorhanden, Button offen. |
| Datenschutz/Diagnosepaket ohne Teilnehmerdaten | 🔴 | Für Support wichtig. |

## Priorisierte nächste Blöcke

### Block A: Schweizer System voll belastbar machen

1. FIDE-Dutch-Regelwerk analysieren und Testfälle definieren.
2. Pairing-Engine als Strategie-System umbauen.
3. Golden Tests für komplette Turnierverläufe.
4. Vergleichstest: gleiche Teilnehmer/Ergebnisse → erwartete Paarungen.
5. Qualitätsbericht automatisch im Audit speichern.

### Block B: Swiss-Chess-Parität Import/Export

1. Export-/Importformate sammeln.
2. Swiss-Chess/Swiss-Manager/Chess-Results/TRF/DWZ-Dateien analysieren.
3. Erst Roundtrip-Tests mit Beispielturnieren.
4. Danach UI-Importassistent.

### Block C: Mannschaftsturniere

1. Mannschaft, Bretter, Spielerlisten modellieren.
2. Matchpunkte/Brettpunkte/Wertungen.
3. Mannschafts-Schweizer-System.
4. Rundenlisten und Ergebnisbögen.

### Block D: Veröffentlichung und Turnierbetrieb

1. Aushänge PDF/HTML verbessern.
2. Zuschaueransicht/LAN.
3. Ergebnis-Erfassung durch zweite Geräte.
4. Backup-/Restore-/Undo-Konzept.

## Praktischer Maßstab

Für lokale Vereins- und Schnellschachturniere ist der aktuelle Stand bereits als lokaler Prototyp nutzbar. Für offizielle, große, DWZ-/FIDE-auswertbare Open fehlt aber noch vor allem: FIDE-Dutch, DWZ/FIDE-Export, robuste Drucklisten, Undo/Historie und Swiss-Chess-kompatible Import-/Exportwege.
