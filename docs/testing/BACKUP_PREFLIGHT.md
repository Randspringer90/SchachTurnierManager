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
The preview mirrors the backend import contract where it is known, so that it never
reports STRUCTURE_OK for a file the import rejects or silently changes: duplicate
display names are errors (EnsureUniquePlayerNames), rounds must run 1..n without
gaps and not exceed settings.plannedRounds (default 5, ValidateImportedRounds), and
createdOn must be a valid yyyy-MM-dd date (a missing value would silently become
"today"). Other JSON export/audit wrappers are rejected.

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

76/76 tests passed (core cases incl. the backend-contract cases plus synthetic DOM/source-contract cases).
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

## Remaining scope (STM-UX-003 stays open)

The preview is a standalone page. It does NOT protect the actual import yet: the
existing import still accepts unchecked text and overwrites with
overwriteExisting=true, and the checked file is not handed to the import as exactly
that content. Wiring the preview into the import flow (import only the confirmed,
unchanged bytes, with an explicit overwrite confirmation) is the next STM-UX-003
subpackage. Until then the page is an optional pre-check, not a safety barrier.

BACKLOG.md and CHANGELOG.md record this subpackage (issue #73, PR #77) as partial
delivery; Backup/Restore UX as a whole is not Done.
