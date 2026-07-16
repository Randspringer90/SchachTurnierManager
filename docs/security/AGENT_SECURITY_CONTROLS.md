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
- **Pull-Request-Quarantäne**: Base-SHA-Code prüft Metadaten, vollständige Dateiliste und Patch
  vor jeder Ausführung; Report-/Policy-/SHA-Bindung und fail-closed Driftkontrolle.
- **Dependency-/Malware-Risikotrennung**: kein Restore oder Paketmanager in der statischen
  Phase, keine Binär-/Archivausführung, keine automatische Dependency-Aktualisierung.

Durchsetzung lokal durch alle vier Agent-/Knowledge-Gates; in CI durch den
plattformneutralen Instruction-Integrity-Gate und den Base-gebundenen Workflows
`security-gate.yml` sowie `pr-static-security-review.yml`. Die breitere Consumer-Integration
außerhalb des PR-Pfads bleibt als STM-SEC-001 nachgelagert.

Der Nightly-Persistenzschutz wird durch `config/nightly-run.json` und
`scripts/Test-NightlyReadiness.ps1` konkretisiert: nur atomare lokale T3-Checkpoints,
exakte Branch-/SHA-Bindung, sauberer Arbeitsbaum, begrenzte Resume-Versuche und eine
nicht aktivierende Registrierung. Checkpoints enthalten kein Kommando; Git-, Netzwerk-,
Scheduler-, Instruktions- und externe Mutationen bleiben in Policy und Ausgabe `false`.
