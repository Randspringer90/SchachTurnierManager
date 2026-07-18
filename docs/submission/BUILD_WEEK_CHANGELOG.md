# Build Week change log

The SchachTurnierManager existed before OpenAI Build Week. This document separates the earlier
product from work committed during the official Submission Period. Commit timestamps are useful
evidence, but they do not by themselves prove that every line was authored after the cutoff; the
linked AI reports and original contributor PRs remain part of the attribution record.

## Boundary

- Official start: **2026-07-13 09:00 PT**.
- Last `development` commit before the start: `ecfb47365eefa81bcc5e867d1547a5036baf2616`.
- First later `development` commit: `43e62cc53afb3439fffd2c62875e77ab09f2b864`.
- Initial range at the start of this run: `ecfb47365eefa81bcc5e867d1547a5036baf2616..a6f68e8f8e31201f0b9ce2ea77a13c37a50b9518`.
- Initial evidence: 36 commits; 251 files changed; 21,450 insertions and 363 deletions.
- The final range will end at the frozen submission-candidate SHA, not at this initial SHA.

## What already existed

Before the Submission Period the project already included:

- a local .NET/React tournament manager with SQLite persistence;
- Round Robin and the Optimal-V2 Swiss pairing engine, including globally optimized rematch
  avoidance for fields up to 20 active players and an explicit fallback above that size;
- player, round, result, standings, tiebreak, category, cross-table, print, CSV/JSON, backup,
  audit-journal, pairing-quality, and Chess960/QR workflows;
- a self-contained Windows desktop/portable path, Inno Setup configuration, release gates,
  local logging, DPAPI secret handling, and synthetic operator smokes;
- an existing broad dashboard, local assistant/knowledge base, PWA shell, and partial i18n
  foundation.

These earlier capabilities are product context. They are not presented as Build Week work.

## Landed during the Submission Period before this run

### Product and chess workflows

- FIDE-aware handling of unplayed rounds, forfeits, withdrawals, and tiebreak inputs, adopted
  from Marcel's contribution with Codex-assisted secure integration.
- Additional hand-calculated Buchholz, Cut, Median, and Sonneborn-Berger golden tests.
- TRF16 tournament export.
- A selectable, fuller FIDE-Dutch pairing strategy with deterministic audit references; the
  pre-existing Optimal-V2 strategy remains the default.
- Swiss-Manager CSV player import/export and TRF16 player import, including explicit replace
  behavior and defensive UTF-8/Windows-1252 decoding.
- A critical desktop-launch fix binding web content to the application directory so a normal
  shortcut/double-click start serves the actual dashboard.

### Safety and development quality

- Provider-neutral agent/skill/trust manifests and prompt-injection protections.
- Base-SHA-bound static PR review and controlled adoption rather than blind merging.
- Repository-local model routing, knowledge management, checkpoint/resume, and Nightly planning
  infrastructure.
- Hardening against open-stdin hangs and nondeterministic routed-task hashes.

### Candidate work prepared in this run but not yet landed

- PR #49 contains the Android Companion candidate at
  `5aecee91afd7959c0ad368a2b86bf33c55522580`; it remains unmerged and its CI is blocked by the
  pre-existing binary gate. It is not described as a released feature.
- Draft owner PR #50 contains the narrow STM-INFRA-008 artifact-attestation gate at
  `b52a54092c9529ea5cbc744f134ddc5fb15d6d87`. Its isolated tests are green, but protected-path
  owner review/merge is still required.
- The current UX branch adds the five-area navigation, opt-in FIDE-Dutch UI, explicit synthetic
  demo, confirmed/undoable result writes, progressive standings, responsive/theme/accessibility
  polish, public-health path redaction and English submission package. These remain candidate work
  until the exact branch commit passes full gates and is merged.

## Finalization rule

After the submission freeze, this file must be regenerated against the exact candidate SHA.
No pending, local-only, blocked, or PR-only change may be described as landed functionality.
