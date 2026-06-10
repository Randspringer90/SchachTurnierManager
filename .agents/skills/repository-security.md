# Skill: Repository- und Commit-Sicherheit

Ziel: Commits, private GitHub-Arbeit und spätere Open-Source-Veröffentlichung so absichern, dass keine privaten Artefakte, lokalen Konfigurationen oder Zugangsdaten versehentlich veröffentlicht werden.

## Grundregeln

- Vor jedem Commit `git status --short` und danach `git diff --cached --name-status` prüfen.
- Keine blinden `git add .`, `git add --all` oder Massen-Stage-Schritte verwenden, solange die geänderten Dateien nicht angezeigt und geprüft wurden.
- Commit-Automation darf nur explizit geprüfte Pfade stagen.
- Pushes sind nur nach Freigabe erlaubt; berufliche/TFS- oder interne Arbeits-Repositories werden nie automatisch gepusht.

## Blockierte Inhalte

Immer blockieren:

- lokale Tool-Konfigurationen wie `.codex` und IDE-Ordner wie `.vs`
- Build- und Frontend-Artefakte wie `bin`, `obj`, `dist`, `node_modules`
- lokale Audits, Backups, Reports, Dumps, Logs, ZIPs, Datenbanken und temporäre Ausgaben
- `.env`, private Schlüssel, Zertifikate, Tokens, API-Keys und Package-Registry-Zugangsdaten
- interne Registry-/TFS-/Arbeitsprojekt-Referenzen in öffentlich vorgesehenen Snapshots

## Private Entwicklung vs. Open Source

- Das private GitHub-Repo darf für Entwicklung weiter genutzt werden.
- Das bestehende Repo darf nicht direkt öffentlich geschaltet werden, solange die private Historie Altlasten enthalten kann.
- Für Public Release wird ein Clean Snapshot ohne `.git`-Historie erzeugt und separat geprüft.
- Der Snapshot-Report muss vor Veröffentlichung nachvollziehbar zeigen, welche Dateien enthalten und ausgeschlossen wurden.

## Empfohlener Ablauf

1. Arbeitsbaum prüfen.
2. Release-Gate ausführen.
3. Commit-Safety-Check vor Stage ausführen.
4. Nur geprüfte Pfade explizit stagen.
5. Staging anzeigen und Safety-Check erneut ausführen.
6. Commit lokal erstellen.
7. Push nur nach bewusster Freigabe.
8. Public Release nur über Clean-Snapshot-Skript und separaten Sicherheitsreport.
