# PLANS.md

## v0.1 – Projektbasis
- [x] Solution-Struktur mit Domain/Application/Infrastructure/WebApi/WebApp.
- [x] Testprojekte für Domain/Application/Golden Tests.
- [x] Round-Robin-Pairing.
- [x] Basis-Schweizer-System.
- [x] Standings mit Kernwertungen.
- [x] Armageddon-Bidding-Grundlage.
- [x] Lokale Start-/Buildskripte.

## v0.2 – Bedienbares persistentes MVP
- [x] Teilnehmer im Dashboard anlegen.
- [x] Turnier im Dashboard anlegen.
- [x] Runde auslosen und Ergebnisse erfassen.
- [x] Tabelle anzeigen.
- [x] SQLite-Persistenz für Turnier-Snapshots.
- [x] Frontend-Build-Fix für TypeScript/Vite.
- [x] Persistenztest.

## v0.3 – Turnierleiter-Funktionen
- [x] Teilnehmer bearbeiten und zurückziehen im Dashboard.
- [x] Kreuztabelle anzeigen.
- [x] Kategorien U10/U12/U14/U16/U18/U25, Frauen, Senioren und Heldenpokal im UI.
- [x] CSV-Import Teilnehmer.
- [x] CSV-/JSON-Export und JSON-Backup/Restore.
- [x] Bessere Fehler-/Auditansicht im Dashboard.

## v0.4 – Regelhärte
- [x] Swiss-Pairing in Richtung FIDE Dutch vorbereitend ausbauen: Scoregroups, Floater-Audit, Bye-Schutz, Farbhistorie.
- [x] Golden-/Unit-Tests mit Pairing-Fällen für Bye, Rematch und Farben.
- [ ] Buchholz-Feinheiten, kampflose Partien, Cut-Wertungen sauber spezifizieren.
- [x] Druck-/CSV-Export für Tabelle und Paarungen als lokale Adaptergrundlage.
- [ ] Import/Export-Adapter für Swiss-/Chess-Results-Ökosystem untersuchen.

## v0.5 – Installation
- [ ] Portable Publish inklusive Frontend-Auslieferung über Backend.
- [ ] Start-BAT/PowerShell ohne Entwicklerwerkzeuge.
- [ ] Datenpfad unter AppData oder Projektdata konfigurierbar.
- [ ] Windows-Installer evaluieren.


## Nächster Fokus ab 0.4.0

- Schweizer-System weiter Richtung FIDE Dutch entwickeln: Bracket-/Scoregroup-Transpositionslogik, absolute Kriterien, detaillierte Floater-Verwaltung.
- Buchholz-/kampflos-/Cut-Wertungsdetails präzisieren und testen.
- Swiss-Chess/Swiss-Manager/Chess-Results-Adapter als Import-/Export-Schicht vorbereiten.
- Portable Paket und spätere Windows-Installation ausbauen.


## Abgeschlossen in 0.6.0

- v0.5-Testkompilierung stabilisiert.
- Checkpoint-Skript stoppt jetzt bei fehlgeschlagenen Checks.

## Abgeschlossen in 0.5.0

- Manuelle Paarungsänderungen mit Audit.
- Runden sperren/entsperren und als geprüft markieren.
- Ergebnisänderungen in geschlossenen Runden blockieren.
- Checkpoint-Commit-Skript.

## Nächster Fokus 0.6.0

- Kampflos-/Bye-Wertungen fachlich schärfen.
- Buchholz/SB/Cut-Wertungen für kampflose Ergebnisse präzisieren.
- Erweiterte Ergebnisvalidierung und Rundenabschluss-Workflow.


## Abgeschlossen in 0.7.1

- Tabellen-CSV und Paarungs-CSV ergänzt.
- HTML-Druckansicht für Turnierbericht und einzelne Rundenblätter ergänzt.
- Dashboard-Druck-/Exportbereich erweitert.

## Nächster Fokus 0.8.0

- Portable Publish inklusive statischem Frontend über Backend.
- Startskript für Nicht-Entwickler.
- Optionaler Datenpfad/Backup-Ordner im UI.


## v0.8.0 - Portable App / Auslieferung

- Backend liefert gebaute WebApp aus `wwwroot` aus.
- Portable Paket unter `output\portable` mit Start-BAT, app-Ordner, data-Ordner und README.
- Optional später: Self-contained Paket und echter Windows-Installer.

## v0.9.0 - Nächster Vorschlag

- Installations-/Update-Erlebnis verbessern.
- Datenbank-Backup/Restore im Portable-Kontext sichtbarer machen.
- Erste Release-Checkliste und manuelle QA-Szenarien.
