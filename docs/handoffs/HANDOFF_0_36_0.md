# Handoff 0.36.0 – Audit-Journal Query Foundation

## Ziel

v0.36.0 ergänzt eine fachliche Query-/Filter-Schicht für das persistente Audit-Journal. Damit wird der in v0.34 eingeführte Journal-Speicher und die in v0.35 sichtbare Dashboardkarte für spätere Filter-, Review- und Exportfunktionen vorbereitet.

## Enthalten

- `AuditJournalQueryService`
- `AuditJournalQuery`
- `AuditJournalQueryResult`
- `AuditJournalStatistics`
- `AuditJournalSortDirection`
- Regressionstests für:
  - Filter nach Schweregrad und Runde
  - Suche über Summary/Details/Reason/Akteur/Spieler/Aktion
  - Sortierung neueste/älteste zuerst
  - Paging/Truncation
  - Statistikzählungen

## Nicht enthalten

- Keine Änderung an Auslosungslogik
- Keine Änderung an Wertungsberechnung
- Keine Änderung am Speicherformat
- Noch keine neue UI-Filtersteuerung

## Erwartete Nachkontrolle

- Release-Gate grün
- `dotnet test`: ungefähr 86/86 erfolgreich
- `npm run build`: erfolgreich
- Portable Paket: `SchachTurnierManager_Portable_0.36.0.zip`
