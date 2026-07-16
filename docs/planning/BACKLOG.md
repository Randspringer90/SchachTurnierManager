# BACKLOG – Kanonische Aufgabenquelle

> **Dies ist die einzige kanonische Quelle der aktiven Arbeit.** `PLANS.md` und ältere
> Roadmaps (`ROADMAP.md`, `FEATURE_ROADMAP.md`, `docs/ai/prompts/codex-roadmap/**`) sind
> **historisch** und wurden hierher überführt. Ergänzend:
> [`FEATURE_MATRIX.md`](FEATURE_MATRIX.md), [`ROADMAP_TO_1_0.md`](ROADMAP_TO_1_0.md),
> [`DEFINITION_OF_DONE.md`](DEFINITION_OF_DONE.md), [`EXECUTION_WAVES.md`](EXECUTION_WAVES.md),
> [`DEPENDENCY_MAP.md`](DEPENDENCY_MAP.md).

## Regeln

- **Ready** = freigegeben; nur solche Aufgaben darf ein Mitwirkender (der Freund) übernehmen.
- Beim Start: Status → **In Progress**, Branch + GitHub-Issue eintragen.
- Nach PR-Eröffnung: Status → **In Review** (PR-Nummer eintragen).
- Erst nach Merge + grünen Gates: Status → **Done**.
- Jede PR pflegt bei Bedarf `BACKLOG.md`, `CHANGELOG.md` und Doku.
- **Keine personenbezogenen Daten** in Backlog/Issues/PRs.
- Erlaubte Status: `Backlog` · `Ready` · `In Progress` · `In Review` · `Blocked` · `Done` · `Deferred`.
- Prioritäten: `P0` (kritisch/Blocker) … `P3` (nice-to-have).
- Bearbeiter-Ziel: `owner` (der Owner), `friend` (Write-Collaborator), `either`, `ai-assisted`.

## Feld-Schema (pro Eintrag)

`ID · Titel · Beschreibung · Priorität · Status · Kategorie · Bearbeiter-Ziel · Owner ·
GitHub-Issue · Branch · Abhängigkeiten · Akzeptanzkriterien · Tests · Security ·
Doku-Bedarf · Definition of Done · PR · Ziel-Release`

---

## Übersicht

