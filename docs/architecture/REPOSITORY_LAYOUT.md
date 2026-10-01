# Repository layout

Canonical directory map for SchachTurnierManager. This document describes
*where things live*. It does not restate policy — the binding rules are in
`AGENTS.md` at the repository root, which wins on any conflict.

The most recent inventory of the working copy is
`docs/architecture/REPOSITORY_LAYOUT_AUDIT.md`.

## Rules and agent configuration

| Path | Role | Tracked |
|---|---|---|
| `AGENTS.md` | Sole binding, provider-neutral rule source. | yes |
| `agents/` | Provider-neutral agent roles. | yes |
| `.agents/skills/` | Provider-neutral skill canon. | yes |
| `.claude/` | Thin Claude Code adapter. No second source of truth. | yes |
| `.codex/` | Thin Codex adapter: README + safe example config only. | README + example |
| `config/agent-*.json`, `config/*trust*`, `config/*permission*` | Agent manifests, trust and permission boundaries. | yes |

Only paths listed in `config/trusted-instruction-paths.json` may steer agent
behaviour (trust levels T0–T2). See
`docs/architecture/AGENT_TRUST_BOUNDARIES.md` and
`docs/architecture/AI_PROVIDER_ADAPTERS.md`.

## Application code

| Path | Content |
|---|---|
| `src/SchachTurnierManager.Domain/` | Pairing, tie-breaks, Chess960, export formatting. No I/O. |
| `src/SchachTurnierManager.Application/` | `TournamentService`, store abstraction, audit journal. |
| `src/SchachTurnierManager.Infrastructure/` | SQLite persistence, external rating lookups. |
| `src/SchachTurnierManager.WebApi/` | Minimal-API host and the embedded dashboard. |
| `src/SchachTurnierManager.WebApp/` | React frontend (see below). |
| `tests/` | xUnit suites per layer plus golden tests. |
| `installer/`, `scripts/` | Windows installer, release gate, readiness and safety scripts. |

### Frontend module layout

`src/SchachTurnierManager.WebApp/src/` after STM-FE-013/014:

| Path | Content |
|---|---|
| `main.tsx` | Bootstrap only (~23 lines): mount, providers, dice-page routing. |
| `api/contracts.ts` | Backend contract types. |
| `api/client.ts` | `requestJson` / `requestText` fetch helpers. |
| `app/App.tsx` | Application shell and operator workflow. |
| `app/navigation.ts` | Main tab model; rare features sit behind "More". |
| `components/` | Reusable UI: `ErrorBoundary`, `QrPanel`, `dialogs/`, `chess960/`. |
| `features/` | Self-contained screens, currently `mobile-companion/`. |
| `lib/` | Pure helpers: labels, forms, chess960, assistant, knowledge, destructive actions. |
| `i18n/` | Provider, language switcher and locale tables. |
| `knowledge/` | Offline knowledge base JSON. No network calls. |
| `test/` | `node --test` suites with native TypeScript stripping. |

Further extraction of feature areas out of `app/App.tsx` is tracked in
`docs/planning/BACKLOG.md` (STM-FE-015 ff.) and deliberately not forced before
the submission freeze.

## AI evidence

| Path | Content |
|---|---|
| `docs/ai/PROMPTS.md` | Central index of versioned prompts. |
| `docs/ai/prompts/` | Versioned prompts, public-safe. |
| `docs/ai/reports/` | Run completion reports. |
| `docs/ai/run-metadata/` | Machine-readable run metadata. |
| `docs/ai/LESSONS_LEARNED.md` | Cross-run lessons. |
| `docs/ai/README.md` | How this evidence is organised and redacted. |

There is no competing root-level `Prompt(s)/` or `Report(s)/` directory.
`docs/reports/` holds two historical non-AI project reports and is not an
AI-report duplicate.

## Secrets

| Path | Role |
|---|---|
| `.secrets/` | **Preferred** local secret root. Only `README.md` is tracked; `.secrets/local/` is ignored. |
| `secrets/` | **Legacy**, deprecated. Only a compatibility `README.md` is tracked. |

Writers (`scripts/Set-LocalSecret.ps1`) always write to `.secrets/local/`.
Readers (`scripts/Get-LocalSecret.ps1`, `scripts/Invoke-NpmSafe.ps1`) prefer
`.secrets/local/` and fall back to `secrets/local/` only so existing machines
keep working. No live code path writes to the legacy location. Real secret files
are never moved or committed by tooling — migrating an existing machine is a
manual, local step.

## Runtime output (never committed)

`logs/` (only `README.md` and `.gitkeep` are tracked), `output/`, `tmp/`,
`local-input/`, `.local-audits/`, `node_modules/`, build output and databases.
Build artifacts — Setup EXE, APK, keystores — are produced locally and are never
pushed.
