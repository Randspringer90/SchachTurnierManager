# CSV preview/import identity

The React player importer binds a preview to tournament ID, exact CSV content,
replace option and a monotonically changing request generation. Input changes
invalidate immediately, including A/B/A changes. Cancellation saves work; the
identity/generation check also rejects producers that ignore cancellation.

Starting another preview revokes the previous preview. Responses and errors from
old generations cannot change the current UI. Import rechecks the exact snapshot
and consumes the preview synchronously before sending that same snapshot. A
double click cannot reuse the consumed authorization. A failed import requires
a fresh preview. Tournament switches suppress obsolete completion messages.

Run the deterministic regressions with:

```powershell
node --test src/SchachTurnierManager.WebApp/test/playerImportPreview.test.ts
```

Eight cases cover CSV change, tournament change, replace change, reverse response
order, normal unchanged flow, A/B/A, stale closure/server option mismatch and
cleanup invalidation. These cases are part of the existing frontend `npm test`.

`scripts/Smoke-FirefoxCsvImport.ps1 -SourceAssemblyPath <fresh-WebApi-DLL>`
adds actual headless React/browser checks for all five required scenarios. The
source DLL must be a fresh build under repository `tmp/dotnet-bin`, with the
current Vite output in its `wwwroot`. The first four scenarios deliberately
delay preview responses and ignore AbortSignal. The fifth uses the real preview
and import API and verifies the persisted synthetic player in the selected
tournament. No private database or existing browser profile is used.

Set process-local `STM_SMOKE_RETAIN_DATA=1` to retain temporary diagnostic
directories after owned processes have stopped and their ports are verified.
This keeps evidence without retaining running children or opening visible windows.

The same ownership rule protects player and manual-pairing drafts through
`tournamentEditorGuard.ts`. Seven frontend regressions cover selection, ABA,
stale handlers, new typing and reverse completion order. The independent
headless `scripts/Smoke-FirefoxTournamentEditors.ps1` creates two cloned
synthetic tournaments with identical player IDs and board keys. It verifies
selection reset, late player/pairing replies, exact request ownership, unchanged
stored target data and the normal real-API save path (seven browser assertions).

JSON backup required-object regressions live in
`BackupRequiredObjectsTests.cs`: 40 malformed cases must reject before any
stored/input/audit-sink mutation; one legacy/optional-null case must import and
remain usable for standings and export. These 41 tests are included in the
Application suite, rather than counted again as unique cases.
