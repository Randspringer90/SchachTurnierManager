# RUN-54 Runtime-Logging

Datum: 2026-07-10
Agent: ChatGPT 5.5 Thinking

## Ziel

Ein projektinternes `logs/`-Verzeichnis und eine saubere Laufzeitlog-Anbindung fuer Entwicklung, Desktop-/Kollegeninstallation und portable Pakete ergaenzen.

## Umgesetzt

- `logs/README.md` und `logs/.gitkeep` als Repo-Anker, waehrend echte Logdateien ignoriert bleiben.
- WebApi-File-Logger `BoundedFileLoggerProvider` ohne externe Abhaengigkeit.
- FileLogging-Konfiguration in `appsettings.json` und `appsettings.Development.json`.
- Healthcheck meldet File-Logging-Status, Logordner und Retention.
- Desktop-/Portable-Starter setzen `SchachTurnierManager__LogDirectory`.
- `Invoke-LoggingReadiness.ps1` startet eine isolierte App-Instanz, prueft Health/Dashboard/API und kontrolliert Logdateien/Querystring-Schutz.
- Doku/Skills/Guard-Tests aktualisiert.

## Erwarteter Test

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-LoggingReadiness.ps1 -BuildDesktop
```

Erwartung: `LOGGING_READINESS=OK` und ein `UPLOAD_ZIP=...`.
