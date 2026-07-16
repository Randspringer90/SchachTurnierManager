# KI-Agentenarchitektur

Stand: 0.38.7. Dieses Dokument beschreibt, wie KI-Agenten (Codex, Claude Code, künftig Gemini oder lokale Modelle) in diesem Repository arbeiten. Es ist bewusst providerneutral: Der ausführende Agent ist austauschbar, Regeln und Wissen bleiben gleich.

> **Kollaboration & Sicherheit (2026-07-12):** KI-Agenten unterliegen denselben Branch-/PR-Regeln wie Menschen (`docs/planning/BRANCHING_STRATEGY.md`). Modellrouting ist repo-intern in `config/model-routing.json` (keine externe Projektabhängigkeit mehr). Prompt-Injection- und Owner-Review-Regeln: `docs/security/CONTRIBUTOR_SECURITY.md`.

## Ebenenmodell

```text
AGENTS.md                  projektweite, verbindliche Regeln (providerneutral)
.agents/skills/            wiederverwendbares Fachwissen (providerneutral)
.claude/, .codex/, ...     dünne Provider-Adapter, nur Verweise, keine eigenen Regeln
docs/architecture/         dauerhafte Architektur-Entscheidungen
docs/planning/             Orchestrierung, Roadmaps, Prozesse
scripts/                   ausführbare Gates und Werkzeuge (Quelle der Wahrheit für Abläufe)
```

## Providerneutrale Agentenregeln

- `AGENTS.md` im Repo-Root ist die einzige verbindliche Regeldatei für alle Agenten. Widersprüche zwischen Provider-Dateien und `AGENTS.md` werden zugunsten von `AGENTS.md` aufgelöst.
- Provider-spezifische Dateien (`.claude/CLAUDE.md`, `.codex/config.toml`) sind reine Adapter: Sie verweisen auf `AGENTS.md` und `.agents/skills/`, definieren aber keine eigenen oder abweichenden Regeln.
- `.codex/` ist lokal und git-ignoriert; `.claude/CLAUDE.md` ist als Adapter versioniert.

## Ausführende Agenten (austauschbar)

Codex, Claude Code, Gemini oder lokale Modelle sind gleichberechtigte Ausführende. Erwartungen an jeden Agenten:

1. `AGENTS.md` lesen und befolgen.
2. Vor fachlicher Arbeit den passenden Skill unter `.agents/skills/` lesen (z. B. `pairing-engine.md` vor Pairing-Änderungen).
3. Abläufe über die vorhandenen Skripte ausführen, nicht nachbauen (Release-Gate, CommitGuard, Snapshot).
4. Lange Ausgaben nach `output/` schreiben, nicht in die Konsole.

## Skills als gemeinsame Wissensebene

`.agents/skills/*.md` enthält wiederverwendbares Fachwissen pro Themengebiet (Pairing, Wertungen, Tiebreaks, Import/Export, Packaging, UI, Repository-Sicherheit). Skills sind providerneutral formuliert, damit jeder Agent sie ohne Übersetzung nutzen kann. Neues, wiederverwendbares Wissen gehört in einen Skill, nicht in Provider-Dateien.

## Security-Agent als Pflicht-Gate

Repository-Sicherheit ist organisatorisch verankert (technischer Deep-Dive folgt in einem separaten Lauf):

- Skill `.agents/skills/repository-security.md` ist vor Commit-, Push- und Snapshot-Arbeiten verbindlich.
- `scripts/Test-GitCommitSafety.ps1` läuft als Pflicht-Gate in `scripts/Commit-If-Green.ps1` vor und nach dem Staging; kein blindes `git add .`/`git add --all`.
- `scripts/Test-RepositoryOpenSourceSafety.ps1` prüft alle getrackten Dateien als Public-Snapshot-Kandidaten und schreibt Reports nach `output/repo-open-source-safety/`.

## Pull-Request-Reviewer

Der manifestierte `Pull-Request-Reviewer` arbeitet in seiner Initialphase ausschließlich
read-only/static-only. Seine fünf Skills trennen allgemeine PR-Security, Dependency-Delta,
Malware-Risiko, sichere Adoption und Contributor-Feedback. Effektive Toolrechte sind auf
Read/Grep/Glob und kontrolliertes GitHub-Metadatenlesen begrenzt; Restore, Build, Test,
Installation, Secretzugriff, Merge und Push sind verboten.

Er erzeugt höchstens `SAFE_FOR_ISOLATED_BUILD`. Erst der separat manifestierte
`Pull-Request-Integrator` darf nach Owner-Freigabe vom aktuellen `origin/development` beginnen,
nur genehmigte Teile übernehmen und die freigegebenen Tests ausführen. Auch der geprüfte
Integrationsstand erhält niemals Zugriff auf T5. Trust- und Komponentenmodell:
[`PULL_REQUEST_TRUST_BOUNDARIES.md`](PULL_REQUEST_TRUST_BOUNDARIES.md) und
[`PULL_REQUEST_INTEGRATION_ARCHITECTURE.md`](PULL_REQUEST_INTEGRATION_ARCHITECTURE.md).

## Keine Release-Freigabe ohne History-/Snapshot-Entscheidung

Das Repository ist bereits öffentlich; der aktuelle Arbeitsstand ist vorwärts bereinigt, die
alte Historie bleibt jedoch der dokumentierte Owner-Blocker STM-SEC-004. Ein optionaler Clean
Snapshot entsteht nur über `scripts/New-OpenSourceSnapshot.ps1` aus getrackten Dateien eines
sauberen Arbeitsbaums, ohne `.git`-Historie und mit Sicherheitsreport. History-Rewrite,
Repository-Neuanlage oder Release erfolgen nicht automatisch und brauchen eine separate
Owner-Entscheidung sowie Prüfung auf einem frischen Klon.
