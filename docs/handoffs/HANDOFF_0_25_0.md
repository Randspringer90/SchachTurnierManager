# Handoff 0.25.0 – Turnierleiter-Exportcenter

## Ziel

v0.25.0 bündelt die inzwischen vorhandenen Export- und Druckfunktionen an einer zentralen Stelle im Dashboard. Das Feature ist bewusst UI-/Workflow-orientiert und nutzt vorhandene geprüfte Backend-Endpunkte, statt die Pairing-Engine erneut anzufassen.

## Inhalt

- Version auf 0.25.0 angehoben
- neues Dashboard-Panel „Turnierleiter-Exportcenter“
- Kennzahlen:
  - Teilnehmer
  - aktive Spieler
  - inaktive/zurückgezogene Spieler
  - Runden
  - offene Bretter
  - kampflose Bretter
- Schnellaktionen:
  - Gesamt-Druckansicht
  - aktuelle Runde drucken
  - Vorschau drucken
  - Teilnehmer CSV
  - Tabelle CSV
  - alle Paarungen CSV
  - aktuelle Paarungen CSV
  - Vorschau CSV
  - Backup JSON
- Warnhinweise für offene Ergebnisse und kritische Vorschauen
- CSS für Exportcenter ergänzt

## Nachkontrolle

Das Apply-Script führt aus:

- `dotnet restore`
- `dotnet build --no-restore`
- `dotnet test --no-build`
- `npm install`
- `npm run build`
- `scripts\Pack-Portable.ps1`
- `git status --short`

## Nächste sinnvolle Schritte

- bestehende alte Import-/Export-Karte ggf. in v0.25.1 verschlanken oder in das Exportcenter integrieren
- danach fachlicher Block: kampflos/Bye/Buchholz-Feinheiten oder weitere Härtung der FIDE-Dutch-Auslosung