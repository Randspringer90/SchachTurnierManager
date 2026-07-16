# STM-SEC-005 – Sichere Pull-Request-Prüfung und kontrollierte Übernahme

Datum: 2026-07-16
Qualitätsklasse: stärkste Planung und Implementierung, unabhängige Security-, Workflow- und QA-Reviews

## Ergebnis

STM-SEC-005 implementiert einen dauerhaft nutzbaren, vorsichtigen PR-Review-Unterbau. Die
Initialphase behandelt sämtliche PR-Inhalte als T4-Daten, liest nur SHA-gebundene Metadaten,
Dateiliste, Patch und Git-Tree-Modi und führt keinen PR-Code aus. Neun redigierte JSON-/Markdown-
Artefakte binden Repository, Original-PR, Head-/Base-SHA und Policy-Hashes.

Der Workflow klassifiziert Prompt-Injection-, Dependency-, Binär-/Archiv-, Symlink-/Gitlink-,
Workflow-, Build-, Installer- und statische Schadcode-Risiken. Offline-Bundles können Modus-,
Tree- oder Patchvollständigkeit nicht selbst attestieren und bleiben fail-closed. Sichere Teile
werden ausschließlich über einen Owner-Integrationsbranch vom aktuellen `origin/development`
übernommen; Attribution und verständliches, redigiertes Contributor-Feedback bleiben erhalten.

## Lieferumfang

- Pull-Request-Reviewer und Pull-Request-Integrator mit getrennten Least-Privilege-Profilen
- fünf kanonische Skills und manifestiertes Routing
- vier defensive Policies für Review, Dependencies, Risikomuster und Adoption
- statischer Review-, Dependency-, Adoption-Prompt- und Feedback-Unterbau
- Trust-Boundary-, Architektur-, Security- und Ablaufdokumentation
- read-only Check `pr-static-security` ohne `pull_request_target`, Secrets oder Write-Rechte
- SHA-gebundene Owner-Freigabe; ein Label dient nur zum erneuten Triggern
- strict Ruleset-Plan für die erforderlichen Checks

## Verifikation

- 42 synthetische Risiko-, Tamper-, Pfad-, Online-Modus- und Nichtausführungsfälle: grün
- Pester-Contract: 1 bestanden, 0 fehlgeschlagen
- .NET: 191 bestanden, 0 fehlgeschlagen
- Frontend-Typecheck und Vite-Build: grün
- AgentInstructionIntegrity, AgentSkillReadiness, CollaborationReadiness: grün
- PromptInjectionDefense und KnowledgePersistenceSafety: grün
- GitCommitSafety und RepositoryOpenSourceSafety: grün
- vorbereitende ReleaseGate-Läufe mit `-SkipPack`: grün; abschließender vollständiger
  `Commit-If-Green`-ReleaseGate-Lauf einschließlich Portable-Paketierung: grün
- `git diff --check`: grün
- unabhängiger Security-, Workflow-/Trust- und QA-Finalreview: jeweils freigegeben

## GitHub und Scope

- Issue: #11
- Implementierungscommit: `e1f9868`
- Owner-PR: #12, grün per Squash nach `development` integriert
- Mergecommit: `ba55061526311931541a21cd0ed22107066a5036`; Issue #11 geschlossen
- GitHub-CI: acht Checks grün, einschließlich `pr-static-security`, Security-Gate,
  Agent-Integrity, .NET-Build/-Tests, Frontend und Diff-Check
- GitHub-Rulesets für `development`, `main` und Releasebranches angewendet und online verifiziert
- keine Änderung an Schach-, Pairing- oder Wertungslogik
- keine neue Produktdependency
- keine Secrets, PII, lokalen Pfade oder Fremdprojektabhängigkeiten
- keine Dateikollision mit den parallelen PRs #9 und #10

`CHANGELOG.md` wurde bewusst nicht parallel verändert, weil die Datei Bestandteil der beiden
offenen Contributor-PRs ist. Der Paketumfang ist stattdessen in Backlog, Feature-Matrix,
Roadmap, Security-, Architektur- und AI-Dokumentation belegt.

## Verbleibende Betriebsgrenzen

Die Workflowdefinition eines nativen GitHub-`pull_request`-Laufs ist ohne externe
vertrauenswürdige App nicht kryptografisch an den Basebranch gebunden. CODEOWNERS, Rulesets,
Owner-SHA-Review und unabhängiger Finalreview bleiben daher zwingend. Der Ruleset-Plan wurde
nach Merge kontrolliert angewendet und online verifiziert. Ein fehlender statischer Fund ist
keine Garantie für Schadcodefreiheit.
