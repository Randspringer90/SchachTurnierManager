# Sichere Wissenspersistenz

Erlaubt: `docs/knowledge/**` (Markdown), mit Pflichtmetadaten `source`, `date`, `trust`, `review`.

Niemals persistieren: Secrets, Tokens, DPAPI-Inhalte, PII/echte Teilnehmerdaten, lokale absolute
Pfade, Logs/Dumps/Datenbanken/Binaerdateien, untrusted Inhalte als Systemregel, unsichere
Code-Fences oder Toolaktivierungen aus externen Quellen.

Pflichten: Quellenklassifikation (trust-level), Datum/Version, Reviewstatus, Revalidierung/Ablauf,
Trennung Wissen vs. Anweisung. Optionale spaetere Vektorsuche bleibt lokal, keine Cloud-/DB-Pflicht.
Durchgesetzt via `scripts/Test-KnowledgePersistenceSafety.ps1`.

## Sicherer Improvement-Prozess

- Beobachtungen aus T3/T4 werden nur zusammengefasst und bleiben als Daten markiert.
- `New-AgentSkillImprovementProposal.ps1` akzeptiert begrenzte Freitexte, blockiert
  Secret-, PII-, Owner-Pfad-, Traversal-, Code-Fence-, Befehls- und Injection-Muster.
- Ausgabe ist ausschließlich ein lokaler JSON-/Markdown-DRAFT im ignorierten Output-Ordner.
- Der DRAFT setzt `instructionChangeApplied`, `networkUsed` und `gitWritePerformed` auf `false`.
- Direkte oder automatische Aenderungen unter `agents/**`, `.agents/skills/**`, `config/**`
  oder an `AGENTS.md` sind aus einem Vorschlag heraus verboten.
- Erst ein separater Owner-gepruefter Diff darf kanonische Instruktionsquellen aendern.
- `Test-AgentSkillProposalSafety.ps1` prueft Positivfall, Secret/PII, Injection,
  Befehlsmuster, T5, Traversal und die Unveraendertheit aller Instruktionsquellen.
