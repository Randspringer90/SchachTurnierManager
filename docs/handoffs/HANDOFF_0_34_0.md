# Handoff 0.34.0 - Persistent Audit Journal Foundation

## Ziel

0.34.0 legt die Grundlage für ein dauerhaftes Korrektur- und Auditprotokoll im Turnierzustand.

## Enthalten

- Neues Domain-Modell `AuditJournalEntry` inklusive `AuditJournalAction` und `AuditJournalSeverity`.
- `TournamentState` enthält nun `AuditJournal` als persistierbare Liste.
- `TournamentService` protokolliert zentrale Aktionen:
  - Turnier anlegen/importieren
  - Einstellungen ändern
  - Spieler anlegen/ändern/Status ändern/löschen bzw. zurückziehen
  - externe Spielerdaten übernehmen
  - Runde auslosen
  - Ergebnis eintragen
  - Paarung manuell überschreiben
  - Runde sperren/entsperren/geprüft/ungeprüft markieren
- Neuer API-Endpunkt `GET /api/tournaments/{id}/audit-journal`.
- Neue Application-Regressionstests für Audit-Journal-Workflows.

## Nicht enthalten

- Noch keine eigene UI-Karte für das persistente Auditjournal.
- Noch kein Benutzer-/Login-Konzept; Actor ist vorerst `Turnierleitung`.
- Keine Änderung an Auslosung, Wertung oder Speicherformat außer der neuen optionalen State-Liste.

## Nachkontrolle

Das Release-Gate muss grün sein:

- `dotnet restore`
- `dotnet build`
- `dotnet test`
- `npm install`
- `npm run build`
- `scripts/Pack-Portable.ps1`

## Nächster sinnvoller Schritt

0.35.0 kann die neue persistente Auditjournal-Liste im Dashboard anzeigen und später filterbar/exportierbar machen.
