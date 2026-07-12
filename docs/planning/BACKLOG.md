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
| STM-INT-001 | v0.41-Merge nachziehen (AI-Help/Export/Dashboard reconcilen) | P1 | Backlog | infrastructure | owner | – | v1.0.0 |
| STM-SEC-001 | Prompt-Injection-Verteidigung härten | P1 | Backlog | security | owner | – | v1.0.0 |
| STM-SEC-002 | Dependency-/Lizenz-/Supply-Chain-Prüfung | P1 | Backlog | security | either | – | v1.0.0 |
| STM-SEC-003 | Datenschutz / PII-Minimierung | P1 | Backlog | security | owner | – | v1.0.0 |
| STM-SEC-004 | Public Snapshot & Git-History-Abnahme | P0 | Blocked | security | owner | – | v1.0.0 |
| STM-AI-001 | Agenten- & Skill-Zielstandard + Migration | P2 | Backlog | ai | owner | – | v1.0.0 |
| STM-AI-002 | Wissensmanagement repo-intern konsolidieren | P2 | Backlog | ai | owner | – | v1.0.0 |
| STM-AI-003 | Modellrouting finalisieren (config/model-routing.json) | P2 | Backlog | ai | owner | – | v1.0.0 |
| STM-AI-004 | Nightly-/Resume-Unterbau | P3 | Backlog | ai | owner | – | post-1.0 |
| STM-INFRA-001 | Skriptstruktur-Migration | P2 | Backlog | infrastructure | either | – | v1.0.0 |
| STM-INFRA-002 | Performance- & Belastungstests | P2 | Backlog | infrastructure | either | – | v1.0.0 |
| STM-FACH-001 | Kampflose Partien in Paarung & Wertung | P1 | **Ready** | pairing | friend | – | v1.0.0 |
| STM-FACH-002 | Vollständigeres FIDE-Dutch-Schweizer-System | P1 | Backlog | pairing | owner | – | v1.0.0 |
| STM-FACH-003 | Große Schweizer Felder > 20 Spieler | P1 | Backlog | pairing | either | – | v1.0.0 |
| STM-TB-001 | Buchholz / Buchholz-Cut / Sonneborn-Berger – Golden-Tests | P2 | **Ready** | tiebreaks | friend | – | v1.0.0 |
| STM-IE-001 | Excel-/TRF-Export (FIDE-Turnierbericht) | P1 | **Ready** | import-export | friend | – | v1.0.0 |
| STM-IE-002 | Swiss-Manager / Chess-Results-Kompatibilität | P2 | Backlog | import-export | either | – | v1.0.0 |
| STM-IE-003 | DSB / DeWIS-Anbindung | P2 | Backlog | player-data | owner | – | post-1.0 |
| STM-IE-004 | FIDE-Namenssuche | P2 | Backlog | player-data | either | – | v1.0.0 |
| STM-UX-001 | i18n vervollständigen | P2 | Backlog | ui | either | – | v1.0.0 |
| STM-UX-002 | PWA / Offline / Sync-Konflikte | P2 | Backlog | pwa | owner | – | v1.0.0 |
| STM-UX-003 | Backup/Restore-UX | P2 | Backlog | ui | either | – | v1.0.0 |
| STM-UX-004 | BYOK-KI-Provider | P3 | Backlog | ai | owner | – | post-1.0 |
| STM-REL-001 | Setup-EXE (Klick-Installation) | P1 | Backlog | release | owner | – | v1.0.0 |
| STM-REL-002 | Signierung & Update-Konzept | P1 | Backlog | release | owner | – | v1.0.0 |
| STM-REL-003 | Echter Kollegen-PC-Test | P1 | Backlog | release | owner | – | v1.0.0 |
| STM-REL-004 | Release Candidate v1.0.0 | P0 | Blocked | release | owner | – | v1.0.0 |
| STM-DOC-001 | Contributor-Doku verifizieren & abrunden | P3 | **Ready** | documentation | friend | – | v1.0.0 |

---

## Ready-Aufgaben (voll spezifiziert)

### STM-FACH-001 · Kampflose Partien in Paarung & Wertung
- **Beschreibung:** Nicht gespielte Partien (kampfloser Sieg/Niederlage, Freilos/Bye, Rückzug)
  müssen in Paarung und Wertung regelkonform behandelt werden (Punkte, aber i. d. R. keine
  Tie-Break-Beiträge aus ungespielten Runden).
- **Priorität:** P1 · **Status:** Ready · **Kategorie:** pairing · **Ziel-Bearbeiter:** friend · **Owner:** der Owner
- **GitHub-Issue:** _(wird in Phase 6 eingetragen)_ · **Branch:** `feature/STM-FACH-001-kampflose-partien`
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
- **PR:** – · **Ziel-Release:** v1.0.0

