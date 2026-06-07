# CHANGELOG

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
