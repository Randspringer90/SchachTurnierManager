# Final completion run — architecture, Firefox fix, Build Week candidate

- **Date:** 2026-07-19
- **Tool:** Claude Code (Opus 4.8), supporting role
- **Base:** `development` at `995d1a1f50fc883e8533d69eddcc8f894555cf84`
- **Result branch:** `integration/final-candidate` at `9fe244363e43b32feb2b5cd2f49cf1236a36a97e`
- **Outcome:** PARTIAL — all local work is done, committed and green; nothing
  could be pushed.

## The constraint that shaped this run

The environment had **no network access**. `github.com:443` and
`registry.npmjs.org:443` were both unreachable and the stored `gh` token is
invalid. Every remote obligation in the assignment — push, update PR #49 and
#51, wait for CI, merge, close superseded PRs, update issues #23/#25/#43, sync
local `development` with `origin/development` — was therefore impossible, and is
handed over in `docs/submission/OWNER_ACTIONS_BEFORE_SUBMISSION.md`.

Local work continued to completion rather than stopping at the first blocker.

## What was integrated

`integration/final-candidate` was branched from current `development` and now
carries, in seven commits:

1. `cc6e9c5` — preserved the uncommitted Codex build-week prompts, reports and
   run metadata. Redacted the owner's real name to role terms first: the commit
   gate correctly refused them.
