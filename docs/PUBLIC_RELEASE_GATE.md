# SchachTurnierManager - PUBLIC Release/Push Gate

Stand: 2026-07-01

## Status

`SchachTurnierManager` ist ein PUBLIC-Repo. Deshalb gelten strengere Regeln als bei den PRIVATE-KFM-/MAGO-Repos:

- kein Push ohne explizite Freigabe
- keine privaten Turnierdaten, lokalen JSONs, Logs, Dumps, DBs, Backups oder Tokens
- keine Teilnehmerlisten mit privaten Kontaktdaten
- keine lokalen Pfade/Secrets in Release-Artefakten

## Lokaler Snapshot

```powershell
Set-Location -LiteralPath "D:\KFM\KI-Projekte\SchachTurnierManager"; pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Invoke-PublicSafetySnapshot.ps1"
```

## Reihenfolge vor PUBLIC-Push

1. `git status --short --branch --untracked-files=all`
2. `git diff --check`
3. vorhandene Safety-Skripte ausfuehren, insbesondere `Test-RepositoryOpenSourceSafety.ps1` und `Test-GitCommitSafety.ps1`
4. Build/Test/Smoke passend zum geplanten Release
5. Public-Safety-Report lesen
6. Maintainer-Freigabe fuer genau diesen Push einholen

## Stop-Regeln

Sofort stoppen bei:

- lokalen Turnier-/Teilnehmerdateien
- Datenbanken oder Backup-Dateien
- Secrets, Tokens, `.env`, `.npmrc`
- generierten ZIPs/Reports
- nicht erklaerbarem `ahead` oder fremden Aenderungen
