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
- Die EXE ist aktuell unsigniert; SmartScreen-Warnungen sind erwartbar.
- Code-Signing/Zertifikatskauf ist eine spätere Entscheidung und darf nicht automatisch ausgelöst werden.
- Turnierdaten unter `%LocalAppData%\SchachTurnierManager` bleiben bei Deinstallation erhalten.
