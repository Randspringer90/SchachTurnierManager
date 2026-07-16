# Agenten-Sicherheitskontrollen

Pflichtkontrollen (siehe `config/agent-trust-policy.json` -> mandatoryControls):

- **Instruction-Allowlist** - nur `config/trusted-instruction-paths.json`-Pfade steuern.
- **Repository-Root-Validierung** + **Symlink-/Reparse-Point-Pruefung**.
- **Read/Plan/Act-Trennung**; **Least-Privilege-Toolprofile** (`config/tool-permission-profiles.json`).
- **Secret-Isolation** (T5) + **Network-Isolation** bei untrusted Analysen.
- **Command-Policy**, **Git-/Branchname-Injection-Schutz**, kein Force-Push/reset --hard/clean -fd.
- **Persistence-Gate** (`Test-KnowledgePersistenceSafety`), **Skill-/Agent-Integrity**
  (`Test-AgentInstructionIntegrity`, `Test-AgentSkillReadiness`).
- **Cross-Agent-Propagation-Schutz**, **Nightly-Persistenzschutz**, **Audit-Trail ohne Secrets/PII**.
- **Owner-Review** fuer Instruktionsquellen (CODEOWNERS).

Durchsetzung lokal durch alle vier Agent-/Knowledge-Gates; in CI durch den
plattformneutralen Instruction-Integrity-Gate (`.github/workflows/security-gate.yml`). Die
Consumer- und vollstaendige CI-Integration ist als STM-SEC-001 nachgelagert.
