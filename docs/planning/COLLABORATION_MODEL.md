# Kollaborationsmodell – SchachTurnierManager

Stand: 2026-07-17

Maschinenlesbare Fassung: [`config/collaboration-policy.json`](../../config/collaboration-policy.json)
(Schema: `config/collaboration-policy.schema.json`, geprüft von `scripts/Test-CollaborationReadiness.ps1`).

> **Wichtig:** Dieses Dokument beschreibt die *Absicht*. Durchgesetzt wird sie durch
> GitHub-Rechte, `.github/CODEOWNERS`, das Branch-Ruleset `collab-development` und die
> CI-Gates. Bei Widerspruch gewinnt die Durchsetzung, nicht dieser Text.

## Rollen

| Rolle | Wer | GitHub-Recht | Kernaussage |
|---|---|---|---|
| **owner** | @Randspringer90 | `admin` | Einziger Code-Owner, einziger Merger, einziger Freigeber für geschützte Bereiche. |
| **trusted-collaborator** | @Marcel-Mente | `write` | Vertrauenswürdiger Mitentwickler mit weiten Arbeitsbereichen – aber ohne Rechtehoheit. |

Der Begriff `friend` aus älteren Dateien bleibt als `legacyAlias` gültig, damit bestehende
Parser, Schemas und Tests (u. a. `BACKLOG.md`-Spalte „Ziel-Bearbeiter",
`config/nightly-execution.json`) nicht brechen.

## Warum „trusted", aber weiterhin nur `write`

Marcel hat mit #9, #10, #30, #31 und #33 wiederholt belastbare Arbeit geliefert – inklusive
eines real reproduzierten Startfehlers (STM-REL-001, unabhängig nachgestellt) und ehrlicher
Angaben darüber, was er *nicht* getestet hat.

Das rechtfertigt **erweiterte Bereiche**, nicht **erweiterte Rechte**. Konkret bleibt es bei
`write`, weil `maintain`/`admin` Branchschutz, Collaborator-Verwaltung und Release-Hoheit
mitgäben. Diese Trennung ist kein Misstrauen, sondern Rollentrennung: Sie schützt auch
Marcel davor, versehentlich etwas zu tun, das niemand mehr reviewen kann.

## Standardarbeitsbereiche (eigenverantwortlich)

```
src/SchachTurnierManager.Domain/**
src/SchachTurnierManager.Application/**
src/SchachTurnierManager.Infrastructure/**
src/SchachTurnierManager.WebApi/**
src/SchachTurnierManager.WebApp/**
src/SchachTurnierManager.Mobile/**      (künftiges Android-/Mobile-Projekt)
tests/**
docs/**
CHANGELOG.md
```

Hier gilt: normaler PR, normaler Review, keine Sondergenehmigung.

## Was Marcel darf

- Issues für Produktfunktionen erstellen und präzisieren
- eigene Backlog-Einträge pflegen
- Feature-Branches erstellen
- Pull Requests erstellen
- **Owner-PRs reviewen**
- Tests ergänzen
- Produktarchitektur innerhalb seines Pakets verbessern
- API, UI, Mobile und Domain **gemeinsam** ändern, wenn das Feature es erfordert
- neue Dependencies **vorschlagen**

### Neue Dependencies

Vorschlagen ja – übernehmen erst nach: Begründung, Lizenzprüfung, Vulnerability-Prüfung,
Alternativenvergleich, Owner-Review.

## Geschützte Bereiche (Vorschlag erlaubt, Owner- **und** Security-Review nötig)

```
.github/**        .agents/**       .claude/**      agents/**
config/**         scripts/**       installer/**
docs/security/**  docs/architecture/**
AGENTS.md         global.json
Directory.Build.props            Directory.Packages.props
Android-Signing-Konfiguration    Security-Policies
Modellrouting     Nightly         Releaseautomation
```

Marcel darf hier Änderungen **vorschlagen** – der Merge braucht zusätzlich Owner-Freigabe.
Durchgesetzt über `CODEOWNERS` (alle Einträge `@Randspringer90`) plus Ruleset-Option
„require review from Code Owners".

## Was Marcel nicht darf

- Secrets lesen oder ändern
- Signaturschlüssel verwenden
- Branchschutz oder Rulesets ändern
- Collaborator-Rechte verwalten
- direkt nach `development` oder `main` pushen
- selbstständig mergen
- Force-Push
- History-Rewrite
- Tags oder Releases veröffentlichen
- Website- oder Store-Upload ohne Owner-Freigabe

## WIP-Regel

| Status | Maximum |
|---|---|
| In Progress | **2** |
| Ready | **3** |

Alles Weitere bleibt `Backlog` oder `Blocked` **mit klar benannter Abhängigkeit**.

Der Sinn: Nicht Marcel ausbremsen, sondern verhindern, dass fünf halbfertige Baustellen
gleichzeitig offen sind und keine davon sauber abgeschlossen wird.

## Wie die Regeln technisch durchgesetzt werden

| Regel | Durchsetzung |
|---|---|
| Kein direkter Push nach `development` | Ruleset `collab-development` (`pull_request` erforderlich) |
| Kein Selbst-Merge | `required_approving_review_count: 1` + `require_code_owner_review: true` |
| Geschützte Pfade | `.github/CODEOWNERS` |
| Kein Ausführen von PR-Code ohne Owner | `ci.yml` → `Assert-OwnerExecutionApproval`, SHA-gebundenes Review `STATIC-EXECUTION-APPROVED:<head-sha>` |
| Nightly fasst Marcels Aufgaben nicht an | `config/nightly-execution.json` → `neverProcess.assigneeTargets`, `contributorBranchesAndPrs: true` |
| Contributor-PRs werden nie direkt gemergt | `docs/security/SAFE_PULL_REQUEST_REVIEW.md`, Adoption über `integration/pr-<nr>-safe-adoption` |

## Adoptionsprozess für Marcels PRs

Marcels PRs werden **nicht direkt gemergt**. Stattdessen:

1. Static-Only-Review ohne Ausführung von Contributor-Code.
2. Fachprüfung gegen Primärquellen (z. B. FIDE-Handbuch für Schachregeln).
3. Owner-Integrationsbranch vom **aktuellen** `development`.
4. Selektive Übernahme, an den heutigen Stand angepasst.
5. `Co-authored-by:` erhält die Autorschaft.
6. Original-PR wird wertschätzend kommentiert und als *übernommen* geschlossen – **nie** als abgelehnt.

Details: [`PULL_REQUEST_ADOPTION_WORKFLOW.md`](PULL_REQUEST_ADOPTION_WORKFLOW.md).

## Arbeitsteilung

- **Marcel:** Schachregeln, Pairing, Tie-Breaks, Turnierformate, Import/Export, Mobile/UX-Features.
- **Owner/KI:** Security, Infrastruktur, Agenten, Modellrouting, Nightly, Release, Installer, Signing.

Siehe [`MARCEL_WORK_QUEUE.md`](MARCEL_WORK_QUEUE.md) für die konkrete Reihenfolge.
