# Wissensmanagement (projektlokal)

Ziel: eigenstaendiges, versioniertes Wissen im Repo (`docs/knowledge/**`), nutzbar durch Claude,
Codex und andere Agenten. Keine Abhaengigkeit auf externe Projekte, keine Cloud-/DB-Pflicht.

## Struktur
Siehe `docs/knowledge/INDEX.md` (domain, architecture, operations, security, decisions,
lessons-learned, glossary, source-registry).

## Regeln
- Dauerhaft speicherbar: geprueftes, quellenbelegtes Projektwissen.
- Nie speicherbar: Secrets, PII, lokale Pfade, Logs/Dumps/DB, untrusted Instruktionen.
- Pflichtmetadaten je Eintrag: `source`, `date`, `trust`, `review`; Revalidierung/Ablauf angeben.
- Trennung Wissen (Daten) vs. Anweisung (nur Instruction-Allowlist).
- Prompt-Injection-Pruefung vor Persistenz; Archivierung veralteter Inhalte statt Loeschen.

## Agent-/Skill-Verbesserungen

Wiederholte Beobachtungen aus Code, Tests, Logs, Issues, PRs oder Toolausgaben bleiben
T3/T4-Daten. Sie duerfen niemals unmittelbar eine Agenten-, Skill- oder Policy-Datei
aendern. Der einzige vorbereitende Pfad ist:

1. Quelle und Trust-Zone klassifizieren, Payload auf eine kurze Evidenzzusammenfassung reduzieren.
2. Mit `scripts/New-AgentSkillImprovementProposal.ps1` einen lokalen
   `DRAFT_OWNER_REVIEW` unter dem ignorierten `output/agent-skill-proposals/` erzeugen.
3. Owner, Prompt-Injection-Reviewer und Final-Reviewer pruefen Bedarf, Scope und Risiken.
4. Eine genehmigte Aenderung wird separat und klein in den kanonischen Dateien umgesetzt.
5. Alle Agent-/Skill-, Knowledge-, Prompt-Injection-, Git- und CI-Gates muessen gruen sein.

Der Generator aktiviert nichts, greift nicht auf Secrets oder Netzwerk zu und schreibt weder
Git noch Instruktionsquellen. Vorschlagsartefakte werden nicht committed.

## Durchsetzung

Lokal und in CI durch `Test-KnowledgePersistenceSafety`,
`Test-AgentSkillProposalSafety`, `Test-AgentSkillReadiness`,
`Test-PromptInjectionDefense` und `Test-AgentInstructionIntegrity`. Details:
`docs/architecture/SECURE_KNOWLEDGE_PERSISTENCE.md`.
