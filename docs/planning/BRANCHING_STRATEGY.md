# Branching-Strategie – SchachTurnierManager

> Kanonische Branch-Regeln für die gemeinsame Entwicklung. Verbindlich für alle
> Mitwirkenden (Menschen **und** KI-Agenten). Ergänzt durch
> [`COLLABORATION_WORKFLOW.md`](COLLABORATION_WORKFLOW.md) und
> [`RELEASE_WORKFLOW.md`](RELEASE_WORKFLOW.md).

## Überblick

| Branch          | Zweck                                         | Direkter Push | Merge-Quelle                     |
|-----------------|-----------------------------------------------|---------------|----------------------------------|
| `main`          | Nur der jeweils neueste **freigegebene Release-Stand** | Gesperrt (nur Admin-Notfall) | `release/*`, `hotfix/*` (per PR) |
| `development`   | **Standardbranch**, aktueller Entwicklungsstand | Nur Owner (der Owner, Admin-Bypass) | `feature/* fix/* security/* docs/* refactor/*` sowie `integration/pr-<nr>-safe-adoption` (per PR) |
| `feature/*` u.a.| Einzelne Backlog-Aufgabe                       | Ersteller     | –                                |
| `release/*`     | Release-Stabilisierung                        | Gesperrt (PR) | `development`, `release-fix/*`   |
| `hotfix/*`      | Dringende Korrektur am Release                | Gesperrt (PR) | von `main` abgezweigt            |

## `main`

- Enthält ausschließlich den zuletzt **freigegebenen** Release-Stand.
- **Keine** normale Entwicklung direkt auf `main`.
- Integration nur über Pull Request aus `release/*` oder `hotfix/*`.
- Nach erfolgreichem Release wird der Merge-Commit mit einem SemVer-Tag versehen
  (`v1.0.0`, `v1.1.0`, …). Tags erzeugt der Owner bewusst manuell.
- `main` darf **nie** gelöscht oder force-gepusht werden.

## `development`

- **GitHub-Standardbranch** und Quelle aller Feature-Branches.
- Neue Planung, Architektur, Features und Bugfixes laufen grundsätzlich gegen `development`.
- **der Owner** darf als Repository-Owner/Admin bei Bedarf direkt auf `development` arbeiten
  (dokumentierter Admin-Bypass).
- **Alle anderen Mitwirkenden** (der später eingeladene Freund, KI-Agenten in deren
  Auftrag) arbeiten **ausschließlich** über Feature-Branches und Pull Requests.
- `development` darf nie gelöscht oder force-gepusht werden.

## Feature-Branches

Namensschema (genau ein Backlog-Eintrag pro Branch):

```
feature/<backlog-id>-<kurzer-name>
fix/<backlog-id>-<kurzer-name>
security/<backlog-id>-<kurzer-name>
docs/<backlog-id>-<kurzer-name>
refactor/<backlog-id>-<kurzer-name>
```

Beispiel: `feature/STM-FACH-012-fide-dutch`

Regeln:

- Immer vom **aktuellen** `development` erzeugen (Skript: `scripts/New-FeatureBranch.ps1`).
- `<backlog-id>` muss ein existierender Eintrag in
  [`BACKLOG.md`](BACKLOG.md) sein; `<kurzer-name>` nur `[a-z0-9-]`.
- Pull Request richtet sich an `development`.
- Vor dem PR den Branch mit `development` aktualisieren (`git merge origin/development`
  oder Rebase, kein Force-Push auf geschützte Branches).
- Nach dem Merge wird der Feature-Branch automatisch gelöscht (Repo-Einstellung).
- Keine Secrets, Logs, Datenbanken, ZIPs, Dumps oder lokale Konfiguration committen.

## Sichere PR-Integrationsbranches

`integration/pr-<nummer>-safe-adoption` ist ausschließlich für eine kontrollierte Übernahme
eines bereits statisch geprüften Beitrags erlaubt. Der Branch startet vom erneut abgerufenen
aktuellen `origin/development`, nie vom fremden PR-Branch. Nur im SHA-/Policy-gebundenen
Owner-Plan freigegebene Teile dürfen übernommen werden; Original-PR und Contributor werden
attributiert. Der Ablauf steht in
[`PULL_REQUEST_ADOPTION_WORKFLOW.md`](PULL_REQUEST_ADOPTION_WORKFLOW.md).

## Release-Branches

```
release/<semver>      # z. B. release/1.0.0
```

- Erst erzeugen, wenn `development` fachlich und technisch releasefähig ist.
- Wird von `development` abgezweigt (`scripts/Prepare-ReleaseBranch.ps1`).
- Nur Stabilisierung, Dokumentation, Versionsanpassungen, Release-Fixes – **keine** neuen Features.
- Integration nach `main` per Pull Request.
- Nach Freigabe wird der Release-Fix-Stand **zwingend nach `development` zurückgeführt**.
- **In diesem Bootstrap-Lauf wurde kein Release-Branch erzeugt** – nur dokumentiert und Skripte vorbereitet.

## Hotfix-Branches

```
hotfix/<semver>-<kurzer-name>   # z. B. hotfix/1.0.1-crash-import
```

- Werden von `main` erzeugt (`scripts/Prepare-HotfixBranch.ps1`).
- Per Pull Request nach `main`.
- Anschließend **zwingend** nach `development` zurückführen.

## Merge- und Rückmerge-Regeln (Kurzfassung)

- Feature → `development`: **Squash-Merge** (eine saubere Commit-Zeile je Aufgabe).
- `release/*` → `main`: **Merge-Commit** (Release-Historie bleibt nachvollziehbar), danach Tag.
- `hotfix/*` → `main`: **Merge-Commit**, danach Tag, danach Rückmerge nach `development`.
- Rebase-Merge ist deaktiviert, um die dokumentierte Strategie eindeutig zu halten.

## KI-Agenten

KI-Agenten (Claude Code, Codex u. a.) unterliegen exakt denselben Branch-Regeln wie
Menschen. Details und Sicherheitsregeln: [`../security/CONTRIBUTOR_SECURITY.md`](../security/CONTRIBUTOR_SECURITY.md)
und `AGENTS.md` (Repo-Root).
