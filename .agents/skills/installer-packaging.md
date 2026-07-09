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
