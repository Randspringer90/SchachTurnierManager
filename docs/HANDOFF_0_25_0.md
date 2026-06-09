# Handoff 0.25.0 – Turnierleiter-Exportcenter

## Ziel

v0.25.0 bündelt die vorhandenen Export- und Druckfunktionen an einer zentralen Stelle im Dashboard. Das Feature ist UI-/Workflow-orientiert und nutzt vorhandene Backend-Endpunkte.

## Inhalt

- Version auf 0.25.0
- neues Dashboard-Panel „Turnierleiter-Exportcenter“
- Kennzahlen zu Teilnehmern, aktiven/inaktiven Spielern, Runden, offenen Brettern und kampflosen Brettern
- Schnellaktionen für Gesamt-Druckansicht, aktuelle Runde, Vorschau, CSV-Exporte und Backup JSON
- Warnhinweise für offene Ergebnisse und kritische Vorschauen
- CSS für Exportcenter

## Nachkontrolle

- dotnet restore
- dotnet build --no-restore
- dotnet test --no-build
- npm install
- npm run build
- scripts\Pack-Portable.ps1
- git status --short
