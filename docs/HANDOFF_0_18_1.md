# Handoff 0.18.1 - Pairing-Qualität im Dashboard

## Inhalt

- Fix-Forward für das v0.18.0-Nachkontrollskript.
- `TournamentService.GetPairingQuality(...)` ergänzt.
- API-Endpunkt `GET /api/tournaments/{id}/rounds/{roundNumber}/pairing-quality` ergänzt.
- Dashboard kann pro Runde den Pairing-Qualitätsbericht laden und anzeigen.
- Anzeige enthält Qualitätswert, Schweregrad, Zusammenfassung und brettweise Hinweise.
- Application-Test für den neuen Service-Workflow ergänzt.

## Nachkontrolle

Ausführen:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\After-Apply-V0.18.1.ps1"
```

Danach committen:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; git status; git add .; git commit -m "Show pairing quality reports in dashboard"; git push
```

## Nächster Vorschlag

v0.19.0: Pairing-Qualitätsbericht direkt in den Swiss-Pairing-Audit integrieren und Golden Tests für komplette Turnierverläufe ergänzen.