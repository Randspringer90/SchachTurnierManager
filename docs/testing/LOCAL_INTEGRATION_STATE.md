# STM-INFRA-010: local integration state

Issue #74. This read-only CLI complements the remote PR report from STM-INFRA-009;
it does not merge, fetch, inspect source contents or repair Git configuration.

## Use

From the verified repository root:

```text
node scripts/Get-LocalIntegrationState.mjs
node --test tests/scripts/local-integration-state.test.mjs
```

An explicit repository-root argument is supported. The root and effective origin
must identify Randspringer90/SchachTurnierManager. The tool rejects an unexpected
repository rather than returning a misleading clean result. Git and Node are
required; no new npm package is used. Tests create synthetic temporary repositories
and never contact their configured remote.

## Report semantics

The JSON on stdout includes counts, HEAD, the locally stored development ref,
ahead/behind, operation markers, worktree count and a status-metadata fingerprint.
Progress goes to stderr. No filenames, file contents, full paths, raw remote URLs,
authentication values or raw Git errors are included.

Exit 0 means observation completed, not clean source, current remote state or
merge approval. Exit 2 means usage/observation incomplete. mergeAuthorized is
always false. LOCAL_CHANGES_PRESENT and INTEGRATION_IN_PROGRESS require review.
NO_VISIBLE_CHANGES does not inspect ignored files or prove absence of active writers.
The fingerprint hashes status metadata, NOT source content. Branch/HEAD/status/ref
and URL checks cannot detect every concurrent content edit. Worktree count does
not inspect other worktrees. Tracking refs may be stale: there is no fetch.

Effective fetch and push URLs include Git URL rewrites. A noncanonical push target
is reported, never removed. Per-process fsmonitor/untracked-cache disabling and
GIT_OPTIONAL_LOCKS=0 prevent optional metadata-query index writes. Repository and
global configuration are not changed; inherited GIT_* routing overrides are not
used. Normal filesystem/Git permissions still apply. This is not a secret scanner.

## Evidence and integration

46/46 Node tests passed on the Linux execution environment with Node 22.16.0.
Tests include actual temporary repos, index byte/mtime invariance, renamed paths,
linked worktrees, staged plus unstaged changes, real merge conflicts, index locks,
Git URL rewrites, unchanged push blocks and sanitized error output.

Windows execution, complete project gates, independent review and final CI remain
unverified. The command is not automatically wired into the existing CI. Run the
explicit test command during integration. No product version/dependency changes.

Canonical BACKLOG.md and CHANGELOG.md synchronization is still required before
merge. Proposed backlog: STM-INFRA-010, local read-only integration-state report,
P2, In Review, infrastructure, owner, issue #74. Proposed Unreleased entry:
"STM-INFRA-010: added bounded read-only local Git integration-state inspection;
effective origin/push targets and local deltas are reported, never changed."
These notes are integration input, not a second canonical backlog or Done claim.
