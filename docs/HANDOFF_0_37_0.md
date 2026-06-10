# Handoff 0.37.0 - Audit-Journal Query API

## Ziel

Die in 0.36.x eingeführte Audit-Journal-Query-Schicht wird über die WebApi nutzbar gemacht.

## Änderungen

- Version auf 0.37.0 gesetzt.
- `Program.cs` importiert `SchachTurnierManager.Domain.Services`.
- Neuer Endpunkt:
  - `GET /api/tournaments/{id}/audit-journal/query`
- Query-Parameter:
  - `severity`
  - `action`
  - `roundNumber`
  - `boardNumber`
  - `playerId`
  - `search`
  - `maxResults`
  - `sort`
- Sortierung akzeptiert u. a. `oldest`, `oldestFirst`, `asc`, `ascending`; Standard bleibt neueste zuerst.

## Nicht geändert

- Keine Änderung an Auslosungslogik.
- Keine Änderung an Wertungsberechnung.
- Keine Änderung am Speicherformat.
- Keine UI-Filterleiste. Diese kann in 0.38.x folgen.

## Nachkontrolle

`After-Apply-V0.37.ps1` führt das vorhandene Release-Gate aus.
