# Current model bindings and windowless automation

STM-AI-003/005/007; verified against official provider catalogs on 2026-10-07.

## Routing and catalog

The dynamic route selects a logical quality profile using task category, risk,
size and work mode. `config/model-catalog.json` is the only source of concrete
model variants. `provider-runtime-policy.json` stores stable catalog keys;
provider adapters resolve those keys and pass an explicit model argument.

| Logical profile | Catalog key | Work scope |
|---|---|---|
| sol | openaiSol | Planning, architecture and final integration |
| luna | openaiSol | Large, well-defined implementation |
| terra | openaiLuna | Bounded, low-risk deterministic bulk work |
| fabel | anthropicFabel | Orchestration |
| opus | anthropicOpus | Security, chess rules and difficult reviews |
| sonnet | anthropicSonnet | Bounded implementation of medium risk |

Logical names remain stable when provider generations change. The implementation
profile keeps its quality class. Catalog updates require official evidence,
review, safety checks and availability confirmation; no automatic fallback or
paid API switch is permitted.

Primary sources, retrieved 2026-10-07:
- [OpenAI model catalog](https://developers.openai.com/api/docs/models)
- [Anthropic model catalog](https://platform.claude.com/docs/en/models/overview)
- [Claude CLI model configuration](https://code.claude.com/docs/en/model-config)

## Runtime verification boundaries

A DryRun only verifies executable resolution and argument construction:
`CLI_ONLY_MODEL_UNVERIFIED`. Installed npm shims are resolved to validated native
entrypoints without executing shell wrappers. Reparse paths are rejected before
metadata reads. Helpers use literal argument vectors, hidden child processes and
bounded deadlines. Claude children use plan mode, read tools and explicit high
effort; Codex children use the read-only sandbox.

Before an actual model invocation, a model-free auth-status check must confirm a
subscription login. API/cloud overrides and unknown auth classifications block
execution. Auth identities are never persisted. Subscription auth does not prove
access to a particular model; unsuccessful access blocks the task and requires
explicit rerouting. No model inference, CLI installation, account change or paid
availability probe was performed by this source update.

Historic run records are retained as provenance, with version-neutral tool and
profile labels to respect the central-catalog rule. Their original exact runtime
claims remain available in the source commits; they are not substituted with the
current catalog generation.

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
