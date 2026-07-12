# Skills - kanonischer Standard

> Kanonische Wahrheit fuer wiederverwendbares Agentenwissen. Neues Format:
> \.agents/skills/<name>/SKILL.md\ mit vollem Schema. Manifest: \config/skill-manifest.json\.

## Schema (jeder kanonische Skill)
\
ame, version, purpose, trigger, do-not-use-when, prerequisites, trusted-inputs, untrusted-inputs,
required-tools, forbidden-tools, procedure, security-controls, verification, outputs,
typical-failures, lessons-learned, owning-agent\

## Status
- **canonical** (neues SKILL.md, volles Schema): prompt-injection-defense, instruction-integrity, untrusted-content-review, knowledge-management, secret-management, model-routing.
- **legacy-flat** (bestehende \.agents/skills/*.md\, Migration zu SKILL.md offen unter STM-AI-001b):
  repository-security, ai-run-logging, release-operations, runtime-logging, pairing-engine, tiebreaks, imports-exports, ui-dashboard, plus click-installation, colleague-*, external-player-lookup,
  installer-packaging, logging-observability, rating-performance, ui-dashboard, internet-research.
- **planned** (noch zu autorieren, STM-AI-001b): public-snapshot, fide-dutch, contributor-workflow, documentation-maintenance, dependency-security.

Legacy-Skills bleiben gueltig und werden nicht dupliziert; die Migration ueberfuehrt sie 1:1 ins
SKILL.md-Format ohne fachliche Aenderung.
