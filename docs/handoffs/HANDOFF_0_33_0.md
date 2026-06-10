# Handoff 0.33.0 - Forfeit/Bye Regression Gate

## Ziel

v0.33.0 ergänzt fachliche Regressionstests für kampflose Ergebnisse und Bye/Spielfrei-Wertungen. Der Patch ändert keine Produktivlogik, sondern schützt bestehendes Verhalten rund um Buchholz, Sonneborn-Berger, Gegnerschnitt und Bye-Siegzählung.

## Inhalt

- Neue Domain-Testdatei `ForfeitByeRegressionGateTests.cs`.
- Regression für `CountForfeitsAsNormalGames`.
- Regression für `CountForfeitOpponentForBuchholzOnly`.
- Regression für `ExcludeForfeitsFromTiebreaks`.
- Regression für `CountByeAsWin` ohne Gegnerwertungs-Effekt.
- Versionen auf `0.33.0` angehoben.
- Keine Änderung an Auslosungslogik, Wertungsberechnung, Speicherformat oder UI.

## Nachkontrolle

Das Script führt das vorhandene Release-Gate aus:

- `dotnet restore`
- `dotnet build`
- `dotnet test`
- `npm install`
- `npm run build`
- `scripts/Pack-Portable.ps1`

## Commit

Empfohlener Commit nach grünem Release-Gate:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Commit-If-Green.ps1" -Message "Add forfeit bye regression gate" -Push
```
