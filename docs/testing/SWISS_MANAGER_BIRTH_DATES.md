# STM-IE-010: validate Swiss-Manager birth input

## Scope and cause

The former parser extracted only the first slash-separated or final dot-separated
year. Invalid values such as 31.02.2000 or 1990/garbage could become valid-looking
birth years. Validate the complete input before reducing it to a year.

## Contract

Accept a four-digit ASCII year or an exact calendar date in yyyy/MM/dd or
dd.MM.yyyy using invariant DateOnly.TryParseExact. Keep the existing inclusive
1900-2100 range; do not silently introduce a new age or current-year policy.
Field-level whitespace trimming is unchanged.

Missing optional birth input is not an error. For nonempty invalid input, preserve
the player and other fields, set BirthYear to null and add a line-specific error.
The error explains allowed formats but does not echo the personal birth value.
Only the year remains in the domain object; no full birth date is persisted.

No new export format, dependency, version, runtime configuration or pairing rule
is introduced. Existing accepted canonical dates and plain years remain valid.
Previously tolerated malformed dates now produce a diagnostic intentionally.

## Integration

Original package branch started from development cc47f1101983d3f3272a893dbf54bd66fa2355b4.
The changes touch only the BirthYear call and ParseBirthYear implementation. Source
three-way merging with PR #67 and STM-IE-009 is conflict-free. With STM-IE-009,
physical record start lines also apply to these new birth diagnostics.

The existing owner branch was synchronized normally with development
abecd00c93d8c651f362d8ef3f0098200fe385ba on 2026-10-06. Static review of current
head 866d1f37c17284e44bd46202183390b9e8ba067f resolved all three contextual
findings before execution. The CSV output encoder from PR #67 is preserved.
BACKLOG/CHANGELOG now describe this scope as In Review. No Done status before
all required gates and the actual merge.

## Verification

43 new xUnit cases: canonical years/dates, leap-year and century boundaries,
malformed dates and ranges, optional blanks, preservation of other fields and rows,
and independence from the current culture. Run SwissManagerBirthDateTests and the
existing SwissManagerCsvCodecTests, then the full solution.

The historical implementation environment had no .NET SDK or PowerShell and did
not execute the cases. Current integration verification on 2026-10-06 passed
55/55 focused tests: 43 new birth-date cases plus 12 existing Swiss-Manager cases,
zero failures/skips. Full project gates, final independent review and current CI
remain merge requirements; this targeted result is not a merge approval.
DateOnly API reference: https://learn.microsoft.com/en-us/dotnet/api/system.dateonly.tryparseexact?view=net-10.0 .
