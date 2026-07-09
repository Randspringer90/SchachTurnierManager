# scripts/ – Skriptübersicht

Aktive Skripte liegen bewusst flach in diesem Ordner, weil sie sich gegenseitig über feste Pfade aufrufen (siehe Zielstruktur unten).

## Entwicklung (dev)

- `Start-Dev.ps1` – Backend für lokale Entwicklung starten.
- `Run-Backend.ps1` / `Run-WebApp.ps1` – Backend bzw. Frontend einzeln starten.

## Tests (test)

- `Test-All.ps1` – .NET-Tests gesamt.
- `Run-ExternalLookupSmoke.ps1` – Smoke-/Live-Tests externer Spielerdaten-Lookup.

## Release (release)

- `Invoke-ReleaseGate.ps1` – Pflicht-Gate: restore, build, test, Frontend-Build, Pack-Portable.
- `Pack-Portable.ps1` / `Start-Portable.bat` – portables Paket bauen und starten.
- `Invoke-PortableFreshFolderTest.ps1` – RUN-03: Portable-ZIP bauen, frisch entpacken, Health/Dashboard/API/SQLite-Datenpfad smoke-testen und als Run-ZIP bündeln.
- `Publish-DesktopApp.ps1` / `Start-Desktop.bat` – self-contained Desktop-Paket (`output\desktop`), Klick-Start, Daten unter `%LocalAppData%\SchachTurnierManager`.
- `Build-Installer.ps1` – Installer-EXE über Inno Setup 6 aus `installer\SchachTurnierManager.iss` bauen (ISCC.exe erforderlich).
- `Invoke-InstallerReadiness.ps1` – RUN-05-Readiness mit Run-Log-Bundle, Desktop-Publish, optionalem Installer-Build und Manifesten.
- `Invoke-PwaReadiness.ps1` – RUN-08: PWA-Manifest, Icons, Service Worker und Vite-Ausgabe prüfen; `/api` bleibt network-only und wird nicht offline gecacht.

## Git (git)

- `Commit-If-Green.ps1` – CommitGuard: Release-Gate + Sicherheitsprüfungen + explizites Staging + Commit. Lokale `NEXT_PROMPT.md`-Handoffs werden nicht automatisch gestaged.
- `Commit-Checkpoint.ps1` – älteres Checkpoint-Skript; bevorzugt `Commit-If-Green.ps1` verwenden.

## Sicherheit (security)

- `Test-GitCommitSafety.ps1` – Commit-Sicherheitsprüfung (Pfade, interne Referenzen, Zugangsdaten-Muster).
- `Invoke-NpmSafe.ps1` – npm-Aufrufe mit isolierter temporärer npmrc ausführen; lokale Auth optional aus `.secrets/local/`.
- `Set-LocalSecret.ps1` – lokale Secrets per Windows-DPAPI unter `.secrets/local/` speichern, ohne Werte zu loggen.
- `Test-RepositoryOpenSourceSafety.ps1` – Public-Snapshot-Kandidaten prüfen, Reports unter `output/repo-open-source-safety/`.
- `New-OpenSourceSnapshot.ps1` – Clean Snapshot ohne Git-Historie für Open-Source-Veröffentlichung.

## Wartung (maintenance)

- `Clean-Generated.ps1` – generierte Artefakte entfernen.

## Lauf-Logging (operator/diagnostics)

- `Invoke-LoggedCommand.ps1` – lange Befehle mit kurzer Terminalausgabe ausführen; vollständige Ausgabe landet im Run-Logordner.
- `New-RunLogBundle.ps1` – Run-Ordner unter `D:\Temp` anlegen bzw. Logs, Git-Status und Diff-Stat zu einem ZIP bündeln.

## Archiv

- `archive/after-apply/` – historische After-Apply-/Patch-Skripte; nicht mehr ausführen (siehe dortiges README).

## Zielstruktur

Die Unterordner `dev/`, `test/`, `release/`, `git/`, `security/`, `maintenance/` sind als Zielzustand in `docs/planning/PROJECT_ORCHESTRATION.md` dokumentiert. Die Migration erfolgt in einem eigenen Lauf, weil dabei alle gegenseitigen Skriptaufrufe, Doku-Verweise und Regex-Pfadmuster (`patternSourceRegex`, Snapshot-Excludes) gleichzeitig angepasst und über das Release-Gate verifiziert werden müssen.

- `Invoke-TournamentAssistantReadiness.ps1`: RUN-17-Readiness fuer den lokalen Turnierassistenten; ReleaseGate, Frontend-Build und UI-/Privacy-Merkmale als Run-ZIP.
- `Invoke-KnowledgeChatReadiness.ps1` prueft RUN-10/11: lokale Chat-Hilfe/Wissensbasis, Datenschutz-Hinweis, Schnellfragen, Chat-Export und Frontend-Build.
- `Invoke-KnowledgeBaseReadiness.ps1` prueft RUN-11: ausgelagerte lokale JSON-Wissensbasis, Quellen-/Privacy-Regeln, UI-Import und Frontend-Build.
