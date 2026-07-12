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

## Keine öffentlichen Releases ohne Clean Snapshot

Das private Entwicklungsrepo wird nie direkt öffentlich geschaltet. Public Release nur über `scripts/New-OpenSourceSnapshot.ps1`: Snapshot aus getrackten Dateien eines cleanen Arbeitsbaums, ohne `.git`-Historie, ohne `docs/handoffs/`, ohne `scripts/archive/`, mit Sicherheits-Report. Vor einem echten Release wird der Snapshot auf einem frischen Klon geprüft und manuell abgenommen.
