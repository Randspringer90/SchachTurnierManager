# Glossar

- **Agent** - providerneutrale Rolle mit definiertem Scope (`agents/**`).
- **Skill** - wiederverwendbares Verfahren (`.agents/skills/**`).
- **Trust-Zone (T0-T5)** - Vertrauensstufe einer Quelle (`config/agent-trust-policy.json`).
- **Instruction-Allowlist** - Pfade, die Agentenverhalten steuern duerfen (`config/trusted-instruction-paths.json`).
- **Qualitaetsklasse** - modellneutrale Routing-Stufe (`config/agent-routing.json`).
- **Prompt-Injection** - Versuch, ueber untrusted Inhalte Agentenverhalten zu steuern.
