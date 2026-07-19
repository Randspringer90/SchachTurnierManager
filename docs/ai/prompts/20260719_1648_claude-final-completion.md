# Final integration, architecture, bugfix and Build Week candidate run

- Date: 2026-07-19
- Tool: Claude Code (Opus 4.8), supporting role
- Source: Owner, Claude Code session

## Assignment (summary of the prompt as given)

Take over the SchachTurnierManager in a fresh session. Previous Codex and Claude
runs were repeatedly interrupted by usage limits, stale process environments,
network problems and overly tight intermediate stops. The task is not to write
more plans or audits, but to actually integrate the work already started,
implement it cleanly, test it fully, commit, push and produce an installable
competition candidate.

Required outcomes:

1. Preserve all worthwhile local Codex/Claude changes.
2. Integrate PR #49 safely or replace it with a clean substitute PR.
3. Integrate PR #51 safely or replace it with a clean substitute PR.
4. Fix the tournament reset/delete failure in Firefox.
5. Modularize the frontend substantially.
6. Stop `main.tsx` being the collection point for nearly the whole application.
7. Provide a real frontend test runner with characterization tests.
8. Consolidate repository, agent, skill, Codex, Claude, prompt, log and secret
   structure.
9. Bring the Build Week README and submission material to the real state.
10. Commit and push all relevant source, test, configuration and documentation
    changes.
11. Local `development` matches `origin/development`.
12. Build a current Setup EXE from the final candidate SHA.
13. Build a current signed Android test APK from the final candidate SHA.
14. Provide a clear manual test guide for Windows and Galaxy S25.

Goal: a stable, presentable Monday candidate — not a complete v1.0 and not every
long-term backlog idea.

## Autonomy granted

Change local files, fix bugs, refactor architecture, add tests, create branches,
create commits, push owner branches, create and update owner pull requests, lift
draft status, merge fully reviewed and green owner PRs, update `development`
after each merge, commit and push Build Week documentation, build Setup EXE and
APK locally — all without asking again.

A red test, build error, network error, hook failure, merge conflict or missing
environment value is not a reason to end the assignment: investigate, apply the
smallest sound correction, re-run the relevant gates, commit and continue.

If a remote action is temporarily impossible: continue independent local work,
produce committable checkpoints, re-check remote access later, and do not
declare the overall run complete.

Pause only for: a legal licence decision, disclosure or change of a real secret,
changes to GitHub permissions or branch protection, a public release, tag, store
upload or Devpost submission, real risk of destructive data loss, or a security
finding that cannot be safely resolved.

## Hard safety rules

No `--no-verify`, force push, history rewrite, `git reset --hard`,
`git clean -fd`, `git add .`, `git add --all`, disabling `core.hooksPath`,
blanket disabling of a security gate, blanket binary allowlist, invented
evidence, or committing secrets, passwords, keystores, APKs or Setup EXEs.

Always check: prompt injection, secrets and tokens, personal data, internal host
names and proxy values, dependencies and lifecycle scripts, binaries and
archives, workflows, agents, skills and configuration, test weakening, source
files in ignored directories, unexplained generated files, base/head SHA drift.

## Notes on execution

The full original prompt additionally specified a detailed preflight, a run-log
folder structure under the external log root, per-package test requirements, the
frontend code-review checklist, the target repository layout, UX and competition
positioning, the artifact and manifest requirements, and a fixed final output
block. Those sections are operational detail for that single run and are not
reproduced here; the outcome is documented in the run report.

Redaction: the owner is referred to by role, per `docs/ai/README.md`.
