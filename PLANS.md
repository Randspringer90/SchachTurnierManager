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
- [ ] Teilnehmer bearbeiten und zurückziehen im Dashboard.
- [ ] Kreuztabelle anzeigen.
- [ ] Kategorien U10/U12/U14/U16/U18/U25, Frauen, Senioren und Heldenpokal im UI.
- [ ] CSV-Import Teilnehmer.
- [ ] CSV-/JSON-Export und JSON-Backup/Restore.
- [ ] Bessere Fehler-/Auditansicht im Dashboard.

## v0.4 – Regelhärte
- [ ] Swiss-Pairing in Richtung FIDE Dutch ausbauen.
- [ ] Golden-Testdateien mit bekannten Pairing-Fällen.
- [ ] Buchholz-Feinheiten, kampflose Partien, Cut-Wertungen sauber spezifizieren.
- [ ] Import/Export-Adapter für Swiss-/Chess-Results-Ökosystem untersuchen.

## v0.5 – Installation
- [ ] Portable Publish inklusive Frontend-Auslieferung über Backend.
- [ ] Start-BAT/PowerShell ohne Entwicklerwerkzeuge.
- [ ] Datenpfad unter AppData oder Projektdata konfigurierbar.
- [ ] Windows-Installer evaluieren.
