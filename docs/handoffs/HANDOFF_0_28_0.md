# Handoff 0.28.0 - Auslosungsfreigabe / Pairing-Readiness

## Ziel

v0.28.0 ergänzt im Dashboard eine Turnierleiter-Checkliste zur Freigabe der nächsten Auslosung. Der Block macht vor Vorschau, Aushang oder echter Auslosung sichtbar, ob noch offene Ergebnisse, ungeprüfte vollständige Runden, zu wenige aktive Spieler oder kritische Vorschauhinweise existieren.

## Umfang

- Versionen auf `0.28.0` angehoben.
- Neues Dashboard-Panel `Auslosungsfreigabe` ergänzt.
- Pairing-Readiness-Helfer im Frontend ergänzt.
- Status-Badge `bereit`, `blockiert`, `prüfen`, `kein Turnier` ergänzt.
- Schnellaktionen für Auslosungsvorschau, nächste Runde auslosen, aktuelle Runde drucken und Turnierbericht ergänzt.
- CSS für das Freigabe-Panel ergänzt.

## Nachkontrolle

Das Apply-Script führt aus:

- `dotnet restore`
- `dotnet build`
- `dotnet test`
- `npm install`
- `npm run build`
- `scripts/Pack-Portable.ps1`
- `git status --short`

## Hinweis

Die Auslosungslogik und Wertungsberechnung bleiben unverändert. v0.28.0 ist ein Dashboard-/Workflow-Feature zur besseren Turnierleiter-Sicherheit.
