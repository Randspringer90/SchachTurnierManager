# Handoff 0.37.4 - Audit-Journal Query API Syntax Fix

## Ziel

v0.37.4 repariert die gescheiterten v0.37.2/v0.37.3-Versuche fuer den Audit-Journal-Query-Endpunkt.

## Umsetzung

- `Program.cs` wird aus dem letzten gruenen Git-Stand wiederhergestellt.
- Danach wird die Version auf `0.37.4` gesetzt.
- Der Endpunkt `GET /api/tournaments/{id:guid}/audit-journal/query` wird als kurze `MapGet`-Route auf `QueryAuditJournal` gemappt.
- Die eigentliche Query-Logik liegt in einem statischen Handler am Ende der Datei.
- Dadurch bleibt die einzeilige Minimal-API-Datei deutlich weniger anfaellig fuer fehlerhafte Inline-Lambda-Inserts.

## Erwartung

- `dotnet build` gruen.
- `dotnet test` weiterhin 86/86 gruen.
- Frontend-Build gruen.
- Portable-ZIP `SchachTurnierManager_Portable_0.37.4.zip`.