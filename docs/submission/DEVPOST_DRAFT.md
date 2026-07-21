# Devpost draft — owner review required

This is a draft only. It must not be submitted until the final candidate, video, repository access,
licence decision and `/feedback` session ID have been verified by the owner.

## Project name

SchachTurnierManager

## Tagline

A local-first tournament workstation for chess clubs—from pairing desk to phone result entry.

## Category

Work & Productivity

## Inspiration

Volunteer tournament directors do complex operational work with limited time and infrastructure.
Registration lists, pairing rules, result slips, standings and federation-compatible files need to
stay consistent, yet a small club may not want accounts, hosted servers or a collection of separate
tools. We wanted one understandable, local workplace that protects the director's attention as well
as the tournament data.

## What it does

SchachTurnierManager installs as a per-user Windows application and stores tournament state locally.
A director can create a round-robin or Swiss event, manage participants, preview auditable pairings,
record confirmed results, review standings, exchange Swiss-Manager player master data and generate
print, CSV and TRF16 tournament output.

Optimal V2 remains the normal Swiss strategy. FIDE Dutch is an explicit advanced option with an
initial-colour setting and detailed audit evidence; this is not a claim of FIDE certification. A
synthetic eight-player preset makes the complete path testable without personal data. The Android
companion candidate connects directly to the tournament PC on the same private Wi-Fi for narrow
result-entry tasks, with no cloud relay.

## How we built it

The existing codebase uses a layered .NET architecture: Domain for chess rules, Application for use
cases, Infrastructure for SQLite/adapters, and a local Web API. The operator interface is React,
TypeScript and Vite. Windows distribution uses self-contained .NET packaging and Inno Setup; the
mobile candidate uses Capacitor/Android.

This was an existing project before Build Week. The submission-period changelog and exact commit
range distinguish the pre-existing baseline from new work.

## How Codex was used

Codex served as the primary finalisation environment in one traceable thread. It re-established the
repository/run state, performed exact-SHA pull-request analysis, implemented the progressive UX and
synthetic demo, wrote tests and public-safe submission documentation, and prepared exact-candidate
build/evidence workflows. It also designed a fail-closed Android-artifact attestation gate rather
than bypassing existing binary/security checks.

Codex output was not accepted automatically: failing or incomplete checks remained blockers, the
first demo smoke assertion was investigated instead of being reported green, and protected
security changes were left in an owner-review PR. The owner retains merge, release, upload and
submission decisions.

## How GPT-5.6 was used

The owner selected the GPT-5.6 Sol logical profile for the primary Codex finalisation. It was used
for architecture/security reasoning, product hierarchy, implementation, test interpretation and
competition narrative. No silent fallback to another model or external LLM adapter was allowed.
The final Codex version, model label, prompt/report paths and hashed feedback metadata are recorded
with the candidate; the raw `/feedback` session ID is entered manually and is not committed.

## Challenges

- Preserving advanced tournament features while making the first five minutes understandable.
- Exposing FIDE Dutch honestly without implying certification or silently changing legacy events.
- Combining local-Wi-Fi mobile access with a narrow trust boundary and no cloud relay.
- Verifying required Gradle and Android image binaries without a blanket allowlist.
- Separating pre-existing work, human decisions and earlier contributions from the evaluated Build
  Week additions.

## Accomplishments

- A calm five-area core workflow with progressive disclosure.
- Explicit, reproducible synthetic demo data and a judge path designed for under five minutes;
  the final timed run remains an exact-candidate acceptance step.
- Auditable opt-in FIDE Dutch selection while keeping Optimal V2 default.
- Confirmed, reversible result entry and narrower mobile/standings views.
- Swiss-Manager player-master-data exchange and TRF16 tournament-report compatibility in the same local workflow.
- Exact-path/hash/type/provenance Android artifact verification prepared for owner acceptance.
- Public-safe evidence that does not commit binaries, signing keys, private paths or the feedback ID.

## What we learned

Productivity software is not improved merely by adding functions. The decisive work was deciding
which action deserves attention now, which expert control can wait behind More, and which safety
detail must remain visible. We also learned that “allow this binary” is the wrong security unit:
the useful unit is an exact artifact bound to a path, digest, provenance, tool version and reviewed
PR head.

## What is next

- Complete owner review/merge order and rebuild Windows/APK from the exact final SHA.
- Record the Galaxy S25, breakpoint and fresh-install evidence.
- Scale and deepen Swiss edge-case validation for larger opens.
- Continue accessibility and mobile view work after the submission freeze.
- Evaluate standalone Android/offline operation and public distribution only as future roadmap
  work; no F-Droid or store availability is claimed today.

## Installation

Use the owner-provided Windows setup and verify its SHA-256 against the final artifact manifest.
Source-build instructions and the self-contained packaging command are in the repository README.
The Android companion is optional and must only be used if the final manifest and real-device test
are present.

## Testing instructions

Follow `docs/submission/JUDGE_QUICKSTART.md`. Open the synthetic demo, generate the next round,
confirm a result, inspect standings and export TRF16/Swiss-Manager data. The path should take under
five minutes and requires no real player information or cloud account.

## Known limitations

- Not FIDE-certified or officially approved by FIDE.
- Android is a companion candidate, not a standalone offline tournament manager.
- No Play Store, F-Droid or public release claim.
- Final setup/APK/device evidence is pending until the owner-controlled candidate freeze.
- A repository-wide licence decision remains with the owner pending rights confirmation.

## Submission placeholders

- Repository URL: `<OWNER_TO_INSERT>`
- Public YouTube demo URL: `<OWNER_TO_INSERT>`
- `/feedback` session ID: `<OWNER_TO_INSERT_FROM_PRIVATE_RUN_FILE>`
- Final candidate SHA: `<OWNER_TO_INSERT>`
- Build Week commit range: `<OWNER_TO_INSERT>`
