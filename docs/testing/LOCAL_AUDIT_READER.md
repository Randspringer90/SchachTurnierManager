# STM-SEC-003: audit feature

A linked read-only page opens the existing AuditForensicExportBuilder JSONL
format (stm-audit-bundle-1). The manifest must be first; declared event count
must match the event rows. Duplicate event IDs and invalid event shapes fail.
Limits: 5 MiB, 10,000 lines and 5,000 events. Snapshots/forensics are counted
but not retained by the reader; unknown record types have a visible counter.

Filters combine action, severity and optional round. Pagination shows up to
200 rows at a time without hiding the total. Original export order and date
strings are retained. Timestamp fields have a bounded ISO-style shape, not a
new chronology or timezone conversion. Summary text is hidden by default and
shown only after a deliberate checkbox choice. Clear resets that choice and
removes parsed data from the controller. Actor, player-name, reason, details,
raw snapshots and IDs are never rendered. Summary text itself can contain PII:
the page explicitly warns that this is not anonymization. Rendering uses text
nodes only, even when the imported summary contains markup.

This is NOT a forensic integrity validator, signature verifier, backup importer
or chess-rule validator. JSON.parse semantics apply to duplicate member names
(last value wins). A maliciously edited manifest/count is not proof of origin.
The viewer does not certify timestamps, references, snapshots or ignored records.
Ordinary structured JSON audit bundles are not JSONL and are not accepted here.

48 Node tests cover the actual parser, limits, current serializer-shaped
fixtures, records, filters, pagination, privacy defaults, File reads and UI
races. They are not a real .NET serializer roundtrip or browser acceptance.
Source contracts read at base: AuditJournalEntry.cs (706bc3bfe6779ece3ccfb7c22846599fa58bb287)
and AuditForensicExportBuilder.cs (3fabaa98560f2073b32803321fa82da562a60364).

## Integration and remaining gates

Basis: development 338d27186238659463d4f8eef78f62f08a4860da, read live
2026-10-05. Only this package's new files and two small entry/build integrations
are included. Original index.html and package.json were reconstructed from
complete connector text and matched their Git blob hashes before editing.
No successful repository clone is claimed (container DNS unavailable).

Preserve ALL other entry links, #92 root/startup-panel adjacency, #104 offline
notice and previous test/audit commands when merging. New controls are BEFORE
root or links AFTER the main module, not between root and startup panel. The
#102 runner can discover the new top-level test suite; do not run it twice in
a combined build. No new dependency, lockfile, model or policy change. No PWA
precache update: these assets are not guaranteed to load offline.

A real headless Chromium smoke was attempted; its FIRST navigation to the
owned loopback server returned ERR_BLOCKED_BY_ADMINISTRATOR, zero browser
assertions ran. No alternate route or browser-policy change was attempted.
BROWSER=NOT_RUN. Full pinned React/Vite/ASP.NET hosting, keyboard/screen-reader,
Windows/.NET/PowerShell, repository/ReleaseGate and Commit-If-Green checks,
independent Codex/CODEOWNERS review and final green CI remain open.

The canonical BACKLOG/CHANGELOG must be reconciled before merge; this scoped
partial feature does not mark its parent Done. No local user worktree, existing
PR branch, development/main ref, permission setting, release or deployment was
changed. Tests use only synthetic data. No screenshots or raw logs are committed.
