# Handoff 0.3.1

## Ergebnis

Stabilisierungspatch für v0.3.0.

## Behoben

- `CrossTableCalculatorTests` und `HeroCupCalculatorTests` verwenden nun `Pairings = new[] { ... }` statt Collection-Initializer auf `IReadOnlyList<Pairing>`.
- `After-Apply-V0.3.ps1` und `Test-All.ps1` prüfen `$LASTEXITCODE` nach externen Befehlen und stoppen zuverlässig bei Fehlern.
- `Start-Dev.ps1` wartet auf Backend und Frontend, bevor der Browser geöffnet wird.

## Lokale Prüfung

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\After-Apply-V0.3.1.ps1"
```

Alternativ:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; dotnet build; dotnet test
Set-Location "D:\Schach\SchachTurnierManager\src\SchachTurnierManager.WebApp"; npm install; npm run build
```

## Nächster Schritt

Nach grünem Build/Test kann v0.4.0 mit Härtung des Schweizer Systems beginnen: Farben, Bye-Regeln, Doppelbegegnungen, Scoregroups, Floater-Audit und manuelle Paarungsänderungen.
