# Handoff 0.24.1 – Dashboard-Integration der Vorschau-Exports vervollständigt

## Anlass

v0.24.0 wurde nach einem abgebrochenen Apply-Script bereits committed. Backend, Export-Formatter und Tests waren teilweise vorhanden, aber die UI-Erweiterung der Vorschaukarte wurde nicht vollständig angewendet.

## Inhalt

- Version auf 0.24.1 angehoben
- Buttons in der Vorschaukarte ergänzt:
  - Druckansicht öffnen
  - CSV exportieren
- Warnboxen in der Vorschaukarte ergänzt:
  - kritische Vorschau
  - nicht speicherbare Vorschau
- CSS für Vorschau-Warnungen ergänzt
- CHANGELOG nachgetragen
- Portable-Paket wird nach erfolgreicher Prüfung neu gebaut

## Nachkontrolle

- `dotnet restore`
- `dotnet build`
- `dotnet test`
- `npm install`
- `npm run build`
- `scripts\Pack-Portable.ps1`
- `git status --short`