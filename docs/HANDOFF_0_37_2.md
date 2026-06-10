# Handoff 0.37.2 - Audit-Journal Query API Fix

## Ziel

0.37.2 repariert den fehlgeschlagenen 0.37.1-Fix. Ursache war ein PowerShell-Parserfehler durch Backticks in einer doppelt gequoteten Here-String-Zeichenkette.

## Inhalt

- Version auf 0.37.2 gesetzt.
- using SchachTurnierManager.Domain.Models; sichergestellt.
- using SchachTurnierManager.Domain.Services; sichergestellt.
- Endpunkt GET /api/tournaments/{id:guid}/audit-journal/query ergänzt.
- Unterstützte Queryparameter: severity, action, roundNumber, boardNumber, playerId, search, maxResults, sort.
- Fehlerhafte Enum-Werte liefern 400 BadRequest.
- Unbekannte Turniere liefern 404 NotFound.

## Nachkontrolle

Das Script führt scripts/Invoke-ReleaseGate.ps1 aus. Erst bei grünem Gate committen/pushen.
