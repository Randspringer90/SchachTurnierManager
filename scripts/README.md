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

## Git (git)

- `Commit-If-Green.ps1` – CommitGuard: Release-Gate + Sicherheitsprüfungen + explizites Staging + Commit.
- `Commit-Checkpoint.ps1` – älteres Checkpoint-Skript; bevorzugt `Commit-If-Green.ps1` verwenden.

## Sicherheit (security)

- `Test-GitCommitSafety.ps1` – Commit-Sicherheitsprüfung (Pfade, interne Referenzen, Zugangsdaten-Muster).
- `Test-RepositoryOpenSourceSafety.ps1` – Public-Snapshot-Kandidaten prüfen, Reports unter `output/repo-open-source-safety/`.
- `New-OpenSourceSnapshot.ps1` – Clean Snapshot ohne Git-Historie für Open-Source-Veröffentlichung.

## Wartung (maintenance)

- `Clean-Generated.ps1` – generierte Artefakte entfernen.

## Archiv

- `archive/after-apply/` – historische After-Apply-/Patch-Skripte; nicht mehr ausführen (siehe dortiges README).

## Zielstruktur

Die Unterordner `dev/`, `test/`, `release/`, `git/`, `security/`, `maintenance/` sind als Zielzustand in `docs/planning/PROJECT_ORCHESTRATION.md` dokumentiert. Die Migration erfolgt in einem eigenen Lauf, weil dabei alle gegenseitigen Skriptaufrufe, Doku-Verweise und Regex-Pfadmuster (`patternSourceRegex`, Snapshot-Excludes) gleichzeitig angepasst und über das Release-Gate verifiziert werden müssen.
