# Dynamische LLM-Orchestrierung (STM-AI-005)

Stand: 2026-07-16. Ergänzt `MODEL_ROUTING.md` (auswählendes Routing) um die
**tatsächlich ausführende, providerübergreifende Aufgabenorchestrierung**.

## Ziel

Ein Masterprompt an Fabel oder Sol wird in einen validierten **Taskgraph** zerlegt.
Geeignete Teilaufgaben werden **tatsächlich** an kleinere logische Profile delegiert
(lokale, nichtinteraktive CLI-Runtimes als kontrollierte Unterprozesse). Fabel bzw.
Sol bleiben Orchestrator und Final-Integrator.

## Bausteine

| Ebene | Artefakt |
|---|---|
| Policy | `config/task-decomposition-policy.json` (Zerlegung, Tiefe 2, 1 Writer, kritische Kategorien, Integration-Gate) |
| Policy | `config/provider-runtime-policy.json` (Profil→Runtime, Retry/Backoff, Klassifikation, Redaktion) |
| Skripte | `scripts/New-RoutedTaskGraph.ps1` (validieren + routen via `Resolve-ModelRoute.ps1`) |
| Skripte | `scripts/Invoke-RoutedTaskGraph.ps1` (ausführen, Checkpoints, Quarantäne, Eskalation) |
| Skripte | `scripts/Resume-RoutedTaskGraph.ps1` (bindungsgeprüftes Fortsetzen) |
| Adapter | `scripts/Invoke-AnthropicProfile.ps1`, `scripts/Invoke-OpenAIProfile.ps1` |
| Lib | `scripts/lib/RoutedExecutionCommon.ps1` |
| Agenten | `agents/task-decomposer.md`, `agents/routing-supervisor.md`, `agents/result-integrator.md` |
| Skills | `.agents/skills/task-decomposition/`, `routed-execution/`, `cross-model-review/`, `token-budget-management/` |
| Tests | `scripts/Test-RoutedExecutionReadiness.ps1` (offline, synthetisch) |

## Taskgraph

Jede Teilaufgabe trägt die Pflichtfelder aus `requiredTaskFields` (Task-ID, Parent,
Backlog-ID, Zweck, Eingaben, erlaubte/verbotene Dateien, Abhängigkeiten, Risiko,
Kategorie, workMode, Größe, Determinismus, Mindestqualität, bevorzugter
Provider/Profil, Tokenbudget, Timeout, Tests, Reviewer, Ergebnisformat, Status).
`New-RoutedTaskGraph` validiert fail-closed (Zyklen, Tiefe ≤ 2, Scope-Kollisionen,
kritische Reviewer) und lässt **jede** Profilzuweisung durch `Resolve-ModelRoute.ps1`
bestätigen – Owner-Präferenzen ersetzen nie die Capability-/Qualitätsentscheidung.

## Rollenverteilung der Profile

Wie `config/model-routing.json`: Fabel = Masterorchestrierung/Resume/Handoff,
Sol = große Planung/Architektur/Finalintegration, Opus = Security/Schach/Release/
schwierige Reviews, Luna = klar definierte große Implementierung, Sonnet = abgegrenzte
mittlere Implementierung, Terra = ausschließlich risikoarme deterministische
Massenarbeit. Kritische Kategorien (`criticalCategories`) werden nie automatisch
herabgestuft; die Finalentscheidung liegt bei Fabel/Opus/Sol.

## Ausführung und Arbeitssicherheit

- Runtimes: vorhandene lokale Logins (`claude`, `codex`), keine Tokens im Repo/Log,
  Proxy nur prozesslokal aus der Umgebung.
- Children laufen nichtinteraktiv im bestehenden Terminal (kein neues Fenster),
  read-only (codex `--sandbox read-only`; claude ohne Permission-Bypass), dürfen
  **nie** committen oder pushen.
- Max. 1 paralleler Writer (Policy-konstant); read-only-Analysen dürfen parallel.
- Jede Child-Ausgabe ist **T3**: Injection-Marker-Scan, bei Verdacht Quarantäne;
  Child-Output wird nie Instruktionsquelle (`AGENT_TRUST_BOUNDARIES.md`).
- Nach jedem Task ein SHA-256-gebundener Checkpoint; Rate-/Usage-Limit und
  Tokenbudget beenden zustandserhaltend (Exit 2); `Resume-RoutedTaskGraph` prüft
  Bindung (Hash, Repo, Branch, Versuchslimit) und setzt fort.
- Fehler eskalieren an die nächsthöhere Qualitätsklasse
  (anthropic: sonnet→opus→fabel; openai: terra→luna→sol); kein stiller Wechsel.

## Qualitätsgate für Delegation (Tokensparen)

Delegiert wird nur bei: begrenztem Scope, definiertem Ergebnisformat,
deterministisch/testbarem Ergebnis, bekannten Dateien, erfüllter Mindestqualität und
stärkerem Final-Review. Sonst bearbeitet der Orchestrator selbst.

## Nachweise (2026-07-16)

- Offline: `Test-RoutedExecutionReadiness.ps1` 34/34 grün.
- Live: Anthropic-Delegation (sonnet, README-Linkcheck) real erfolgreich und durch
  Fabel geprüft; Eskalation terra→luna und Resume real durchlaufen; OpenAI-Seite
  funktional (Adapter/Klassifikation/Checkpoint), Modellantwort durch externes
  Nutzungskontingent blockiert und ehrlich als solches klassifiziert.
