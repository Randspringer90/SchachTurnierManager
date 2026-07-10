# Skill: Runtime Logging

Nutzen, wenn Laufzeitlogging, Fehlerdiagnose, App-Start, Kollegeninstallation oder Release-Smoke-Tests betroffen sind.

## Zielbild

- Entwicklungslaeufe schreiben nach `logs/` im Projekt, ohne generierte Logdateien zu committen.
- Desktop-/Kollegeninstallationen schreiben nach `%LocalAppData%\SchachTurnierManager\logs`.
- Portable Pakete schreiben nach `logs\` neben dem Starter.
- Lange Build-/Testlogs bleiben weiterhin in `D:\Temp\<RunName>_<Timestamp>` und werden als Upload-ZIP gebuendelt.

## Regeln

- Niemals Querystrings, Tokens, API-Keys, `.npmrc`-Inhalte oder echte Teilnehmerlisten in Logs schreiben.
- HTTP-Logging nur mit Methode, Pfad ohne Querystring, Statuscode und Laufzeit.
- LogLevel ueber `appsettings*.json` und Environment-Konfiguration steuern.
- `logs/README.md` und `logs/.gitkeep` duerfen ins Repo; `*.log` nicht.
- Vor Release-/Installationsaenderungen `scripts/Invoke-LoggingReadiness.ps1` oder einen umfassenderen Release-/ClickInstall-Lauf ausfuehren.

## Pruefpunkte

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-LoggingReadiness.ps1 -BuildDesktop
```

Erwartung: `LOGGING_READINESS=OK` und genau ein `UPLOAD_ZIP=...`.
