# Handoff 0.37.5 - Audit-Journal Query API Reset Fix

## Ziel

v0.37.5 repariert die weiterhin fehlerhafte Program.cs-Syntax aus den vorherigen v0.37.x-Versuchen.

## Umsetzung

- Program.cs wird aus dem letzten gruenen Git-Stand wiederhergestellt.
- Versionen werden auf 0.37.5 gesetzt.
- Der Endpunkt GET /api/tournaments/{id:guid}/audit-journal/query wird als Inline-Minimal-API-Handler eingefuegt.
- Queryparameter werden ueber HttpRequest.Query gelesen.
- Optionale int-/Guid-Parameter werden ueber kleine lokale Helfer geparst.

## Erwartung

- dotnet build gruen.
- dotnet test weiterhin 86/86 gruen.
- Frontend-Build gruen.
- Portable-ZIP SchachTurnierManager_Portable_0.37.5.zip.