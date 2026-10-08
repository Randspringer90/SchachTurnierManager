# Final integration continuation — source candidate

The Owner explicitly authorized source integration, commits, pushes, PRs and
merges, and replaced human/CODEOWNER approval with real independent SHA-bound
AI reviews. Existing rulesets, CODEOWNERS, tests and all CI remain intact.
Release, deployment, costs, history rewrite, force push and historical checkout
deletion remain unauthorized. SignalNewsLogger is outside the task scope.

Live discovery confirmed the canonical repository, clean carrier `dcb4bd3`,
baseline main/development `abecd00` and 39 open PRs. The repository is PUBLIC;
local environment identifiers were redacted from the public prompt copy.
`.editorconfig` was absent. Historical checkpoints were read as data and not
treated as current success evidence.

## CSV correction

The import preview now carries exact tournament/content/replace/generation
identity through a small tested guard. Changes invalidate synchronously,
out-of-order replies/errors are ignored, and import checks and consumes the
current preview before sending the captured payload. The focused eight tests
pass. Actual headless React regression scenarios are documented in
`docs/testing/CSV_PREVIEW_IDENTITY.md` and run against a fresh source build.

## Scanner integration

PR #115 was freshly reviewed read-only at exact head `1bf337c` / tree
`87fcdfed`. Independent verdict READY, zero BLOCKER/MAJOR. Fresh scanner checks:
106 text-evidence assertions, 285 pattern assertions, 44 risk cases; repository,
prompt-injection, instruction, catalog and routing gates green. Repeated
assertions are not counted as unique tests twice.

The live Base scan completed with OWNER_REVIEW_REQUIRED. The old remote failures
were a missing SHA-bound execution marker, not a currently observed scanner
timeout. A truthful COMMENTED execution review followed the actual AI inspection;
no APPROVED or human review was fabricated. All seven required remote checks
then passed, and #115 merged to development at `bc33fb0`. The existing bypass
was used solely for human approval. The scanner-statuscheck bootstrap was unused.
Current development was merged into the carrier without force or history rewrite.

## Verification and remaining completion evidence

Full source ReleaseGate passes: .NET Domain 625, Application 139,
Infrastructure 26, Golden 13; frontend tests, TypeScript and Vite build plus
their QR/catalog/PWA prerequisites. Product packaging was explicitly skipped.
The first restore failed because the native tool environment omitted standard
ProgramFiles variables; actual Windows special-folder values were supplied
process-locally, with no machine configuration change.

All Node suites, repository/security gates and headless browser smokes are
recorded separately in local run evidence. Initial invocation/environment/test-
harness failures remain distinguishable from successful corrected runs. Pure
Java companion contracts pass 113 assertions; Android SDK/APK/device acceptance
is not claimed. Dependency provenance remains PARTIAL; actual signing, package
release and complete offline replay/lifecycle acceptance are separate backlog work.

The consolidated source includes reviewed adaptations of all 37 original PRs,
with shared UI entries/package scripts merged additively and the native Android
companion replacing the unsafe older Capacitor scaffold. Per-file comparison
and semantic replacement witnesses are retained in the local integration matrix.
No original PR closes until its complete useful contents are proven in main.

This source report does not claim final Main or COMPLETE. Exact final review,
remote CI, protected merges, PR closure proofs, clean main synchronization,
post-main backlog/DoD audit and validated result ZIP are the remaining steps.
Their final evidence will be added by a regular reviewed documentation PR.

Official model catalog sources were retrieved on 2026-10-08:
[OpenAI catalog](https://developers.openai.com/api/docs/models) and
[Anthropic catalog](https://platform.claude.com/docs/en/models/overview).
The repository catalog entries remain current; no generation or provider change
was needed. The existing CoreKI runtime and inherited review runtime were used;
no paid model probe or provider/profile fallback was started.
