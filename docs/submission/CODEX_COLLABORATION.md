# How Codex and GPT-5.6 were used

The SchachTurnierManager was not created from scratch during Build Week. The competition work
extends an existing local tournament manager. This document records both AI acceleration and the
human decisions that constrained it.

## Codex and GPT-5.6

Codex/GPT-5.6 work during the Submission Period includes:

- designing and hardening a SHA-bound static review pipeline for untrusted pull requests;
- comparing contributor work against the current `development` architecture and adapting safe
  parts without blind merges;
- implementing or integrating FIDE-aware unplayed-round behavior with regression coverage;
- creating repository-local routing, knowledge, and resumable-run controls;
- running this primary finalization thread: requirement verification, competition evidence,
  PR #49/STM-INFRA-008 work, product/UX decisions, a synthetic demo path, final build
  verification, and submission documentation.

The exact prompt, evolving report, machine-readable metadata, commit history, test outputs, and
final artifact hashes provide dated evidence. The `/feedback` Session ID for this primary thread
will be placed only in the Devpost form; the repository will contain at most its SHA-256.

## Human and contributor roles

- **Owner:** sets scope, owns product and release decisions, authorizes repository and
  signing operations, reviews protected paths, performs the physical Windows/Galaxy S25 test, and
  alone decides merges, releases, uploads, licensing, and submission.
- **Marcel / trusted collaborator:** originated substantial chess and compatibility contributions,
  including tiebreak tests, FIDE-Dutch work, TRF16/Swiss-Manager work, and the desktop-launch finding.
  His work remains attributed even when adapted on Owner branches.
- **Claude runs before this finalization thread:** performed documented orchestration/review work,
  including prior integrations and the first Android candidate. This is disclosed rather than
  attributed to Codex. Claude/Anthropic is not used in this finalization run.
- **Codex/GPT-5.6:** performs the current core competition, UX, infrastructure, and finalization
  work in this primary thread. Secondary Codex agents, if used, are limited to independent
  read-only audits or reviews.

## Where AI suggestions were corrected or constrained

- The existing Optimal-V2 pairing strategy stayed the default; FIDE-Dutch is opt-in so old
  tournaments are not silently reinterpreted.
- A superficial wait-only fix for a flaky routed-execution checkpoint was rejected after repeated
  failures; the actual nondeterministic graph serialization was fixed instead.
- A contributor follow-up ID collision was corrected rather than copied into the canonical backlog.
- The Windows-1252 package was accepted only after a first-party/license/necessity review.
- Android binary failures were not bypassed. PR #49 remained blocked until a narrow provenance,
  path, type, hash, size/dimension, generator-version, Owner-review, and head-SHA model could be
  designed.
- Old Setup/APK outputs are rejected as final evidence; they must be rebuilt from the frozen SHA.
- No unsupported certification, release, signing, offline, store, or distribution claim is allowed.

## What remains a human decision

Licensing, PR approval/merge, Windows signing strategy, physical Galaxy S25 results, video
publication, repository access mode, Devpost submission, and the final `/feedback` entry remain
Owner actions.
