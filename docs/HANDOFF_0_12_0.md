# Handoff 0.12.0 - Externe Spielerdaten anwenden und Dublettenprüfung

## Ziel

Der Stand ergänzt den Workflow rund um externe Spielerdaten. Gefundene FIDE-/DSB-/ThSB-Profile können jetzt nicht nur ins Formular übernommen werden, sondern auch direkt als neuer Teilnehmer gespeichert oder auf einen bestehenden Teilnehmer angewendet werden.

## Umgesetzt

- Neue Domain-Modelle für Dublettenprüfung und Apply-Ergebnis.
- Neuer `ExternalPlayerImportService` mit Matching-Regeln:
  - FIDE-ID: sicherer Treffer
  - DSB-/National-ID: sicherer Treffer
  - Name + Geburtsjahr: wahrscheinlicher Treffer
  - Name-only: Hinweis, aber kein sicherer Treffer
- `TournamentService` kann externe Profile prüfen, neue Teilnehmer anlegen oder bestehende Teilnehmer aktualisieren.
- Neue API-Endpunkte:
  - `POST /api/tournaments/{id}/external-players/check-duplicates`
  - `POST /api/tournaments/{id}/external-players/apply`
- Dashboard zeigt mögliche Dubletten je externem Treffer und bietet Aktionen:
  - Ins Formular übernehmen
  - Dubletten prüfen
  - Als neuen Teilnehmer speichern
  - bestehenden Teilnehmer ergänzen
  - bestehenden Teilnehmer mit externen Daten überschreiben
- Tests für FIDE-ID-, Name+Geburtsjahr-Dubletten, Neuanlage und Aktualisierung.

## Nachkontrolle

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\After-Apply-V0.12.ps1"
```

Danach committen:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; git status; git add .; git commit -m "Add external player duplicate checks and apply workflow"; git push
```

## Nächster Schritt

- DSB/DeWIS konkreter modellieren.
- Offizielle API-/Registrierungsfrage klären.
- Externe Trefferkonflikte im UI noch detaillierter anzeigen.
