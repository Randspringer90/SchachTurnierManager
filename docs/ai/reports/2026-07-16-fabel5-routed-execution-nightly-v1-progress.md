# Abschlussbericht: Fabel5 – Routed Execution, Nightly-Aktivierung, Contributor-Queue

Datum: 2026-07-16 (Abendlauf) · Orchestrator: Claude Fabel 5 · Modus: autonomer Owner-Lauf

## Ergebnis (Kurzfassung)

1. **Marcels Schach-Work-Queue vollständig vorbereitet:** Issues #3/#4 präzisiert und
   Marcel zugewiesen; neue Issues #22 (STM-FACH-002, Ready), #23 (STM-FACH-003,
   Blocked), #24 (STM-IE-002, Blocked), #25 (STM-IE-004); `MARCEL_WORK_QUEUE.md` neu.
2. **STM-AI-005 (Routed Execution) Done:** echte providerübergreifende Delegation
   implementiert, 34/34 Offline-Gate, realer Live-Smoke; PR #29 nach vollständig
   grüner CI gemergt (`8305814`), Issue #26 geschlossen.
3. **STM-AI-006 (aktive Nightly) Done:** projektlokale Ausführungsebene + 19/19-Gate;
   PR #32 nach grüner CI gemergt (`c1a2d4c`), Issue #27 geschlossen; **zentrale
   Registrierung ACTIVE**, nächster Lauf **2026-07-17 00:00 lokale Zeit** verifiziert.
4. **Marcels neue PRs #30/#31** (heute Abend eröffnet) ausschließlich **statisch**
   geprüft (kein Fremdcode ausgeführt, keine Direktintegration, Branches unberührt).

## Git

