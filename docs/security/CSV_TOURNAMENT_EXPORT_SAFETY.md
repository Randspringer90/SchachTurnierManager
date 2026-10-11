# STM-SEC-006: formula-safe tournament CSV exports (v1.0 DoD follow-up)

This scoped change closes a previously unprotected CSV output path:
`TournamentExportFormatter` produced table CSV, pairing CSV (all rounds and
single-round selection), and next-round preview CSV using a quoting-only helper.
Quoted CSV syntax alone does not prevent spreadsheet applications interpreting
formula-looking user text as formulas.

All three outputs now delegate every cell to the existing, already tested
`CsvFieldEncoder.Encode(value, ';')`. It prefixes formula-like text with an
apostrophe inside a quoted cell, handles leading whitespace/control/format
characters, doubles quotes, and contains embedded separators and newlines.
Ordinary values and invariant numeric literals (including negative decimals)
retain their previous representation. Export ordering, header columns and
line-ending behavior remain unchanged. Domain inputs are not modified.

## Surface inventory in scope

- Standings: user-supplied player names in ranking rows.
- Pairings: both player names and the pairing notes, for all or one round.
- Preview: player names and concatenated quality findings.

This is only CSV *output* hardening. No changes to JSON backups, player CSV,
Swiss-Manager CSV, HTML, or the fixed-width TRF16 format. The existing CSV
encoder itself was not changed. A spreadsheet may strip protective apostrophes
on a later re-save; there is no promise of universal spreadsheet roundtrip.
Normal code consumers may see apostrophes in imported names/notes. Operators
should use the original JSON backup for exact data preservation.

## Regression tests and gates

`TournamentCsvFormulaSafetyTests.cs` adds source-level xUnit cases for:
formula-leading names, whitespace and Unicode prefixes, embedded quote/semicolon
and multiline notes, a preview finding, numeric fields and non-mutation. A
separate small CSV reader in the tests checks the expected 17/9/12 column
layouts and text values without using the production encoder as its oracle.

In the authoring environment .NET and PowerShell are not installed. The xUnit
suite, pinned full solution build, repository safety/commit gates, real
spreadsheet imports, and final exact-SHA GitHub CI must run later in the normal
Codex/Windows integration workflow. A source syntax/structure check alone is
not a claim that xUnit or any full build has passed. Keep the PR draft until
these gates and an independent KI review succeed.

STM-SEC-006 as a *whole* is not marked Done: the remaining project-wide CSV
inventory and real spreadsheet compatibility checks are still outstanding.
The related open #124/#125 PRs are independent and must remain unchanged.
