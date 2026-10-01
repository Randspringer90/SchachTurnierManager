# STM-IE-009: CSV record import

## Scope and cause

Both participant and Swiss-Manager exporters support quoted line breaks. The old
importers split the whole document at CR/LF before decoding cells. This could turn
one quoted field into extra player rows. CsvRecordReader now scans records first,
with a shared comma/semicolon state machine, before either codec creates players.

## Contract

- Preserve CR, LF and CRLF inside quoted fields; outside quotes they end records.
- Decode doubled quotes and preserve empty/trailing fields.
- Remove one initial UTF-8 BOM character; never strip later BOM characters.
- Skip blank physical lines, retain quoted/explicit empty fields.
- Tolerate spaces/tabs outside quoted fields as a compatibility extension.
- Reject malformed quoting for the entire document; do not return partial rows.
- Errors include physical line and record start, not the offending field contents.
- Participant import throws ArgumentException (already handled by the API).
- Swiss-Manager returns one structural error and zero players on malformed CSV;
  ordinary per-field diagnostics use the physical start line of the record.

CSV quoting reference: https://www.rfc-editor.org/rfc/rfc4180.html . This is a
project dialect supporting comma and semicolon, not a claim of universal CSV
compatibility. Existing semantic trimming and optional-field defaults remain.
No delimiter autodetection, mapping UI, database or pairing changes are included.

## Integration

This package starts from development cc47f1101983d3f3272a893dbf54bd66fa2355b4.
It does not require another open PR to compile. Preserve the output-only
CsvFieldEncoder delegates from PR #67 when combining the changes. A source-level
three-way merge with those delegates and the separate STM-IE-010 date fix is
conflict-free; that is not a build or functional integration result.

Proposed canonical BACKLOG entry (still pending in this delivery):
STM-IE-009 | CSV record import: multiline fields and BOM | P2 | In Review |
import-export | owner | issue #76 | development.
Proposed CHANGELOG entry: fix participant/Swiss-Manager multiline CSV parsing,
initial BOM handling and physical-line diagnostics; reject malformed documents.
The final integrator must apply these entries without replacing newer planning
content. Do not mark Done before complete tests/review and merge.

## Verification

35 xUnit cases added: reader grammar, newline variants, malformed quotes,
participant roundtrip, Swiss-Manager diagnostics and deterministic cell parsing.
Run the new class and existing PlayerCsvCodecTests/SwissManagerCsvCodecTests, then
the full solution. New tests are SDK-included in the existing Domain.Tests project.
The existing CI dotnet test job will discover them after its static prerequisite.

Static checks: original files bound to Git blob hashes; scoped diff and whitespace
checked. This environment has no .NET SDK or PowerShell: C# compilation, xUnit,
application persistence/API smoke, full ReleaseGate/Commit-If-Green, independent
Codex/CODEOWNERS review and final CI are NOT_RUN or pending. A clean text merge
is not merge authorization. No dependencies, versions or product artifacts change.
