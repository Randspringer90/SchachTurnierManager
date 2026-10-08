# STM-INFRA-001: one entry point for repository Node test suites

Run npm run test:node:all from the WebApp or node scripts/Run-NodeTestSuites.mjs
from the repository. The root is tied to the script, not the shell directory.
Add --list to print a deterministic JSON inventory without executing a test.

Discovery covers regular TOP-LEVEL files in tests/scripts whose names end in
.test.mjs, .test.cjs, .test.js, .test.ts, .test.mts or .test.cts. Fixtures below
subdirectories, arbitrary .mjs utilities, C# tests and browser suites using a
separate runner are not implicitly executed. New suites following the naming
contract need no additional package.json command. Existing focused commands
remain useful and must not be deleted merely because discovery exists.

A missing/empty test directory, links/junctions in the test-directory path,
linked/non-file suites, case collisions, too many suites or an oversized
command fail rather than silently drop tests. Bounds are 256 suite files and
a conservative 24,000-character command estimate. The root itself can be
accessed through an ordinary symbolic alias; nested test links are rejected.
This is not protection against an adversarially changing filesystem.

Execution uses the current Node executable and separate argv elements, no
shell, no detached process, windowsHide=true, closed stdin and inherited
stdout/stderr. Suites run serially with Node's five-minute test timeout.
No forced successful exit, filtering or automatic snapshot update is added.
Exit codes, start failures and interruption are not converted into success.
A spawn error followed by close cannot print a second successful status.
Only Node's inherited internal NODE_TEST_CONTEXT worker marker is removed;
other environment and policy settings are preserved.

The runner EXECUTES repository code. It is not a security sandbox and must
remain after static PR authorization. It does not install dependencies, contact
GitHub, grant approval, build packages, run .NET or replace the project DoD.
A no-console direct-child configuration does not prove that every test's own
subprocess is windowless. Test bodies keep their own permission boundaries.

## Integration

The default WebApp build calls this runner before the unchanged tsc/Vite steps.
Preserve all existing prebuild hooks, audits, focused test scripts and metadata.
On the consolidated branch use --list to account for every expected top-level
suite. Only remove DUPLICATE invocations of the same suites after verifying
coverage. Keep non-test checks such as catalog audits, browser workflows and
PowerShell gates separate. Do not overwrite an integrated package.json with
this branch's older base file. No dependency/lockfile/version update is needed.

## Evidence

46/46 tests passed on Linux/Node 22.16.0. Tests exercise the actual CLI with
passing/failing/syntactically invalid/typed suites, unrelated cwd, literal
filenames, list-only mode, empty discovery, links, bounds, signals and failed
starts. An initial synthetic empty-directory cleanup error and a real runner
error/close double-reporting defect were found and fixed before publication.
The two Linux filesystem cases (file symlink and case collision) are explicitly
not applicable on Windows; the junction test still runs there. No Windows
result is claimed. npm run test:node:all and --list both executed successfully.
Combined with the locale package, real discovery selected both suite files
and ran 70 tests successfully (not 70 additional tests).

Full pinned application/Windows/.NET/PowerShell/CI and independent review remain
open. BACKLOG/CHANGELOG synchronization for STM-INFRA-001 remains an integration
gate. Base: development f6f9e342277385ee3807008d2dafabdbb84cba47.

Primary contracts checked 2026-10-05:
https://nodejs.org/download/release/v22.16.0/docs/api/cli.html
https://nodejs.org/download/release/v22.16.0/docs/api/child_process.html
https://nodejs.org/download/release/v22.16.0/docs/api/typescript.html
