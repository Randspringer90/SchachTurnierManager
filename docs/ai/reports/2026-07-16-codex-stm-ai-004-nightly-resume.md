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

Vollständiger ReleaseGate, alle Repository-Gates und Remote-CI werden vor dem
Owner-Merge ergänzt und im Abschluss dieses Berichts dokumentiert.
