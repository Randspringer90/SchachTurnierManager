# Installer (Inno Setup)

Der Installer wird aus dem self-contained Desktop-Paket gebaut.

## Build

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build-Installer.ps1
```

oder als dokumentierter RUN-05-Readiness-Lauf:

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-InstallerReadiness.ps1 -BuildInstaller -AllowMissingInnoSetup
```

## Grenzen

- `output/installer` wird nicht committet.
- Ein normaler Build bleibt unsigniert; SmartScreen-Warnungen sind dabei erwartbar.
- Für Release-Kandidaten kann die Setup-EXE explizit per Authenticode signiert werden (`Build-Installer.ps1 -SignArtifacts ...`). Private Keys/PFX-Dateien gehören nie ins Repository.
- Zertifikatskauf oder andere Kostenaktionen werden durch kein Skript automatisch ausgelöst. Produktionssignierung benötigt eine ausdrückliche Owner-Freigabe; Details: `docs/release/SIGNING_AND_UPDATES.md`.
- Turnierdaten unter `%LocalAppData%\SchachTurnierManager` bleiben bei Deinstallation erhalten.
