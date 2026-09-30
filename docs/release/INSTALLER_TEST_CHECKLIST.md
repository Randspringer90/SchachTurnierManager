# Installer-Testcheckliste (RUN-05)

Ziel: Nachweis, dass die Desktop-/Installer-Variante auf einem Windows-Rechner ohne Entwicklerwerkzeuge nutzbar ist.

## Vorbedingungen

- Repository ist sauber synchronisiert.
- Release-Gate `-SkipPack` ist gruen.
- `scripts/Publish-DesktopApp.ps1 -NoZip` erstellt `output/desktop` erfolgreich.
- Optional: Inno Setup 6 ist lokal installiert und `ISCC.exe` ist im PATH oder unter einem Standardpfad auffindbar.

## Automatischer Readiness-Lauf

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-InstallerReadiness.ps1 -BuildInstaller -AllowMissingInnoSetup
```

Der Lauf erstellt einen Ordner unter `D:\Temp\STM_RUN05_InstallerReadiness_<Zeit>` und am Ende ein ZIP mit Logs, Manifesten, Git-Status und Diff-Stat.

## Manueller Installationstest

1. Setup-EXE aus `output/installer` starten.
2. Installation ohne Adminrechte durchführen.
3. App über Desktop- oder Startmenü-Verknüpfung starten.
4. Dashboard muss unter `http://127.0.0.1:5088/` erreichbar sein.
5. Testturnier mit synthetischen Spielern anlegen.
6. App schließen und erneut starten; Testturnier muss erhalten bleiben.
7. Deinstallieren.
8. Prüfen: `%LocalAppData%\SchachTurnierManager` bleibt erhalten.
9. Testdaten manuell löschen, wenn nicht mehr gebraucht.
10. Bei einem Entwicklungsbuild SmartScreen-Hinweis dokumentieren. Bei einem Produktionskandidaten `Get-AuthenticodeSignature` prüfen: Status `Valid`, erwarteter Signer-Thumbprint.
11. Update-Manifest unter `output\release` mit `Test-ReleaseUpdateManifest.ps1` gegen die gebauten Artefakte validieren.

## Abnahmekriterien

- Desktop-Paket vollständig: BAT, README, WebApi-EXE und `wwwroot/index.html` vorhanden.
- Installer-EXE vorhanden, falls Inno Setup installiert ist.
- SHA256/Größe der Setup-EXE im Run-ZIP dokumentiert.
- Produktionskandidat: Setup-EXE sowie Desktop-/Portable-Apphost gültig Authenticode-signiert; Update-Manifest `manual-only` und Hashprüfung grün.
- Datenpersistenz nach Neustart nachgewiesen.
- Deinstallation löscht keine Turnierdaten.
