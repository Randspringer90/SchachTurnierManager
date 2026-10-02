# STM-SEC-003: count-only support preview

Open /support-summary/index.html and explicitly select a native JSON backup.
A new allowlisted output contains only player, round, pairing, audit-entry,
locked-round and verified-round counts, plus fixed explanatory metadata.
No names, identifiers, dates, ratings, free text, settings values, paths,
filenames or hashes of the source are emitted. No upload, storage, automatic
clipboard write or file export occurs. The user can inspect and manually copy
the report. Input backup bytes and local tournament data are never changed.

This is data minimization, NOT guaranteed anonymization. Counts can still be
confidential or identifying in context. It is also not backup/schema/chess-rule
validation or a restore decision. The original file must not be shared just
because the count preview succeeded. Current reporter scope does not cover
other application logs, exports, historical Git content or legal approval.

The small bounded JSON reader rejects duplicate keys, including escaped
equivalents. Known camelCase/PascalCase aliases must not coexist. Input UTF-8
is strict and one initial BOM is accepted. Limits are 5 MiB, depth 32, 100,000
JSON values and 5,000 members of each checked collection. Unknown fields are
parsed within these budgets but never copied to output. Missing optional
auditJournal means zero events; absent lock/verified flags mean false.

55/55 focused tests PASS, covering allowlist-only output with synthetic
identifier/text markers, counts, parser/shape/budget errors, unchanged input,
a real Blob-to-preview path and stale/double-click/controller races.

File API reference: https://www.w3.org/TR/FileAPI/ (consulted 2026-10-02).

## Integration and evidence boundaries

Base: development cc47f1101983d3f3272a893dbf54bd66fa2355b4.
Entry HTML and package.json were reconstructed and byte-verified against their
Git blob hashes before modification. No user workstation or existing PR branch
was modified. The new entry link and npm test command must be merged additively
with ALL other pending links/build commands; never replace an integrated file
with this branch's older baseline. The shared ui-harness.mjs is identical across
the three packages. No dependencies, lockfiles, versions or security policies
were changed. The existing full TypeScript/Vite build follows the added tests.

The focused Node tests run on Node 22.16.0. Tests using DOM adapters are not
browser, accessibility, React, ASP.NET hosting or full application evidence.
Full pinned build, .NET/PowerShell gates, Commit-If-Green, independent
Codex/CODEOWNERS review and green remote CI remain required. No browser
acceptance test was executed in this run. New static .js assets are not
automatically added to the pending PWA precache; no full offline-app guarantee.

Keep the existing parent task open until its entire original acceptance scope
is fulfilled. The linked PR supplies only the feature described here, not a
release/merge authorization. Synchronize the canonical BACKLOG/CHANGELOG on
integration before marking anything Done. No runtime logs, real rating lists,
personal backups, secrets, screenshots or other visual artifacts are published.
