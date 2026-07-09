# Report 2026-07-09 – RUN-05 Installer-Readiness

## TL;DR

RUN-05 ist jetzt als prüfbarer Readiness-Lauf umgesetzt: `scripts/Invoke-InstallerReadiness.ps1` erstellt einen Run-Ordner unter `D:\Temp`, führt optional ReleaseGate, Desktop-Publish und Installer-Build aus, prüft zentrale Desktop-Artefakte und bündelt Logs/Manifeste/Checklisten als ZIP. Inno Setup wird nicht automatisch installiert; fehlt `ISCC.exe`, wird das als Blocker dokumentiert.

## Geänderte Dateien

- `scripts/Invoke-InstallerReadiness.ps1` neu
- `scripts/Build-Installer.ps1` erweitert um `-InnoSetupCompiler` und SHA256-Ausgabe
- `installer/SchachTurnierManager.iss` gehärtet: expliziter Per-User-Installationspfad unter `%LocalAppData%\Programs`, Versionsmetadaten
- `installer/README.md` neu
- `docs/release/INSTALLER_TEST_CHECKLIST.md` neu
- `README.md`, `scripts/README.md`, `.agents/skills/installer-packaging.md` aktualisiert
- `PLANS.md`, `CHANGELOG.md`, `docs/ai/PROMPTS.md` aktualisiert
- Version auf `0.43.0` in Health, `package.json`, `package-lock.json`

## Verifikation

Vom Nutzer lokal auszuführen:

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-InstallerReadiness.ps1 -BuildInstaller -AllowMissingInnoSetup
```

Erwartung:

- ReleaseGate `-SkipPack` grün.
- Desktop-Publish erfolgreich.
- Desktop-Manifest enthält BAT, README, WebApi-EXE und `wwwroot/index.html`.
- Bei installiertem Inno Setup: Setup-EXE unter `output\installer` plus SHA256 im Manifest.
- Bei fehlendem Inno Setup: Exit 0 mit dokumentiertem Blocker wegen `-AllowMissingInnoSetup`.

## Risiken / Grenzen

- Der echte Installations-/Deinstallationstest bleibt manuell, weil er Windows-UI/Startmenü/Desktop-Verknüpfung betrifft.
- Die Setup-EXE ist unsigniert; SmartScreen-Warnung ist erwartbar.
- Kein Code-Signing, keine Zertifikatskäufe, keine Releases oder Uploads ohne Freigabe.

## Nächster Schritt

Nach grünem RUN-05-Readiness-ZIP: entweder echten Installer auf der Workstation testen, wenn Inno Setup installiert ist, oder RUN-03 frischer Portable-ZIP-Test bzw. RUN-02 Release-Reife-Prüfung fortsetzen.
