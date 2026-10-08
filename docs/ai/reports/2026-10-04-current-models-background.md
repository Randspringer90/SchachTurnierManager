# Current models and background execution: evidence

Request: one PR updating the concrete dynamic-routing models and suppressing
extra console/browser windows in automated project starts/tests.
Base: cc47f1101983d3f3272a893dbf54bd66fa2355b4 (development).
The inspected integration/final-candidate ref is from July 19, not a new build.
No local user checkout or global CORE-KI/runtime/profile settings were changed.

Changed real paths: provider-runtime-policy model IDs, Start-Dev supervision,
ClickInstall test backend start. New shared no-window native-process helper.
RoutedExecutionCommon's existing no-console flags are retained, not weakened.

Executed: 23 Node SOURCE CONTRACT tests PASS, 0 fail/skip; policy schema validation,
original blob checks, UTF-8 and diff whitespace validation. These are not .NET,
PowerShell or Windows runtime tests. PowerShell/.NET are absent here.
Added real process/console regression suite and an xUnit bridge for normal test
execution. Those tests, the full application/release gates and independent review
are NOT_RUN in this environment. No paid model-availability calls or CLI updates.

Latest-model evidence is a dated official-catalog review, not live account access
or automatic permanent freshness. See CURRENT_MODELS_AND_BACKGROUND_EXECUTION.md.
No unrelated versions, dependencies, lockfiles, CI protection, releases or merges.
Canonical planning/changelog reconciliation and final Windows/CI verification
remain merge requirements. Existing user work and pending PRs remain untouched.
