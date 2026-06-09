# Handoff 0.29.2

## Ziel

v0.29.2 repariert den fehlerhaften v0.29.1-Zwischenstand.

## Änderung

- Doppelte `openLatestRoundPrint`-Funktion in `src/SchachTurnierManager.WebApp/src/main.tsx` entfernt.
- Versionen auf `0.29.2` gesetzt.
- Changelog ergänzt.

## Erwartete Nachkontrolle

- `dotnet restore`
- `dotnet build`
- `dotnet test`
- `npm install`
- `npm run build`
- `scripts/Pack-Portable.ps1`

## Hinweis

Der Fix ändert keine Fachlogik, keine Auslosungslogik und kein Speicherformat.
