# Handoff 0.35.0 - Audit Journal Dashboard

## Ziel

0.35.0 macht das in 0.34.x eingeführte persistente Auditjournal im Dashboard sichtbar. Der Turnierleiter soll sofort sehen können, welche Aktionen protokolliert wurden und ob Warn-/kritische Einträge vorhanden sind.

## Änderungen

- Frontend-Typ `AuditJournalEntry` ergänzt.
- `loadDerived(...)` lädt zusätzlich `/api/tournaments/{id}/audit-journal`.
- Neue Dashboardkarte `Audit-Journal` mit Kennzahlen, letzten Einträgen und Warnhinweis.
- Clientseitiger CSV- und JSON-Export des Journals ergänzt.
- CSS für Journal-Karte, Severity-Pills und Tabelle ergänzt.

## Nicht geändert

- Keine Änderung an Auslosungslogik.
- Keine Änderung an Wertungsberechnung.
- Keine Änderung am Speicherformat über das bestehende Auditjournal aus 0.34.x hinaus.

## Erwartung

- `dotnet test`: 81/81 grün.
- `npm run build`: grün.
- `Pack-Portable`: `SchachTurnierManager_Portable_0.35.0.zip`.
