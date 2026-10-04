# PR #98: logging smoke no-console follow-up

This is an addition to the existing current-models/background-execution PR,
not a second PR or an integration of the other open branches.
Inspected parent: 7138e8efbe044e419cfab68b09f4ef57297801b1.
The remote development ref remained cc47f1101983d3f3272a893dbf54bd66fa2355b4.
No claim is made about unpushed local work or active workstation processes.

## Additional change

Invoke-LoggingReadiness.ps1 previously used Start-Process -WindowStyle Hidden.
It now uses the same native BackgroundProcess helper as Start-Dev and
ClickInstallReadiness: UseShellExecute=false, CreateNoWindow=true, separate
stdout/stderr log files and explicit cleanup of its own child. The source
change supersedes the older operation document's statement that the logging
readiness caller was left unchanged. Other already-hidden callers were not
arbitrarily rewritten, and external CORE-KI/user interfaces are out of scope.

Test data/log directory settings now apply to the child rather than temporarily
modifying and subsequently removing the caller's environment. All four HTTP
waits detect an exited owned child and keep their bounded timeouts. Existing
logging, directory, request and query-redaction assertions are unchanged.
Automated PowerShell subcalls are noninteractive. Existing packaging decisions
are unchanged; this change does not authorize executing a packaging smoke.

## Evidence

Both edited PowerShell source copies were byte-verified against their Git blob
SHAs before editing (7cc5572b8ef5acca709468ff60417838d60cb7bd and
74bbdb0468ae347cb6c3c00cb38f4c98646a960b). The existing process suite's AST
coverage now includes the logging caller and stays reachable via the existing
BackgroundAutomationTests xUnit bridge.

Ten additional Node SOURCE CONTRACT tests passed with zero failures/skips.
Against the unchanged source, the same checks had 3 PASS / 7 FAIL. This is a
source-level regression comparison, NOT an observation of Windows windows.
Node syntax, UTF-8 and git diff --check passed. The 23 checks reported for the
first PR commit were not rerun in this follow-up and are not added to this count.

PowerShell parsing/execution, the real GetConsoleWindow child probe, xUnit/.NET,
full logging/installation readiness and independent Codex review are NOT_RUN:
PowerShell and .NET are unavailable in the current Linux execution environment.
Keep the PR draft until the required runtime, safety and CI gates are satisfied.
No required review, test or permission gate was removed.

The existing explicit model IDs were rechecked against official catalog pages
on 2026-10-04 and left unchanged. They are a dated reviewed model snapshot, not
a runtime discovery of every future release. Account/CLI model acceptance was
not probed; no inference, login or global provider configuration was changed.

References:
- https://developers.openai.com/api/docs/models/gpt-6.1-sol
- https://developers.openai.com/api/docs/models/gpt-6-luna
- https://code.claude.com/docs/en/model-config
- https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.processstartinfo.createnowindow

Before merge: run Test-BackgroundProcess.ps1 and the complete project gates on
the actual Windows integration candidate, reconcile BACKLOG/CHANGELOG without
losing other pending work, and inspect any remaining visible process by its
real parent/checkout. No workstation, background agent or other PR was modified.
