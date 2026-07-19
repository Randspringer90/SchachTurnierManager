# Remote integration attempt and Firefox browser verification

- **Date:** 2026-07-19 (later session)
- **Tool:** Claude Code (Opus 4.8)
- **Branch:** `integration/final-candidate` at `0666e05`
- **Outcome:** PARTIAL — every remote obligation is blocked; the largest local
  gap was closed instead.

## The remote work could not be started

The assignment was a remote integration: merge the candidate pull request,
clean up PR #51, re-attest and merge PR #49, update issues, then build final
artifacts from the merged `origin/development`.

Preflight established that none of that is reachable:

| Probe | Result |
|---|---|
| `gh auth status` | token in keyring invalid |
| `git fetch origin --prune` | `Failed to connect to github.com:443` |
| `github.com:443`, `api.github.com:443`, `github.com:22`, `codeload.github.com:443` | all refused |
| `registry.npmjs.org:443` | refused |
| `1.1.1.1:443` | refused |
| DNS (`Resolve-DnsName github.com`) | resolves normally |
| Proxy (git, env, WinINET, WinHTTP) | none configured, direct access |

DNS works and every outbound TCP 443 connection fails, including to an address
unrelated to GitHub. This is an egress block outside the repository, not a
credential or configuration fault, and not something a session can repair.

One correction to the previous report: `integration/final-candidate` **is**
pushed. `git reflog show origin/integration/final-candidate` records an
`update by push` at 19:45 local time, so a short network window existed after
that report was written. `origin/development` is unchanged at `995d1a1`, so the
candidate is pushed but **not merged**.

## What was done instead

### The Firefox fix is now verified in Firefox

The prior report listed this as its most serious gap: the defect was
browser-specific — Firefox suppressing the second of two chained native modal
dialogs — but the evidence was unit and guard tests, which cannot reproduce it.
Playwright could not be installed with the npm registry unreachable.

Firefox itself is installed locally and speaks the Marionette remote protocol,
so a client for it was written directly:

- `scripts/lib/MarionetteClient.psm1` — minimal Marionette client (TCP,
  `<length>:<json>` framing, session, navigation, script evaluation, element
  lookup, real clicks, key input).
- `scripts/Smoke-FirefoxDialogs.ps1` — self-contained regression smoke. Packs
  the portable app, starts the backend on an isolated port and temp data
  directory, seeds two tournaments over the API, drives a real headless Firefox,
  then stops everything and deletes the temp directory.

19 checks, all passing against **Firefox 152.0.6**:

| Group | Checks |
|---|---|
| In-app dialog | delete opens `role="alertdialog"`; `aria-modal`, `aria-labelledby`, `aria-describedby` present |
| No native dialogs | `window.confirm`, `prompt` and `alert` are replaced by recorders at page load and are never called anywhere in the run |
| Typed confirmation | confirm starts disabled; a wrong name keeps it disabled; the exact name enables it — this is precisely the step Firefox used to swallow |
| Delete | dialog closes, the tournament is gone from the backend, the remaining tournament is selected, no console errors |
| Reset | opens the in-app dialog; `Esc` closes it without confirming |
| Empty state | deleting the last tournament leaves zero tournaments, no console errors, no error-boundary crash |

The native-dialog trap is the important one: it makes any regression back to
`window.confirm`/`window.prompt` fail the test rather than silently pass.

The script is deliberately **not** wired into `Invoke-ReleaseGate.ps1`, because
it requires a local Firefox installation. It is documented as a pre-candidate
step in `docs/submission/OWNER_MANUAL_TEST.md`, section A2.

### One false alarm, and where it actually was

The smoke initially reported that deleting the *last* tournament left it in the
database. That looked like a real race in the empty-state path and was chased
accordingly: resource timings taken inside the page showed the `DELETE` firing
10 ms after the click and completing in 29 ms, a single backend process on the
port, no proxy or cache in between.

The defect was in the test. `@(Invoke-RestMethod ...)` wraps an empty JSON array
into a **one-element** array in PowerShell, so the assertion read "1 tournament
left" for an empty list. The application had been correct throughout. The helper
now collects names through the pipeline, which enumerates correctly, and the
gotcha is commented at the call site so it is not reintroduced.

Recording this because the first two runs of that assertion produced a plausible
but entirely fictitious bug report.

### Remaining native dialogs (deliberate, not a regression)

`window.confirm` still appears three times: `App.tsx:712` (pair a round despite
critical preview findings), `App.tsx:756` and `BoardDiceRoller.tsx:93`
(overwrite existing Chess960 starting positions). Each is a **single**
confirmation, not a chain, so the Firefox suppression behaviour does not apply.
They are outside the scope of this fix and are left as is.

### Three readiness scripts that could never pass

