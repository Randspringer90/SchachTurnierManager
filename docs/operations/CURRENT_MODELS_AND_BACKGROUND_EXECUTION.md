# Current model bindings and windowless automation

Follow-up to STM-AI-003/STM-AI-005, requested 2026-10-04.

## What is actually routed

`Resolve-ModelRoute.ps1` still chooses the same logical quality profiles.
`Invoke-RoutedTaskGraph.ps1` delegates to `Invoke-OpenAIProfile.ps1` or
`Invoke-AnthropicProfile.ps1`; both read the concrete model from
`config/provider-runtime-policy.json` and pass it with `--model`.
No account/profile change, CLI installation or paid availability probe occurs.

| Logical profile | Concrete model as reviewed on 2026-10-04 |
|---|---|
| sol (planning/final integration) | gpt-6.1-sol |
| luna (large, well-defined implementation) | gpt-6.1-sol |
| terra (bounded low-risk bulk tasks) | gpt-6-luna |
| fabel | claude-fable-5-1 |
| opus | claude-opus-5-5 |
| sonnet | claude-sonnet-5-5 |

A logical profile name is not a provider's model family. In particular, the
existing large-implementation `luna` role is not silently downgraded to the
current efficient/high-volume Luna model. The low-risk `terra` role uses that
model instead; no unverified GPT-6-Terra ID is invented.

Explicit IDs avoid provider/CLI aliases that can still select older versions.
This is a dated, reviewed catalog snapshot, NOT a promise to discover every
future model automatically. Refresh it from official provider metadata in a
reviewed change. Never select models by guessing the largest version string,
from repository/PR instructions, or as a workaround for a security refusal.

Existing runtime availability checks and no-silent-reroute policy remain.
An executable found by a DryRun is not proof that the selected model is enabled
for the account or that a gateway serves it. Runtime model acceptance has NOT
been tested in this change. Claude Code needs at least 2.1.284 for Sonnet 5.5,
2.1.280 for Opus 5.5 and 2.1.257 for Fable 5.1. Do not auto-upgrade a running CLI
or change provider credentials; report the exact prerequisite if unavailable.

Primary sources consulted 2026-10-04:
- https://developers.openai.com/api/docs/models/gpt-6.1-sol
- https://developers.openai.com/api/docs/models/gpt-6-luna
- https://code.claude.com/docs/en/model-config

## Window causes and changed execution paths

The old Start-Dev explicitly launched two PowerShell windows with `-NoExit`
and opened the default browser. ClickInstallReadiness started its test backend
with `WindowStyle Minimized`, which is not invisible. Those paths are changed.

`BackgroundProcess.ps1` launches native CLI executables with UseShellExecute=false,
CreateNoWindow=true, Hidden style and an ArgumentList (not a command string).
Both output streams drain concurrently to new, separate local log files. Stdin
is closed. Environment overrides apply only to the child. Exit codes survive;
cleanup uses the owned process handle, not a process name or unrelated PID.
PowerShell/.cmd scripts are not accepted as native Windows launch targets.

Start-Dev now supervises its own background services in the invoking session:
- PowerShell 7, a restored .NET project and installed Vite are prerequisites.
- Backend build and TargetPath evaluation have bounded waits and local logs.
- The built DLL runs directly under dotnet; no extra dotnet-run/profile launcher.
- Vite starts directly under Node, not through a new PowerShell/npm shell.
- No automatic browser, console window, dependency install or firewall change.
- Existing listeners are not assumed to be this application or terminated.
- `-RunSeconds N` ends an automated session after N seconds of ready service;
  the default 0 supervises until the caller stops it. It no longer detaches.
- Ctrl+C/normal teardown stops owned children. An OS-level force kill of the
  supervisor cannot be claimed to execute its finally block.

Backend/frontend URLs remain 127.0.0.1:5088/5173; Vite retains the existing
0.0.0.0 binding for LAN development. It does not make OS consent dialogs vanish.
The caller already owns its terminal/agent surface; this change opens no new one.
Logs default to `logs/dev/<unique-run>`. They are local and must not be committed.
Do not invoke an interactive BAT/desktop/browser launcher from automated tests.

The ClickInstall smoke uses the same native helper and existing run log folder,
keeps the isolated data directory and all health/dashboard/tournament/SQLite
assertions, and no longer changes/removes its parent's environment variables.
Its existing package-building/install/uninstall behavior is NOT authorized or
executed merely by this source change.

Existing LoggedCommand, RoutedExecutionCommon and PortableFreshFolderTest
already use CreateNoWindow=true with UseShellExecute=false. The inspected
LoggingReadiness/OperatorWorkflow/FreshRun paths request Hidden/NoNewWindow.
They were not arbitrarily rewritten. A source search is not a live process trace:
future tests, unmerged local code, external CORE-KI components or a GUI program's
own windows need their own headless contract. No global window-hiding hack,
permission bypass, process-name kill or hidden elevation is added here.

## Verification

`dotnet test` discovers BackgroundAutomationTests. It verifies model bindings
and executes `scripts/Test-BackgroundProcess.ps1` through a no-window process.
PowerShell 7 is an explicit prerequisite; missing tools do not mean PASS.
The suite checks exact arguments, closed stdin, child-only environment, separate
large stdout/stderr, nonzero exit codes, bounded cleanup, idempotence, refusal of
an unknown executable/arbitrary PID, and the two callers' PowerShell ASTs.
On Windows it actually probes GetConsoleWindow in the synthetic child.

`node --test tests/scripts/current-models-background.test.mjs` is an additional
source-contract suite, not a PowerShell/GUI behavior substitute.

Publication evidence: 23/23 Node source contracts PASS, 0 fail/skip; updated
policy validates against the byte-verified existing JSON schema. Original three
modified source files were checked against their Git blob hashes. Static review
and whitespace checks performed. PowerShell parser execution, real process
suite, .NET compilation/tests, Windows window observation, full repository/
release gates and independent Codex/CODEOWNERS review are NOT_RUN here.
No inference, new credentials, product build/release artifact or deployment.

Before merge run the real suite and full project gates on the current integrated
Windows candidate, including an observation of any still-opening windows. Keep
required owner/security approvals. This is not a finished workstation fix until
the source is integrated and actually used by the local automation.

Canonical BACKLOG/CHANGELOG follow-up must be reconciled with the ongoing
integration: this supplements STM-AI-003/005 rather than resetting their historic
Done state or claiming new feature completion. No unrelated PR is integrated.

Process API / build-property references:
- https://learn.microsoft.com/dotnet/api/system.diagnostics.processstartinfo
- https://learn.microsoft.com/visualstudio/msbuild/evaluate-items-and-properties
