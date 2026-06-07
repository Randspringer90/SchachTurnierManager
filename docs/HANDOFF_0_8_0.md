# Handoff 0.8.0

## Ergebnis

Portable lokale Auslieferung vorbereitet. Das Backend kann das gebaute React-Dashboard aus `wwwroot` ausliefern. Das Pack-Skript erstellt ein portables Paket unter `output\portable` und optional `output\SchachTurnierManager_Portable_0.8.0.zip`.

## Geänderte Dateien

- `src/SchachTurnierManager.WebApi/Program.cs`
- `src/SchachTurnierManager.WebApp/package.json`
- `src/SchachTurnierManager.WebApp/package-lock.json`
- `scripts/Pack-Portable.ps1`
- `scripts/Start-Portable.bat`
- `scripts/After-Apply-V0.8.ps1`
- `README.md`
- `CHANGELOG.md`
- `PLANS.md`
- `docs/ROADMAP.md`
- `.agents/skills/installer-packaging.md`

## Lokale Nachkontrolle

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\After-Apply-V0.8.ps1"
```

Danach testen:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Pack-Portable.ps1"
```

Start:

```text
output\portable\Start-SchachTurnierManager.bat
```

## Risiken / offen

- Framework-dependent Paket benötigt eine passende .NET-10-Laufzeit. Für fremde Geräte kann später `-SelfContained` genutzt oder ein klassischer Installer gebaut werden.
- Noch kein automatischer Windows-Installer, nur portable ZIP-Variante.
