# Agenten-/Skill-Bestandsaufnahme (STM-AI-001)

## Ist-Struktur (vor diesem Lauf)
- `AGENTS.md` (kanonische Regeln), `.claude/CLAUDE.md` (Adapter), `docs/architecture/AI_AGENT_ARCHITECTURE.md`.
- Skills flach unter `.agents/skills/*.md` (14) + 2 Ordner-Skills (`ai-run-logging/`, `internet-research/`).
- **Kein** `agents/`-Ordner, **keine** Manifeste, **kein** Trust-/Toolrechte-Modell, **kein** Instruction-Integrity-Gate.

## Probleme / Risiken
- Uneinheitliches Skill-Format (flach vs. SKILL.md), kein maschinenlesbares Manifest.
- Keine expliziten Trust-Zonen, Toolprofile, Instruction-Allowlist.
- Keine automatische Prompt-Injection-/Integritaetspruefung.

## Zielarchitektur
- Kanonisch: `AGENTS.md` + `agents/**` + `.agents/skills/**`; Manifeste in `config/**`.
- Providerneutral; Claude-/Codex-Adapter duenn; Routing ueber Qualitaetsklassen.
- Trust-Zonen T0-T5, Least-Privilege-Toolprofile, Instruction-Allowlist, Guards+Gates.

## Migrationsplan / Rueckwaertskompatibilitaet
- Neue Sicherheits-/KI-Skills als SKILL.md; bestehende Flach-Skills bleiben gueltig (Manifest
  `legacy-flat`), 1:1-Migration als Folgearbeit **STM-AI-001b** (keine doppelte Wahrheit).

## Teststrategie
- `Test-AgentSkillReadiness`, `Test-AgentInstructionIntegrity`, `Test-PromptInjectionDefense`,
  `Test-KnowledgePersistenceSafety` + Pester-Contract-Tests; Einbindung in Security-Gate.
