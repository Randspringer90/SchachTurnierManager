## 0.40.4 - Audit-Journal-Forensik: Pairing-Diagnostik, Datei-Spiegel und Export-Bundle

Folgearbeit zum Bergfest-Postmortem: Die dort benannte Forensik-Lücke („Audit-Journal existiert
in der DB, wurde aber nicht exportiert/gesichert") ist geschlossen. **Keine Änderung an
Auslosungs- oder Wertungslogik** – ausschließlich Diagnose, Persistenz und Export. Details in
`docs/AUDIT_JOURNAL.md`. Alle Tests mit synthetischen Spielern; keine echten Daten/Exporte committet.

- **Pairing-Forensik je Runde (`PairingForensics`):** Bei Vorschau und Auslosung wird ein
  unveränderlicher Entscheidungs-Snapshot aus dem Stand **vor** der Runde festgehalten – Format,
  geplante/aktuelle Runde, aktive/inaktive Spielerzahl, offene Vorrundenergebnisse, Bretter/Byes/
  manuelle Paarungen, Rematches, Scoregruppen-Abweichungen, Farbfolgerisiken, Qualitätswert sowie
  die vorgeschlagenen Paarungen je Brett (Punkte vor der Runde, Differenz, Flags). Reine Diagnose
  über den bestehenden `PairingQualityAnalyzer`.
- **Mehr auditierte Ereignisse:** Runde-Vorschau erzeugt, Turnier gelöscht, **blockierte
  Auslosungen** (Rundenlimit, Round-Robin-Roster-Sperre, offene Vorrunde, zu wenige Spieler) und
  Audit-Export werden jetzt protokolliert. So taucht z. B. der Rundenlimit-Blocker beim Versuch
  einer zu vielen Runde nachvollziehbar im Journal auf.
- **Append-only Datei-Spiegel (`FileAuditJournalSink`):** Jedes Audit-Ereignis wird zusätzlich zur
  DB in eine JSONL-Datei pro Turnier unter `%LocalAppData%\SchachTurnierManager\audit\` geschrieben
  (außerhalb des Repos). Der Spiegel überlebt DB-Verlust und `Reset`. **Fehlertolerant:** Ein
  Schreibfehler bricht den Turnierschritt nie ab, sondern erzeugt einen sichtbaren
  `AuditJournalMirrorFailed`-Warneintrag.
- **Forensisches Export-Bundle:** Neue Endpunkte
  `GET /api/tournaments/{id}/audit-journal/export.jsonl` und `…/export.json` liefern ein in sich
  geschlossenes Bundle (Manifest, vollständiger Turnier-Snapshot, Pairing-Forensik je Runde, alle
  Audit-Ereignisse). Dateiname `Turniername_round{n}_{Zeitstempel}_audit.jsonl/json`. WebApp:
  Buttons „Audit-Bundle (JSONL)/(JSON)" in der Audit-Karte. Skript:
  `scripts\Export-TournamentAudit.ps1` (speichert lokal nach `output\audit\`, kein Upload).
- **Tests (+12 → 170 gesamt):** Audit deckt create/add-player/preview/next-round/result/
  manual-pairing/chess960/reset/delete ab; Schreibfehler im Spiegel wirft nicht und liefert eine
  Warnung; Rundenlimit-Blocker und Round-Robin-Late-Entry-Blocker sind auditierbar; Late-Entry-
  Swiss ist auditierbar; Export-Bundle (JSONL/JSON) ist self-contained. Plus
  `FileAuditJournalSink`-Tests (append-only, Verzeichnis-Anlage). HTTP-Smoke (Port 5099, isoliertes
  Datenverzeichnis): Export 200 mit korrektem Dateinamen, Rundenlimit-Blocker im Bundle, Datei-Spiegel
  geschrieben.
- **Version:** `0.40.3` → `0.40.4` (Health, `package.json`).

## 0.40.3 - Bergfest-Postmortem: Stabilisierung Rundenlimit, Late Entry, Round-Robin, DB-Start

Nach dem realen Bergfest-Turnier (Freitag, 2026-06-19): harte Ursachenanalyse und gezielte
Stabilisierung statt neuer Features. Details in `docs/POSTMORTEM_BERGFEST_2026.md`.

- **Jeder-gegen-jeden / Round-Robin – Late Entry & Rückzug nicht mehr stillschweigend
  rückwirkend:** `TournamentService.GetNextRoundRobinRound` berechnete bei jeder Auslosung den
  kompletten Spielplan aus den aktuell aktiven Spielern neu. Kam ein Spieler nach Runde 1 dazu
  (oder zog sich zurück), verschob das die Circle-Methode und machte bereits gespielte Runden
  inkonsistent (falsche Farben, Rematches, falsche Byes, abweichende Rundenzahl). Jetzt **harte
  Sperre mit klarer Meldung**: Der Teilnehmerkreis ist ab Runde 1 fixiert; nachträgliche
  Änderungen erfordern bewusste Neuplanung (Zurücksetzen/Neuanlage). Bestätigt per Domain-/
  Application-Test und HTTP-Smoke (HTTP 400 mit Hinweis „Spielplan ab Runde 1 fixiert").
- **SQLite-Start robust + verständliche Diagnose:** Der Backend-Start (`Program.cs`) prüft das
  Datenverzeichnis jetzt vorab auf Existenz/Schreibrechte (`DatabaseStartupDiagnostics.Probe`)
  und fängt Fehler bei `EnsureCreated()` ab. Statt eines kryptischen Stacktraces
  („SQLite Error 10: 'disk I/O error'" beim WAL-Pragma, real am Turniertag aufgetreten) gibt es
  eine mehrzeilige, handlungsorientierte Klartextmeldung (Pfad, Schreibbarkeit, Ursachen wie
  OneDrive/Antivirus/zweite Instanz/Reststände) und einen sauberen Exit-Code (2), den das
  Startskript erkennen kann. Keine riskante Schema-/Journal-Migration.
- **Rundenlimit zusätzlich abgesichert:** Die bestehende harte Sperre `EnsureCanCreateNextRound`
  (keine Runde über `PlannedRounds` hinaus – greift bei `next-round`, Preview, Round-Robin und
  Swiss gleichermaßen) ist nun durch explizite Szenario-Tests (Swiss 12 Spieler / 5 Runden und
  6 Runden) und einen HTTP-Smoke (HTTP 400 „maximale Rundenzahl") fest verankert.
- **Neue Tests (Application/Infrastructure):** Postmortem-Szenarien mit synthetischen Spielern –
  Rundenlimit (Swiss 5/6 Runden), Late Entry nach Runde 2/4 mit 0 Punkten und unveränderten
  Altrunden, Rückzug, Reaktivierung, doppelte FIDE-ID, manuelle Paarung (Persistenz + als
  gespielt gewertet + Schutz gegen Doppelpaarung/inaktive Spieler), Round-Robin 4/5/6/12/13
  Spieler (jede Paarung genau einmal, Byes korrekt, Rundenlimit), Round-Robin Late Entry/Rückzug
  blockiert. Plus DB-Startdiagnose-Tests (schreibbar, readonly, Hinweistexte).
- Keine Änderung an Schweizer-Paarungs-, Wertungs-, Such-/Dedupe- oder Chess960-Logik. Versionen
  auf `0.40.3`.

## 0.40.2 - Chess960-Würfeln pro Brett (Modal mit Reitern, lokaler QR-Code)

- Neuer **„🎲 Würfeln"-Button pro Brett** in der Rundentabelle (Chess960-Spalte). Öffnet ein
  Popup für genau dieses Turnier/Runde/Brett mit Turniername, Runde, Brettnummer, Paarung,
  aktuell gespeicherter Stellung und Überschreib-Warnung. Der bestehende Button für alle
  Bretter einer Runde bleibt unverändert.
- **Interne Reiter im Popup:** „Browser würfeln" (Default) und „QR / Handy" – ohne neuen
  Browser-Tab für die Hauptnavigation, auch bei schmaler Breite bedienbar.
- **Schritt-für-Schritt-Würfel:** Der 3D-Würfel arbeitet die acht Felder der Grundreihe von
  links nach rechts ab und zeigt die Figuren (König, Dame, Turm, Läufer, Springer). Danach
  „Für Brett speichern", „Nochmal würfeln" oder „Abbrechen". Die Animation ist Visualisierung;
  gespeichert wird die vorab gewürfelte Positionsnummer, die der Domain-Service
  `Chess960PositionService` erneut als gültige Stellung ableitet (Läufer verschiedenfarbig,
  König zwischen den Türmen). Vorhandene Stellungen werden nur nach Rückfrage überschrieben.
- **QR / Handy lokal:** QR-Code (eingebetteter, abhängigkeitsfreier Generator – kein Cloud-
  Dienst, kein Tunnel, kein externer Upload) plus kopierbare LAN-URL und Feld für die
  Laptop-IP. Eigene mobile Würfelseite über `/?dice=<id>&round=<r>&board=<b>`, die nur dieses
  Brett anzeigt und denselben Backend-Endpunkt nutzt. Schlägt die QR-Erzeugung fehl, bleiben
  URL-/Kopier-Funktion und die Browser-Würfelfunktion uneingeschränkt nutzbar.
- **Backend:** Neuer Single-Board-Endpunkt
  `POST /api/tournaments/{id}/rounds/{round}/chess960/start-positions/{board}`
  (optional `overwriteExisting`, `seed`, `positionNumber`). Nutzt weiterhin den bestehenden
  `Chess960PositionService`; ändert nur das gewählte Brett, lässt andere Bretter und Ergebnisse
  unberührt. Neue Tests für gültige Stellung, Isolierung anderer Bretter, Persistenz und
  Überschreib-Schutz.
- **LAN/Start:** `vite --host 0.0.0.0` (localhost bleibt erreichbar) für Handy-Zugriff im
  gleichen WLAN/Hotspot; `Start-Dev.ps1` zeigt nur lesend die möglichen Laptop-IPv4-Adressen
  und Firewall-/`localhost`-Hinweise an. Keine Firewall-/Systemänderung, kein Prozess-Kill.
- Keine Änderung an Auslosungs-, Wertungs-, Such-, Dedupe- oder Ergebnislogik. Versionen auf
  `0.40.2`.

## 0.40.1 - Turniertag-Startfix (Ein-Klick-BAT, Operator-Leiste nicht mehr fixiert)

- Neue klickbare Startdatei `RUN_TURNIERMANAGER.bat` im Repo-Root: startet Backend,
  Frontend und Browser. Nutzt `pwsh`, sonst `powershell`, jeweils mit `-ExecutionPolicy
  Bypass` nur prozesslokal (keine Änderung der globalen ExecutionPolicy, keine Adminrechte).
  Behebt das Problem, dass `Start-Dev.ps1` wegen fehlender Signatur direkt blockiert wurde.
- `scripts/Start-Dev.ps1` robuster: pwsh-/powershell-Fallback für die Teilfenster und
  Port-Prüfung für 5088/5173 (läuft ein Dienst bereits, wird er weiterverwendet statt hart
  zu crashen oder Prozesse aggressiv zu killen).
- Operator-Leiste ist nicht mehr `sticky`/fixiert: sie bleibt oben im normalen
  Dokumentfluss und blockiert beim Scrollen keinen Platz mehr. Schnellaktionen (Backup,
  Turnierpaket drucken, Rundenblatt drucken, nächster Schritt) und der Turniertag-Modus
  bleiben unverändert funktionsfähig.
- Keine Änderung an Auslosungs-, Wertungs-, Such-, Dedupe-, Chess960- oder Persistenzlogik.
  Versionen auf `0.40.1`.

## 0.40.0 - Turniertag-Härtung (Outdoor-Modus, Sticky-Leiste, Backup-Hinweise)

- Neuer „Turniertag-Modus" (Outdoor): ein CSS-Klassen-Umschalter in der Operator-Leiste
  vergrößert Schrift und Buttons und erhöht den Kontrast für den Einsatz draußen.
  Die Einstellung wird lokal (localStorage) gespeichert und wirkt ohne Reload.
- Operator-Leiste bleibt jetzt beim Scrollen oben sichtbar (sticky) und bietet
  Schnellaktionen: Backup erstellen, Turnierpaket drucken, Rundenblatt drucken.
- Neuer Backup-Status-Chip („Letztes Backup" / „Backup empfohlen"). Nach Auslosung
  und Chess960-Würfeln erscheint ein klarer Backup-Hinweis. „Jetzt Backup erstellen"
  lädt einen lokalen JSON-Snapshot mit Turniername, Runde und Zeitstempel (keine Cloud);
  der Zeitpunkt des letzten Backups wird pro Turnier lokal gemerkt.
- Ergebnis-Eingabe robuster: sichtbare „Speichere …" / „✓ Ergebnis gespeichert"-Bestätigung
  und klare Fehlermeldung, wenn das Speichern fehlschlägt. Auslosungs-Blocker bei offenen
  Ergebnissen bleibt unverändert.
- Reset/Delete sicherer: Bestätigungsdialoge nennen den Turniernamen und den Unterschied
  (Reset behält Teilnehmer/Einstellungen, löscht Runden/Ergebnisse/Chess960; Delete entfernt
  das ganze Turnier). Delete verlangt zusätzlich die exakte Eingabe des Turniernamens.
- Aufklappbare „Vor-Ort-Checkliste & Laptop-Hinweise" in der Operator-Leiste (rein statisch).
- Neues schreibgeschütztes Skript `scripts/Show-EventReadiness.ps1`: prüft nur lesend
  Backend, Frontend-Port, DB-Pfad, Backup-Ordner und Git-Status. Keine Systemänderung.
- QR/LAN bewusst noch nicht implementiert (Roadmap-Hinweis im UI).
- Keine Änderung an Auslosungs-, Wertungs- oder Dedupe-Logik. Versionen auf `0.40.0`.

## 0.39.0 - Operator-Bedienleiste und Druck-/Backup-Polish

- Neue Operator-Bedienleiste oben im Dashboard: Backend-Status, gewähltes Turnier,
  aktuelle Runde, offene Ergebnisse und ein klarer „Nächster Schritt" mit Direkt-Aktion
  (Runde 1 auslosen / Ergebnisse eintragen / Vorschau erzeugen / Abschluss prüfen).
- Health-Endpunkt liefert zusätzlich den vollständigen Datenbankpfad; die Bedienleiste
  zeigt Pfad, Autosave-Hinweis und Backup-Erinnerung vor Runde 1.
- Rundenblatt-Druck und Turnierbericht zeigen jetzt das Druckdatum; offene Bretter
  erhalten auf dem Rundenblatt ein leeres, beschreibbares Ergebnisfeld.
- Teilnehmerliste in der Druckansicht enthält jetzt FIDE-ID, Jahrgang und ca.-Alter.
- Neues lokales Backup-Skript `scripts/Backup-BergfestTournament.ps1` (nur lokaler
  JSON-Export nach `D:\Schach\Backups`, keine Cloud, keine echten Beispieldaten).
- Versionen auf `0.39.0` angehoben.

## 0.38.7 - Bergfest-Operatorunterlagen und Dry-run-CLI-Fix

- Freitag-Unterlagen ergänzt/geschärft: Operator Card, 09:30-Startcheck, Backup,
  Papier-/CSV-Fallback und Vorgehen bei Rematch-Warnungen.
- `scripts/New-DemoTournament.ps1` akzeptiert zusätzlich den freitags verwendeten
  Parameteralias `-Players`.
- WebApi-Start nutzt explizit Console-Logging, damit lokale Startfehler nicht vom
  Windows-EventLog-Provider verdeckt werden.
- Kleiner Testvertrag dokumentiert den `-Players`-Alias im Demo-Skript.

## 0.38.6 - Tie-Break-Roadmap und Virtual-Opponent-Modell für ungespielte Runden

- `docs/FEATURE_ROADMAP.md` (P1–P5) und `docs/IMPORT_EXPORT_ROADMAP.md` ergänzt.
- Reines, getestetes Domain-Modell `UnplayedRoundTiebreak` mit `UnplayedRoundBuchholzMode`
  für die FIDE-Behandlung eigener ungespielter Runden (C.07/2024 Art. 16.4, virtueller Gegner).
- Unit-Tests für gespielte Partie, kampflosen Sieg, Bye, konfigurierbare Wertung und
  vorbereitete Buchholz-Cut-Liste.
- `docs/TIEBREAK_UNPLAYED_ROUNDS.md` dokumentiert Modell, Annahmen und Integrationspfad.
- Bewusst noch nicht in `StandingsCalculator` verdrahtet (Default = bisheriges Verhalten,
  keine Wertungs-Regression).

## 0.38.5 - Commit-Guard-Fix und Clean-Current-Baseline

- Entfernt fehlgeschlagene v0.38-Zwischenpatch-Dateien aus dem aktuellen Arbeitsstand.
- Repariert den Git-Sicherheitscheck, damit er eigene Prüfpattern nicht mehr selbst als Treffer blockiert.
- Prüft staged Diffs nur auf neu hinzugefügte Zeilen, damit Löschungen alter belasteter Dateien möglich bleiben.
- Hält lokale Audit-/Backup-Verzeichnisse und Paket-Backups konsequent aus künftigen Commits heraus.
- Bestätigt weiterhin: Das private Repo wird wegen der Historie nicht direkt öffentlich geschaltet; Open Source erfolgt später als Clean Snapshot.
## 0.38.4 - Commit-Guard-Härtung und Lockfile-Fix

- Repariert die v0.38.3-Anwendung bei package-lock.json-Dateien mit leerem Root-Package-Key.
- Erzwingt public npm Registry im WebApp-Projekt und blockiert interne Registry-URLs im Lockfile.
- Härtet Commit-If-Green und Git-Safety-Prüfungen gegen lokale Audits, Backups, Artefakte, interne URLs und typische Secret-Muster.
- Aktualisiert README auf den aktuellen Stand und dokumentiert Clean-Snapshot-Empfehlung für Open Source.

## 0.38.0 - README und Safe Commit Guard

- README/GitHub-Startseite auf den aktuellen Funktionsstand bis 0.37.6 aktualisiert.
- `.gitignore` um typische Build-Artefakte, lokale Daten, Logs, Dumps, Archive und Secret-Dateien erweitert.
- `scripts/Test-GitCommitSafety.ps1` ergänzt: prüft geänderte Dateien vor Commit auf Artefakte, große Dateien und typische Secret-Muster.
- `scripts/Commit-If-Green.ps1` ersetzt: Release-Gate, Sicherheitsprüfung vor/nach Stage, Dateiübersicht und erst danach Commit/Push.
## 0.37.3

- Fix: fehlerhaft eingefügten Audit-Journal-Query-Endpunkt entfernt und syntaktisch robust neu eingefügt.
- Queryparameter werden über HttpRequest gelesen, damit die Minimal-API-Signatur stabil bleibt.
- Release-Gate bleibt verpflichtend: Restore, Build, Tests, Frontend-Build und Portable-Paket.

## 0.37.2

- Fix: Audit-Journal-Query-API-Fixscript repariert; keine PowerShell-Backtick-/Unicode-Escape-Falle mehr in eingebetteten Markdown-Texten.
- Query-Endpunkt wird robust vor stabilen WebApi-Tokens eingefügt, notfalls vor app.Run().
- Release-Gate bleibt verpflichtend: Restore, Build, Tests, Frontend-Build und Portable-Paket.
## 0.36.1 - Audit-Journal Query Testfix

- Fehlendes `using Xunit;` in den AuditJournalQueryServiceTests ergänzt.
- v0.36.0-Query-Fundament bleibt fachlich unverändert; der Fix behebt nur den Test-Build.
## 0.36.0 - Audit-Journal Query Foundation

- AuditJournalQueryService ergänzt, um das persistente Audit-Journal nach Schweregrad, Aktion, Runde, Brett, Spieler und Freitext zu filtern.
- AuditJournalStatistics ergänzt für Info-/Warn-/Kritisch-Zählungen sowie Runden-, Brett- und Spielerbezüge.
- Regressionstests für Sortierung, Paging, Suche und Statistikzählungen ergänzt.
## 0.35.3 - Audit Journal Dashboard Fix 2

- Repariert den teilweise angewendeten Audit-Journal-Dashboard-Stand nach 0.35.0 bis 0.35.2.
- Fügt Audit-Exportfunktionen über tokenbasierte Einfügepunkte ein statt über zeilenbasierte Spezialanker.
- Ergänzt Audit-Journal-Dashboardkarte und Styles idempotent.
- Keine Änderung an Auslosungslogik, Wertungsberechnung oder Speicherformat.
## 0.34.1 - Audit Journal Round Review Fix

- Auditjournal-Einträge für `SetRoundLock` und `SetRoundVerified` ergänzt.
- Runden-Sperren, Entsperren, Prüfen und Zurücksetzen werden nun dauerhaft im Auditjournal protokolliert.
- Behebt den roten `AuditJournal_TracksManualCorrectionsAndRoundReview`-Regressionstest aus 0.34.0.
- Keine Änderung an Auslosungslogik, Wertungsberechnung oder UI.
## 0.34.0 - Persistent Audit Journal Foundation

- Persistierbares Auditjournal im `TournamentState` ergänzt.
- Neue Domain-Typen `AuditJournalEntry`, `AuditJournalAction` und `AuditJournalSeverity` ergänzt.
- Zentrale Turnierleiteraktionen werden nun dauerhaft protokolliert: Turnier/Spieler/Runden/Ergebnisse/manuelle Paarungen/Rundenprüfung.
- Neuer API-Endpunkt `GET /api/tournaments/{id}/audit-journal`.
- Neue Application-Regressionstests für Kernworkflow, manuelle Korrekturen und Snapshot-Persistenz.
- Keine Änderung an Auslosungslogik oder Wertungsberechnung.
## 0.33.0 - Forfeit/Bye Regression Gate

- Zusätzliche Domain-Regressionstests für kampflose Ergebnisse und Bye/Spielfrei ergänzt.
- Forfeit-Tiebreak-Policies `ExcludeForfeitsFromTiebreaks`, `CountForfeitOpponentForBuchholzOnly` und `CountForfeitsAsNormalGames` werden in Mehr-Runden-Szenarien abgesichert.
- Bye mit `CountByeAsWin` wird als Sieg gezählt, bleibt aber ohne Gegnerwertung, Sonneborn-Berger, Gegnerschnitt und Performance.
- Keine Änderung an Auslosungslogik, Wertungsberechnung, Speicherformat oder UI.
## 0.32.0 - Swiss-Regression-Gate

- Zusätzliche Domain-Regressionstests für grundlegende Swiss-Pairing-Invarianten ergänzt.
- Gerade und ungerade erste Runde prüfen jetzt eindeutige Spielerzuordnung, Bye-Anzahl und fortlaufende Brettnummern.
- Zweite Runde nach entschiedener erster Runde prüft keine direkten Rematches und keine kritische Pairing-Qualität.
- xUnit2031-Warnung aus `SwissRegressionScenarioTests` bereinigt.
- Keine Änderung an Auslosungslogik, Wertungsberechnung oder Speicherformat.
## 0.31.0 - Swiss-Regression-Szenarien

- Zusätzliche Application-Regressionstests für echte Schweizer-System-Turniersituationen ergänzt.
- Ungerade Teilnehmerzahl mit Bye und temporärer Auslosungsvorschau abgesichert.
- Kampflose Ergebnisse werden inklusive Rundenabschluss und Diagnosewirkung geprüft.
- Rückzug nach gespielter Runde wird abgesichert: zurückgezogene Spieler dürfen in der nächsten Vorschau nicht gepaart werden.
- Keine Änderung an Auslosungslogik, Wertungsberechnung oder Speicherformat.
## 0.30.0 - Release-Gate und Commit-Guard

- Release-Gate `scripts/Invoke-ReleaseGate.ps1` ergaenzt.
- Commit-Guard `scripts/Commit-If-Green.ps1` ergaenzt.
- Bekannte versehentliche Datei `tatus` wird vor Release/Commit geblockt.
- Node.js-Engine-Hinweis fuer Vite/Rolldown integriert.
- Ziel: rote Zwischenstaende wie 0.29.0/0.29.1 kuenftig vor Commit/Push erkennen.

## 0.29.2

- Fix: doppelte `openLatestRoundPrint`-Funktion im Korrekturjournal-Stand entfernt.
- Nachkontrolle: Backend-Build, Tests, Frontend-Build und Portable-Paket laufen wieder grün.
## 0.29.1 - Korrekturjournal-Buildfix

- Korrekturjournal-Helfer in den richtigen React-App-Scope verschoben.
- TypeScript-Buildfehler aus v0.29.0 behoben.
- Keine Änderung an Auslosungslogik, Wertungsberechnung oder Speicherformat.
## 0.29.0 - Korrektur- und Eingriffsübersicht

- Dashboard-Panel fuer Turnierleiter-Korrekturen ergaenzt.
- Manuelle Paarungen, gesperrte/gepruefte Runden, inaktive Teilnehmer und Sonderergebnisse werden zentral sichtbar.
- Status-Badges und Schnellzugriffe auf letzte Runde, Turnierbericht und Paarungs-CSV ergaenzt.
- Keine Aenderung an Auslosungslogik, Wertungsberechnung oder Speicherformat.
## v0.28.0
- Dashboard um eine Auslosungsfreigabe erweitert.
- Offene Ergebnisse, ungeprüfte vollständige Runden, aktive Spielerzahl und kritische Vorschauhinweise werden vor der nächsten Auslosung zentral geprüft.
- Schnellaktionen für Auslosungsvorschau, nächste Runde, aktuelle Runde und Turnierbericht ergänzt.
- Version auf 0.28.0 angehoben.
## v0.27.0

- Dashboard um ein Bye- und Kampflos-Audit erweitert.
- Spielfreie und kampflose Bretter werden inklusive Wertungswirkung sichtbar gemacht.
- Anzeige für Buchholz-, Direkt-/Sonneborn-Berger- und Performance-Wertung ergänzt.
- Schnellaktionen für aktuelle Runde, Paarungen-CSV und Turnierbericht ergänzt.
- Version auf 0.27.0 angehoben.
## v0.26.0

- Dashboard um eine Rundenabschluss-Checkliste erweitert.
- Offene Ergebnisse, kampflose Bretter, ungeprüfte vollständige Runden und Diagnosehinweise werden zentral sichtbar.
- Schnellaktionen für aktuelle Runde, Turnierbericht und Tabellen-CSV ergänzt.
- Version auf 0.26.0 angehoben.
## 0.25.0

- Ergänzt ein Turnierleiter-Exportcenter im Dashboard.
- Bündelt Aushänge, Tabellen-, Paarungs-, Vorschau- und Backup-Exporte an einer Stelle.
- Zeigt Schnellkennzahlen zu Teilnehmern, aktiven Spielern, Runden, offenen Brettern und kampflosen Partien.
- Ergänzt Warnhinweise für offene Ergebnisse und kritische Auslosungsvorschauen.
- Baut das Portable-Paket als `SchachTurnierManager_Portable_0.25.0.zip`.
## 0.24.1

- Vervollständigt die Dashboard-Integration der Auslosungsvorschau-Exports.
- Ergänzt die fehlenden Buttons für Druckansicht und CSV-Export in der Vorschaukarte.
- Ergänzt deutliche Warnboxen für kritische oder nicht speicherbare Vorschauen.
- Baut das Portable-Paket nach der Korrektur neu.
## 0.23.0 - Auslosungsvorschau im Dashboard

- Die Next-Round-Auslosungsvorschau ist jetzt direkt im Dashboard sichtbar.
- Die Vorschau zeigt Pairing-Qualität, Warnungen, Bretter, Byes, Rematches, Scoregruppen-Abweichungen, Farbfolge-Risiken und Audit-Details.
- Turnierleiter können die Vorschau schließen oder danach bewusst die Runde wirklich auslosen.
## 0.22.2

- Stabilisiert den abgebrochenen v0.22.1-Patchlauf.
- Entfernt defekte Zwischenstandsdateien aus v0.22.0 und v0.22.1.
- Behält die Auslosungsvorschau ohne Persistenz aus v0.22 bei.
- Nachkontrolle bricht bei fehlgeschlagenem Restore, Build, Test, Frontend-Build oder Portable-Packaging hart ab.
# Changelog

## 0.21.0 - Pairing-Audit mit Qualitätsbericht

- Pairing-Qualität wird nach jeder automatisch erzeugten Runde direkt in das Runden-Audit geschrieben.
- Audit nennt Qualitätswert, Rematches, Scoregruppenabweichungen, Farbfolgenrisiken und Byes.
- Zusätzliche Application-Workflow-Tests sichern die Verbindung von Rundenerzeugung, Qualitätsbericht und Audit.
- Neue Swiss-Pairing-Golden-Szenarien prüfen Zwei-Runden-Verläufe und Bye-Audit.
## 0.20.5 - Export-Test für erweiterte Wertungen stabilisiert

- CSV-Export-Test auf den tatsächlich exportierten erweiterten Tabellenkopf angepasst.
- Fehlgeschlagene lokale Zwischenstandsartefakte aus v0.20.3/v0.20.4 werden beim Fix-Forward entfernt.
- Nachkontrolle bricht weiterhin hart ab, wenn Build, Tests, Frontend-Build oder Portable-Paket fehlschlagen.

## 0.20.2 - Teststabilisierung erweiterte Wertungen

- Stabilisiert den CSV-Export-Test nach der Erweiterung der Tabellenwertungsspalten in 0.20.1.
- Versionen auf `0.20.2` angehoben.
- Nachkontrollskript bricht nun hart ab, sobald `dotnet test`, Frontend-Build oder Packaging fehlschlagen.

## 0.19.0 - Swiss-Chess-Paritätsroadmap

- Funktionsmatrix für Swiss-Chess-/Swiss-Manager-artige Turnierverwaltung ergänzt.
- Offene Blöcke für Schweizer System, Mannschaftsturniere, Import/Export, Ratingauswertung, Druck, Betrieb und Support dokumentiert.
- Priorisierte Roadmap für die nächsten Entwicklungsphasen ergänzt.
## 0.18.1 - Pairing-Qualität im Dashboard

- Fix-Forward für das v0.18.0-Nachkontrollskript.
- Application-Endpunkt für Pairing-Qualität pro Runde ergänzt.
- WebApi-Endpunkt `/api/tournaments/{id}/rounds/{roundNumber}/pairing-quality` ergänzt.
- Dashboard zeigt Pairing-Qualitätswert, Schweregrad, Rundenhinweise und brettweise Erklärungen.
- Tests für den Application-Workflow der Pairing-Qualitätsberichte ergänzt.
## 0.17.0 - Pairing-Qualitätsbericht

- Pairing-Qualitätsmodell für Schweizer-System-Runden ergänzt.
- Analyzer erkennt Rematches, Scoregruppen-Unterschiede, dritte gleiche Farbe in Folge und Bye/Spielfrei.
- Qualitätswert und Schweregrad für spätere UI-Erklärung „Warum wurde so gelost?“ ergänzt.
- Golden-nahe Tests für Pairing-Qualität ergänzt.
## 0.16.1 - CSV-Import bewusst bestätigen und Vorlagen

- CSV-Import mit Warnungen muss im Dashboard bewusst bestätigt werden, bevor der Import ausgeführt werden kann.
- CSV-Beispielvorlage kann direkt im Dashboard eingefügt werden.
- Änderungen an CSV-Inhalt oder Ersetzen-Option verwerfen Vorschau und Warnungsbestätigung automatisch.
- Importstatus und Bedienhinweise im Dashboard präzisiert.
## 0.12.0 - Externe Spielerdaten anwenden und Dublettenprüfung

- Dublettenprüfung für externe Spielerdaten ergänzt: FIDE-ID, DSB-/National-ID, Name+Geburtsjahr und Name-only-Hinweis.
- Externe Treffer können direkt als neuer Teilnehmer gespeichert oder auf bestehende Teilnehmer angewendet werden.
- Dashboard zeigt mögliche Dubletten und bietet Aktionen zum Ergänzen oder Überschreiben bestehender Teilnehmer.
- API-Endpunkte für Dublettenprüfung und Apply-Workflow ergänzt.
- Tests für FIDE-ID `4610563`, Name+Geburtsjahr-Matching und externe Aktualisierung ergänzt.

## 0.11.3 - FIDE-Testassert endgültig stabilisiert

- FIDE-Provider-Test prüft die Request-URI jetzt tolerant auf das Suffix `profile/4610563`.
- Nachkontrollskript ersetzt alte Assert-Zeilen per Regex und bricht ab, falls der alte Assert weiterhin vorhanden ist.
- Versionen auf `0.11.3` angehoben.

## 0.11.2 - FIDE-Testassert robust fixiert

- FIDE-Provider-Test endgültig auf absolute/relative Profil-URI tolerant gemacht.
- Nachkontrollskript korrigiert die alte Assert-Zeile vorsorglich, falls ein vorheriger Patch nicht sauber überschrieben wurde.
- Versionen auf `0.11.2` angehoben.

## 0.11.1 - FIDE-Test und Ticket-Vorbereitung stabilisiert

- Korrigiert den FIDE-Provider-Test: `HttpClient` liefert bei gesetzter BaseAddress eine absolute `RequestUri`; der Test prüft nun robust auf `/profile/4610563`.
- GitHub-Issue-Templates für Bugreports und Feature-Wünsche ergänzt.
- Ticket-/Feedback-Workflow dokumentiert: GitHub Issues für öffentliche Nutzer, optional später In-App-Link mit Diagnosepaket.
- Versionen auf `0.11.1` angehoben.

## 0.11.0 - FIDE-Adapter testbar gemacht

- FIDE-Provider akzeptiert jetzt einen injizierten `HttpClient`, bleibt aber per Standardkonstruktor produktiv nutzbar.
- Offline-Parser-Test für FIDE-ID `4610563` ergänzt.
- Invalid-ID-Test für den FIDE-Provider ergänzt.
- Externe Lookup-Tests sind damit stabiler und weniger abhängig von Live-Webseiten.

## 0.10.4 - Stabilisierung externe Lookup-Tests

- Infrastructure-Live-Tests entkoppelt von konkreter DSB-/ThSB-Provider-Sichtbarkeit.
- FIDE-Live-Test bleibt optional über `STM_RUN_LIVE_LOOKUP_TESTS=1`.
- Offline-Snapshots für FIDE/DSB/ThSB bleiben als stabiler Testanker erhalten.
- Versionsanzeige auf `0.10.4` vereinheitlicht.

## 0.10.0 - Externe Spielersuche (FIDE-Grundlage)

- Provider-Struktur für externe Spielerdatenquellen ergänzt.
- FIDE-ID-Suche über `ratings.fide.com/profile/{id}` als erster aktiver Adapter.
- DSB/DeWIS und ThSB als vorbereitete Provider mit klarer Unsupported-Rückmeldung.
- Dashboard-Bereich „Spielerdaten suchen“ ergänzt; Treffer können ins Teilnehmerformular übernommen werden.
- Teilnehmerformular um Federation, Land, Rapid-/Blitz-Elo und DWZ-Index erweitert.
- Tests für Lookup-Routing und Profil-zu-Teilnehmer-Mapping ergänzt.

## 0.9.2 - Versions-/Packaging-Fix und externe Spielerdatenplanung

- Portable-Paket liest Version automatisch aus `package.json`.
- Nachkontrollskript `After-Apply-V0.9.2.ps1` ergänzt.
- Planungsdokument und Agenten-Skill für FIDE-/DSB-/ThSB-Spielerdaten-Anbindung ergänzt.

## 0.9.1 - Stabilisierung Turniereinstellungen

- Fix-Forward für den v0.9.0-Patch: `TournamentService.UpdateSettings(...)` ist in der Application-Schicht enthalten.
- Nachkontrollskript `After-Apply-V0.9.1.ps1` ergänzt.



## 0.9.1 - Turniereinstellungen und Wertungskette

- Turniereinstellungen im Dashboard bearbeitbar gemacht.
- Punktesystem, TWZ-Quelle, Forfeit-Policy, Bye-als-Sieg, Seniorenjahr und Heldenpokal-Mindestpartien konfigurierbar gemacht.
- Wertungskette im Dashboard auswählbar und sortierbar gemacht.
- Backend-Endpunkt zum Speichern der Turniereinstellungen ergänzt.
- Tabellenberechnung nutzt jetzt die konfigurierte Wertungskette nach Punkten.
- Tests für Settings-Workflow und konfigurierbare Wertungskette ergänzt.

## 0.8.0 - Portable App / lokale Auslieferung

- Backend kann das gebaute React-Dashboard direkt aus `wwwroot` ausliefern.
- Portable Paket erzeugt jetzt `output\portable` mit `app`, `data`, Start-BAT und README.
- `Pack-Portable.ps1` baut Frontend, publisht Backend und kopiert `dist` in das veröffentlichte `wwwroot`.
- `Start-Portable.bat` startet die lokale API auf `http://127.0.0.1:5088` und öffnet das eingebettete Dashboard.
- Healthcheck meldet, ob ein eingebettetes Dashboard gefunden wurde.
- Neues Nachkontrollskript `After-Apply-V0.8.ps1`.


## 0.7.1 - Stabilisierung Druckansichten

- Korrigiert Buildfehler im HTML-Export: Rundenprüfung nutzt `RoundDiagnostics.Warnings` statt einer nicht existierenden `Messages`-Eigenschaft.
- Ergänzt Handoff und Nachkontrollskript für den grünen v0.7.1-Stand.

## 0.7.0 - Druckansichten und Exportpaket

- CSV-Export für Gesamtwertung ergänzt.
- CSV-Export für alle Paarungen oder eine einzelne Runde ergänzt.
- HTML-Druckansicht für kompletten Turnierbericht ergänzt.
- HTML-Druckansicht für einzelne Rundenblätter ergänzt.
- Dashboard-Buttons für Tabelle, Paarungen, Turnierbericht und Rundenblätter ergänzt.
- Export-Formatter mit Tests für CSV/HTML-Ausgaben ergänzt.

## 0.6.0 - Stabilisierung Workflow-Tests und Checkpoint-Skripte

- Fehlendes `using Xunit;` in `RoundWorkflowTests` ergänzt.
- `After-Apply-V0.5.ps1`, `After-Apply-V0.6.0.ps1` und `Commit-Checkpoint.ps1` brechen jetzt zuverlässig bei fehlgeschlagenen nativen Befehlen ab.
- Checkpoint-Commits werden nicht mehr ausgeführt, wenn Build/Test/Frontend-Build fehlschlagen.

## 0.6.0 - Manuelle Paarungen und Rundensperren

- Manuelle Paarungskorrekturen pro Brett ergänzt.
- Rundensperre und Prüfstatus ergänzt.
- Ergebnisänderungen in gesperrten/geprüften Runden werden verhindert.
- Nächste Runde erfordert vollständig eingetragene vorherige Runde.
- Dashboard zeigt Rundenzustand und erlaubt Paarungskorrekturen mit Notiz.
- Checkpoint-Skript für regelmäßige grüne Commits ergänzt.

## 0.4.1 – 2026-06-07

### Fixed
- `Start-Dev.ps1` prüft und öffnet das Frontend jetzt über `http://127.0.0.1:5173`, passend zur Vite-Bindung.
- Vite-Proxy verwendet `http://127.0.0.1:5088` als Backend-Ziel.
- CORS erlaubt zusätzlich `http://127.0.0.1:5173`.
- Startskript wartet länger und protokolliert den letzten Verbindungsfehler, falls Backend oder Frontend nicht rechtzeitig erreichbar sind.

# Changelog
## 0.20.5 - Export-Test für erweiterte Wertungen stabilisiert

- CSV-Export-Test auf den tatsächlich exportierten erweiterten Tabellenkopf angepasst.
- Fehlgeschlagene lokale Zwischenstandsartefakte aus v0.20.3/v0.20.4 werden beim Fix-Forward entfernt.
- Nachkontrolle bricht weiterhin hart ab, wenn Build, Tests, Frontend-Build oder Portable-Paket fehlschlagen.

## 0.20.2 - Teststabilisierung erweiterte Wertungen

- Stabilisiert den CSV-Export-Test nach der Erweiterung der Tabellenwertungsspalten in 0.20.1.
- Versionen auf `0.20.2` angehoben.
- Nachkontrollskript bricht nun hart ab, sobald `dotnet test`, Frontend-Build oder Packaging fehlschlagen.

## 0.19.0 - Swiss-Chess-Paritätsroadmap

- Funktionsmatrix für Swiss-Chess-/Swiss-Manager-artige Turnierverwaltung ergänzt.
- Offene Blöcke für Schweizer System, Mannschaftsturniere, Import/Export, Ratingauswertung, Druck, Betrieb und Support dokumentiert.
- Priorisierte Roadmap für die nächsten Entwicklungsphasen ergänzt.
## 0.18.1 - Pairing-Qualität im Dashboard

- Fix-Forward für das v0.18.0-Nachkontrollskript.
- Application-Endpunkt für Pairing-Qualität pro Runde ergänzt.
- WebApi-Endpunkt `/api/tournaments/{id}/rounds/{roundNumber}/pairing-quality` ergänzt.
- Dashboard zeigt Pairing-Qualitätswert, Schweregrad, Rundenhinweise und brettweise Erklärungen.
- Tests für den Application-Workflow der Pairing-Qualitätsberichte ergänzt.
## 0.17.0 - Pairing-Qualitätsbericht

- Pairing-Qualitätsmodell für Schweizer-System-Runden ergänzt.
- Analyzer erkennt Rematches, Scoregruppen-Unterschiede, dritte gleiche Farbe in Folge und Bye/Spielfrei.
- Qualitätswert und Schweregrad für spätere UI-Erklärung „Warum wurde so gelost?“ ergänzt.
- Golden-nahe Tests für Pairing-Qualität ergänzt.
## 0.4.0 – 2026-06-07

### Added
- Schweizer-System-Auslosung V2 mit scoregruppenorientierter Gegnerwahl.
- Pairing-Audit mit Scoregruppen, Floatern und Farbhistorie-/Farbpräferenz-Hinweisen.
- Erweiterte Swiss-Golden-Tests für Bye-Schutz, Rematch-Vermeidung, Farbpräferenz und Audit.
- Auditanzeige im Dashboard direkt an jeder Runde.
- `scripts\After-Apply-V0.4.ps1` für die lokale Nachkontrolle.

### Changed
- Swiss-Pairing vermeidet Wiederholungen robuster und dokumentiert unvermeidbare Wiederholungen explizit.
- Bye-Vergabe bevorzugt die niedrigste Scoregruppe ohne bisheriges Bye.
- Farbvergabe berücksichtigt Farbbilanz, letzte Farben und drohende dritte gleiche Farbe.
- Dashboard-Version auf 0.4.0 angehoben.

## 0.3.1 – 2026-06-07

### Fixed
- Behebt die Kompilierfehler in `CrossTableCalculatorTests` und `HeroCupCalculatorTests`: `TournamentRound.Pairings` ist `IReadOnlyList<Pairing>` und muss in Tests per Array/Collection-Initializer gesetzt werden.
- `scripts\Test-All.ps1` und `scripts\After-Apply-V0.3.ps1` brechen jetzt bei fehlgeschlagenen externen Befehlen zuverlässig ab.

### Changed
- `scripts\Start-Dev.ps1` wartet nun kurz auf Backend und Frontend, bevor der Browser geöffnet wird. Dadurch werden anfängliche Vite-Proxy-Fehler durch noch nicht gestartetes Backend reduziert.
- Zusätzliches Skript `scripts\After-Apply-V0.3.1.ps1` für die Stabilisierungskontrolle.

## 0.3.0 – 2026-06-07

### Added
- Turnierleiter-MVP: Teilnehmer im Dashboard bearbeiten, löschen, zurückziehen und reaktivieren.
- Erweiterte Teilnehmerfelder im UI: Geburtsjahr, Geschlecht, DWZ, Elo, manuelle TWZ, FIDE-ID, DSB-ID, Titel, Status und Notizen.
- Kategorieauswertungen für Frauen, U10/U12/U14/U16/U18/U25 und Senioren.
- Kreuztabelle mit Ergebnisanzeige aus Spielersicht.
- Heldenpokal-Auswertung auf Basis tatsächlicher Punkte minus erwarteter Punkte gegen Gegner-TWZ.
- CSV-Import/-Export für Teilnehmer.
- JSON-Backup/-Restore für ganze Turniere.
- API-Endpunkte für Kreuztabelle, Kategorien, Heldenpokal und Import/Export.
- Unit-Tests für Kreuztabelle, Kategorien, Heldenpokal und CSV-Import/-Export.

### Changed
- Dashboard auf Version 0.3.0 erweitert und Tabellenbereiche für große Turniere scrollbar gemacht.
- Rundenturnier-Auslosung berücksichtigt nur aktive Spieler.

## 0.2.1 – 2026-06-07

### Fixed
- Stabilisiert den SQLite-Persistenztest: Testdatenbank liegt jetzt in einem eigenen temporären Verzeichnis, SQLite-Pooling ist deaktiviert, Connection-Pools werden vor dem Cleanup geleert und der Cleanup wiederholt Datei-/Ordnerlöschungen kurz.
- Behebt den lokalen Testfehler `IOException: ... sqlite ... used by another process` in `SqliteTournamentStoreTests`.

## 0.2.0 – 2026-06-07

### Added
- SQLite-/EF-Core-basierter `SqliteTournamentStore` in `Infrastructure`.
- Lokale Datenbankanlage beim API-Start unter `%LOCALAPPDATA%\SchachTurnierManager`.
- API-Endpunkte für Turnierliste, Turnierdetails, Teilnehmeranlage/-änderung/-entfernung, nächste Runde, Ergebnis, Tabelle und Audit.
- Bedienbares React-Dashboard für Turnieranlage, Teilnehmererfassung, Auslosung, Ergebniseingabe und Live-Tabelle.
- Persistenztest für Speichern/Laden eines Turniers mit Runde und Ergebnis.
- `.gitattributes` und erweiterte `.gitignore`-Regeln für stabile Zeilenenden und generierte Dateien.
- `scripts\Start-Dev.ps1` und `scripts\Clean-Generated.ps1`.

### Changed
- Frontend-Build von `tsc -b` auf `tsc --noEmit` umgestellt.
- TypeScript `moduleResolution` von veraltetem `Node` auf `Bundler` umgestellt.
- `scripts\Test-All.ps1` prüft jetzt zusätzlich den Frontend-Build.
- `Pack-Portable.ps1` baut vor dem Publish auch das Frontend.

### Fixed
- xUnit-Warnung `xUnit2031` in `SwissPairingEngineTests` behoben.
- TypeScript-Fehler `TS5107` im Frontend behoben.

## 0.1.0 – 2026-06-07

### Added
- .NET-10-Solution mit Domain, Application, Infrastructure und WebApi.
- React/TypeScript/Vite-Dashboard-Grundlage.
- Round-Robin-Pairing-Engine.
- Basis-Schweizer-Pairing-Engine mit Audit-Hinweisen.
- StandingsCalculator mit Punkten, Siegen, Direktvergleich, Buchholz, Buchholz Cut-1, Sonneborn-Berger, Performance und Heldenpokal-Grundlage.
- Armageddon-Bidding-Service mit Commitment-Hash und Entscheidungslogik.
- Unit-Test-Projekte und erste Tests.
- Codex-/Agenten-/Skill-Dokumente.
- Build-/Test-/Run-/Portable-Pack-Skripte.




## 0.37.4

- Repariert den Audit-Journal-Query-API-Patch durch Wiederherstellung der Program.cs aus dem letzten gruenen Git-Stand.
- Ergaenzt die Query-Route als kurze MapGet-Zeile und verlagert die Logik in einen statischen Handler, damit die einzeilige Program.cs nicht erneut syntaktisch zerstoert wird.
- Behaelt das gruenes-Gate-vor-Commit-Prinzip bei.
## 0.37.5

- Repariert den Audit-Journal-Query-API-Patch durch Reset der Program.cs aus dem letzten gruenen Git-Stand.
- Ergaenzt den Query-Endpunkt als Inline-Minimal-API-Handler mit HttpRequest-Query-Auswertung.
- Fuegt kleine Parser-Helfer fuer optionale int- und Guid-Queryparameter hinzu.
## 0.37.6

- Repariert den Audit-Journal-Query-API-Patch erneut durch Reset der Program.cs aus dem letzten gruenen Git-Stand.
- Entfernt die separate Helper-Funktionsstrategie der vorherigen Fixes.
- Ergaenzt den Query-Endpunkt als eigenstaendigen Inline-Minimal-API-Handler ohne zusaetzliche lokale Helfer.
