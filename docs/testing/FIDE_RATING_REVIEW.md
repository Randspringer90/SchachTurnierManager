# STM-IE-004: compare selected players with FIDE lookup values

The linked /rating-review/index.html reads the existing tournament list and
chosen tournament only after explicit clicks. Select 1-20 players with unique,
valid ASCII FIDE IDs, confirm that the server may contact FIDE, then compare
stored Standard/Rapid/Blitz ratings with existing FIDE-ID lookup responses.
No automatic write, update/apply endpoint, player merge or deletion exists.

Queries are serial; per-player missing/unsupported/unavailable/failed or
identity-mismatched results remain visible, not successful no-change reports.
Found profiles must identify the exact requested FIDE ID. A different name
gets a human identity-review warning. Missing/zero source ratings mean unknown
or unrated, never a suggestion to erase existing values. Selection/consent
changes invalidate old replies. Cancellation stops the batch result; another
UI operation waits until the old one settles. Clear/pagehide drops the data.

The GET transport permits only /api/tournaments, one GUID-specific tournament
and /api/external-players/fide/<ASCII-ID> on the same origin. Redirects and
credential forwarding are disabled. Fetch and body share a bounded deadline
(up to eight seconds), strict UTF-8/JSON MIME and byte limits. FIDE response
bodies are at most 64 KiB. Raw provider messages, profile links, birth years,
notes and errors are not copied into the report.

These are client restrictions, NOT a new server authorization boundary. The
existing tournament list sends complete TournamentState objects; full private
bodies reach the browser before projection. Use a trusted operator environment,
not an untrusted public kiosk. Backend provider activity on an explicit click
may contact FIDE. This package neither activates name lookup nor changes the
existing provider or its credentials, timeouts, cache or network policy.

The baseline is captured when players load; it may become stale while checking.
RetrievedAt is reported source metadata, not proof of current published ratings.
Review identity and refresh the tournament before any later manual edit. No
persistent cache, automated background refresh, export or extra window exists.
This complements #95 offline name search and #110 candidate research; it does
not duplicate their interfaces or claim STM-IE-004 fully complete.

48 focused tests passed: exact route whitelist, real Response/ReadableStream
with synthetic transport, full-body timeout, cancellation, identifiers,
profile projection, batch boundaries, serial requests, identity/name warnings,
unknown ratings, per-row errors and explicit UI consent. No live FIDE query,
actual account access, ASP.NET host or database was used in verification.

## Integration / remaining DoD

Base: development abecd00c93d8c651f362d8ef3f0098200fe385ba; inspected 2026-10-06. Original index.html and
package.json were reconstructed exactly and bound to their Git blob SHAs.
Both integrated QR test commands are preserved. Each feature has its own
focused npm test before the existing build chain; shared read-tools-test-dom
is byteidentical across the three PRs. The combined source subset passes 135
unique tests (38 + 49 + 48); repeat runs are not additional coverage.

Preserve every other entry link, #92 root/startup-panel adjacency, prebuild hook
and test/audit command when integrating other pending PRs. New links are after
the main module. The #102 suite runner can discover these top-level tests;
verify discovery, then avoid running the same suites twice. No new dependency,
lockfile, product version, model catalog, API schema or security policy changed.
Only public .js assets are used; these are not added to the PWA precache.

A headless Playwright smoke was attempted, but Chromium's executable is absent
in this environment. The browser did not launch; zero browser assertions ran.
This is NOT the older ERR_BLOCKED_BY_ADMINISTRATOR case. Full pinned React/Vite,
ASP.NET, Windows, .NET/PowerShell, repository/Release/Commit-If-Green gates and
independent Codex/CODEOWNERS review remain NOT_RUN. Focused Node tests are not
full DoD or merge approval. Required CI and canonical BACKLOG/CHANGELOG
synchronization remain before merge. Parent tasks are not declared Done.

No changes to existing PR/integration branches, user checkouts, development/main,
permissions, external accounts or release/deployment artifacts. All tests use
synthetic data; no user backups, passwords, screenshots or raw runtime logs
are committed. Source verification used a subset, not a successful full clone.
