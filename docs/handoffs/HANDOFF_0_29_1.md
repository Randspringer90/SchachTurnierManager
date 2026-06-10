# Handoff 0.29.1 - Korrekturjournal-Buildfix

## Ziel

v0.29.1 behebt den TypeScript-Buildfehler aus v0.29.0. Das Panel war vorhanden, aber die abgeleiteten Variablen und Helfer lagen nicht im React-App-Render-Scope.

## Enthalten

- Entfernt falsch platzierte Korrekturjournal-Helfer.
- Fügt die Korrekturjournal-Helfer unmittelbar vor dem Render-Return von `function App()` ein.
- Hebt Versionen auf 0.29.1 an.
- Aktualisiert Changelog und Handoff.

## Nicht geändert

- Keine Änderung der Auslosungslogik.
- Keine Änderung der Wertungsberechnung.
- Keine Änderung am Speicherformat.

## Nachkontrolle

- dotnet restore
- dotnet build
- dotnet test
- npm install
- npm run build
- scripts/Pack-Portable.ps1