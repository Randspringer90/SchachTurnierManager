# Skill: Logging und Observability

Ziel: Lokale Turnierleiter sollen Fehler verstehen können, ohne Debugger oder Entwicklerwerkzeuge.

## Regeln

- Logging-Level werden über `appsettings.json`, `appsettings.Development.json` und Environment-Konfiguration gesteuert.
- Standard: `SchachTurnierManager=Information`, Framework/EF auf `Warning`, Development auf `Debug`.
- HTTP-Logging enthält Methode, Pfad ohne Querystring, Statuscode und Laufzeit. Keine Querystrings, Tokens, Secrets oder Personendaten loggen.
- Lange Build-/Test-Ausgaben gehören in Run-Logs unter `D:\Temp`, nicht in die sichtbare Konsole.
- Scripts sollen kurze Statuszeilen und am Ende `UPLOAD_ZIP=...` ausgeben.

## Prüfpunkte

- `scripts/Invoke-ReleaseGate.ps1` grün.
- `scripts/Invoke-SecretSafetyReadiness.ps1` grün.
- `tests/SchachTurnierManager.Application.Tests/OperationalGuardTests.cs` grün.
