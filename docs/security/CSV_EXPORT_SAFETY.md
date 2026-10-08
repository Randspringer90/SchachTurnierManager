# STM-SEC-006: participant CSV safety, first delivery

## Implemented scope

PlayerCsvCodec (semicolon) and SwissManagerCsvCodec (comma) use one CsvFieldEncoder.
Formula-like values receive a leading apostrophe INSIDE a quoted field. Existing
quotes are doubled; delimiters and line breaks remain inside the cell. Leading
whitespace/Unicode format characters do not hide an ASCII or full-width formula
prefix. Leading control characters are also protected. Plain invariant numeric
literals, including negative decimals, are preserved. Input objects are never
modified and ordinary export ordering/header/line-ending rules stay unchanged.

## Compatibility and limitations

This is output encoding, not a lossless backup format. The added apostrophe can
remain visible when a CSV is imported programmatically, including Swiss-Manager.
No importer silently removes it. Existing JSON backup is the lossless channel.
Both CSV import areas of the WebApp (participant CSV, Swiss-Manager CSV) state this
next to the import controls, so an operator re-importing an exported CSV is warned
before the apostrophe becomes part of names or IDs.

OWASP warns that spreadsheet re-save/re-open can remove protection and that no
CSV strategy is universal. This delivery does NOT claim an Excel roundtrip or
real Swiss-Manager acceptance test. Do not enable formulas or remove text markers
from untrusted exported cells. Source checked 2026-10-01:
https://owasp.org/www-community/attacks/CSV_Injection

## Remaining parent scope

STM-SEC-006 is NOT complete: TournamentExportFormatter table/pairing/preview CSV,
frontend audit CSV and operator-generated CSV must be inventoried and hardened in
follow-up scopes. TRF16 is fixed-width text, not CSV: never add CSV quoting or text
prefixes to its fixed positions. No pairing or tie-break formula is changed here.

## Original submission evidence (historical)

39 xUnit cases added, including 19 dangerous-input cases that each cover both
separators. Test source and original codec blob identities checked statically.
C# compilation, xUnit, full project gates and real spreadsheet/Swiss-Manager
checks are NOT_RUN in the chat environment (no .NET runtime). This remains a draft
until the independent local review/test/integration run supplies that evidence.
## Evidence

39 xUnit cases added, including 19 dangerous-input cases that each cover both
separators. `CsvExportRoundTripTests` (integration run 2026-10-01) reads both exports
with an independent RFC 4180 parser and checks column count and every cell value
(including CR/LF, quotes, separators and negative numbers), determinism, non-mutation
and the export -> import round trip together with the multiline/BOM reader of
STM-IE-009. Real spreadsheet and real Swiss-Manager acceptance checks remain NOT_RUN.
