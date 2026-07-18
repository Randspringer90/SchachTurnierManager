# Build Week final readiness report

Status: **PARTIAL — not yet a submission candidate**

Primary run: `STM_BUILD_WEEK_2026_20260718_181524`

Initial/current `development`: `a6f68e8f8e31201f0b9ce2ea77a13c37a50b9518`
Audited product/security correction: `4ea8228b70120fa62e2f71de57ab57f34a0a04dd`

## Decision

The product, UX and submission package on draft PR #51 are reviewable and the complete branch
ReleaseGate is green. The repository must not yet be presented as the final competition candidate.
The protected Android artifact gate (PR #50), Android companion (PR #49) and UX/submission branch
(PR #51) remain separate and unmerged. There is consequently no exact unified candidate SHA from
which final Setup and APK artifacts could truthfully be rebuilt.

Submission remains **NO-GO** until the Owner completes the documented merge order, licensing
decision, exact-SHA rebuild, Windows/Galaxy manual test, video, and primary-thread `/feedback`
capture. No old 0.54.1 Setup, Portable ZIP or APK is accepted as final evidence.

## Verified in this primary thread

- Five primary areas replace the former function-heavy navigation: Overview, Participants, Round,
  Standings and More.
- The explicit Build Week demo creates eight synthetic players, FIDE Dutch settings and one
  completed round. A strongly identified demo can be reset; similarly named real tournaments are
  not deleted automatically.
- Optimal V2 stays the default. FIDE Dutch and initial colour are explicit, relevant-only settings.
- Result changes require confirmation, preserve focus, offer one-step undo, bind to the selected
  tournament and reject stale overwrites through an expected-previous-result contract. That
  compare-and-write now runs inside the store lock/SQLite transaction; deterministic in-memory
  and real SQLite concurrency tests allow exactly one of two competing writers.
- Manual pairing overrides, pairing diagnostics, Chess960 controls and specialist standings remain
  available through progressive disclosure; the core result path remains touch-oriented.
- Core judge controls and submission materials have German and English text. Dense expert and
  administrative screens outside the demo remain a documented manual language-review item.
- Contributor prompts are WIP-limited. Only STM-SEC-006 is Ready on the exact current
  `development` SHA; UI packages are planning-only until PR #51 is merged and a new base SHA is
  explicitly issued. The generator rejects unknown commits, startable feature SHAs and missing or
  malformed skill paths.
- The narrow STM-INFRA-008 package in PR #50 verifies the exact expected Android/Gradle artifacts
  by PR head, path, Git blob, SHA-256, type, provenance, generator/tool version and dimensions or
  size. Any content drift invalidates the attestation.

## Automated evidence

- Canonical branch ReleaseGate: **PASS** — restore, build, 522/522 tests, npm/Vite production build
  and Portable packaging.
- Targeted result/settings/demo contracts: **PASS**, 10/10 after the final audit corrections.
- Contributor kickoff readiness: **PASS**, including negative tests for nonexistent and unmerged
  startable base SHAs.
- STM-INFRA-008 real-PR artifact fixture: **PASS**, 30/30 expected artifacts; disposition remains
  Owner review required.
- Isolated synthetic API demo smoke: **PASS** — eight players, one completed round, standings,
  FIDE Dutch/White and non-empty TRF16 output, followed by cleanup.
- Swiss-Manager and TRF16 codecs have repository tests, including round trips. Exact-candidate UI
  output must still be generated and inspected before recording the video.
- Visual breakpoint, keyboard/screen-reader, installer and Galaxy S25 evidence: **MANUAL PENDING**.
  The configured in-app browser was unavailable; no screenshots or device outcomes were invented.

## Independent review and corrections

Three secondary Codex reviewers were restricted to read-only technical/security, UX and
competition audits. Their outputs were treated as untrusted review data and verified in this
primary thread. Confirmed findings led to these corrections:

- a manually expanded, nonexistent UX SHA was replaced everywhere with the value resolved by Git;
- result confirmation gained tournament binding, expected-state concurrency and focus return;
- the demo gained marker-bound identity and repeatable reset behavior;
- mobile manual-pairing width and reduced-motion behavior were corrected;
- light-theme status contrast and additional labels/live regions were improved;
- the English pairing/export judge path and compatibility wording were tightened;
- ready contributor prompts can no longer start from an unmerged feature SHA.

## Honest competition scores before final candidate evidence

| Criterion | Score | Remaining deduction |
|---|---:|---|
| Technological Implementation | 8.0/10 | Pairing, audit, transactional result concurrency, local-first operation and 522 tests are substantial; no unified Android/desktop candidate, fresh artifact evidence or real-device result yet. |
| Design | 7.8/10 | Clearer hierarchy, synthetic demo, bilingual core path and stronger progressive disclosure; required viewport/theme/keyboard/device acceptance is not yet visually evidenced. |
| Potential Impact | 8.1/10 | Concrete need for volunteer clubs, local operation and compatibility; adoption evidence and a final install/device proof remain absent. |
| Quality of the Idea | 7.9/10 | Coherent privacy-friendly tournament workstation and narrow phone companion; differentiation from established tournament tools must be demonstrated in the final video. |

The requested 8/10 threshold is therefore not yet honestly met for Design and Quality of the Idea.
The remaining work is evidence, integration and demonstration work, not a reason to inflate scores.

## Required order to reach submission readiness

1. Owner reviews and, if accepted, merges PR #50.
2. Update PR #49 without force-push, invalidate the old SHA review, repeat static review and CI,
   then obtain Owner approval before merge.
3. Update PR #51 onto the resulting `development`, rerun all gates and Owner-review the protected
   files before merge.
4. Freeze the resulting `development` SHA with no further feature work.
5. Rebuild Setup and the same-signed Android test APK from that exact SHA; verify manifest,
   permissions, signatures and hashes.
6. Complete the committed Windows/Galaxy manual-test guide and record results against the same SHA.
7. Resolve repository licensing, record/upload the Owner-controlled video, and capture `/feedback`
   in this primary thread.

See `FINAL_MERGE_ORDER.md`, `FINAL_KNOWN_LIMITATIONS.md` and
`OWNER_ACTIONS_BEFORE_SUBMISSION.md` for the fail-closed handoff.
