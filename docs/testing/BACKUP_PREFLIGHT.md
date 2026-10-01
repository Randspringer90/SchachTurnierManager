# STM-UX-003: browser-local backup preflight

Issue #73. A standalone page at /backup-check/index.html is linked from the app
entry HTML. Choose a native Backup JSON export from
GET /api/tournaments/{id}/export/json. The page never calls that API, uploads,
stores or imports the selected file. The actual import remains a separate action.

## Scope

Strict UTF-8 JSON, duplicate keys (including escaped spellings), a 5 MiB input
limit, depth 64, list size 20000 and a bounded 100-entry issue display. The native
camelCase TournamentState shape is checked for required root fields and lists,
nonzero GUID identifiers, repeated player/round/board identifiers and valid
per-round player references. Self-pairing and multiple assignments are errors.
Duplicate display names are warnings. Other JSON export/audit wrappers are rejected.

All user text uses textContent. CSP disallows connections/forms and only loads
local script/style resources. New file selection or reset invalidates pending
reads. Reset clears the local view, not the original file or application data.

STRUCTURE_OK is explicitly not a restore guarantee. Settings, game results, audit
contents, chess rules, backend limits and version compatibility are not fully
validated. The page does not assert that a backup can safely overwrite a tournament.
Before an actual import, preserve the current state and make that decision separately.

## Tests

```text
npm --prefix src/SchachTurnierManager.WebApp run test:backup
```

65/65 tests passed: 53 core cases and 12 synthetic DOM/source-contract cases.
They cover malformed input, limits, duplicate escaped keys, references, byes,
Unicode/BOM, nonmutation, literal rendering, stale reads, reset and read failures.
These are not browser tests. The attempted Chromium navigation was blocked with
ERR_BLOCKED_BY_ADMINISTRATOR before the UI ran; it was not bypassed. Browser,
actual ASP.NET hosting/static MIME behavior, responsive layout, full pinned-toolchain
app build, .NET/PowerShell gates and independent review remain unverified.

The new npm command is dedicated; it is not automatically added to existing CI or
prebuild chains. Preserve all other scripts from #69/#71/#72 and newer dependencies
when merging package.json. No lockfile/version change is required. The original
entry HTML and package.json were byte-verified before the targeted changes.

## Remaining integration documentation

BACKLOG.md / CHANGELOG.md synchronization remains required before merge. Existing
STM-UX-003 should reference issue #73 and this PR as an In Review subpackage, not
mark all Backup/Restore UX Done. Proposed Unreleased entry:
"STM-UX-003: added a browser-local structural backup preview with bounded validation,
literal findings and no upload/import side effects. Actual restore remains separate."
The existing canonical planning file remains the only task authority.
