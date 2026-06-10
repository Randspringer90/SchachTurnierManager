# Handoff 0.37.6 - Audit-Journal Query API Inline Fix

## Ziel

v0.37.6 repariert die fehlerhafte Program.cs-Syntax aus den vorherigen v0.37.x-Versuchen.

## Umsetzung

- Program.cs wird aus dem letzten gruenen Git-Stand wiederhergestellt.
- Versionen werden auf 0.37.6 gesetzt.
- Der Endpunkt GET /api/tournaments/{id:guid}/audit-journal/query wird als Inline-Minimal-API-Handler eingefuegt.
- Es werden keine separaten Hilfsfunktionen in Program.cs ergaenzt, um Top-Level-/Local-Function-Syntaxprobleme zu vermeiden.

## Erwartung

- dotnet build gruen.
- dotnet test weiterhin 86/86 gruen.
- Frontend-Build gruen.
- Portable-ZIP SchachTurnierManager_Portable_0.37.6.zip.