2. `c4fdd2a` — merged `feature/STM-FE-013-frontend-modularization`, which
   already contained the whole PR #51 scope (Build Week UX, demo tournament,
   submission docs). One conflict in `BACKLOG.md`, resolved to the truthful
   state (STM-INFRA-008 is Done via PR #52, not "In Progress").
3. `b4f9008` — **the Firefox fix**.
4. `b174519` — **the frontend modularization**.
5. `0f5c2bb` — tournament package endpoints.
6. `ab61005` / `eee20dd` — repository and AI-adapter layout consolidation.

PR #49 (Android) was deliberately **not** merged; the reasoning is in the owner
actions document.

## The Firefox bug

Reset used `window.confirm`; delete used `window.confirm` followed by
`window.prompt`. Firefox suppresses repeated modal dialogs raised from the same
script turn ("prevent this page from creating additional dialogs"), so the
second dialog of the delete chain never appeared. The name check then compared
against `null`, the delete aborted silently, and the selection was left stale.

Replaced with a reusable `ConfirmDialog`
(`src/components/dialogs/ConfirmDialog.tsx`):

- `role="alertdialog"`, labelled and described, focus trap, focus restored to
  the triggering button, `Escape` cancels but never confirms and never abandons
  an in-flight request;
- typed confirmation for delete — the button stays disabled until the tournament
  name matches verbatim;
- busy state that blocks double submits;
- backend errors rendered **inside** the dialog so the operator keeps context
  instead of losing the message behind a closed modal.

Both actions now run through one guarded dispatch. The reloaded tournament list
is filtered by the deleted id, so a stale response can never re-select a
tournament that no longer exists. The empty-state path was verified to issue no
requests against a dead id.

Pure decision logic lives in `src/lib/destructiveActions.ts` so it is testable
without a DOM.

## The modularization

`main.tsx` went from **4550 lines to 23**. It is now bootstrap only: mount,
providers, dice-page routing.

| New module | Content |
|---|---|
| `app/App.tsx` | Application shell (moved verbatim) |
| `app/navigation.ts` | Main tab model |
| `lib/tournamentOptions.ts` | Option catalogues, form shapes, demo markers |
| `lib/labels.ts` | Display formatting for backend enum values |
| `lib/playerForms.ts` | Contract ↔ form mapping |
| `lib/browser.ts` | localStorage, downloads, display mode |
| `lib/chess960.ts` | Position derivation, dice URL parsing |
| `lib/knowledge.ts` | Offline knowledge base lookup |
| `lib/tournamentAssistant.ts` | Planning recommendation |
| `lib/destructiveActions.ts` | Reset/delete decision logic |
| `components/QrPanel.tsx`, `components/chess960/{ChessDie,BoardDiceRoller}.tsx` | Extracted components |
| `features/mobile-companion/MobileDicePage.tsx` | Standalone phone dice page |

`app/App.tsx` is still 3253 lines. Splitting it further into feature areas was
judged too risky this close to the candidate and is left as explicit backlog
work; the assignment's own instruction was to finish a clean cut rather than
destabilise the candidate chasing perfection.

The `App` body was moved **verbatim**, so behaviour is preserved by
construction.

### Contract checks were following the file, not the capability

Three .NET contract tests and four readiness scripts asserted against
`src/main.tsx` by path, so the extraction broke them — the release gate caught
this and refused the commit. Rather than repoint them at `App.tsx` (which would
break again at the next extraction), they now assert against the whole WebApp
source tree:

- `TournamentSettingsTransportContractTests.ReadWebAppSources()`
- `scripts/lib/WebAppSourceSnapshot.ps1`, shared by the four readiness scripts

## Two pre-existing defects found and fixed

Neither was caused by this run; both were found by actually executing the tools.

**The operator smoke could never pass.** It probed
`src/…/bin/Release/net10.0/` for the WebApi DLL, but `Directory.Build.props`
redirects output to `tmp/dotnet-bin/`. The script aborted before starting the
backend. After fixing the probe, two assertions still failed: the tournament
package export endpoints were asserted from the start but **never mapped** in
`Program.cs`, although `TournamentExportFormatter` and `TournamentService` had
implemented them all along and domain tests covered them. Mapping the two routes
made the feature reachable. Operator smoke went from *aborting* → *29 OK / 2
failed* → **31 OK / 0 failed**.

**The release gate never ran the frontend tests.** It ran `npm install` and
`npm run build`, but not `npm test`. Added.

## Repository layout

Executed the package that `REPOSITORY_LAYOUT_AUDIT.md` had recommended:
a tracked `.codex` adapter (README + placeholder-only example config),
`docs/architecture/REPOSITORY_LAYOUT.md`,
`docs/architecture/AI_PROVIDER_ADAPTERS.md` and `docs/ai/README.md`.

Both the commit gate and the public-snapshot gate block `.codex/` wholesale. The
exemption added is an **explicit two-file allowlist, not a prefix**, so a real
`config.toml` or `auth.json` is still blocked and any new file under `.codex/`
is blocked again by default. `OperationalGuardTests.CodexAdapter_ExemptsOnlyThe
TwoTrackedAdapterFiles` pins that.

The secret migration turned out to be already done in substance: writers target
`.secrets/local/` exclusively, and `secrets/local/` survives only as a read-only
compatibility fallback. No secret file was moved.

Attribution is recorded honestly in `AI_PROVIDER_ADAPTERS.md`: Codex/GPT-5.6 as
the primary finalisation tool, Claude supporting, contributor pull requests, and
the owner making product decisions.

## Verification

| Gate | Result |
|---|---|
| Release gate (restore, build, test, npm install/test/build, pack) | pass |
| .NET tests | 523 pass, 0 fail |
| Frontend tests | 17 pass, 0 fail (was 5) |
| TypeScript `--noEmit` | clean |
| Vite production build | clean, 54 modules |
| Operator workflow smoke | 31 OK, 0 failed |
| Installer readiness | pass |
| GitCommitSafety, PromptInjectionDefense, AgentInstructionIntegrity, AgentSkillReadiness/ProposalSafety, KnowledgePersistenceSafety, ModelRouting, RoutedExecution (34/34), CollaborationReadiness | pass |
| RepositoryOpenSourceSafety | 799 candidates, 0 blocking (2 before the `.codex` allowlist) |
| ContributorKickoffReadiness | pass — needs a `development`/feature branch; fails by precondition on an `integration/*` branch name |
| `git diff --check` | clean |

No test was weakened to get green. Two gate failures during the run were real
findings — the PII anchor in the Codex prompts and the `.codex` path block — and
both were resolved by fixing the content or narrowing the rule deliberately,
never by disabling a check.

## Artifacts

`SchachTurnierManager_Setup_0.54.1.exe`, 38,556,523 bytes, SHA-256
`D5D9E1DFE3A20209609F0DE9AC6E9B5468FF8E7F19D8DC253534961DA2D8CAE0`, **unsigned**.

Built from `9fe2443`. The first build (at `eee20dd`) was discarded and rebuilt
rather than relabelled.

Commits after `9fe2443` touch `docs/` only and change no build input — verify
with `git diff --name-only 9fe2443 HEAD`. The artifact therefore still
corresponds to the candidate. If any non-documentation file changes, the
installer must be rebuilt and its hash re-recorded before the artifact is used.

No Android APK: PR #49 is unmerged, so no companion source exists at the
candidate SHA.

## One mislabelled commit

`b4f9008`, the Firefox fix, carries `[STM-UX-012]` in its subject. That ID was
already taken by "public read-only live display in the local network". The fix
is registered in the backlog as **STM-UX-013**, and that row is canonical. The
commit subject was left alone rather than rewriting history, which the
assignment forbids.

## Honest gaps

- Nothing is pushed. `origin/development` does not contain any of this.
- The Firefox fix is proven by unit and guard tests, not by a real browser. No
  browser driver was installable offline. The manual pass is section A2 of
  `OWNER_MANUAL_TEST.md` and is a genuine open risk.
- `app/App.tsx` is still a 3253-line component.
- Issues #23, #25, #43 were not touched — they need the GitHub API.
- `npm audit` could not run (no registry access).
- ~5 MB of stale vite bundles ship inside the installer because the build uses
  `--emptyOutDir false`. The correct bundle is referenced; the rest is dead
  weight. Left alone deliberately this late.
