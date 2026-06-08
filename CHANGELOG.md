# Changelog


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

# CHANGELOG


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


