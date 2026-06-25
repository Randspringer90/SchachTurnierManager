# Rundenaktionen und Turnierverwaltung

Dieser Patch ergänzt die Bedienung für kleine Schweizer Turniere:

- Auslosungsvorschau öffnet zusätzlich als Popup, damit sie nach Klick unten direkt sichtbar ist.
- Scoregruppen-Abweichungen und kritische Qualitätswerte blockieren die nächste Runde nicht hart. Sie werden angezeigt und müssen bewusst bestätigt werden.
- Nur harte Voraussetzungen blockieren weiterhin: kein Turnier, zu wenige aktive Spieler, offene Ergebnisse, geplante Rundenzahl erreicht oder kein Backend-Vorschlag.
- Turnier zurücksetzen entfernt Runden und Ergebnisse, behält aber Teilnehmer und Einstellungen.
- Turnier löschen entfernt das Turnier vollständig aus der lokalen SQLite-Datenbank.

## Test

```powershell
.\scripts\Test-TournamentAdminEndpoints.ps1 -ApiBaseUrl "http://localhost:5088"
```

Wenn DELETE mit 405 oder Reset mit 404 antwortet, läuft noch ein Backend ohne diesen Patch oder `Program.cs` wurde nicht korrekt überschrieben.
