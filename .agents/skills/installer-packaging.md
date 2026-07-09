# Skill: Installer und Packaging

Ziel: Später portable ZIP und Windows-Installer.

Regeln:
- Erst portable Version, dann Setup.
- Keine Datenbanken/Logs in Release-ZIP.
- Startskripte robust und verständlich.
- AppData-/Datenpfade später konfigurierbar.


## Stand 0.8.0

- `scripts/Pack-Portable.ps1` baut Frontend und Backend in ein portables Paket.
- Das Backend hostet das React-Dashboard aus `wwwroot`; normale Nutzer brauchen keinen separaten Vite-Prozess.
- `Start-SchachTurnierManager.bat` startet die lokale API auf `127.0.0.1:5088` und öffnet das Dashboard.
- Daten liegen portable unter `data\SchachTurnierManager.sqlite`, wenn die Start-BAT genutzt wird.
- Keine Installer-/Release-Aktionen ohne explizite Freigabe.


## Stand 0.43.0

- `scripts/Invoke-InstallerReadiness.ps1` ist der Standard fuer RUN-05: ruhiger Run-Ordner unter `D:\Temp`, Desktop-Publish, Manifestpruefung und optionaler Inno-Setup-Build.
- Inno Setup wird nicht automatisch installiert; fehlendes `ISCC.exe` ist ein dokumentierter Blocker, kein Grund fuer Downloads/Kostenaktionen.
- Manuelle Installationstests muessen Datenpersistenz unter `%LocalAppData%\SchachTurnierManager`, Uninstaller-Verhalten und SmartScreen-Hinweis pruefen.

## Stand 0.50.0

- Release-Kandidaten werden mit `scripts/Invoke-ReleaseCandidateReadiness.ps1` geprüft.
- Für Kollegeninstallation ist `output/desktop/SchachTurnierManager.bat` aktuell der sichere Klick-Start; echte Setup-EXE folgt, sobald Inno Setup lokal verfügbar ist.
- Das Release-Artefaktmanifest enthält SHA256-Prüfsummen für ZIP-/EXE-Dateien.
- Installer/ZIP dürfen keine Datenbanken, Logs, `.secrets`, `.npmrc`, `.env` oder echten Turnierdaten enthalten.

## Stand 0.51.0

- `scripts/Invoke-ColleagueInstallReadiness.ps1` erzeugt ein eigenstaendiges Kollegenpaket mit Desktop-ZIP, Portable-ZIP, optionaler Setup-EXE, README, Manifest und SHA256-Pruefsummen.
- Ziel ist die Weitergabe an Kolleginnen/Kollegen ohne Entwicklerwerkzeuge und ohne Abhaengigkeit zu anderen lokalen Projekten.
- Fehlendes Inno Setup bleibt mit `-AllowMissingInnoSetup` ein dokumentierter Blocker; Desktop-ZIP und Portable-ZIP bleiben trotzdem auslieferbar.
