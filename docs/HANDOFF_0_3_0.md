# Handoff 0.3.0

## Inhalt

Version 0.3.0 erweitert das persistente MVP zum Turnierleiter-MVP.

Umgesetzt:

- Teilnehmer im Dashboard bearbeiten, aktivieren, pausieren/zurückziehen und löschen bzw. bei vorhandenen Paarungen automatisch zurückziehen.
- Zusätzliche Teilnehmerfelder im UI: Geburtsjahr, Geschlecht, DWZ, Elo, manuelle TWZ, FIDE-ID, DSB-ID, Titel, Status und Notizen.
- Kategorieauswertungen für Frauen, U10/U12/U14/U16/U18/U25 und Senioren.
- Kreuztabelle für gespielte Runden mit Ergebnis aus Sicht des jeweiligen Spielers.
- Heldenpokal-Auswertung auf Basis tatsächlicher Punkte minus erwarteter Punkte gegen Gegner-TWZ.
- CSV-Import/-Export für Teilnehmer.
- JSON-Backup/-Restore für ganze Turniere.
- API-Endpunkte für Kreuztabelle, Kategorien, Heldenpokal und Import/Export.
- Neue Unit-Tests für Kreuztabelle, Kategorien, Heldenpokal und CSV.

## Erwartete lokale Checks

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; dotnet build; dotnet test
Set-Location "D:\Schach\SchachTurnierManager\src\SchachTurnierManager.WebApp"; npm install; npm run build
```

## Einschränkungen

- Die Schweizer-System-Auslosung ist weiterhin eine Basisimplementierung und noch kein vollständiger FIDE-Dutch-Swiss-Algorithmus.
- CSV-Import ist bewusst einfach gehalten: Semikolon-getrennte Teilnehmerlisten mit optionaler Kopfzeile.
- JSON-Restore überschreibt bei gleicher Turnier-ID, wenn `OverwriteExisting=true` gesendet wird.
- Heldenpokal ist derzeit als inoffizielle Vereins-/Sonderwertung implementiert; kampflose Partien und ungeratete Gegner fließen nicht in die Erwartungswertung ein.
