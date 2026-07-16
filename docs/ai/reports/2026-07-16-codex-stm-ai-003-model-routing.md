# STM-AI-003: dynamisches Modellrouting

## Ergebnis

Das providerneutrale Modellrouting ist als reproduzierbare, fail-closed Policy
operationalisiert. Die Policy nutzt ausschließlich logische Profile und
Qualitätsklassen, enthält keine Modellversionspins und startet selbst kein Modell.
Eine aufrufende Runtime muss die tatsächlich verfügbaren Profile bestätigen.

## Scope und Basis

- Backlog: `STM-AI-003`
- GitHub-Issue: #15
- Integrationsbasis: `fededbf1faf858787f77539b2633f0fcb058a588`
- Arbeitsbranch: `feature/STM-AI-003-model-routing`
- keine Fachlogik, Persistenz, API oder UI geändert
- keine neuen Dependencies, Binärdateien, Archive oder Fremdprojektpfade

## Umsetzung

- `config/model-routing.json` auf schemaVersion 2 mit geordneten Regeln gehoben;
- lokales fail-closed Schema `config/model-routing.schema.json` ergänzt;
- Profile Fabel, Sol, Luna, Terra, Opus und Sonnet eindeutig abgegrenzt;
- Security, Schachregeln, Pairing/Tie-Breaks, Release, Installer und schwierige
  Reviews zwingend dem stärksten Expertenprofil zugeordnet;
- Terra auf risikoarme deterministische Massenarbeit begrenzt;
- `scripts/Resolve-ModelRoute.ps1` liefert eine auditierbare JSON-Entscheidung,
  startet kein Modell und führt keinen Fallback aus;
- fehlende Verfügbarkeit, unbekannte Profile, Policy-Konflikte oder nicht
  abgedeckte Aufgaben blockieren;
- Skill, AGENTS, Architektur- und Skriptdokumentation konsistent aktualisiert;
- `scripts/Test-ModelRoutingReadiness.ps1` prüft Policy und zwölf Positiv-/
  Negativentscheidungen.

## Verifikation

- PowerShell-Parser: 127 Dateien grün
- ModelRoutingReadiness: 12/12 Fälle grün
- AgentSkillReadiness: grün
- AgentInstructionIntegrity: grün
- PromptInjectionDefense: grün
- KnowledgePersistenceSafety: grün
- PullRequestReviewReadiness: 42 synthetische Risikofälle grün
- PullRequestDependencyDelta: manifestfreier Kontrollfall `NOT_APPLICABLE`;
  die Paket-Dateiliste enthält keine Manifest- oder Lockfile-Änderung
- `dotnet build`: grün
- `dotnet test`: 220/220 grün, davon 3 Golden-Tests
- Frontend-Typecheck und Frontend-Build: grün
- GitCommitSafety, RepositoryOpenSourceSafety und CollaborationReadiness: grün
- `git diff --check`: grün
- vollständiges ReleaseGate einschließlich Paketierung: grün

Ein zu kurz gesetztes lokales Prozess-Timeout unterbrach den ersten ReleaseGate-
Aufruf vor einem fachlichen Ergebnis. Der unveränderte Gate wurde anschließend mit
ausreichendem Timeout vollständig und erfolgreich wiederholt. Die anfänglichen
Harness-Fehler bei Array-Übergabe und Nullvergleich wurden durch die neue Matrix
sichtbar und vor der erfolgreichen Wiederholung korrigiert.

## Sicherheit und Restrisiko

Die Runtime-Zuordnung eines logischen Profils zu einem konkreten Provider-Modell
liegt bewusst außerhalb des Repositories. Deshalb kann der Resolver eine Auswahl
nur dann freigeben, wenn die Runtime das erforderliche logische Profil explizit als
verfügbar meldet. Owner-Review und Remote-CI bleiben vor der Integration verbindlich.
