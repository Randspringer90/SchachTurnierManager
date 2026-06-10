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

## Trigger (wann dieser Skill verpflichtend gilt)

- Jeder **Commit** in dieses Repo.
- Jeder **Push** (zusätzlich bewusste Freigabe nötig).
- Jedes **Release** / Paketieren.
- Jeder **Public Snapshot** / jede geplante Veröffentlichung.
- Änderung an `package-lock.json`, NuGet-Konfiguration (`*.csproj`, `Directory.Packages.props`, `nuget.config`), `.npmrc` oder CI-Dateien.
- Änderung an Agenten-/Config-Dateien (`AGENTS.md`, `.agents/**`, `.codex/**`, `.claude/**`, Skripte unter `scripts/`).

## Stop-Regeln (harter Abbruch)

- Verbotener Pfad in Worktree/Staging/Tracked (`.codex`, `.vs`, `output`, `bin`, `obj`, `dist`, `node_modules`, lokale Audits/Backups, Logs, Dumps, ZIPs, DBs, `.env`, Keys/Zertifikate).
- Interne Referenz (`tfs.fwdev`, `eckdservice`, `_packaging`, `ITM_KFM`, interne Registry-/Feed-URLs) in Inhalt.
- Typisches Token-/Key-Muster in neu hinzugefügtem Inhalt.
- Arbeits-/TFS-Remote erkannt: keine Commit-/Push-Automation.
- Externer Toolfehler (Safety-Check, Release-Gate) -> **niemals** weiter committen.

## Marker für Detection-/Pattern-Quellen

- Eigene Security-/Snapshot-Skripte enthalten bewusst Blocklist-/Credential-Regexe. Sie tragen den Marker `SECURITY-PATTERN-FILE` und werden von den Safety-Checks nicht als Leak gewertet.
- Der Marker gilt nur für Dateien unter `scripts/` oder `.agents/skills/`. Echte Projekt-/Config-Dateien werden weiterhin vollständig gescannt.

## PowerShell: keine Semikolon-Ketten um Toolfehler

- `cmd1; git commit` committet auch dann, wenn `cmd1` (z. B. ein Safety-Check) fehlschlägt — Semikolon trennt nur, prüft keinen Exitcode.
- Für manuelle Abläufe: einzelne Befehle nacheinander, oder `&&` (nur bei Erfolg weiter), oder `scripts/Commit-If-Green.ps1` (stoppt nach jedem Schritt hart).

## Empfohlener Ablauf

1. Arbeitsbaum prüfen (`git status --short`).
2. Release-Gate ausführen.
3. Commit-Safety-Check vor Stage ausführen.
4. Nur geprüfte Pfade explizit stagen (kein `git add .` / `--all`).
5. Staging anzeigen (`git diff --cached --name-status`) und Safety-Check erneut ausführen.
6. Commit lokal erstellen.
7. Push nur nach bewusster Freigabe.
8. Public Release nur über `scripts/New-OpenSourceSnapshot.ps1` (Clean Snapshot ohne `.git`) plus `scripts/Test-RepositoryOpenSourceSafety.ps1` und separaten Sicherheitsreport.
