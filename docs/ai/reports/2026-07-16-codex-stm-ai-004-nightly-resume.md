# STM-AI-004: Nightly-/Resume-Unterbau

## Ergebnis

Der projektlokale Nightly-/Resume-Unterbau ist implementiert. Er erzeugt gebundene
Checkpoints, prüft Resume-Drift fail-closed und exportiert ausschließlich eine
nicht aktivierende zentrale Registrierungsplanung.

## Scope und Basis

- Backlog: `STM-AI-004`
- GitHub-Issue: #20
- Integrationsbasis: `4baa6c8f20559adbba294c7ea723f9d6d8594971`
- Arbeitsbranch: `integration/pr-20-safe-adoption`
- Owner-PR: #21, nach 8/8 grünen Checks squash-gemergt
- Merge-Commit: `a6df385763dadc6538e85e9b3d06e8ae20130019`
- keine Schach-, Pairing-, Persistenz-, API-, UI-, Release- oder Installer-Änderung
- keine neue Dependency und keine Fremdprojektabhängigkeit

## Umsetzung

- schema-validierte T2-Policy mit exaktem `development`, sauberem Worktree und
  begrenzten Resume-Versuchen;
- atomare SHA-256-gebundene Checkpoints nur unter `output/nightly-runs`;
- Redaction und Ablehnung von Secrets, PII, absoluten Pfaden, Traversal,
  Reparse-Points, Steuerzeichen, Befehls- und Injection-Mustern;
- read-only Resume-Entscheidung für gültigen Zustand, Branch-/Head-/Worktree-Drift,
  abgeschlossene Läufe und Attempt-Limit;
- Registrierungsexport `READY_FOR_ACTIVATION`, ohne Aktivierungskommando oder
  automatische Ausführung;
- CI-Erweiterung um `Test-NightlyReadiness.ps1`.

## Sicherheit

Produktivskripte lesen Git ausschließlich. Sie enthalten keine mutierende Git-,
Netzwerk- oder Scheduler-Funktion. Checkpoints und Pläne bleiben lokale T3-Daten,
enthalten kein Kommando und setzen sämtliche Seiteneffektfelder auf `false`.
Synthetische Git-Mutationen des Gates laufen nur in einem verifizierten, ignorierten
Test-Repository unter `output/` und werden anschließend sicher entfernt.

## Verifikation

- PowerShell-Parser: neue Skripte grün
- JSON-Policy und Schema: parsebar
- NightlyReadiness: 56/56 Fälle grün
- Checkpoint-/Resume-Roundtrip: grün
- Tamper, Traversal, Secret, PII, Dirty Worktree, Branch-/Head-Drift: blockiert
- Registrierung: `READY_FOR_ACTIVATION`, keine Aktivierung
- .NET: 220/220, einschließlich GoldenTests 3/3
- Frontend-Typecheck und Frontend-Build: grün
- PullRequestReviewReadiness: 42/42
- AgentSkillProposalSafety: 9/9
- ModelRoutingReadiness: 12/12
- Instruction-, Agent-/Skill-, Knowledge-, Injection-, Git-, Open-Source- und
  Collaboration-Gates: grün
- vollständiger ReleaseGate einschließlich Paketierung: grün
- Remote-CI: 8/8 grün

Nach dem Merge wurde auf sauberem `development` ein realer Registrierungsplan erzeugt:
Status `READY_FOR_ACTIVATION`, `ActivationPerformed=false`. Ein gebundener
`COMPLETED`-Checkpoint lieferte im read-only Roundtrip `NO_RESUME_REQUIRED`; Kommando,
Git-Schreibwirkung und Scheduler-Mutation blieben leer beziehungsweise `false`.
Issue #20 ist geschlossen.
