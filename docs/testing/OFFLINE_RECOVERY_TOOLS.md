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
different browser or user account, on an unvisited origin, after storage eviction or where
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
Because the recovery files carry no version in their names, an activation that
happens while a recovery page is still loading its modules could in rare cases
combine files of two releases (a millisecond window); reloading the page resolves it.
The service worker only stores public application files, not recovery results.

Only the exact `/backup-reader/index.html` and `/backup-lock/index.html` URLs
(used by all in-app links) are served offline. The folder URLs `/backup-reader/`
and `/backup-lock/` are deliberately not intercepted and need the server.

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

Adopted from PR #125 on `integration/pr-125-safe-adoption`, starting from the
current development head. No dependencies, lockfiles, product versions, releases
or deployments change. Exact-SHA local gates, required GitHub CI and the
independent AI review are recorded in the integration pull request. The real
browser scenario above remains open; the parent task stays partial and is not
counted as newly Done.
