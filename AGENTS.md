# AGENTS.md – SchachTurnierManager

## Rolle
Codex arbeitet als vorsichtiger Entwicklungsagent für einen lokalen Schachturnier-Manager.

## Grundregeln
- Qualität vor Geschwindigkeit.
- Erst Ist-Zustand, Build, Tests und Struktur verstehen.
- Keine Pushes, Releases, Deployments, Uploads oder Kostenaktionen ohne ausdrückliche Freigabe.
- Keine Secrets, Tokens, privaten Datenbanken oder Logs committen.
- Lokale Commits sind erwünscht, wenn Build und Tests sauber sind.
- `.git`, `logs`, `output`, `tmp`, Datenbanken und `.env` bleiben außerhalb von Austausch-ZIPs.

## Architektur
- Domain enthält alle fachlichen Regeln: Spieler, Turniere, Paarungen, Wertungen, Rating-Prognosen.
- Application enthält Use Cases und orchestriert Domain-Services.
- Infrastructure enthält später SQLite/EF Core, Import/Export und Dateisystemdetails.
- WebApi stellt lokale HTTP-Endpunkte bereit.
- WebApp ist React/TypeScript/Vite und enthält keine Paarungslogik.

## Aktueller MVP-Scope
- Round Robin / Jeder gegen Jeden.
- Basis-Schweizer-System mit Audit-Hinweis, noch nicht FIDE-Dutch-vollständig.
- Wertungen: Punkte, Siege, Direktvergleich, Buchholz, Buchholz Cut-1, Sonneborn-Berger, Performance, Heldenpokal-Grundlage.
- Armageddon-Zeitgebot-Grundlage.

## Arbeitsweise
- Vor fachlichen Algorithmusänderungen Tests ergänzen.
- Pairing-Entscheidungen müssen auditierbar bleiben.
- Manuelle Overrides später erlauben, aber immer protokollieren.

## Repository-Sicherheit / Open Source
- Dieses private GitHub-Repo bleibt privat; eine spätere öffentliche Veröffentlichung erfolgt nur über einen geprüften Clean Snapshot ohne alte Git-Historie.
- Vor Commits immer staged Dateien anzeigen und prüfen; keine blinden `git add .`-, `git add --all`- oder Massen-Stage-Schritte ohne Sicherheitscheck.
- `.codex`, `.vs`, `output`, `bin`, `obj`, `dist`, `node_modules`, lokale Audits/Backups, Dumps, Logs, ZIPs, Datenbanken, `.env` und Zugangsdaten dürfen nicht in Commits.
- Berufliche/TFS- oder interne Arbeits-Repositories sind besonders restriktiv zu behandeln; Commit-/Push-Automation darf dort nicht automatisch laufen.
- Der wiederverwendbare Skill `.agents/skills/repository-security.md` ist vor Commit-, Push- und Public-Snapshot-Arbeiten zu beachten.
