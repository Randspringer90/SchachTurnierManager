# Architektur der kontrollierten PR-Integration

## Komponenten

| Komponente | Aufgabe | Mutation |
|---|---|---|
| `Invoke-SafePullRequestReview.ps1` | Metadaten/Dateiliste/Patch validieren und neun Berichte erzeugen | nur expliziter Ausgabeordner |
| `PullRequestReviewCommon.ps1` | pure Klassifikation, Redaction, Policy-/SHA-Bindung | keine |
| `Test-PullRequestDependencyDelta.ps1` | Offline-Dependency-Contract ohne Paketmanager | nur explizite Reportdatei |
| `New-PullRequestAdoptionPrompt.ps1` | Trust-getrennten, gebundenen Handoff erzeugen | nur expliziter Ausgabeordner |
| `New-PullRequestFeedback.ps1` | redigierten Entwurf; optional explizites Posting nach SHA-Recheck | Draft, optional GitHub-Kommentar |
| `pr-static-security-review.yml` | Base-Skript als read-only Check aufrufen | keine Repositorymutation |

Die Policies sind T2 und werden vom Instruction-Integrity-Gate semantisch geprüft. Agent,
Skills und Toolprofile bilden Least Privilege ab: `Pull-Request-Reviewer` ist statisch
read-only, `Pull-Request-Integrator` darf erst nach Owner-Freigabe scope-begrenzt editieren und
testen. Prompt-Injection- und Final-Reviewer bleiben unabhängige Reviewer der beiden Routen.

## Phasentrennung

1. **Control Plane:** GitHub liefert über validierte API-Argumente Metadaten, Dateiliste und
   Patch. Es wird kein PR-Code ausgeführt.
2. **Static Analysis:** Pure Klassifikation erzeugt SHA-/Policy-gebundene Artefakte. Eine
   Entscheidung bis `SAFE_FOR_ISOLATED_BUILD` ist möglich, aber kein Merge.
3. **Isolated Inspection:** Nur nach Freigabe darf der PR-Head in einen separaten Worktree ohne
   Secrets oder produktive Daten gelangen.
4. **Adoption:** Der `Pull-Request-Integrator` übernimmt auf einem neuen Branch vom aktuellen `origin/development` nur genehmigte
   Teile. Semantischer Vergleich verhindert doppelte oder veraltete Parallelstrukturen.
5. **Verification:** Tests und Security-Gates laufen auf dem Integrationsstand. Neue
   Dependencies werden dort ohne Lifecycle-Skripte auditiert.
6. **Integration:** Owner-PR, Attribution, Feedback, unabhängiger Final-Review und grüne CI
   ermöglichen den Merge nach `development`.

## Fehler- und Driftmodell

Unvollständige API-Seiten, fehlende Textpatches, blockierte Dateitypen, ungültige Modi,
unsichere Refnamen, Regex-Timeouts sowie SHA-/Policy-Drift sind fail-closed. Berichte mit
abweichender Review-ID oder Bindung dürfen weder Prompt noch Feedback oder Adoption auslösen.

`BLOCKED_NEEDS_OWNER` beendet nur den betroffenen Zustandszweig. Der Beitrag wird nicht
gelöscht oder pauschal entwertet; sichere, separat belegte Teile können nach Owner-Entscheidung
in einem neuen Reviewzyklus übernommen werden.
