# STM-UX-003: local comparison of two native backups

Open `/backup-compare/index.html` from the application entry. Select two native
TournamentState JSON backups of the same tournament. The left file is the
baseline, the right file is the comparison; dates/names never pick a newer
file automatically. No import, merge, restore, API request or file write exists.

Players/audit entries are matched by GUID; rounds by a positive safe integer
roundNumber. Added, removed and changed records are counted; changes anywhere
inside a record, including pairing results, are considered. Root metadata and
settings are compared separately. Only IDs/counts are displayed, no player
names, audit text or arbitrary values. Detail lists are capped at 200 per group
with explicit omitted counts; the aggregate counts still cover all records.

UTF-8 is strict; one initial BOM is accepted. The parser rejects duplicate JSON
keys (including escaped equivalents), ambiguous camel/Pascal key aliases,
duplicate entity IDs, invalid collection shapes and missing required root
fields. Limits: 5 MiB per file, depth 32, 100,000 JSON values, 5,000 records per
principal list. Native camelCase and PascalCase roots are recognized. Missing
optional auditJournal means an empty list. Audit bundles, wrappers and SQLite
files are not native snapshots and are not accepted as such.

Comparison is deliberately conservative: object key order, external JSON
whitespace and ordering of the three principal lists are ignored. Other array
orders, key casing, numeric spelling and all unknown fields remain significant.
Number tokens are preserved, avoiding silent equality through IEEE-754 rounding
of large integers or long decimals. Thus 1 and 1.0 count as different content.

This is comparison, not schema/semantic validation, chess-rule validation or
restore authorization. It does not prove correct player references, meaningful
results or which backup should be restored. It complements #77 without importing
or modifying that pending PR's parser or review fixes. No stored differences or
user filenames leave the page. Reset/new selections invalidate delayed results.

## Verification and integration

93/93 Node 22.16.0 tests PASS, 0 FAIL, 0 SKIP. The npm command
`test:backup:compare` was actually executed; repeat runs are not additional cases.
The same test command runs before the existing tsc/Vite build. All tests are
synthetic. No new dependency, lockfile or version is introduced.

A shared Chromium 144 smoke was attempted on loopback. Its first navigation
to the fingerprint page was blocked; the comparison page was not reached.
The browser reported
ERR_BLOCKED_BY_ADMINISTRATOR before the first assertion. BROWSER=NOT_RUN;
no alternate route or policy changes were used. Full ASP.NET MIME/static
hosting, full React/Vite build, Windows, .NET/PowerShell project gates,
Commit-If-Green and independent Codex/CODEOWNERS review remain NOT_RUN here.
Source-level tests are not a complete UI or accessibility acceptance.

Direct basis: development cc47f1101983d3f3272a893dbf54bd66fa2355b4.
No prior PR branches, integration worktrees, user files, main or development
were modified. Preserve the entry links and ALL prior test/build commands
from #69/#71/#72/#77/#82/#84/#88/#92 during integration. Both new backup tools
have independent scripts/folders; neither requires the other's PR. New assets
are not added to #71's precache. This is not a complete offline-app guarantee.

Part of existing STM-UX-003, related to #73. Do not count this as an extra
v1.0 requirement or mark the parent Done. Canonical BACKLOG/CHANGELOG must be
reconciled in the integration branch before merge; no status is silently
promoted. This PR's feature description and evidence live in this document.
