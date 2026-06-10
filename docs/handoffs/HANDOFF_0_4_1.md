# Handoff 0.4.1

Version 0.4.1 ist ein kleiner Stabilisierungspatch für den lokalen Entwicklerstart.

## Grund

Der v0.4-Stand war fachlich grün, aber `scripts/Start-Dev.ps1` meldete gelegentlich, dass das Frontend nach 30 Sekunden nicht erreichbar sei, obwohl Vite im Frontend-Fenster bereits auf `http://127.0.0.1:5173/` lief. Ursache ist sehr wahrscheinlich die Kombination aus Vite-Bindung an `127.0.0.1` und Prüfung auf `localhost`, das unter Windows je nach Umgebung zuerst IPv6 auflösen kann.

## Änderungen

- `Start-Dev.ps1` nutzt für das Frontend konsistent `http://127.0.0.1:5173`.
- Vite-Konfiguration bindet explizit an `127.0.0.1`.
- Der Proxy zeigt auf `http://127.0.0.1:5088`.
- WebApi-CORS erlaubt zusätzlich `http://127.0.0.1:5173`.
- Startskript wartet 60 Sekunden und zeigt den letzten Verbindungsfehler an.

## Prüfung

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\After-Apply-V0.4.1.ps1"
```

Danach:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Start-Dev.ps1"
```
