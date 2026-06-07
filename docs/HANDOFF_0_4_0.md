# Handoff 0.4.0

## Zweck

Version 0.4.0 härtet die Schweizer-System-Auslosung, ohne sie bereits als vollständiges FIDE-Dutch-System zu deklarieren.

## Enthalten

- `SwissPairingEngine` arbeitet scoregruppenorientiert und bewertet Kandidaten mit Rematch-, Score-, Farb- und Drittfarbe-Penalties.
- Bye-Vergabe bevorzugt die niedrigste Scoregruppe ohne bisheriges Bye.
- `PairingAudit` enthält nun `ScoreGroups`, `Floaters` und `ColorNotes` zusätzlich zu allgemeinen Meldungen.
- Dashboard zeigt das Rundenaudit je Runde als aufklappbaren Bereich.
- Neue Tests in `SwissPairingEngineAdvancedTests` prüfen Bye-Schutz, Rematch-Vermeidung, Farbpräferenz und Audit.

## Lokale Nachkontrolle

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\After-Apply-V0.4.ps1"
```

## Erwartet

- `dotnet build` erfolgreich.
- `dotnet test` erfolgreich.
- `npm install` und `npm run build` erfolgreich.
- Dashboard unter `http://localhost:5173` zeigt in den Runden Auditdetails an.

## Offene Punkte

- Noch kein vollständiges FIDE-Dutch-System.
- Transpositions-/Exchanges innerhalb von Scoregroups sind noch nicht vollständig implementiert.
- Manuelle Paarungsänderungen mit UI-Protokoll kommen in einem späteren Schritt.
