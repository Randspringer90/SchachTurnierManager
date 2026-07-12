# Abschlussbericht – Agenten-, Skill- & Security-Grundlage (STM-AI-001) 2026-07-12

- **Modell:** Claude Opus 4.8 (claude-opus-4-8).
- **Ausgangscommit (development):** `ecfb473` (PR #6/STM-INT-001 gemergt; verifiziert).
- **Branch:** `feature/STM-AI-001-agent-skill-foundation`.
- **Offene PRs bei Start:** keine. **Collaborator-Kollision:** keine (keine PRs/Remote-Feature-Branches/Assignees; STM-TB-001/FACH-001/IE-001/DOC-001 nicht berührt).

## Vorherige Probleme
Kein `agents/`-Ordner, keine Manifeste, kein Trust-/Toolrechte-Modell, keine Instruction-Allowlist,
keine automatische Prompt-Injection-/Integritätsprüfung; Skills uneinheitlich (flach vs. SKILL.md).
Analyse: `docs/architecture/AGENT_SKILL_CURRENT_STATE.md`.

## Neue Zielstruktur (real, getestet)
- **Agenten (14 + README):** `agents/**` – Orchestrator, Architecture-Reviewer, Chess-Domain,
  Pairing, Tiebreak, Import-Export, UI, QA-Test, Security, Prompt-Injection-Reviewer, Release,
  Knowledge-Curator, Documentation, Final-Reviewer. Jede Datei mit vollem Schema (Scope,
  Nicht-Scope, Trust-Eingaben, Tools, Skills, Sicherheitsgrenzen, Eskalation, Handoff).
- **Skills:** 6 neue kanonische SKILL.md (prompt-injection-defense, instruction-integrity,
  untrusted-content-review, knowledge-management, secret-management, model-routing) +
  `.agents/skills/README.md`. Bestehende Flach-Skills bleiben gültig (Manifest `legacy-flat`);
  Rest-Migration + geplante Skills = **STM-AI-001b** (keine doppelte Wahrheit).
- **Manifeste:** `config/agent-manifest.json`, `config/skill-manifest.json`,
  `config/agent-routing.json` (Qualitätsklassen, kein Modell-Hardcoding).
- **Adapter:** `.claude/agents/**` dünn (16 via `Sync-ClaudeAgentAdapters.ps1`), Codex-kompatibel
  (kanonische Wahrheit `AGENTS.md`/`agents/**`).

## Routingstrategie
Qualitätsklassen `strongest-planning | strongest-implementation | standard-low-risk |
local-deterministic | human-required`. Security/Architektur/Pairing/Tie-Breaks/Release werden
nicht heruntergestuft; `securityReviewRequired`/`humanApprovalRequired` je Kategorie.

## Trust-Zonen & Prompt-Injection-Kontrollen (STM-SEC-001-Grundlage)
- **Trust T0–T5** (`config/agent-trust-policy.json`, `docs/architecture/AGENT_TRUST_BOUNDARIES.md`):
  nur T0-geprüftes T2 steuert; T3/T4 sind Daten; T5 isoliert/unerreichbar bei T4-Verarbeitung.
- **Configs:** `config/trusted-instruction-paths.json` (Allowlist),
  `config/tool-permission-profiles.json` (Least-Privilege).
- **Docs:** `PROMPT_INJECTION_THREAT_MODEL.md`, `AGENT_SECURITY_CONTROLS.md`,
  `UNTRUSTED_CONTENT_PIPELINE.md`, `SECURE_KNOWLEDGE_PERSISTENCE.md`.
- **Nachweis:** `Test-PromptInjectionDefense.ps1` mit 12 synthetischen, ungefährlichen Fixtures
  (README-ignoriert-AGENTS, Secret-Exfil, Branchname-Metazeichen, CSV-Befehle, Log-Folgeprompt,
  Skill-Toolaktivierung, Wissenseintrag-als-Regel, Toolausgabe-git-push, Dependency-Skript,
  PR-History-Rewrite, Code-Fence-Ausbruch, Pfad-Traversierung): erkannt/isoliert, nichts
  ausgeführt/persistiert, keine Secrets gelesen, Diagnose ohne Payload.

## Knowledge-Persistence-Kontrollen (STM-AI-002-Grundlage)
`docs/knowledge/**` (INDEX, domain/architecture/operations/security, decisions, lessons-learned,
glossary, source-registry trusted/untrusted). Pflichtmetadaten `source/date/trust/review`;
`Test-KnowledgePersistenceSafety.ps1` blockt PII/Secrets/Pfade/Binaries/getarnte Systemregeln.

## Neue Skripte
`Test-AgentInstructionIntegrity.ps1`, `Test-AgentSkillReadiness.ps1`,
`Test-PromptInjectionDefense.ps1`, `Test-KnowledgePersistenceSafety.ps1`,
`Sync-ClaudeAgentAdapters.ps1` (Check/Apply/WhatIf/RepositoryRoot).

## Tests & Gate-Integration
- Lokal grün: 4 Guards (Integrity/Readiness/PromptInjection/KnowledgePersistence),
  Pester-Contract-Tests `tests/agents/AgentSkillSecurity.Tests.ps1` (CI/Pester 5),
  PowerShell-Parserchecks, `dotnet build/test` (unverändert), GitSafety, OpenSourceSafety,
  CollaborationReadiness, `git diff --check`, ReleaseGate (via Commit-If-Green).
- **CI:** neuer Job `agent-integrity` in `.github/workflows/security-gate.yml` (cross-platform).
  Kein `pull_request_target`, keine Secrets für PR-Code.

## Backlog-Status
- STM-AI-001 → In Review (PR), STM-SEC-001 → In Progress, STM-AI-002 → In Progress,
  STM-AI-003 → In Progress, neu STM-AI-001b (Legacy-Skill-Migration).

## Risiken / offene Folgearbeiten
- Legacy-Skills noch nicht ins SKILL.md-Format migriert (STM-AI-001b); 5 geplante Skills offen.
- run-zip-Guards (Readiness/PromptInjection/Knowledge) sind Windows-lokale Gates (`D:\Temp`);
  in CI läuft der cross-platform Instruction-Integrity-Gate.
- Änderungen an Instruktionsquellen (`AGENTS.md`, `.claude/**`, `agents/**`, `config/**`)
  erfordern Owner-Review (CODEOWNERS) – über den PR.

## Commit / Push / PR
- Commit-SHA / Push / PR: siehe Endausgabe (`COMMIT=`, `PUSH=`, `PR=`).

## Nächster empfohlener Owner-Arbeitsauftrag
- **STM-SEC-001** weiter härten (Laufzeit-Enforcement der Guards in weiteren Abläufen) oder
  **STM-AI-001b** (Legacy-Skill-Migration). Fachlich bleibt STM-TB-001 der Bereich des Collaborators.
