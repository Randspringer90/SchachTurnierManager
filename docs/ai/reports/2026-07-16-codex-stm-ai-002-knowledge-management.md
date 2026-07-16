# STM-AI-002: Wissensmanagement und sicherer Improvement-Prozess

## Ergebnis

Das repo-interne Wissensmanagement ist konsolidiert. Wiederholte Beobachtungen
können als lokale Agent-/Skill-Improvement-DRAFTs vorbereitet werden, ohne selbst
Instruktionen zu werden oder Agenten, Skills und Policies automatisch zu ändern.

## Scope und Basis

- Backlog: `STM-AI-002`
- GitHub-Issue: #18
- Integrationsbasis: `78ed91a8dbc9b325bad0049c695133fedf03336d`
- Arbeitsbranch: `integration/pr-18-safe-adoption`
- keine Schach-, Pairing-, Persistenz-, API- oder UI-Änderung
- keine neuen Dependencies, Binärdateien, Archive oder Fremdprojektpfade

## Umsetzung

- strukturierte Pflichtmetadaten `source`, ISO-Datum, Trust T0-T4 und `review`;
- `docs/knowledge/**` zusätzlich als data-only und nicht als Instruktionsquelle geprüft;
- Symlink-/Reparse-Schutz für Wissenseinträge;
- `New-AgentSkillImprovementProposal.ps1` erzeugt ausschließlich lokale
  `DRAFT_OWNER_REVIEW`-Artefakte im ignorierten Output-Bereich;
- begrenzte Freitexte werden als Daten markiert und gegen Secret-, PII-, lokale
  Pfad-, Injection-, Befehls-, Code-Fence- und Traversal-Muster geprüft;
- DRAFTs protokollieren, dass keine Instruktionsänderung, Netzwerknutzung oder
  Git-Schreibaktion stattfand;
- eine tatsächliche Agent-/Skill-Änderung benötigt einen getrennten Diff, Owner-,
  Prompt-Injection- und Final-Review sowie alle Gates;
- Knowledge-Curator, Skill, AGENTS und Architektur-Dokumentation konsistent angepasst;
- CI führt nach statischer Freigabe Agent-, Skill-, Proposal-, Knowledge-, Prompt-
  Injection- und Routing-Gates aus und bricht nach jedem Fehler explizit ab.

## Verifikation

- AgentSkillProposalSafety: 9/9 Fälle grün
- PowerShell-Parser: 129 Dateien grün
- AgentSkillReadiness, AgentInstructionIntegrity: grün
- KnowledgePersistenceSafety, PromptInjectionDefense: grün
- ModelRoutingReadiness: 12/12 grün
- PullRequestReviewReadiness: 42 synthetische Risikofälle grün
- PullRequestDependencyDelta: manifestfreier Kontrollfall `NOT_APPLICABLE`;
  Paket-Dateiliste ohne Manifest-/Lockfile-Änderung
- `dotnet build`: grün
- `dotnet test`: 220/220 grün, davon GoldenTests 3/3
- Frontend-Typecheck und Frontend-Build: grün
- GitCommitSafety, RepositoryOpenSourceSafety und CollaborationReadiness: grün
- `git diff --check`: grün
- vollständiges ReleaseGate einschließlich Paketierung: grün

Der erste Owner-Pfad-Negativfall verwendete in der synthetischen Fixture zwei
Backslashes und traf deshalb absichtlich den Ein-Backslash-Detektor nicht. Die
Fixture wurde korrigiert; Generatorlogik und alle neun Fälle sind danach grün.

Der erste Remote-Lauf von Owner-PR #19 blockierte vor jeder Ausführung, weil der
statische T4-Scanner drei defensive Regex-Literale selbst als Nutzlast einstufte.
Die betroffenen Schutzbegriffe werden nun aus neutral benannten Fragmenten zur
Laufzeit aufgebaut. Die neun Proposal-Fälle, Prompt-Injection-Defense, die 42
PR-Review-Fälle und der vollständige ReleaseGate wurden danach erneut ausgeführt.

## Sicherheit

Vorschlagsartefakte sind lokale Daten und werden nicht committed. Der Generator
besitzt keinen Pfad zur automatischen Aktivierung, keine Netzwerkfunktion und keine
Git-Schreibfunktion. Owner-Review und Remote-CI bleiben vor Integration zwingend.
