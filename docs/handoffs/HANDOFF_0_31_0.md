# Handoff 0.31.0 - Swiss-Regression-Szenarien

## Ziel

v0.31.0 ergänzt zusätzliche Regressionstests für echte Turniersituationen, damit die zuletzt stark gewachsene Dashboard-/Export-/Audit-Oberfläche nicht über rote Zwischenstände oder unbemerkte Pairing-Nebenwirkungen instabil wird.

## Enthalten

- Neues Testfile `tests/SchachTurnierManager.Application.Tests/SwissRegressionScenarioTests.cs`.
- Regression für ungerade Schweizer-System-Turniere mit Bye und temporärer Auslosungsvorschau.
- Regression für kampflose Ergebnisse inklusive Rundenabschluss und Diagnosewirkung.
- Regression für Rückzug nach gespielter Runde: zurückgezogene Spieler dürfen in der nächsten Vorschau nicht mehr gepaart werden.
- Versionen auf `0.31.0` angehoben.

## Nicht enthalten

- Keine Änderung an Auslosungslogik.
- Keine Änderung an Wertungsberechnung.
- Kein persistentes Audit-Log.
- Keine UI-Erweiterung.

## Nachkontrolle

Das vorhandene Release-Gate führt Restore, Build, Tests, Frontend-Build und Portable-Paketierung aus.