- Ausgangs-SHA development: `4fa6ed407f2f9a1d8008c05f6732e497bc8e272e`
- Commits dieses Laufs: `11b3b59` (Contributor-Queue-Doku, direkt), `8305814`
  (STM-AI-005, PR #29), `c1a2d4c` (STM-AI-006, PR #32), plus finaler Doku-Commit.
- Offene PRs: Start 0 → Ende 2 (Marcels #30/#31, In Review).
- Offene Issues: Start 2 (#3, #4) → Ende 6 (#3, #4, #22–#25; #26/#27 geschlossen).
- Kein Force-Push, kein History-Rewrite, keine Marcel-Branches berührt.

## Netzwerk-Besonderheit (Workstation)

github.com ist nur über den internen Proxy erreichbar (zentrale Policy, pro Prozess
gesetzt, nie committet); Direktverbindungen werden von der Firewall abgelehnt.

## STM-AI-005 – dynamische Promptzerlegung & Routed Execution

- Neu: `New-/Invoke-/Resume-RoutedTaskGraph.ps1`, Adapter `Invoke-AnthropicProfile.ps1`
  / `Invoke-OpenAIProfile.ps1`, `scripts/lib/RoutedExecutionCommon.ps1`, Policies
  `task-decomposition-policy.json` / `provider-runtime-policy.json` (+ Schemas, in der
  Instruction-Allowlist), Agenten Task-Decomposer/Routing-Supervisor/Result-Integrator,
  Skills task-decomposition/routed-execution/cross-model-review/token-budget-management,
  Doku `DYNAMIC_LLM_ORCHESTRATION.md` + `docs/operations/ROUTED_EXECUTION.md`.
- Sicherheit: Children read-only ohne Commit/Push; Child-Output T3 mit
  Injection-Quarantäne; kritische Kategorien nie automatisch herabgestuft; kein
  stiller Modellwechsel; SHA-256-Checkpoints; max. Tiefe 2, max. 1 Writer.
- **Tatsächliche Modellaufrufe (Live-Smoke):**
  - anthropic/sonnet: README-Linkcheck real ausgeführt, Ergebnis durch Fabel
    faktisch verifiziert (COMPLETED, reviewedBy=fabel) → **Anthropic-Routing OK**.
  - openai/gpt-5.6-terra → reale Eskalation → openai/gpt-5.6-luna: beide durch das
    externe ChatGPT-/Codex-Wochenkontingent blockiert („try again at Jul 23rd,
    2026 1:54 PM“); vom System korrekt als usage-limit klassifiziert und
    zustandserhaltend gecheckpointet → **OpenAI-Routing PARTIAL, ehrlich
    dokumentiert** (Auth grün; Nachweis ab 2026-07-23 nachholbar).
  - Resume nach Limit real und synthetisch bewiesen.
- Zusätzliche Delegationen im Lauf: 2 read-only Audit-Analysen an kleinere
  Anthropic-Profile (haiku/sonnet), Ergebnisse durch Fabel geprüft und übernommen.
- Tokenersparnis: Mechanik (Budget-Gate, Delegationsgate) implementiert und
  getestet; belastbarer Messwert erst mit produktiven Delegationen → NOT_MEASURABLE
  in diesem Lauf.
- Routingfehler/Eskalationen: 1 Adapter-Bug (leerer Auth-Probe-Prompt) → korrekte
  automatische Eskalation terra→luna; Bug behoben und mit Test abgedeckt.
- Prozess-Lessons: (a) PRs mit Instruktionsquellen verlangen
  `integration/pr-<n>-safe-adoption` + SHA-gebundenes Owner-Review
  (`STATIC-EXECUTION-APPROVED:<sha>`) – PR #28 wurde transparent durch #29 ersetzt;
  (b) `config/` darf keine Credential-Regexe tragen → Redaktionsmuster leben in der
  SECURITY-PATTERN-Lib; (c) literale Scheduler-Kommandos im Patch treffen das
  kritische Persistenzmuster → Laufzeit-Komposition (Fix `a243235`).

## STM-AI-006 – aktive zentrale Nightly-Orchestrierung

- Zentrale Struktur read-only verifiziert: zentraler Orchestrator mit DryRun/Run/
  Status/Resume, Provider-Reihenfolge Sol→Fabel mit Handoff, Nachtfenster
  22:00–06:30, Locking/Heartbeat/Checkpoints; vorhandene zentrale Scheduled Task
  (aktiviert, täglich 00:00, Timeout 6 h, letzter Lauf heute 11:54 Exit 0).
  **Keine zweite Task erzeugt.**
- Projektlokal neu: `Invoke-NightlyProjectRun.ps1` (Lock, Vorbedingungen,
  Owner-Queue aus BACKLOG mit striktem friend-/Blocked-/Audit-only-Ausschluss,
  Plan+Masterprompt+Gates), `Resume-NightlyProjectRun.ps1`,
  `Register-NightlyProject.ps1` (nur Override-Flip in der vorhandenen zentralen
  Registry, WhatIf-Default, Backup, nie Scheduler-Mutation),
  `config/nightly-execution.json` (+Schema), `Test-NightlyExecutionReadiness.ps1`
  (19/19; zusammen mit dem Routed-Gate zusätzlich in CI).
- Aktivierung: WhatIf 6/6 PASS → Apply (Override `enabled=true`,
  activatedAtUtc 2026-07-16T19:54Z, Owner-Freigabe aus dem heutigen Auftrag; die
  Alt-Begründung „interne Adresse in Doku“ ist seit `9ada246` bereinigt und wurde
  heute per Scan bestätigt) → zentrale Queue: `eligible=true, taskClass=feature`.
  Registry-Änderung im zentralen Repo committet und gepusht.
- **Nächster Nightly-Lauf: Donnerstag, 2026-07-17 00:00 lokale Zeit** (verifiziert);
  erste geplante Backlog-Aufgabe: **STM-SEC-001** (zusätzlich stehen Marcels PRs
  #30/#31 als sichere Adoptionsarbeit im lokalen NEXT_PROMPT).
- Die Plan-Ebene aus STM-AI-004 (`config/nightly-run.json`) bleibt unverändert
  nicht selbstaktivierend; das 56-Fälle-Gate bleibt unangetastet grün.

## Marcels PRs #30/#31 (T4, static-only)

- PR #30 (STM-IE-001, TRF16-Export): Base-SHA-gebundener statischer Review in CI:
  **OWNER_REVIEW_REQUIRED, 8 Findings, kein Critical**; Ausführungsjobs by design
  gehalten. PR #31 (STM-DOC-001): **ADAPTATION_REQUIRED, 4 Findings (medium)**.
- Kein Fremdcode ausgeführt; Adoption erfolgt als separater Owner-Prozess vom
  aktuellen `origin/development` (Attribution + wertschätzendes Feedback geplant).
- Lokaler Befund: die lokalen Volл-Läufe von `Invoke-SafePullRequestReview`/
  `Test-PullRequestReviewReadiness` hängen auf dieser Workstation (CI-Läufe grün);
  als Folgeaufgabe notiert.

## Tests & Gates (Endstand)

dotnet 220/220 · Frontend Typecheck+Build grün · RoutedExecution 34/34 ·
NightlyExecution 19/19 · Nightly 56/56 · ModelRouting 12/12 · Instruction-Integrity,
Skill-Readiness, ProposalSafety 9/9, PromptInjectionDefense,
KnowledgePersistenceSafety, CollaborationReadiness grün · CommitGuard-Kette
(GitSafety, RepoOpenSourceSafety, ReleaseGate) je Commit grün · CI der PRs #29/#32
vollständig grün · `git diff --check` grün.

## Security

Keine Secrets/PII/internen Adressen committet (Proxy nur prozesslokal); alle neuen
Instruktionsquellen owner-reviewt und SHA-gebunden freigegeben; Child-Ausgaben
T3-behandelt; STM-SEC-004 (History-Altlast) unverändert Blocked bis
Owner-Entscheidung – kein Rewrite in diesem Lauf.

## Fortschritt & Release-Reife

- Backlog: Start 9/31 Done (29 %) → **11/33 Done (33 %)** (AI-005/006 neu und Done).
- Release-Reife (erledigte P0/P1): Start 4/15 (27 %) → **6/17 (35 %)**.
- Kritischer Pfad unverändert: FACH-002→003 (Marcel, kritischer Final-Review),
  IE-001→002 (Marcel, PRs laufen), SEC-001..003 → SEC-004 (Owner-Entscheidung) →
  REL-001..003 → REL-004.

## Nächster Folgeprompt

Lokales `NEXT_PROMPT.md` (Status `ready-safe-local`): PR-#30/#31-Adoption →
Owner-Queue ab STM-SEC-001 → OpenAI-Live-Nachweis ab 2026-07-23. Vollständige
Artefakte: externer Runordner `STM_FABEL5_COMPLETION_20260716_175700` (+ ZIP).
