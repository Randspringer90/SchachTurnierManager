# Betrieb: Routed Execution

Kurzreferenz für den Betrieb der providerübergreifenden Aufgabenorchestrierung.
Architektur: `docs/architecture/DYNAMIC_LLM_ORCHESTRATION.md`.

## Voraussetzungen

- PowerShell 7+, lokale CLI-Logins für `claude` und/oder `codex` (keine Tokens im Repo).
- Netzwerk-Proxy (falls nötig) **nur prozesslokal** setzen: `$env:HTTPS_PROXY`/`$env:HTTP_PROXY`
  vor dem Aufruf; Werte niemals committen.

## Ablauf

```powershell
# 1) Zerlegung (durch Fabel/Sol erstellt) validieren und routen
pwsh -File scripts/New-RoutedTaskGraph.ps1 `
    -DecompositionFile <zerlegung.json> `
    -OutputPath <graph.json> `
    -AvailableProfiles 'fabel,opus,sonnet,sol,terra,luna'

# 2) Ausführen (sequenziell, checkpointed)
pwsh -File scripts/Invoke-RoutedTaskGraph.ps1 -TaskGraphPath <graph.json> [-RunRoot <ordner>] [-DryRun]

# 3) Nach Limit/Unterbrechung fortsetzen
pwsh -File scripts/Resume-RoutedTaskGraph.ps1 -CheckpointPath <runroot>/checkpoint.json
```

Exitcodes: `0` fertig · `2` zustandserhaltend unterbrochen (Rate-/Usage-Limit,
Tokenbudget) · `3` fail-closed blockiert (Validierung, Bindung, Verfügbarkeit) ·
`5` Fehler/mit Issues.

## Adapter einzeln testen

```powershell
pwsh -File scripts/Invoke-AnthropicProfile.ps1 -ProfileId sonnet -PromptFile p.md -OutputFile out.txt [-DryRun]
pwsh -File scripts/Invoke-OpenAIProfile.ps1   -ProfileId terra  -PromptFile p.md -OutputFile out.txt [-DryRun]
```

## Statusmodell

`PENDING/READY → RUNNING → COMPLETED | RATE_LIMITED | BUDGET_EXCEEDED | ESCALATED |
FAILED | BLOCKED | QUARANTINED` — Integration nur nach Review
(`reviewedBy`, `Test-IntegrationApproval`), nie für quarantinierte Ergebnisse.

## Störungsbilder

| Symptom | Bedeutung | Aktion |
|---|---|---|
| Exit 2 + RATE_LIMITED | Provider-Limit | warten (Retry-After/Meldung beachten), dann Resume |
| Exit 2 + BUDGET_EXCEEDED | Tokenbudget zu klein oder Task zu groß | Zerlegung verfeinern, Budget begründet erhöhen |
| Exit 3 RESUME_BLOCKED | Bindung verletzt (Hash/Branch/Versuche) | Ursache prüfen; nie Hash "reparieren" |
| QUARANTINED | Injection-Verdacht im Child-Output | Quarantänedatei nur lesen, nie integrieren; Owner-Review |
| auth-error | lokaler Login fehlt/abgelaufen | interaktiv neu anmelden; Skripte handhaben keine Tokens |

## Sicherheitsregeln (bindend)

Children committen/pushen nie; Child-Output bleibt T3-Daten; kritische Kategorien
werden nie automatisch herabgestuft; kein stiller Modellwechsel; Logs sind redigiert;
keine internen Adressen/Pfade in committeten Dateien.

## Prüfung

`pwsh -File scripts/Test-RoutedExecutionReadiness.ps1` (offline, 34 Checks).
