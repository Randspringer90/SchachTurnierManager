# Kollaborations-Workflow – SchachTurnierManager

> Wie der Owner und ein später eingeladener Freund (Rolle **Write**) gemeinsam
> arbeiten. Ergänzt [`BRANCHING_STRATEGY.md`](BRANCHING_STRATEGY.md),
> [`RELEASE_WORKFLOW.md`](RELEASE_WORKFLOW.md) und die kanonische Aufgabenquelle
> [`BACKLOG.md`](BACKLOG.md).

## Rollen

| Rolle            | GitHub-Recht | Darf direkt auf `development` pushen | Arbeitet über PR |
|------------------|--------------|--------------------------------------|------------------|
| der Owner    | Admin        | Ja (bewusster Admin-Bypass)          | optional         |
| Freund           | **Write**    | **Nein** (technisch blockiert)       | **Ja, immer**    |
| KI-Agent         | –            | Nein (im Namen des jeweiligen Menschen) | wie der Mensch |

Der Freund erhält ausdrücklich **nur Write**, niemals Maintain oder Admin. Die
Einladung erfolgt in einem **separaten manuellen Schritt** (siehe
[`../onboarding/COLLABORATOR_ONBOARDING.md`](../onboarding/COLLABORATOR_ONBOARDING.md)),
nicht automatisiert.

## Kanonischer Ablauf einer Aufgabe

1. **Aufgabe wählen** – nur Einträge mit Status `Ready` in [`BACKLOG.md`](BACKLOG.md)
   bzw. das zugehörige GitHub-Issue. Der Freund wählt ausschließlich `Ready`-Aufgaben.
2. **Status setzen** – Backlog-Status → `In Progress`, Branch- und Issue-Referenz eintragen.
3. **Branch erzeugen** – `scripts/New-FeatureBranch.ps1 -BacklogId STM-… -Name kurz-name`
   (immer von aktuellem `development`).
4. **Umsetzen** – Code + Tests + Doku. Gate lokal grün halten (`scripts/Test-All.ps1`,
   `scripts/Invoke-ReleaseGate.ps1`).
5. **Aktualisieren** – vor dem PR `development` in den Branch mergen.
6. **PR öffnen** – Ziel `development`, PR-Template vollständig ausfüllen
   (Backlog-ID, Issue, Tests, ReleaseGate, Security-/Prompt-Injection-Check).
   Backlog-Status → `In Review`.
7. **Review** – der Owner (CODEOWNER) reviewt. Alle Konversationen müssen gelöst sein,
   CI grün, veraltete Freigaben nach neuen Commits neu einholen. Vor jeder Ausführung
   klassifiziert `pr-static-security` den Beitrag mit dem vertrauenswürdigen Base-Skript.
8. **Merge** – Squash-Merge nach `development`; Feature-Branch wird automatisch gelöscht.
9. **Abschluss** – Backlog-Status → `Done`, `CHANGELOG.md` und Doku aktualisiert
   (spätestens im PR). Abgeschlossene Aufgaben bleiben nachvollziehbar.

## Pflege-Pflichten je PR

Jeder PR aktualisiert bei Bedarf:

- [`BACKLOG.md`](BACKLOG.md) (Status, PR-Nummer)
- `CHANGELOG.md`
- betroffene Dokumentation und Tests

## Umgang mit Konflikten

- Merge-Konflikte löst der **PR-Autor** durch Aktualisieren des Feature-Branches gegen
  `development`. Kein Force-Push auf geschützte Branches.
- Inhaltliche Konflikte (konkurrierende Umsetzungen) entscheidet **der Owner** als Owner.
- Bei divergierten lokalen Klonen gilt: **`development` (Remote) ist die Wahrheit**.
  Lokale Sonderstände zuerst als Backup-Branch sichern, dann gegen `development` neu aufsetzen.

## Kontrollierte Übernahme fremder Pull Requests

Fremde PRs werden nicht ungeprüft direkt nach `development` gemergt. Metadaten, Dateiliste und
Patch bleiben zunächst T4 und werden static-only geprüft. Sind Anpassungen nötig, startet ein
Owner-Integrationsbranch `integration/pr-<nummer>-safe-adoption` vom aktuellen
`origin/development`; nur sichere Teile werden selektiv übernommen, getestet und attributiert.
`BLOCKED_NEEDS_OWNER` ist keine automatische Ablehnung. Vollständiger Ablauf:
[`PULL_REQUEST_ADOPTION_WORKFLOW.md`](PULL_REQUEST_ADOPTION_WORKFLOW.md).

## Umgang mit Änderungen durch KI-Agenten

- KI-Agenten arbeiten nur im Auftrag eines Menschen und mit denselben Rechten wie dieser.
- Änderungen an Instruktionsquellen (`AGENTS.md`, `.claude/**`, `.agents/**`, `config/**`,
  `.github/**`, Security-Skripte) erfordern **Owner-Review** (CODEOWNERS).
- Prompt-Injection-Regeln: [`../security/CONTRIBUTOR_SECURITY.md`](../security/CONTRIBUTOR_SECURITY.md).

## Eigenständigkeit

Das Projekt ist **self-contained**. Weder Build, Tests, Skripte noch Doku dürfen von
anderen lokalen Projekten oder fremden Maschinenpfaden abhängen. Optionale, nur beim Owner
vorhandene Werkzeuge (z. B. externes Wissensmanagement) sind als **optional** zu kennzeichnen
und dürfen kein Gate blockieren.
