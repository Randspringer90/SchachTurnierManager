# Handoff 0.10.0 - Externe Spielersuche

## Inhalt

- Provider-Struktur für externe Spielerdatenquellen.
- FIDE-Adapter mit direktem Profilabruf per FIDE-ID über `ratings.fide.com/profile/{id}`.
- DSB/DeWIS- und ThSB-Provider als vorbereitete Adapter mit klarer Unsupported-Rückmeldung.
- Neue API-Endpunkte:
  - `GET /api/external-players/providers`
  - `GET /api/external-players/search?source=0&query=4610563`
  - `GET /api/external-players/fide/{fideId}`
- Dashboard-Bereich „Spielerdaten suchen“.
- Suchtreffer können ins Teilnehmerformular übernommen werden.
- Teilnehmerformular wurde um Federation/Land/Rapid-/Blitz-Elo/DWZ-Index erweitert.
- Neue Application-Tests für Lookup-Routing und Mapping.

## Grenzen

- FIDE-Namenssuche ist noch nicht aktiv, weil zunächst eine stabile und rechtlich saubere Suchschnittstelle geprüft werden muss.
- DSB/DeWIS benötigt voraussichtlich API-/Schnittstellenklärung bzw. Registrierung.
- ThSB wird zunächst über DSB/DeWIS-Filterstrategie geplant, solange keine eigene öffentliche ThSB-API hinterlegt ist.

## Nachkontrolle

Ausführen:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\After-Apply-V0.10.ps1"
```

Danach committen:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; git status; git add .; git commit -m "Add external player lookup foundation"; git push
```
