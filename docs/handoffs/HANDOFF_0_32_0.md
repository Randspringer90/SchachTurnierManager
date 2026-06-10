# Handoff 0.32.0 - Swiss-Regression-Gate

## Ziel

v0.32.0 ergänzt zusätzliche Domain-Regressionstests für grundlegende Swiss-Pairing-Invarianten und bereinigt die xUnit-Analyzer-Warnung aus v0.31.0.

## Inhalt

- Neue Tests in `SwissPairingRegressionGateTests`:
  - erste Runde mit gerader Teilnehmerzahl: jeder Spieler genau einmal, keine Bye-Paarung, fortlaufende Brettnummern,
  - erste Runde mit ungerader Teilnehmerzahl: genau ein Bye, alle Spieler genau einmal,
  - zweite Runde nach entschiedener erster Runde: keine direkten Rematches, keine kritische Pairing-Qualität, jeder aktive Spieler genau einmal.
- xUnit2031-Warnung in `SwissRegressionScenarioTests` wird bereinigt.
- Keine Änderung an Auslosungslogik, Wertungsberechnung oder Speicherformat.

## Nachkontrolle

Das vorhandene Release-Gate muss grün laufen:

- `dotnet restore`
- `dotnet build`
- `dotnet test`
- `npm install`
- `npm run build`
- `Pack-Portable.ps1`
