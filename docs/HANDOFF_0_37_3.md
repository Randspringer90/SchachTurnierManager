# Handoff 0.37.3 - Audit-Journal Query API Syntax Fix

## Ziel

0.37.3 repariert den fehlgeschlagenen 0.37.2-Stand. In 0.37.2 wurde der Audit-Journal-Query-Endpunkt syntaktisch ungünstig in Program.cs eingefügt, wodurch der WebApi-Build mit CS1001 fehlschlug.

## Inhalt

- Version auf 0.37.3 gesetzt.
- Bereits eingefügte fehlerhafte Audit-Journal-Query-Endpunkte werden textuell entfernt.
- using SchachTurnierManager.Domain.Models; und using SchachTurnierManager.Domain.Services; werden sichergestellt.
- GET /api/tournaments/{id:guid}/audit-journal/query wird neu eingefügt.
- Queryparameter werden über HttpRequest gelesen, damit die Minimal-API-Signatur robust bleibt.
- Unterstützte Parameter: severity, action, roundNumber, boardNumber, playerId, search, maxResults, sort.
- Ungültige Enum-/Zahlen-/Guid-Werte liefern 400 BadRequest.
- Unbekannte Turniere liefern 404 NotFound.

## Nachkontrolle

Das Script führt scripts/Invoke-ReleaseGate.ps1 aus. Erst bei grünem Gate committen/pushen.
