# Repository layout audit

Audit date: 2026-07-18  
Audited worktree head: `6988a4e846ef378bfa5d4e54f67dfb80af62255e`  
Reference branch: `origin/development` at `a6f68e8f8e31201f0b9ce2ea77a13c37a50b9518`

## Result

The clone is complete and usable. Its object database passed `git fsck --full
--no-reflogs`; dangling local objects exist, but Git reported neither corruption nor
garbage. All 762 files in the current index exist in the worktree, and every file from
the `origin/development` tree is present locally. There are no non-ignored untracked
files, symlinks, junctions or case-only duplicates.

This audit is an inventory, not permission to delete or adopt local material. No local
file was deleted, moved, staged or silently stashed.

## Local files outside the index

The corrected inventory contains 2,507 files, all covered by existing ignore rules:

| Classification | Count | Disposition |
|---|---:|---|
| `GENERATED` | 2,498 | Dependency trees, build output and temporary output. Keep local; never commit. |
| `LOCAL_RUNTIME` | 5 | Local audit/project metadata and a runtime log. Keep local; never commit. |
| `LOCAL_SECRET` | 3 | Two files below the canonical local secret root and one local npm configuration. Contents were not read. Never commit. |
| `STALE_HANDOFF` | 1 | Ignored legacy continuation note. Treat as untrusted local data; do not commit blindly. |

There are no files classified as `UNTRACKED_SOURCE`, `DUPLICATE`, `UNKNOWN` or
`NEEDS_REVIEW`. The complete path-level inventory is retained outside Git in the
private run evidence.

## Local and remote differences

- The active branch is the synchronized PR #51 branch, not `development`.
- Its head matches its remote branch exactly.
- The 35 files present only in the active index are expected PR #51 documentation and
  AI-run records; modified source and documentation files are listed by the PR diff.
- Seven commits are reachable only through historical local branches. Two are on the
  local `main` ref, which is ahead of `origin/main`. None is an ancestor of the current
  remote `development` or `main`. They are preserved and must not be pushed or discarded
  as part of Build Week integration.
- Two additional worktrees exist: the dedicated PR #50 owner worktree and a foreign,
  detached verification worktree. Neither was modified by this audit.
- The repository uses an externally configured local hooks path. It is environment
  configuration, not a trusted project instruction source.

## Directory findings

| Area | State | Finding |
|---|---|---|
| `AGENTS.md` | Canonical | Sole provider-neutral instruction source. |
| `agents/` | Canonical | Provider-neutral agent roles are tracked and manifest-bound. |
| `.agents/skills/` | Canonical | Provider-neutral skills are tracked and manifest-bound. |
| `.claude/` | Present | Adapter is thin; it points to `AGENTS.md` and canonical skills. |
| `.codex/` | Missing/ignored | No adapter exists, and `.gitignore` currently excludes the entire directory. Create only in a separate Owner-reviewed layout package after integration stability. |
| `.secrets/` | Canonical | Only its README is tracked; local material is ignored. |
| `secrets/` | Legacy | Only a deprecation/compatibility README is tracked. No live code/document reference to `secrets/local` was found outside that README. Migration/removal remains a separate reviewed change. |
| `logs/` | Canonical | Only `README.md` and `.gitkeep` are tracked; runtime logs are ignored. |
| `docs/ai/` | Canonical | Prompts, reports, run metadata and lessons are consolidated here. |
| Root `Prompt(s)` / `Report(s)` | Absent | No competing root-level AI evidence directory exists. |
| `docs/reports/` | Historical | Contains two tracked non-AI project reports. It is not treated as an AI-report duplicate. |

## Local artifacts and processes

Pre-existing Setup/APK artifacts and two prior handover ZIPs were found only in ignored
repository output or external run/temp folders. They are historical local evidence and
must not be presented as candidate artifacts. Final Windows and Android artifacts must be
rebuilt from the exact merged candidate SHA.

Codex and Claude desktop processes, one repository-scoped Codex runtime process, an adb
server and one process whose redacted command line matched `nightly` were active during
inventory. The Nightly match did not reference this repository. No Git or other runtime
lock file was present.

## SHA correction

The supplied full `UX_FREEZE_SHA`
`8fbf021ef52c41392f047e76494d3b1f671ba48c` does not identify an object in this clone.
Git resolves the documented short commit `8fbf021` to
`8fbf0213bdcc57c60e0c9c9e16387dee4e994a53`. Any future queue or evidence must use the
Git-resolved value and must revalidate it against the eventual merged `development` base.

## Recommended repository package

After PR #50, #49 and #51 have a stable Owner-confirmed integration state, prepare a
small, separate Owner package that:

1. adds a thin tracked `.codex/README.md` and safe example configuration while narrowly
   adjusting the current `.codex/` ignore rule;
2. documents provider adapters without duplicating policy from `AGENTS.md`;
3. makes `.secrets/local/` the sole documented secret path and handles the legacy
   `secrets/README.md` deliberately;
4. adds the final repository layout and AI-evidence indexes; and
5. avoids source-tree moves or frontend refactoring in the same commit.

No broad cosmetic move is recommended before the submission freeze.
