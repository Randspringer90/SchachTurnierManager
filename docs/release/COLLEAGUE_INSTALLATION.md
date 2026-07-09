# Kollegeninstallation und Release-Auslieferung

Ziel: Eine Kollegin oder ein Kollege soll den SchachTurnierManager ohne Entwicklerwerkzeuge starten können.

## Standardweg

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-ColleagueInstallReadiness.ps1 -BuildInstaller -AllowMissingInnoSetup
```

Der Lauf erzeugt:

- einen ruhigen Run-Ordner unter `D:\Temp\STM_RUN51_ColleagueInstallReadiness_<Zeitstempel>`,
- ein Upload-ZIP mit Logs und Manifest,
- ein eigenständiges `output\SchachTurnierManager_Kollegenpaket_<Version>.zip`.

## Inhalt des Kollegenpakets

Das Paket enthält je nach lokaler Umgebung:

1. `SchachTurnierManager_Setup_<Version>.exe`, falls Inno Setup verfügbar ist,
2. `SchachTurnierManager_Desktop_<Version>.zip` als Klick-Start-Variante,
3. `SchachTurnierManager_Portable_<Version>.zip` als portable Alternative,
4. `README_START_HIER.txt`,
5. `KOLLEGENPAKET_MANIFEST.txt`,
6. `CHECKSUMS_SHA256.txt`.

## Installation beim Kollegen

Empfohlen:

1. Setup-EXE per Doppelklick starten, falls vorhanden.
2. Sonst Desktop-ZIP vollständig entpacken.
3. `SchachTurnierManager.bat` per Doppelklick starten.
4. Healthcheck prüfen: `http://127.0.0.1:5088/api/health`.
5. Dashboard prüfen: `http://127.0.0.1:5088/`.

## Datenschutz, Secrets und Eigenständigkeit

- Das Release-Paket darf keine Datenbanken, Logs, Dumps, `.npmrc`, `.env`, `.secrets/local/`, `secrets/local/` oder echte Turnierdaten enthalten.
- Das Projekt ist eigenständig. Ein Kollegenpaket darf nicht von anderen lokalen Projekten, Build-Ordnern oder privaten Maschinenpfaden abhängen.
- Falls später KI-Provider oder externe Dienste benötigt werden, werden Secrets pro Benutzer/Rechner lokal über Windows-DPAPI unter `.secrets/local/` gesetzt.
- DPAPI-Dateien sind bewusst nicht portabel und werden nie committet.

## SmartScreen und Signatur

Die Setup-EXE ist aktuell unsigniert. SmartScreen-Warnungen sind erwartbar. Code-Signing ist eine spätere bewusste Entscheidung und darf nicht automatisch beschafft oder ausgelöst werden.

## Abnahmekriterien

- ReleaseGate ist grün.
- SecretSafety ist grün.
- Desktop-Paket ist self-contained.
- Portable-Paket startet aus einem frischen Ordner.
- Kollegenpaket enthält README, Manifest und SHA256-Prüfsummen.
- Optional: Setup-EXE lässt sich installieren, starten und deinstallieren; Turnierdaten unter `%LocalAppData%\SchachTurnierManager` bleiben erhalten.