### STM-TB-001 · Buchholz / Buchholz-Cut / Sonneborn-Berger – Golden-Tests _(empfohlene Erstaufgabe)_
- **Beschreibung:** Golden-Test-Abdeckung der bestehenden Tie-Break-Berechnungen erweitern und
  gegen dokumentierte Beispielturniere absichern; keine Verhaltensänderung, nur Absicherung/Doku.
- **Priorität:** P2 · **Status:** Ready · **Kategorie:** tiebreaks · **Ziel-Bearbeiter:** friend · **Owner:** der Owner
- **GitHub-Issue:** _(Phase 6)_ · **Branch:** `feature/STM-TB-001-tiebreak-golden-tests`
- **Abhängigkeiten:** keine.
- **Akzeptanzkriterien:**
  - Deterministische Golden-Tests für Buchholz, Buchholz-Cut-1 und Sonneborn-Berger an ≥ 2 Beispielturnieren.
  - Bestehende Tie-Break-Ergebnisse bleiben unverändert (reine Absicherung).
- **Tests:** neue Golden-/Unit-Tests im `Domain.Tests`/`GoldenTests`-Projekt.
- **Security:** keine.
- **Doku-Bedarf:** kurze Notiz in `CHANGELOG.md`; ggf. Beispieldaten dokumentieren.
- **Definition of Done:** DoD + Gates grün. **Guter Einstieg**: additive Tests, kein Risiko an Kernlogik.
- **PR:** – · **Ziel-Release:** v1.0.0

### STM-IE-001 · Excel-/TRF-Export (FIDE-Turnierbericht)
- **Beschreibung:** Read-only-Export der Turnierdaten ins TRF(x)-Format (FIDE) und/oder Excel,
  ohne Änderung der Turnierlogik.
- **Priorität:** P1 · **Status:** Ready · **Kategorie:** import-export · **Ziel-Bearbeiter:** friend · **Owner:** der Owner
- **GitHub-Issue:** _(Phase 6)_ · **Branch:** `feature/STM-IE-001-trf-export`
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
- **GitHub-Issue:** _(Phase 6)_ · **Branch:** `docs/STM-DOC-001-contributor-review`
- **Abhängigkeiten:** keine.
- **Akzeptanzkriterien:** Alle in `CONTRIBUTING.md`/Onboarding genannten Befehle funktionieren
  auf einem frischen Klon; tote Links behoben.
- **Tests:** Markdown-Linkcheck / manuelle Verifikation dokumentiert im PR.
- **Security:** keine.
- **Doku-Bedarf:** die betroffenen Doku-Dateien.
- **Definition of Done:** DoD + Gates grün.
- **PR:** – · **Ziel-Release:** v1.0.0

---

## Weitere aktive/geplante Einträge (Kurzform)

Nicht-Ready-Einträge tragen dieselben Felder; Details werden beim Übergang nach `Ready`
ausgeschrieben. Auszug der wichtigsten:

- **STM-INT-001** – Reconcile des in `development` gemergten lokalen v0.41-Stands (lokales
  `Application.Ai`-Provider-Modul vs. origins Chat-Hilfe 0.47; Operator-Dashboard-/Export-Doppelungen).
  Quelle des lokalen Stands verlustfrei im Branch `backup/pre-development-bootstrap-2026-07-12`.
  Enthält auch die Frage, ob die lokale `.env.example` (AI-Help-Config-Template, leere Keys)
  wieder aufgenommen wird – das erfordert eine **Owner-reviewte** Anpassung von
  `scripts/Test-GitCommitSafety.ps1` (blockt aktuell jedes `.env*`, obwohl `.gitignore`
  `.env.example` whitelistet). *Security:* betrifft Security-Skript. *Abhängigkeiten:* keine. *Owner:* der Owner.
- **STM-SEC-001** – Prompt-Injection-Verteidigung (Guards/Gates, untrusted-content-Handling in
  KI-Läufen, Tests). *Abhängig von* Agentenstruktur STM-AI-001.
- **STM-SEC-004** – Public Snapshot & History-Abnahme: alte Git-Historie ist der offene
  Public-Blocker (`scripts/New-OpenSourceSnapshot.ps1`). **Konkreter Befund (2026-07-12):** der
  gepushte Merge-Commit `5d64d12` (auf `origin/development`, public) enthielt in
  `TournamentServiceTests.cs` personenbezogene Test-Fixtures (Owner-Name/FIDE-ID) sowie eine
  `.env.example`. Beide sind in `development`-HEAD **vorwärts bereinigt**, verbleiben aber in der
  **Historie** dieses public Repos. Bereinigung erfordert eine Owner-Entscheidung (History-Purge /
  Clean-Snapshot-Neustart) – **kein Force-Push in diesem Lauf**. *Blocked* bis Owner-Entscheidung.
- **STM-REL-004** – Release Candidate v1.0.0: *Blocked* bis P0/P1-Aufgaben erledigt.

Die vollständige Liste steht in der Übersichtstabelle oben; jeder Eintrag wird beim
Aktivieren nach dem Feld-Schema ausgeschrieben.
