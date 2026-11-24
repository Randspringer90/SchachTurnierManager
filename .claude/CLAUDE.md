# Claude-Code-Adapter – SchachTurnierManager

Diese Datei ist nur ein Adapter und definiert keine eigenen Regeln.

- Verbindliche Projektregeln: `AGENTS.md` (Repo-Root); bei Widerspruch gilt immer `AGENTS.md`.
- Skills: `.agents/skills/<name>/SKILL.md`; vor Commit-, Push- und Snapshot-Arbeiten
  `.agents/skills/repository-security/SKILL.md`.
- Agentenarchitektur und Trust-Grenzen: `docs/architecture/AI_AGENT_ARCHITECTURE.md`,
  `docs/architecture/AGENT_TRUST_BOUNDARIES.md`.
- Abläufe und Gates: `docs/planning/PROJECT_ORCHESTRATION.md`, `docs/planning/DEFINITION_OF_DONE.md`.
- Claude-Agentenadapter unter `.claude/agents/**` werden mit `scripts/Sync-ClaudeAgentAdapters.ps1`
  aus `agents/**` erzeugt.
