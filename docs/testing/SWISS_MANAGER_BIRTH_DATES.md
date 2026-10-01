# STM-IE-010: validate Swiss-Manager birth input

## Scope and cause

The former parser extracted only the first slash-separated or final dot-separated
year. Invalid values such as 31.02.2000 or 1990/garbage could become valid-looking
birth years. Validate the complete input before reducing it to a year.

## Contract

Accept a four-digit ASCII year or an exact calendar date in yyyy/M/d or
d.M.yyyy (month and day with one or two digits, e.g. 1990/6/15 and 15.6.1990,
which were accepted before this change) using invariant DateOnly.TryParseExact.
Keep the existing inclusive
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

Independent branch from development cc47f1101983d3f3272a893dbf54bd66fa2355b4.
The changes touch only the BirthYear call and ParseBirthYear implementation. Source
three-way merging with PR #67 and STM-IE-009 is conflict-free. With STM-IE-009,
physical record start lines also apply to these new birth diagnostics.

Proposed canonical BACKLOG entry (still pending): STM-IE-010 | Swiss-Manager birth
validation | P2 | In Review | import-export | owner | scoped issue | development.
Proposed CHANGELOG entry: reject invalid complete birth dates before year reduction;
report the record location without echoing personal input. Integrate these entries
without discarding newer planning changes. No Done status before all required gates.

## Verification

43 new xUnit cases: canonical years/dates, leap-year and century boundaries,
malformed dates and ranges, optional blanks, preservation of other fields and rows,
and independence from the current culture. Run SwissManagerBirthDateTests and the
existing SwissManagerCsvCodecTests, then the full solution.

The environment has no .NET SDK or PowerShell. The 43 cases are added, NOT executed;
C# compilation, xUnit, full project gates, independent review and CI are pending.
DateOnly API reference: https://learn.microsoft.com/en-us/dotnet/api/system.dateonly.tryparseexact?view=net-10.0 .