| ID | Titel | Prio | Status | Kategorie | Ziel-Bearb. | Issue | Release |
|----|-------|------|--------|-----------|-------------|-------|---------|
| STM-INT-001 | v0.41-Merge nachziehen (AI-Help/Export/Dashboard reconcilen) | P1 | Done | infrastructure | owner | [#5](https://github.com/Randspringer90/SchachTurnierManager/issues/5) (geschlossen; PR [#6](https://github.com/Randspringer90/SchachTurnierManager/pull/6), Merge `ecfb473`) | v1.0.0 |
| STM-SEC-001 | Prompt-Injection-Verteidigung härten | P1 | In Progress | security | owner | via [#7](https://github.com/Randspringer90/SchachTurnierManager/issues/7) | v1.0.0 |
| STM-SEC-002 | Dependency-/Lizenz-/Supply-Chain-Prüfung | P1 | Backlog | security | either | – | v1.0.0 |
| STM-SEC-003 | Datenschutz / PII-Minimierung | P1 | Backlog | security | owner | – | v1.0.0 |
| STM-SEC-004 | Public Snapshot & Git-History-Abnahme | P0 | Blocked | security | owner | – | v1.0.0 |
| STM-SEC-005 | Sichere Pull-Request-Prüfung und kontrollierte Übernahme | P1 | Done | security | owner | [#11](https://github.com/Randspringer90/SchachTurnierManager/issues/11) (PR [#12](https://github.com/Randspringer90/SchachTurnierManager/pull/12)) | v1.0.0 |
| STM-AI-001 | Agenten- & Skill-Zielstandard + Migration | P2 | Done | ai | owner | [#7](https://github.com/Randspringer90/SchachTurnierManager/issues/7) (PR [#8](https://github.com/Randspringer90/SchachTurnierManager/pull/8)) | v1.0.0 |
| STM-AI-001b | Restliche Legacy-Skills nach SKILL.md migrieren + geplante Skills autorieren | P3 | Backlog | ai | owner | – | v1.0.0 |
| STM-AI-002 | Wissensmanagement repo-intern konsolidieren | P2 | Done | ai | owner | [#18](https://github.com/Randspringer90/SchachTurnierManager/issues/18), [PR #19](https://github.com/Randspringer90/SchachTurnierManager/pull/19), Merge `98648e7` | v1.0.0 |
| STM-AI-003 | Modellrouting finalisieren (Qualitätsklassen + MODEL_ROUTING.md) | P2 | Done | ai | owner | [#15](https://github.com/Randspringer90/SchachTurnierManager/issues/15) (PR [#17](https://github.com/Randspringer90/SchachTurnierManager/pull/17), Merge `dfa7520`) | v1.0.0 |
| STM-AI-004 | Nightly-/Resume-Unterbau | P1 | Done | ai | owner | [#20](https://github.com/Randspringer90/SchachTurnierManager/issues/20), [PR #21](https://github.com/Randspringer90/SchachTurnierManager/pull/21), Merge `a6df385` | v1.0.0 |
| STM-AI-005 | Providerübergreifende Promptzerlegung und Routed Execution | P1 | Done | ai | owner | [#26](https://github.com/Randspringer90/SchachTurnierManager/issues/26) (PR [#29](https://github.com/Randspringer90/SchachTurnierManager/pull/29), Merge `8305814`) | v1.0.0 |
| STM-AI-006 | Aktive zentrale Nightly-Orchestrierung | P1 | Done | ai | owner | [#27](https://github.com/Randspringer90/SchachTurnierManager/issues/27) (PR [#32](https://github.com/Randspringer90/SchachTurnierManager/pull/32), Merge `c1a2d4c`; zentrale Registrierung ACTIVE 2026-07-16) | v1.0.0 |
| STM-INFRA-001 | Skriptstruktur-Migration | P2 | Backlog | infrastructure | either | – | v1.0.0 |
| STM-INFRA-002 | Performance- & Belastungstests | P2 | Backlog | infrastructure | either | – | v1.0.0 |
| STM-INFRA-003 | Codex-Contributor-Starterpaket (Doku/Vorlage/Generator/Tests) | P3 | Done | infrastructure | owner | – | development |
| STM-FACH-001 | Kampflose Partien in Paarung & Wertung | P1 | Done | pairing | friend | [#1](https://github.com/Randspringer90/SchachTurnierManager/issues/1) (Original-PR [#10](https://github.com/Randspringer90/SchachTurnierManager/pull/10), sichere Adoption [#14](https://github.com/Randspringer90/SchachTurnierManager/pull/14), Merge `31a3a06`) | v1.0.0 |
| STM-FACH-002 | Vollständigeres FIDE-Dutch-Schweizer-System | P1 | In Progress | pairing | friend | [#22](https://github.com/Randspringer90/SchachTurnierManager/issues/22), Branch `feature/STM-FACH-002-fide-dutch` | v1.0.0 |
| STM-FACH-003 | Große Schweizer Felder > 20 Spieler | P1 | Blocked | pairing | either | [#23](https://github.com/Randspringer90/SchachTurnierManager/issues/23) | v1.0.0 |
| STM-TB-001 | Buchholz / Buchholz-Cut / Sonneborn-Berger – Golden-Tests | P2 | Done | tiebreaks | friend | [#2](https://github.com/Randspringer90/SchachTurnierManager/issues/2) (Original-PR [#9](https://github.com/Randspringer90/SchachTurnierManager/pull/9), sichere Adoption [#13](https://github.com/Randspringer90/SchachTurnierManager/pull/13), Merge `2e0fdd7`) | v1.0.0 |
| STM-IE-001 | Excel-/TRF-Export (FIDE-Turnierbericht) | P1 | In Review | import-export | friend | [#3](https://github.com/Randspringer90/SchachTurnierManager/issues/3) (PR [#30](https://github.com/Randspringer90/SchachTurnierManager/pull/30), Static-Review: OWNER_REVIEW_REQUIRED) | v1.0.0 |
| STM-IE-002 | Swiss-Manager / Chess-Results-Kompatibilität | P2 | Blocked | import-export | either | [#24](https://github.com/Randspringer90/SchachTurnierManager/issues/24) | v1.0.0 |
| STM-IE-003 | DSB / DeWIS-Anbindung | P2 | Backlog | player-data | owner | – | post-1.0 |
| STM-IE-004 | FIDE-Namenssuche | P2 | Backlog | player-data | either | [#25](https://github.com/Randspringer90/SchachTurnierManager/issues/25) | v1.0.0 |
| STM-UX-001 | i18n vervollständigen | P2 | Backlog | ui | either | – | v1.0.0 |
| STM-UX-002 | PWA / Offline / Sync-Konflikte | P2 | Backlog | pwa | owner | – | v1.0.0 |
| STM-UX-003 | Backup/Restore-UX | P2 | Backlog | ui | either | – | v1.0.0 |
| STM-UX-004 | BYOK-KI-Provider | P3 | Backlog | ai | owner | – | post-1.0 |
| STM-REL-001 | Setup-EXE (Klick-Installation) | P1 | Backlog | release | owner | – | v1.0.0 |
| STM-REL-002 | Signierung & Update-Konzept | P1 | Backlog | release | owner | – | v1.0.0 |
| STM-REL-003 | Echter Kollegen-PC-Test | P1 | Backlog | release | owner | – | v1.0.0 |
| STM-REL-004 | Release Candidate v1.0.0 | P0 | Blocked | release | owner | – | v1.0.0 |
| STM-DOC-001 | Contributor-Doku verifizieren & abrunden | P3 | In Review | documentation | friend | [#4](https://github.com/Randspringer90/SchachTurnierManager/issues/4) (PR [#31](https://github.com/Randspringer90/SchachTurnierManager/pull/31), Static-Review: ADAPTATION_REQUIRED) | v1.0.0 |

---

## Ready-Aufgaben (voll spezifiziert)

### STM-FACH-001 · Kampflose Partien in Paarung & Wertung
- **Beschreibung:** Nicht gespielte Partien (kampfloser Sieg/Niederlage, Freilos/Bye, Rückzug)
  müssen in Paarung und Wertung regelkonform behandelt werden (Punkte, aber i. d. R. keine
  Tie-Break-Beiträge aus ungespielten Runden).
- **Priorität:** P1 · **Status:** Done · **Kategorie:** pairing · **Ziel-Bearbeiter:** friend · **Owner:** der Owner
- **GitHub-Issue:** [#1](https://github.com/Randspringer90/SchachTurnierManager/issues/1) · **Branch:** `feature/STM-FACH-001-kampflose-partien`
- **Abhängigkeiten:** keine (baut auf bestehender Wertungslogik/`TournamentService`).
- **Akzeptanzkriterien:**
  - Freilos/Bye vergibt korrekte Punkte, erzeugt keine Gegner-Paarung.
  - Kampfloser Sieg/Niederlage und Rückzug korrekt in Tabelle.
  - Tie-Breaks (Buchholz/SB) rechnen ungespielte Runden nach der gewählten Regel
    (siehe `docs/TIEBREAK_UNPLAYED_ROUNDS.md`).
- **Tests:** Golden-/Unit-Tests für Freilos, Rückzug, kampflos; Regressionsschutz bestehender Wertungen.
- **Security:** keine (keine externen Daten, keine Secrets).
- **Doku-Bedarf:** `CHANGELOG.md`, ggf. `docs/TIEBREAK_UNPLAYED_ROUNDS.md` ergänzen.
- **Definition of Done:** siehe [`DEFINITION_OF_DONE.md`](DEFINITION_OF_DONE.md) + alle Gates grün.
- **PR:** Original [#10](https://github.com/Randspringer90/SchachTurnierManager/pull/10) · **Sichere Adoption:** [#14](https://github.com/Randspringer90/SchachTurnierManager/pull/14), Merge `31a3a06` · **Ziel-Release:** v1.0.0

### STM-TB-001 · Buchholz / Buchholz-Cut / Sonneborn-Berger – Golden-Tests _(empfohlene Erstaufgabe)_
- **Beschreibung:** Golden-Test-Abdeckung der bestehenden Tie-Break-Berechnungen erweitern und
  gegen dokumentierte Beispielturniere absichern; keine Verhaltensänderung, nur Absicherung/Doku.
- **Priorität:** P2 · **Status:** Done · **Kategorie:** tiebreaks · **Ziel-Bearbeiter:** friend · **Owner:** der Owner
- **GitHub-Issue:** [#2](https://github.com/Randspringer90/SchachTurnierManager/issues/2) · **Branch:** `feature/STM-TB-001-tiebreak-golden-tests`
- **Abhängigkeiten:** keine.
- **Akzeptanzkriterien:**
  - Deterministische Golden-Tests für Buchholz, Buchholz-Cut-1 und Sonneborn-Berger an ≥ 2 Beispielturnieren.
  - Bestehende Tie-Break-Ergebnisse bleiben unverändert (reine Absicherung).
- **Tests:** neue Golden-/Unit-Tests im `Domain.Tests`/`GoldenTests`-Projekt.
- **Security:** keine.
- **Doku-Bedarf:** kurze Notiz in `CHANGELOG.md`; ggf. Beispieldaten dokumentieren.
- **Definition of Done:** DoD + Gates grün. **Guter Einstieg**: additive Tests, kein Risiko an Kernlogik.
- **PR:** Original [#9](https://github.com/Randspringer90/SchachTurnierManager/pull/9) · **Sichere Adoption:** [#13](https://github.com/Randspringer90/SchachTurnierManager/pull/13), Squash-Merge `2e0fdd7f12b4dcc6d25b2103b693356c051ee53e` · **Ziel-Release:** v1.0.0

### STM-IE-001 · Excel-/TRF-Export (FIDE-Turnierbericht)
- **Beschreibung:** Read-only-Export der Turnierdaten ins TRF(x)-Format (FIDE) und/oder Excel,
  ohne Änderung der Turnierlogik.
- **Priorität:** P1 · **Status:** Ready · **Kategorie:** import-export · **Ziel-Bearbeiter:** friend · **Owner:** der Owner
- **GitHub-Issue:** [#3](https://github.com/Randspringer90/SchachTurnierManager/issues/3) · **Branch:** `feature/STM-IE-001-trf-export`
- **Abhängigkeiten:** `TournamentExportFormatter` (bereits vorhanden).
- **Akzeptanzkriterien:**
  - Gültige TRF(x)-Datei für ein abgeschlossenes Beispielturnier.
  - Deterministische Ausgabe, keine PII über die Turnierteilnahme hinaus.
- **Tests:** Formatter-Unit-Tests inkl. Golden-Datei.
- **Security:** Ausgabe darf keine lokalen Pfade/Secrets enthalten.
- **Doku-Bedarf:** `docs/IMPORT_EXPORT_ROADMAP.md`, `CHANGELOG.md`.
- **Definition of Done:** DoD + Gates grün.
- **PR:** – · **Ziel-Release:** v1.0.0

### STM-DOC-001 · Contributor-Doku verifizieren & abrunden
- **Beschreibung:** Onboarding-/Contributing-Doku praktisch nachvollziehen und Lücken/Fehler
  korrigieren (Befehle, Versionsangaben, Links).
- **Priorität:** P3 · **Status:** Ready · **Kategorie:** documentation · **Ziel-Bearbeiter:** friend · **Owner:** der Owner
- **GitHub-Issue:** [#4](https://github.com/Randspringer90/SchachTurnierManager/issues/4) · **Branch:** `docs/STM-DOC-001-contributor-review`
- **Abhängigkeiten:** keine.
- **Akzeptanzkriterien:** Alle in `CONTRIBUTING.md`/Onboarding genannten Befehle funktionieren
  auf einem frischen Klon; tote Links behoben.
- **Tests:** Markdown-Linkcheck / manuelle Verifikation dokumentiert im PR.
- **Security:** keine.
- **Doku-Bedarf:** die betroffenen Doku-Dateien.
- **Definition of Done:** DoD + Gates grün.
- **PR:** – · **Ziel-Release:** v1.0.0

### STM-FACH-002 · Vollständigeres FIDE-Dutch-Schweizer-System
- **Beschreibung:** Ausbau des Basis-Schweizer-Systems zum vollständigeren FIDE-Dutch-System
  (Score Groups, Floater, Farbpräferenzen, Wiederholungsschutz, Bye-Regeln, deterministische
  Entscheidungsreihenfolge, Audit-Trail). Vollständige Spezifikation im Issue.
- **Priorität:** P1 · **Status:** In Progress · **Kategorie:** pairing · **Ziel-Bearbeiter:** friend · **Owner:** der Owner
- **GitHub-Issue:** [#22](https://github.com/Randspringer90/SchachTurnierManager/issues/22) · **Branch:** `feature/STM-FACH-002-fide-dutch`
- **Regelgrundlage:** `docs/FIDE_DUTCH_REFERENCE.md` (Fassung gültig ab 01.02.2026, abgerufen 2026-07-16).
  **Achtung:** C.04.3 wurde zum 01.02.2026 neu gefasst (Artikel 1–5, Kriterien [C1]–[C21]); die
  2017er Struktur (A–E, C.5–C.19, PSD) gilt nicht mehr. Die Artikelnummern im Issue
  („C.04.1.b", „C.04.1.c-d") stammen aus der alten Fassung – Inhalt korrekt, Fundstellen veraltet.
- **Architekturentscheidung:** FIDE-Dutch als eigene Strategie hinter `ISwissPairingStrategy`;
  die bestehende Optimal-V2-Engine bleibt unverändert und **Default** (vgl.
  `docs/ai/prompts/codex-roadmap/RUN-12-fide-dutch.md`, `docs/SWISS_PAIRING_ENGINE.md`).
- **Abgegrenzt:** Setzlisten-Vergabe nach C.04.2 Art. 2.2 (Startrang = derzeit Eingabereihenfolge)
  ist **nicht** Teil dieses Tickets; die Strategie warnt nur im Audit. Siehe Folge-Ticket
  STM-FACH-004.
- **Abhängigkeiten:** STM-FACH-001 (Done; Forfeit-/Bye-Verhalten darf nicht regressieren). Blockiert STM-FACH-003.
- **Akzeptanzkriterien:** siehe Issue #22 (Golden-Turniere zuerst, Property-Tests für absolute
  Kriterien, Determinismus, Audit-Trail, FIDE-C.04-Abgleich mit Artikelnummern).
- **Tests:** Golden-/Property-/Regressionstests; Tests zuerst (fachliche Algorithmusänderung).
- **Security:** keine externen Daten; nur synthetische Fixtures.
- **Doku-Bedarf:** `docs/AUDIT_JOURNAL.md`, `CHANGELOG.md`.
- **Definition of Done:** DoD + Gates grün; **Final-Review durch unabhängigen Owner-Prozess mit
  stärkstem Review-Profil (fachlich kritisch, kein Auto-Merge).**
- **PR:** – · **Ziel-Release:** v1.0.0

---

## Weitere aktive/geplante Einträge (Kurzform)

Nicht-Ready-Einträge tragen dieselben Felder; Details werden beim Übergang nach `Ready`
ausgeschrieben. Auszug der wichtigsten:

- **STM-INT-001** – *Done* (Issue [#5](https://github.com/Randspringer90/SchachTurnierManager/issues/5) geschlossen,
  PR [#6](https://github.com/Randspringer90/SchachTurnierManager/pull/6), Branch `refactor/STM-INT-001-reconcile-v041`). Reconcile des in `development` gemergten v0.41-Stands.
  **Entscheidung:** kanonische lokale KI-Hilfe = Frontend-Wissensbasis (`localKnowledgeBase.json`,
  offline/providerlos); das tote, unreferenzierte Backend-Modul `Application.Ai` (+ isolierter Test)
  wurde entfernt. Export (`TournamentExportFormatter`) und Dashboard/Health sind bereits kanonisch.
  Details: `docs/architecture/V041_RECONCILIATION.md`. Quelle des lokalen Stands verlustfrei im
  Branch `backup/pre-development-bootstrap-2026-07-12`.
  **Offene Folgearbeit (STM-INT-001b, Backlog):** ob die lokale `.env.example` (AI-Config-Template,
  leere Keys) wieder aufgenommen wird – erfordert **Owner-reviewte** Anpassung von
  `scripts/Test-GitCommitSafety.ps1` (blockt `.env*`, obwohl `.gitignore` `.env.example` whitelistet);
  ein echter BYOK-Provider gehört zu STM-UX-004 (frisch in Infrastructure). *Owner:* der Owner.
- **STM-SEC-001** – Prompt-Injection-Verteidigung (Guards/Gates, untrusted-content-Handling in
  KI-Läufen, Tests). *Abhängig von* Agentenstruktur STM-AI-001.
- **STM-SEC-005** – *Done* (Issue [#11](https://github.com/Randspringer90/SchachTurnierManager/issues/11),
  PR [#12](https://github.com/Randspringer90/SchachTurnierManager/pull/12), Squash-Merge
  `ba55061526311931541a21cd0ed22107066a5036`). Statische, read-only Prüfung fremder
  Pull Requests vor jeder Ausführung und kontrollierte Übernahme auf einem vom aktuellen
  `origin/development` gestarteten Owner-Integrationsbranch. *Priorität:* P1 · *Kategorie:*
  security · *Ziel-Bearbeiter/Owner:* owner · *Abhängigkeiten:* STM-AI-001 · *Ziel-Release:*
  v1.0.0.
  **Akzeptanzkriterien:** PR-Payload bleibt T4 und wird vor Ausführung auf Prompt Injection,
  Dependency-Deltas, Binär-/Archiv-/Symlink-/Submodule-, Workflow-, Build-, Installer- und
  Schadcode-Risiken geprüft; neue Dependencies benötigen nachvollziehbare Begründung;
  vorhandene `development`-Logik wird vor Übernahme verglichen; sichere Teile dürfen selektiv
  und attributiert angepasst werden; Feedback ist redigiert; kein Fremd-PR wird direkt nach
  `development` gemergt; `UNVERIFIED` und unvollständige Evidenz verlangen Owner-Review.
  **Tests:** `Test-PullRequestReviewReadiness.ps1`, Pester-Contract, Dependency-Delta-Contract,
  Agent-/Instruction-/Prompt-/Repository-Gates und vollständiges ReleaseGate.
  **Security:** initial static-only, kein Restore/Build/Test/Install, keine Secrets, kein Netzwerk
  durch PR-Code, keine rohe Payloadpersistenz, SHA-/Policy-Bindung.
  **Doku/DoD:** Trust Boundaries, Review-/Adoption-Workflow, Templates, Agent/Skills und CI-Gate;
  alle Gates und Owner-Integrations-PR grün; Rulesets online verifiziert. *PR:* [#12](https://github.com/Randspringer90/SchachTurnierManager/pull/12).
- **STM-SEC-004** – Public Snapshot & History-Abnahme: alte Git-Historie ist der offene
  Public-Blocker (`scripts/New-OpenSourceSnapshot.ps1`). **Konkreter Befund (2026-07-12):** der
  gepushte Merge-Commit `5d64d12` (auf `origin/development`, public) enthielt in
  `TournamentServiceTests.cs` personenbezogene Test-Fixtures (Owner-Name/FIDE-ID) sowie eine
  `.env.example`. Beide sind in `development`-HEAD **vorwärts bereinigt**, verbleiben aber in der
  **Historie** dieses public Repos. Bereinigung erfordert eine Owner-Entscheidung (History-Purge /
  Clean-Snapshot-Neustart) – **kein Force-Push in diesem Lauf**. *Blocked* bis Owner-Entscheidung.
- **STM-REL-004** – Release Candidate v1.0.0: *Blocked* bis P0/P1-Aufgaben erledigt.
- **STM-AI-005** – Providerübergreifende Promptzerlegung und Routed Execution: Masterprompts
  an Fabel/Sol werden in einen validierten Taskgraph zerlegt; geeignete Teilaufgaben werden
  tatsächlich an kleinere Profile delegiert (Adapter je Provider), Fabel/Sol bleiben
  Orchestrator und Final-Integrator. Kritische Kategorien werden nie automatisch
  herabgestuft; kein stiller Modellwechsel; Checkpoint/Resume bei Limits; Child-Output
  bleibt T3-Daten. *Priorität:* P1 · *Kategorie:* ai · *Owner:* owner · *Ziel-Release:* v1.0.0.
- **STM-AI-006** – Aktive zentrale Nightly-Orchestrierung: der plan-only Unterbau aus
  STM-AI-004 (`READY_FOR_ACTIVATION`) wird um eine reale projektlokale Ausführungsebene
  ergänzt und das Projekt nach Owner-Freigabe (2026-07-16) einmalig im **vorhandenen
  zentralen** Nightly-Mechanismus der Workstation registriert (keine zweite Scheduled Task,
  kein main-Merge, kein Release, kein History-Rewrite, kein Secretzugriff; Contributor-/
  Marcel-Aufgaben sind ausgeschlossen). *Priorität:* P1 · *Kategorie:* ai · *Owner:* owner ·
  *Ziel-Release:* v1.0.0.

Die vollständige Liste steht in der Übersichtstabelle oben; jeder Eintrag wird beim
Aktivieren nach dem Feld-Schema ausgeschrieben.
