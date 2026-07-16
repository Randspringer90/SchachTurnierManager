# Nightly-/Resume-Unterbau

## Ziel

STM-AI-004 stellt einen checkpointfähigen, projektlokalen Unterbau bereit. Er führt
keine autonome Entwicklungsarbeit aus. Nightly- und Resume-Inhalte sind T3-Daten und
dürfen weder Agentenverhalten steuern noch als Kommando interpretiert werden.

## Bausteine

| Baustein | Verantwortung | Seiteneffekt |
|---|---|---|
| `config/nightly-run.json` | T2-Policy für Branch, Attempt-Limit und harte Controls | keiner |
| `New-NightlyCheckpoint.ps1` | sauberen Git-Zustand lesen und gebundenes JSON atomar schreiben | nur lokale Datei unter `output/nightly-runs` |
| `Get-NightlyResumePlan.ps1` | Binding und aktuellen Git-Zustand vergleichen | keiner |
| `New-NightlyRegistrationPlan.ps1` | Consumer-Vertrag für spätere Owner-Aktivierung exportieren | nur lokale Datei unter `output/nightly-registration` |
| `Test-NightlyReadiness.ps1` | Positiv-, Tamper-, Drift- und Datenschutzmatrix | temporäre, wieder entfernte Daten unter `output/` |

## Checkpoint-Vertrag

Ein Checkpoint enthält ausschließlich begrenzte Metadaten: Projekt, Run-/Paket-ID,
Phase, Status, UTC-Zeit, Branch, Head-SHA, Attempt, letzten erfolgreichen Schritt und
nächste Aktion als Daten. Die kanonischen Felder werden mit SHA-256 gebunden. Absolute
Pfade, Secrets, PII, Steuerzeichen, Code-Fences sowie Befehls- und Injection-Muster
werden abgelehnt. Das JSON enthält explizit `command: null` und alle Seiteneffektfelder
auf `false`.

Ein Checkpoint entsteht nur bei sauberem Arbeitsbaum auf `development`. Damit ist ein
grüner, bereits commitfähiger Zwischenstand die Voraussetzung; uncommittete Arbeit wird
nicht durch Nightly kaschiert.

## Resume-Entscheidungen

Der Resume-Plan führt die gespeicherte nächste Aktion nicht aus. Er liefert genau eine
Entscheidung:

- `READY_TO_RESUME` bei gültigem Binding und identischem Branch, Head und sauberem Baum;
- `NO_RESUME_REQUIRED` bei abgeschlossenem Checkpoint;
- `BLOCKED_ATTEMPT_LIMIT` nach Erreichen der Policy-Grenze;
- `BLOCKED_BRANCH_MISMATCH`, `BLOCKED_HEAD_MISMATCH` oder
  `BLOCKED_DIRTY_WORKTREE` bei Git-Drift.

Manipulierte, fremde, außerhalb des konfigurierten Roots liegende oder über Reparse-
Points erreichbare Checkpoints werden als Fehler abgelehnt.

## Registrierung

Die Registrierung ist bewusst zweistufig. Das Repository exportiert nur einen lokalen
Plan mit `READY_FOR_ACTIVATION`, `activationRequiresExplicitOwnerAction: true` und
`activationCommand: null`. Eine zentrale Orchestrierung darf diesen Vertrag später
einlesen, muss Aktivierung, Identität, Zeitplan und Betriebsüberwachung aber in einem
getrennten Owner-Lauf prüfen. Dieses Paket legt keine Windows-Aufgabe an und verändert
keinen externen Scheduler.

## Verwendung

Nach einem grünen Commit auf `development`:

```powershell
pwsh scripts/New-NightlyCheckpoint.ps1 -RunId run-20260716 -PackageId STM-AI-004 -Phase Final -Status READY_TO_RESUME -LastSuccessfulStep "ReleaseGate completed" -NextAction "Verify remote CI" -Attempt 1
```

Der ausgegebene Pfad kann anschließend read-only geprüft werden:

```powershell
pwsh scripts/Get-NightlyResumePlan.ps1 -CheckpointPath <lokaler-checkpoint-pfad>
```

Die Registrierungsplanung bleibt lokal:

```powershell
pwsh scripts/New-NightlyRegistrationPlan.ps1
```

Vor Integration ist `pwsh scripts/Test-NightlyReadiness.ps1` verbindlich.
