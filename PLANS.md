# Aktueller Zusatz 0.12.0

- Externe Profile können auf Dubletten geprüft und als neuer oder bestehender Teilnehmer angewendet werden.
- DSB/DeWIS bleibt nächster Integrationsblock nach Klärung der offiziellen Schnittstelle.

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

## v0.9.1 - Nächster Vorschlag

- Installations-/Update-Erlebnis verbessern.
- Datenbank-Backup/Restore im Portable-Kontext sichtbarer machen.
- Erste Release-Checkliste und manuelle QA-Szenarien.


## Abgeschlossen in 0.9.1

- Turniereinstellungen im Dashboard bearbeitbar.
- Wertungskette konfigurierbar und in der Tabellenberechnung wirksam.
- Punktesystem/TWZ/Forfeit-/Bye-/Kategorie-/Heldenpokal-Regeln im UI.

## Nächster Fokus 0.10.0

- UI-Qualität: Turnierassistent, bessere Validierung, Importvorschau und Exportcenter.


## v0.10.0 - Externe Spielerdaten

- Provider-Modell für FIDE, DSB/DWZ und ThSB-Kontext.
- FIDE-ID-Direktabruf als erster realer Provider.
- DSB/DWZ über offizielle API/Wertungsportal vorbereiten.
- UI-Vorschau und Übernahme ins Teilnehmerformular.
- Tests mit Fixtures statt Live-Netzwerk.


## v0.10.0 umgesetzt

- FIDE-ID-Lookup-Grundlage aktiv.
- DSB/ThSB-Provider vorbereitet.
- Nächster Schritt: robuste DSB/DeWIS-Klärung, FIDE-Namenssuche und Import-Vorschau verbessern.

## Open-Source-Sicherheitsfreigabe vor Veröffentlichung

Status: OFFEN, vor Public Release zwingend erledigen.

Dieses private Entwicklungsrepo darf nicht direkt öffentlich geschaltet werden, solange die bestehende Git-Historie nicht vollständig geprüft oder bereinigt wurde.

Begründung:
- In der privaten Historie gab es interne Registry-/Package-Feed-Referenzen.
- Zwischenstände enthielten zeitweise lokale Audit-/Backup-Dateien.
- Für ein öffentliches Open-Source-Projekt soll niemand über die Git-Historie interne, private oder unpraktische Informationen finden.

Bevorzugter Zielweg:
- Privates Entwicklungsrepo bleibt privat.
- Öffentliches Repository wird später aus einem geprüften Clean Snapshot ohne alte Git-Historie erzeugt.
- Snapshot darf keine .git-Historie, .codex, .vs, output, bin, obj, dist, node_modules, security-audit, .local-backups, Logs, Dumps, ZIPs, Datenbanken, lokale Configs oder interne Registry-/TFS-/ECKD-Begriffe enthalten.

Security-Agent/Skill-Aufgabe:
- Vor Commits/Pushes staged files prüfen.
- Vor Public Release vollständige Repository-/History-/Snapshot-Prüfung durchführen.
- Zwischen lokalem Git, privatem GitHub und beruflichem TFS-Git unterscheiden.
- Bei TFS-/Arbeitsrepos besonders restriktiv agieren.
- Bei privaten GitHub-Open-Source-Repos Clean-Snapshot-Strategie bevorzugen.

## v0.38.6 - CommitGuard und Clean-Snapshot-Folgearbeit

- [x] Open-Source-Sicherheitsgate in `PLANS.md` auffindbar dokumentiert.
- [x] Repository-Security-Regeln in `AGENTS.md` und als Skill ergänzt.
- [x] CommitGuard auf explizites Staging geprüfter Pfade statt blindem `git add --all` umstellen.
- [x] Safety-Checks gegen False Positives aus eigenen Patternquellen härten.
- [x] Grundskript für Clean Snapshot ohne alte Git-Historie ergänzen.
- [ ] Vor echtem Public Release Snapshot auf einem frischen Klon prüfen und Report manuell abnehmen.
