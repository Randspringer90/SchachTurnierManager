# STM-INFRA-011: reproducible backlog status counts

Issue: #87. This offline tool measures the canonical overview table in
BACKLOG.md, not feature volume, engineering hours, code quality or release
readiness. It never calls GitHub, invokes git, changes status, or grants merge
permission. There is no automatic remaining-PR forecast.

## Usage

From the repository root:
node scripts/Measure-BacklogProgress.mjs --release v1.0.0

Omit --release for all tracked releases. An optional positional Markdown path
supports an explicitly selected snapshot. The default path is relative to the
script, not the shell working directory. From the WebApp, npm run progress
selects v1.0.0. npm run test:progress runs the isolated tests; prebuild includes
that test command before the existing production build.

## Metric

Each unique task has weight 1. Only status Done contributes to the numerator.
Backlog, Ready, In Progress, In Review, Blocked and Deferred all stay in the
denominator. Reports include total/done/remaining, counts for every status,
release groups, remaining IDs and exact UTF-8 input SHA-256 (including a BOM).
Partial tasks receive no invented fractional percentage. Empty or malformed
input and unknown/missing release selections fail instead of reporting 100%.

Only the uniquely named level-2 Uebersicht heading (spelled with German umlaut
in BACKLOG.md) and its eight-column table are parsed. Fenced examples outside
that table and the later repeated detailed task descriptions are not counted.
Unsupported table shapes, duplicate IDs, invalid statuses/priority/release,
invalid UTF-8 and inputs over 1 MiB fail closed. This is a repository-specific
Markdown subset, not a general Markdown interpreter. No task content executes.
Titles, issue text and raw input paths/errors are absent from output; task IDs
are intentionally included. The source hash is document identity, not redaction
or proof that its declared statuses are current.

## Limits and verification

The report explicitly labels Git integration, tests and CI NOT_CHECKED and
sets mergeAuthorized=false. A stale BACKLOG produces stale status counts.
Independent source review, current PR/CI checks and real DoD evidence are still
required. Updating or splitting tasks changes the denominator; compare a stable
milestone scope instead of treating every new PR as completed functionality.

51/51 Node 22.16.0 tests passed, including actual CLI child processes, real
files, nonmutation and symbolic-path entry. npm prebuild ran the same suite;
repeat executions are not additional tests. Full application/.NET/PowerShell
and Windows runs, independent review and remote CI remain integration gates.

## Integration

No dependencies, lockfiles, product versions or protected workflows changed.
Merge package.json additively with existing i18n/PWA/backup/QR prebuild/tests;
never replace those with this branch's older base scripts. Keep the default
build command and dependency versions. Add STM-INFRA-011 as an In Review
infrastructure helper (target development) to canonical BACKLOG and record the
new command in CHANGELOG before merge. This is not a new v1.0 product mandate.
