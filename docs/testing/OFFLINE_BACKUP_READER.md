# STM-UX-002: read native backups without a running backend

The linked /backup-reader/index.html opens one explicitly selected native
TournamentState JSON backup locally. It shows players, selected rounds,
pairings and stored result kinds, with name/status filtering and player pages.
No fetch, upload, database write, import, score calculation or pairing algorithm
is included. It displays a file snapshot, never claims live synchronization.

Limits: 5 MiB, depth 32, 200000 structural tokens, 5000 players, 1000 rounds,
5000 pairings per round and 20000 pairings total. UTF-8 is strict; initial BOM
is accepted. Duplicate decoded JSON keys, conflicting camel/Pascal aliases,
duplicate player/round/board identities and invalid field shapes are rejected.
Projection drops settings, birth years, contact fields, notes, audit details
and source metadata. Unknown statuses/results and unresolved valid GUID
references remain explicit counters/labels rather than invented data.

Names and the tournament title are hidden initially. Explicitly showing names
also enables name filtering; hiding names clears the filter. This is a display
choice, not access control or anonymization. The input file and tab memory
still contain confidential material. Clear/pagehide discards the projection.
Files read before a newer selection cannot later replace that selection.

This is not the structural preflight in #77, byte/content comparison or a
restore workflow. It neither verifies legal results nor recalculates points
or standings. Stored round lock/verification flags are reported, not certified.
A malformed relationship can be displayed as missing; no import is allowed.
Read the file through a previously loaded application page: the PR does not
precache these assets or promise first-time loading without the backend.

49 focused tests passed, covering numeric/string enum forms, all result kinds,
UTF-8/BOM, aliases, duplicate keys/IDs, budget limits, preserved source bytes,
privacy projection, pagination, File reads and asynchronous controller state.
The domain contracts TournamentState, Player, TournamentRound, Pairing,
GameResult and Enums were read from the immutable base. No real .NET export
roundtrip or actual browser visual/screen-reader acceptance is claimed.

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
