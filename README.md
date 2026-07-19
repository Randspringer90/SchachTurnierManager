# SchachTurnierManager

**A local-first tournament workstation for chess clubs: install on Windows, run pairings,
capture results from the tournament desk or a phone, and export compatible tournament data
without requiring a cloud account.**

> OpenAI Build Week candidate · Work & Productivity · version line `0.54.1`

SchachTurnierManager is built for volunteer tournament directors, chess clubs and organisers of
small and medium-sized opens. The project predates Build Week; the submission evaluates only the
documented additions made during the submission period. It is not an official FIDE product or a
FIDE-certified pairing program.

## What it solves

A club tournament often spans registration lists, pairings, handwritten results, standings and
several exchange formats. Existing workflows can require specialist knowledge or hosted services.
SchachTurnierManager keeps that operational loop on the tournament computer:

1. create a tournament or open the synthetic demo;
2. add/import participants;
3. preview and generate a round;
4. enter confirmed results on the PC or a local-Wi-Fi companion;
5. review standings and export the event.

The primary interface exposes only **Overview, Participants, Round, Standings and More**. Advanced
pairing, audit, backup and compatibility tools remain available through progressive disclosure.

## Main capabilities

- Round robin and Swiss tournaments with persistent SQLite storage.
- Optimal V2 Swiss pairing as the default, plus opt-in **FIDE Dutch** pairing with an auditable
  initial-colour setting.
- Pairing preview, quality findings, round locks, manual overrides and a persistent audit journal.
- Confirmed result entry with a visible undo path.
- Standings, cross table, categories, tie-breaks, performance and printable round sheets.
- Swiss-Manager CSV player-master-data exchange, TRF16 tournament export/player-data import, plus JSON backup and CSV exports.
- German and English demo path; additional registered languages are explicitly marked preview.
- Self-contained Windows desktop/portable packaging and an Inno Setup per-user installer path.
- Android companion candidate for same-Wi-Fi use; see the status boundary below.
- No ads and no tracking. Core tournament operation has no cloud requirement. Optional external
  player lookup is a separate network action and is not needed for the demo.

## Two-minute quick start

For a judge or first-time user, follow [Judge Quickstart](docs/submission/JUDGE_QUICKSTART.md).
The intended packaged path is:

1. install the per-user Windows setup (no administrator account required);
2. launch **SchachTurnierManager**;
3. choose **Open demo tournament**;
4. inspect the eight synthetic players and completed first round;
5. preview/generate the next FIDE-Dutch round;
6. confirm a result and review the updated standings;
7. open **More → Print, export & backup** and generate TRF16/Swiss-Manager output.

No real players, clubs or FIDE records are included in the demo.

## Windows setup

The repository contains the self-contained desktop and installer build paths. Final Build Week
binaries are deliberately **not committed**. Build the current source locally:

```powershell
pwsh -NoLogo -NoProfile -File .\scripts\Invoke-ClickInstallReadiness.ps1
```

The readiness flow validates packaging, checksums, a fresh per-user installation, shortcut,
isolated app smoke test and uninstall. Installed tournament data is stored separately below the
current user's local application-data directory, so uninstall behaviour can preserve user data.
See [Colleague installation](docs/release/COLLEAGUE_INSTALLATION.md) for the operational details.

For a self-contained desktop folder without an installer:

```powershell
pwsh -NoLogo -NoProfile -File .\scripts\Publish-DesktopApp.ps1
```

The target computer does not need Node.js or a separate .NET runtime.

## Android companion status

