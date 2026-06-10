# Handoff 0.38.0 - README und Safe Commit Guard

## Ziel

Der GitHub-Einstieg und der Commit-Prozess wurden abgesichert.

## Umsetzung

- README ersetzt und auf aktuellen Stand bis 0.37.6 gebracht.
- `.gitignore` um Artefakt-/Secret-/Dump-/Log-Regeln erweitert.
- `scripts/Test-GitCommitSafety.ps1` neu eingefuehrt.
- `scripts/Commit-If-Green.ps1` ersetzt und um Sicherheitspruefungen erweitert.

## Ergebnispruefung

Nach dem Patch muss das Release-Gate gruen sein. Vor jedem Commit zeigt der Guard die geaenderten und die tatsaechlich gestagten Dateien an. Der Commit bricht ab, wenn verbotene Artefakte oder typische Secret-Muster gefunden werden.

## Erwartung

- `dotnet test`: 86/86 erfolgreich
- `npm run build`: erfolgreich
- `Pack-Portable`: erfolgreich
- README auf GitHub zeigt nicht mehr den alten 0.12.0-Stand