Running the remaining gates surfaced three pre-existing defects. None was caused
by this run; all three were found by executing the tools rather than reading
them, and all three are fixed in `6dc57af`.

**`Invoke-PortableFreshFolderTest`** asserted against `health.databasePath`. The
health endpoint deliberately exposes only the database *file name*
(`databaseHealthLabel`), never the full path, so local machine paths cannot leak
— that property has never existed. Under `Set-StrictMode` the script threw. It
now proves the same property, that the SQLite file is created inside the
isolated test data directory, against the file system instead of trusting the
API to reveal a path it must not reveal.

**`Test-PortablePackageGate`** called `Pack-Portable.ps1` with `-OutputRoot`,
`-LogRoot` and `-StepTimeoutSeconds`. `Pack-Portable` declared none of them, and
without `[CmdletBinding()]` PowerShell accepts unknown named arguments in
silence. The gate therefore built the package into the **real** `output/`
directory — overwriting it as a side effect — and then verified its own empty
`tmp/` directory, failing on a missing `app` folder. `Pack-Portable` now
declares `[CmdletBinding()]` and a genuine `-OutputRoot`, so the gate builds
hermetically under `tmp/` and any future parameter typo fails loudly instead of
being swallowed.

**`Invoke-PublicSafetySnapshot`** piped each step through `Tee-Object` without
discarding the pass-through, so `Run-Step` returned every log line *and* the
result object. The report loop then ran on strings and died on a missing `name`
property. It now completes and reports 6/6, release gate included.

`Test-ContributorKickoffReadiness` was also re-checked. It fails on an
`integration/*` branch because `New-ContributorTaskPrompt` refuses to run
outside `development` or a conforming feature branch. That is a deliberate
precondition, not a defect: on `security/STM-SEC-006-csv-formula-injection` the
gate passes completely. The previous report's explanation was correct.

## Verification at `6dc57af`

| Gate | Result |
|---|---|
| Release gate (restore, build, test, npm install/test/build, pack) | pass |
| .NET tests | 523 pass, 0 fail (13 golden + 114 application + 21 infrastructure + 375 domain) |
| Frontend tests | 17 pass, 0 fail |
| **Firefox dialog smoke (real browser)** | **19 OK, 0 fail** |
| Operator workflow smoke | 31 OK, 0 fail |
| Installer readiness | pass |
| `git diff --check` | clean |
| GitCommitSafety, PromptInjectionDefense, AgentInstructionIntegrity, AgentSkillReadiness, AgentSkillProposalSafety, KnowledgePersistenceSafety, ModelRouting, CollaborationReadiness, RepositoryOpenSourceSafety, RoutedExecution, NightlyExecution, PullRequestReviewReadiness | 12/12 pass |
| Routed execution, three consecutive runs | 34/34 each, identical |
| Portable package gate, portable fresh-folder test, click-install readiness | pass (after the fixes above) |
| Public safety snapshot | 6/6 pass |
| Contributor kickoff readiness | pass on a valid feature branch; refuses by design on `integration/*` |
| `npm audit` | **could not run** — registry unreachable |

No test was weakened.

## Artifact

Rebuilt from the head commit rather than relabelling the earlier build:

| Field | Value |
|---|---|
| File | `output/installer/SchachTurnierManager_Setup_0.54.1.exe` |
| Built from | `6dc57af3413356a514d16efd3fed17cef309c407` |
| Size | 38,557,085 bytes |
| SHA-256 | `145007B1FC994AD81945309CC7EE21E9FA765183F78EC278778E334950AB4190` |
| Signature | **unsigned** (`NotSigned`) — no code-signing certificate exists |
| Toolchain | Inno Setup 6.7.3, .NET SDK 10.0.400-preview.0.26322.102, Node v24.16.0, npm 11.13.0 |

Run bundle and manifest:
`D:\KFM\logs\SchachTurnierManager\runs\STM_CLAUDE_REMOTE_20260719_2000`.

No APK: PR #49 is unmerged, so no companion source exists at this SHA.

## Still open, and why

- **Everything remote.** The candidate is not merged; PR #51 is not closed;
  PR #49 is not re-attested or merged; issues #23, #25 and #43 are untouched;
  the `feature/STM-AI-001-agent-skill-foundation` branch is not resolved. All of
  it needs the GitHub API.
- **No Android APK.** PR #49 is unmerged, so no companion source exists at the
  candidate SHA. Re-attesting 30 binary artifacts against a new head is also an
  owner decision, not an automated one.
- **`npm audit`.** Needs the registry.
- **`app/App.tsx` is still ~3250 lines.** Backlog, not candidate work.

Handover for the remote steps stays
`docs/submission/OWNER_ACTIONS_BEFORE_SUBMISSION.md`.
