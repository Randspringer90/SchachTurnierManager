# AGENTS.md – SchachTurnierManager

## Rolle
Diese Datei ist die zentrale, providerneutrale Regeldatei für alle KI-Agenten (Codex, Claude Code, künftig Gemini oder lokale Modelle). Jeder Agent arbeitet als vorsichtiger Entwicklungsagent für einen lokalen Schachturnier-Manager. Provider-spezifische Dateien (z. B. `.claude/CLAUDE.md`, `.codex/config.toml`) sind reine Adapter und dürfen keine abweichenden Regeln enthalten; bei Widerspruch gilt diese Datei. Details: `docs/architecture/AI_AGENT_ARCHITECTURE.md`.

## Grundregeln
- Qualität vor Geschwindigkeit.
- Erst Ist-Zustand, Build, Tests und Struktur verstehen.
- Keine Pushes, Releases, Deployments, Uploads oder Kostenaktionen ohne ausdrückliche Freigabe.
- Keine Secrets, Tokens, `.npmrc`, privaten Datenbanken oder Logs committen; lokale Authentifizierung nur über `.secrets/local/` oder Prozess-Environment.
- Lokale Commits sind erwünscht, wenn Build und Tests sauber sind.
- `.git`, `logs`, `output`, `tmp`, Datenbanken, `.env`, `.npmrc`, `.secrets/local/` und `secrets/local/` bleiben außerhalb von Austausch-ZIPs.

## Projektstruktur – wo gehört was hin?
- `AGENTS.md` (Root): verbindliche Agentenregeln, providerneutral.
- `.agents/skills/`: wiederverwendbares Fachwissen für alle Agenten; neues wiederverwendbares Wissen gehört hierhin.
- `.claude/`, `.codex/`: nur dünne Provider-Adapter/lokale Konfiguration, keine Regeln.
- `docs/architecture/`: dauerhafte Architektur- und Fachkonzepte.
- `docs/planning/`: Roadmaps, Tickets, Orchestrierung (`PROJECT_ORCHESTRATION.md`).
- `docs/handoffs/`: historisches Handoff-Archiv, wird nicht mehr gepflegt.
- `scripts/`: aktive Skripte flach (Übersicht in `scripts/README.md`); historische After-Apply-Skripte unter `scripts/archive/after-apply/`.
- `output/`, `logs/`, `tmp/`: lokale Ausgaben, niemals committen; lange Ausgaben gehören nach `output/`.

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
- Externe Toolfehler in PowerShell nie mit Semikolon-Ketten (`a; b; c`) verdecken: Bei `cmd1; git commit` läuft das Commit auch dann, wenn `cmd1` (z. B. ein Safety-Check) fehlschlägt. Für manuelle Abläufe einzelne Befehle nacheinander oder `&&` (nur bei Erfolg weiter) verwenden, oder direkt `scripts/Commit-If-Green.ps1` nutzen, das nach jedem Schritt hart stoppt.
- Security-/Detection-Skripte tragen den Marker `SECURITY-PATTERN-FILE` und dürfen Blocklist-/Credential-Regexe dokumentieren, ohne von den Safety-Checks als Leak gemeldet zu werden.

## KI-Lauf-Standard (2026-07)

LLM-neutral fuer Claude Code, Codex und aehnliche Tools:

- **Lauf-Protokoll**: Prompts, Abschlussberichte und Lessons Learned gehoeren nach
  `docs/ai/` (Skill `ai-run-logging`) und werden mit committet.
- **Modell-Policy**: immer das leistungsstaerkste verfuegbare Claude-/OpenAI-Modell
  gemaess `CORE-KFM-Wissensmanagement\config\model-routing.json` (Qualitaet vor Kosten,
  kein automatischer Downgrade bei riskanten Aufgaben).
- **Internet-Recherche**: fuer zeitkritische Fakten Skill `internet-research` nutzen
  (Websuche des Tools, Proxy beachten, Quellen + Datum dokumentieren).
- **Chat-only-Tools** (ChatGPT/Langdock ohne Dateizugriff): Kontextpaket via
  `CORE-KFM-Wissensmanagement\scripts\New-KnowledgePromptPack.ps1` erzeugen und mitgeben.
- **Wissensmanagement**: global indexiert `CORE-KFM-Wissensmanagement` dieses Projekt
  (AGENTS/README/PLANS/CHANGELOG, `docs/ai/**`, `docs/knowledge/**`, `.agents/**`);
  projektspezifisches Wissen gehoert nach `docs/knowledge/` bzw. `docs/ai/`.


## Release-/Betriebsregeln ab 0.50.0

- Vor Arbeiten an Logging, Secrets, Packaging oder Installation die Skills `.agents/skills/release-operations.md`, `.agents/skills/logging-observability.md`, `.agents/skills/repository-security.md`, `.agents/skills/installer-packaging.md` und `.agents/skills/colleague-installation.md` lesen.
- Projekt bleibt eigenständig: keine Abhängigkeiten auf externe lokale Projekte oder fremde Maschinenpfade.
- Lokale Secrets liegen innerhalb des Projektordners unter `.secrets/local/`, sind DPAPI-verschlüsselt und per `.gitignore` ausgeschlossen.
- Sichtbare Konsole bleibt ruhig; ausführliche Logs gehen in einen eigenen `D:\Temp\<RunName>_<Timestamp>`-Ordner und am Ende in ein Upload-ZIP.
- Für Kollegen-/Vereinsinstallation zählt `scripts/Invoke-ReleaseCandidateReadiness.ps1` als Standardprüfung.

- Fuer Kolleginnen-/Kollegeninstallation ist `scripts/Invoke-ColleagueInstallReadiness.ps1` der Standardlauf: eigenstaendiges Paket, keine externen Projektabhaengigkeiten, keine Secrets im Artefakt.