The Android/Capacitor companion is currently an **owner PR candidate (#49)**, not a published
release and not yet part of `development`. It is designed to connect only to a private IPv4 or
`.local` address on the same Wi-Fi/hotspot, verify the SchachTurnierManager health identity and
submit synthetic or real tournament results to the local PC.

Before the candidate can be accepted, owner PR #50 must land the exact-path/hash/provenance gate
for the required Gradle wrapper and Android resources; PR #49 then requires a new SHA-bound static
review, green CI and a real Galaxy S25 test. There is no Play Store or F-Droid build, and the
companion is not claimed to operate as a standalone offline tournament manager.

## Demo data

The WebApp's explicit **Open demo tournament** action creates a versioned local preset:

- `Build Week Demo Open`;
- eight `Demo Player NN` records with fictional clubs and ratings;
- Swiss format, three planned rounds, FIDE Dutch selected and initial colour White;
- one completed round, ready to preview/pair the next round.

The preset is created only after a user action. Choosing it again opens the existing demo instead
of silently adding duplicates. Details and reset behaviour are documented in
[Demo Data](docs/submission/DEMO_DATA.md).

## Run from source

Prerequisites: current .NET SDK and Node.js/npm. From the repository root:

```powershell
dotnet restore SchachTurnierManager.sln
dotnet run --project .\src\SchachTurnierManager.WebApi\SchachTurnierManager.WebApi.csproj
```

In a second terminal:

```powershell
Push-Location .\src\SchachTurnierManager.WebApp
npm ci
npm run dev
Pop-Location
```

Open `http://localhost:5173`. Development data and logs must stay local and are excluded from
commits. The packaged desktop serves the embedded WebApp from the local API process instead.

## Architecture

- `Domain`: tournament rules, pairings, standings and rating calculations.
- `Application`: use cases and orchestration.
- `Infrastructure`: SQLite persistence and external adapters.
- `WebApi`: local HTTP surface and embedded packaged dashboard.
- `WebApp`: React/TypeScript/Vite operator interface; no pairing algorithm lives here.
- Android candidate: Capacitor shell around the deliberately narrow companion workflow.

Pairing decisions remain auditable. Manual interventions do not silently replace the algorithmic
record.

## Local-first, privacy and security

- Tournament state is local SQLite data; backup and exports are explicit user actions.
- The public health response does not expose absolute database or log paths.
- No analytics SDK, ad SDK or tracking service is required for the core workflow.
- Local phone access is limited to the same private network; no tunnel or cloud relay is supplied.
- Pull requests are treated as untrusted data and statically reviewed against their exact base/head
  SHA before any foreign code is executed.
- Required Android binary resources are accepted only through exact path, type, hash, size,
  provenance and owner-review attestations; there is no blanket binary allowlist.
- Secrets, signing material, APKs and installer EXEs are excluded from the repository.

Security details: [Safe PR Review](docs/security/SAFE_PULL_REQUEST_REVIEW.md) and
[Contributor Security](docs/security/CONTRIBUTOR_SECURITY.md).

## How Codex and GPT-5.6 were used

The primary Build Week finalisation uses Codex CLI with the owner-selected GPT-5.6 Sol profile for
repository audit, UX implementation, tests, exact-SHA security-gate design, documentation and
candidate preparation. The main work remains in one traceable Codex thread, which will provide the
submission `/feedback` session ID directly to the owner; the raw ID is never committed.

This is an existing project. Earlier work includes owner decisions and contributions prepared with
other tools and by trusted co-developer Marcel. Those contributions are not relabelled as Codex
work. [Build Week Changelog](docs/submission/BUILD_WEEK_CHANGELOG.md) and
[Codex Collaboration](docs/submission/CODEX_COLLABORATION.md) separate the baseline, submission
period and human/agent roles.

## Build Week additions since 13 July 2026

The dated, commit-backed scope includes FIDE-Dutch implementation and validation, Swiss-Manager /
TRF16 compatibility, safer release/runtime foundations, the Android companion candidate and this
finalisation's progressive UX, synthetic demo, public-safe health contract and submission package.
Only merged commits in the final documented range count as the candidate. See
[Build Week Changelog](docs/submission/BUILD_WEEK_CHANGELOG.md) for the exact boundary and status.

## Tests and quality

Run the repository gate:

```powershell
pwsh -NoLogo -NoProfile -File .\scripts\ReleaseGate.ps1
```

The gate restores and builds .NET, runs the automated tests, compiles TypeScript/Vite and creates a
portable package. Additional installer, security, Android and manual-device gates are listed in
[Submission Checklist](docs/submission/SUBMISSION_CHECKLIST.md). A green source gate does not
substitute for the final exact-SHA installer/APK build or Galaxy S25 test.

## Known limitations and roadmap

- FIDE Dutch is implemented and tested but is not represented as FIDE certification or approval.
- Large Swiss fields and edge cases still require the documented audit review; scaling work remains
  on the roadmap.
- The Android companion and exact artifact gate are pending owner PR review and real-device proof.
- Full standalone Android/offline operation, F-Droid, Play Store and public binary distribution are
  future options only.
- Visual breakpoint/device acceptance is manual until captured on the final candidate.

See [Known Limitations](docs/submission/KNOWN_LIMITATIONS.md) and the final readiness report for the
submission-specific state.

## Licence

No repository-wide licence has yet been approved. Public source visibility does not by itself grant
reuse rights. The owner must choose a licence only after contributor rights/consent are confirmed,
or arrange explicit private jury access if the competition permits it. No silent relicensing is
performed; see [Licence Decision](docs/submission/LICENSE_DECISION.md).
