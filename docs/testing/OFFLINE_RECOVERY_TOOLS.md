# STM-UX-002: cached recovery tools

The existing service worker now precaches the exact five shipped files of each
of backup-reader and backup-lock: index.html, main.js, ui.js, core.js and
style.css. No directory-prefix allowlist is added. API responses, input files,
backup bytes, passwords, JSON exports, query URLs and arbitrary neighbouring
paths remain outside the cache. Existing method/auth/range/no-store exclusions
remain unchanged. The recovery tools themselves do not gain new persistence.

After a successful initial ONLINE installation/activation on the same secure
origin, both tools can be opened for the first time even when the server is
unreachable. The cache must still exist. This does not promise offline use in a
new browser/profile, on an unvisited origin, after storage eviction or where
service workers are unavailable (including ordinary non-secure LAN HTTP).
The explanatory text on both tool pages reflects these prerequisites.

## Update consistency

Recovery HTML AND its unversioned JS/CSS use the existing complete active shell
snapshot. A later network response cannot update an individual module while
leaving its cached HTML old. Installation validates and stages the full existing
shell plus these ten files before activation. A missing, private, redirected,
wrong-MIME or unwritable file rejects the update and preserves the old slot.
The existing build fingerprint already covers the shipped public resources.
No cache namespace or product-version bump is needed.

This preserves the existing two-slot lifecycle, not a new per-client version
pinning system. A tab surviving activation still follows that existing lifecycle;
no broader multi-release or offline-mutation/synchronization guarantee is added.
The service worker only stores public application files, not recovery results.

## Executed verification

95/95 focused tests PASS, zero FAIL/SKIP: 90 service-worker cases and the five
existing build-fingerprint cases, via the real npm run test:pwa command.
16 cases were added; all 74 previous worker cases retain their assertions.
Only the expected installation counts grow by exactly ten resources.
Before the production fix the expanded worker suite had 77 PASS / 13 FAIL.
The unchanged original worker suite separately passed 74/74.

New coverage includes the exact dependency closure read from the current tool
HTML/modules, first offline requests after install, consistent resources before
and after activation, unsafe replies, storage failure, incomplete snapshots,
private cached responses, and excluded query/input/API-like paths. These are
real worker executions in a Node VM with controlled Cache/Fetch event adapters,
not a real browser or ASP.NET-hosted PWA acceptance test.

An additional Chromium 144.0.7559.96 headless test was attempted on an owned
loopback fixture host. The first navigation returned ERR_BLOCKED_BY_ADMINISTRATOR.
Zero browser assertions ran. No alternate route or policy change was attempted.
The browser scenario remains open: install online, disconnect, first-open each
tool, then read a synthetic backup and prepare an encrypted download offline.

No package.json changes: the existing test:pwa/prebuild hook runs these tests.
The second error-boundary package is not required for this package to work.
Source contracts checked 2026-10-08: https://www.w3.org/TR/service-workers/

## Publication and integration gates

Base: development d168a5a12a65dd66af18829277b7dab02c4422db, whose source tree
matches the completed main integration. Original edited files and every
unchanged source used in the focused tests were matched against Git blob SHAs.
This environment uses an explicit source subset, not a full repository clone.
No existing PR, user checkout, main/development ref or security policy changes.
No dependencies, lockfiles, product versions, releases or deployments change.

Full pinned TypeScript/React/Vite, .NET, PowerShell, Windows, repository safety
and Commit-If-Green gates are NOT_RUN here. Static self-review is not a separate
Codex review. Keep the PR a draft until the regular exact-SHA CI and independent
AI review complete. No approval marker or ruleset bypass is supplied by this PR.
Canonical BACKLOG/CHANGELOG integration references still need reconciliation;
the existing parent task remains partial and is not counted as newly Done.
