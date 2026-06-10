# Handoff 0.37.1 - Audit-Journal Query API Fix

## Ziel

0.37.1 repariert den fehlgeschlagenen 0.37.0-Patch. Die Ursache war ein zu fragiler Einfügeanker in der einzeilig formatierten `Program.cs`.

## Inhalt

- Version auf 0.37.1 gesetzt.
- `using SchachTurnierManager.Domain.Services;` sichergestellt.
- Endpunkt `GET /api/tournaments/{id}/audit-journal/query` ergänzt.
- Unterstützte Queryparameter: `severity`, `action`, `roundNumber`, `boardNumber`, `playerId`, `search`, `maxResults`, `sort`.
- Fehlerhafte Enum-Werte liefern `400 BadRequest`.
- Unbekannte Turniere liefern `404 NotFound`.

## Nachkontrolle

Das Script führt `scripts/Invoke-ReleaseGate.ps1` aus. Erst bei grünem Gate committen/pushen.
