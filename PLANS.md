# Aktueller Zusatz 0.42.0

- P0-Importlauf: `scripts\Import-TournamentPreset.ps1` validiert lokale Preset-JSONs robuster,
  erzeugt einen strukturierten JSON-Report unter `output\reports\`, nutzt beim echten Import
  die API-CSV-Vorschau als Gate und verlangt `-AllowWarnings`, wenn Warnungen bewusst akzeptiert
  werden sollen. Dry-run bleibt ohne API-Aenderung.
- API-Backup/Restore-Haertung: `POST /api/tournaments/import` lehnt korrupte Turnier-Snapshots
  mit doppelten Spieler-IDs/FIDE-/DSB-IDs, ungueltigen Runden/Brettern oder Paarungen gegen
  unbekannte Spieler ab.
- Zusammenarbeit und KI-Hilfe sind vorbereitet, aber bewusst noch nicht produktiv verdrahtet:
  siehe `docs/COLLABORATION.md`, `docs/AI_HELP_ASSISTANT.md` und `.env.example`.
- Public-Sonderfall bleibt: lokale Commits erlaubt, aber kein Push/Release/PR ohne ausdrueckliche
  Freigabe.

# Feature-Plan Turnierbetrieb ab 0.42.x

## P0 - Turniertagsnutzen
- [x] Bergfest-Import per lokaler Preset-JSON robuster machen.
- [x] JSON/CSV-Import vor Import validieren und reporten.
- [x] API-Backup/Restore gegen offensichtliche defekte Snapshots absichern.
- [x] Operator-Smoke fuer Runde starten, Paarungen, Ergebnis erfassen, Korrektur, Tabelle,
  Backup/Restore und Chess960/QR synthetisch abdecken.
- [ ] Operator-Dashboard weiter verdichten: naechste Aktion, offene Bretter, letzter Export,
  letzter Backup-/Audit-Stand noch klarer sichtbar.
- [ ] Print/Export fuer Paarungen, Tabellen, Ergebnisse als Turnierpaket sichtbarer buendeln.
- [ ] Offline-/Fallback-Betrieb dokumentiert gegen echte Vor-Ort-Ausstattung testen.

## P1 - Freestyle, Forensik, Qualitaet
- [x] Chess960/Freestyle-Wuerfelschach Wuerfel-/Startposition-Modul pro Brett mit QR-Grundlage.
- [x] Audit-Journal und Pairing-Forensics mit Export-Bundle.
- [ ] QR-Code-Flow mit realem Handy im Veranstaltungs-WLAN/Hotspot testen.
- [ ] Tie-Breaks inkl. kampflos/unplayed rounds fertig in `StandingsCalculator` verdrahten.
- [ ] Swiss-Pairing-Qualitaet Richtung FIDE-Dutch verbessern: Floater, Brackets, grosse Felder.
- [ ] Local-Roster-/Spielersuche fuer schnelle Anmeldung ausbauen.

## P2 - Zusammenarbeit, Anzeige, KI-Hilfe
- [ ] Mehr-Operator-Modus fuer parallele Bedienung konzipieren, ohne lokale Daten zu riskieren.
- [ ] Kommentar-/Notizsystem fuer Runden, Bretter, Spieler und organisatorische Aufgaben.
- [ ] Integrierte KI-Hilfe/Chatbot nur mit BYO-Key/local-secret, Provider-Abstraktion und
  ausgeschaltetem Default; keine Cloud-Aufrufe in Tests.
- [ ] Wissensmanagement-Anbindung an lokale docs/runbooks, keine privaten Rohdaten in Prompts.
- [ ] Export fuer Vereinsseite/WhatsApp/CSV/JSON/HTML/PDF priorisieren.
- [ ] Oeffentliche Anzeige/Beamer-Modus mit reduzierter Operator-Oberflaeche.

# Aktueller Zusatz 0.41.1

- Operator-Smoke `scripts/Smoke-OperatorWorkflow.ps1`: ein hängesicherer End-to-End-Lauf gegen
  ein isoliertes, frisch gebautes Backend (Health, Swiss 12/5, RR-Late-Entry-Sperre, manuelle
  Paarung, Backup/Restore, Chess960/QR-Daten) mit Timeouts, Heartbeat, klarem Exit-Code und
  zuverlässigem Teardown. Runbook/Checklist/Operator-Card und QR-Vorabtest dokumentiert.
- Offen (unverändert): kein vollständiges FIDE-Dutch, Felder > 20 Spieler Greedy-Fallback,
  QR-Anzeige am realen Handy bleibt manueller Vorabtest.

# Aktueller Zusatz 0.41.1

- Operator-/Release-Candidate-Haertung ohne neue Pairing-Architektur:
  `scripts\Smoke-OperatorWorkflow.ps1` prueft synthetisch Health, Swiss 12/5,
  Rundenlimit, Audit-Export, Round-Robin, Manual-Pairing-Guards, Backup/Restore und
  Chess960/QR-URL-Form.
- Runbook/Checklisten geschärft fuer Turniertag: QR-Vorabtest, Audit nach jeder Runde,
  Backup/Restore, MaxRounds, Late Entry je Format, Swiss-Grenzen und Notfallablauf.
- Offen vor echtem Release: realer Handytest im Veranstaltungs-WLAN/Hotspot, keine Tags/Releases
  ohne ausdrueckliche Freigabe.

# Aktueller Zusatz 0.41.0

- Schweizer-System V2: global optimale Minimum-Penalty-Paarung (≤ 20 Spieler) ersetzt die
  Greedy-Gegnerauswahl. Vermeidbare Rematches sind eliminiert (Invariantentest über mehrere
  Feldgrößen/Seeds). Bye/Farben/Forensik unverändert. Details `docs/SWISS_PAIRING_ENGINE.md`.
- Offen (Swiss v2/FIDE-Dutch): Bracket-/Floater-/Erstrunden-Setzungsregeln, austauschbare
  Pairing-Strategien, polynomiales Matching für große Opens.

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
