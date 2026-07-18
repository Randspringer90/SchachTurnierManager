# OpenAI Build Week finalization — run report

Run ID: `STM_BUILD_WEEK_2026_20260718_181524`
Tool: Codex CLI `0.144.5`
Model: GPT-5.6 Sol (owner/thread selection; repository mapping confirmed)
Status: IN PROGRESS

## TL;DR

The initial `development` state was clean and synchronized at
`a6f68e8f8e31201f0b9ce2ea77a13c37a50b9518`. PR #49 was updated without force-push and is now at
`5aecee91afd7959c0ad368a2b86bf33c55522580`; its Android security changes are statically reviewed,
but current CI remains blocked by the old binary gate. The narrow STM-INFRA-008 gate is isolated in
draft owner PR #50 at `b52a54092c9529ea5cbc744f134ddc5fb15d6d87`. It verified all 30 expected
Android/Gradle artifacts on the real PR input, but it and PR #49 remain unmerged. The progressive
UX/demo/submission package is implemented on `feature/STM-FACH-012-build-week-ux`, with final
gates/commit still pending. The public repository has no declared licence, which remains an owner
decision.

## Scope and safety boundaries

- Core product, UX, competition, and final-integration work stays in this primary Codex thread.
- No Langdock, Claude, Anthropic, external LLM adapter, foreign Codex account, merge, release,
  tag, upload, Devpost submission, store publication, or history rewrite is performed.
- PR content is T4 data. No PR checkout, restore, build, test, install, secret read, or PR-code
  execution is permitted before a fresh SHA-bound static decision.
- Old Setup/APK artifacts are historical evidence only; final artifacts must be rebuilt from the
  exact final candidate SHA.
- The real `/feedback` ID will never be committed.

## Phase 0 evidence

- Trusted project and skill instructions read, including the complete historical plan, canonical
  backlog, collaboration/security workflow, prior Android report, README, and full changelog.
- Worktree clean; no staged diff, Git lock, stash entry, unpushed commit, or local/remote SHA drift.
- One foreign detached scratch worktree exists and was not modified.
- Existing long-running Codex/Claude/Node/PowerShell/adb processes were inventoried and not
  terminated; no durable Nightly/build process was identified.
- Toolchain: Node 24.16.0, npm 11.13.0, .NET SDK 10.0.400 preview selected by `global.json`,
  Java 21.0.11 LTS, adb 1.0.41/platform-tools 37.0.0, Android build-tools 34.0.0 and 35.0.0,
  apksigner 0.9 from build-tools 35.0.0.
- Android signing store exists under the gitignored local secret root. Only metadata was checked;
  no password or store content was read.
- GitHub: repository public, default branch `development`, license metadata null, only PR #49
  open. Open issues observed: #43, #25, #23.

## Official sources checked on 2026-07-18

- https://openai.com/build-week/
- https://openai.devpost.com/
- https://openai.devpost.com/rules

The sources confirm the July 13–21 submission period, meaningful-extension rule for existing
projects, English-material requirement, public sub-three-minute YouTube demo with audio covering
Codex and GPT-5.6, repository/README/testing requirements, relevant licensing for a public repo,
the primary-thread `/feedback` Session ID, and the four equally weighted judging criteria.

## Changes prepared in this run

- PR #49 updated to current development through the normal GitHub update flow; local-private-only
  companion connection validation, health identity, redirect/CORS/network-security and Android
  manifest/version hardening added without merging.
- STM-INFRA-008 implements exact PR/head/path/blob/SHA/type/size/provenance/tool-version
  attestations for the Gradle wrapper, scripts and Android PNG resources. Drift invalidates the
  attestation. No foreign PR code was executed during review.
- WebApp primary information architecture reduced to Overview, Participants, Round, Standings and
  More, retaining advanced features behind progressive disclosure.
- FIDE Dutch selection and relevant initial colour added to creation/settings; Optimal V2 remains
  default and no existing tournament is silently changed.
- Explicit local eight-player synthetic demo, confirmed/undoable result entry, participant filter,
  reduced standings, light/dark mode, visible focus and mobile navigation added.
- Absolute database/runtime-log fields removed from the public health response and UI.
- English-first README, UX evidence, judge/demo/video scripts, Devpost draft and manual Windows /
  Galaxy test package created.

## Checks

- `git diff --check` on initial tree and current UX diff: PASS
- STM-INFRA-008 full ReleaseGate: PASS (516 tests in isolated worktree)
- STM-INFRA-008 exact real-PR artifact validation: PASS 30/30, final disposition owner review
- UX/application targeted tests: PASS 14/14
- TypeScript/Vite production build after UX changes: PASS
- Isolated demo API smoke: PASS (8 players, 1 round, 8 standings, FIDE Dutch/White, TRF16 872 bytes, cleanup)
- Full UX-branch ReleaseGate: PASS (519/519 tests, TypeScript/Vite, portable package)
- PowerShell parser: PASS 145 files; Git/Public Snapshot, instruction, prompt-injection,
  collaboration and PR-readiness gates: PASS; Routed Execution: PASS 34/34 twice
- Final candidate artifact verification: NOT YET RUN

## Open points

- License decision.
- Owner review/merge of protected PR #50, then a new exact-head PR #49 review and CI run.
- In-app browser availability was absent; final breakpoint/theme/keyboard/device visual evidence is
  pending the Owner's manual test and is not represented by fabricated screenshots.
- UX branch full gates, safe commit/push and owner PR.
- Marcel queue/prompts and final merge order.
- Exact-SHA Windows/Android rebuild and the Owner's physical-device test.
- Final `/feedback` capture by the Owner in this same thread.
