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
| STM-INFRA-004 | Safe-PR-Skripte gegen offenes stdin härten (`$input`-Kollision) | P2 | Done | infrastructure | owner | [#38](https://github.com/Randspringer90/SchachTurnierManager/issues/38) (PR [#39](https://github.com/Randspringer90/SchachTurnierManager/pull/39), Merge `4681e01`) | v1.0.0 |
| STM-INFRA-005 | Hart verdrahtetes `D:\Temp` in 8 Skripten auf `%TEMP%`-Fallback umstellen | P3 | Backlog | infrastructure | either | – | v1.0.0 |
| STM-INFRA-006 | `Test-RoutedExecutionReadiness.ps1` flaky – Wurzel: nichtdeterministischer Graph-Hash | P2 | In Review | infrastructure | owner | [#46](https://github.com/Randspringer90/SchachTurnierManager/issues/46) (PR läuft; 20/20 lokale Läufe grün) | v1.0.0 |
| STM-INFRA-007 | Branchnamen-Policy: sanktionierter Pfad für Owner-Pakete ohne Contributor-PR | P3 | Backlog | infrastructure | owner | – | v1.0.0 |
| STM-FACH-001 | Kampflose Partien in Paarung & Wertung | P1 | Done | pairing | friend | [#1](https://github.com/Randspringer90/SchachTurnierManager/issues/1) (Original-PR [#10](https://github.com/Randspringer90/SchachTurnierManager/pull/10), sichere Adoption [#14](https://github.com/Randspringer90/SchachTurnierManager/pull/14), Merge `31a3a06`) | v1.0.0 |
| STM-FACH-002 | Vollständigeres FIDE-Dutch-Schweizer-System | P1 | **Ready** | pairing | friend | [#22](https://github.com/Randspringer90/SchachTurnierManager/issues/22) | v1.0.0 |
| STM-FACH-003 | Große Schweizer Felder > 20 Spieler | P1 | Blocked | pairing | either | [#23](https://github.com/Randspringer90/SchachTurnierManager/issues/23) | v1.0.0 |
| STM-TB-001 | Buchholz / Buchholz-Cut / Sonneborn-Berger – Golden-Tests | P2 | Done | tiebreaks | friend | [#2](https://github.com/Randspringer90/SchachTurnierManager/issues/2) (Original-PR [#9](https://github.com/Randspringer90/SchachTurnierManager/pull/9), sichere Adoption [#13](https://github.com/Randspringer90/SchachTurnierManager/pull/13), Merge `2e0fdd7`) | v1.0.0 |
| STM-IE-001 | Excel-/TRF-Export (FIDE-Turnierbericht) | P1 | Done | import-export | friend | [#3](https://github.com/Randspringer90/SchachTurnierManager/issues/3) (Original-PR [#30](https://github.com/Randspringer90/SchachTurnierManager/pull/30), sichere Adoption [#35](https://github.com/Randspringer90/SchachTurnierManager/pull/35), Merge `6a2d021`) | v1.0.0 |
| STM-IE-002 | Swiss-Manager / Chess-Results-Kompatibilität | P2 | **Ready** | import-export | either | [#24](https://github.com/Randspringer90/SchachTurnierManager/issues/24) (entsperrt: STM-IE-001 ist Done) | v1.0.0 |
| STM-IE-003 | DSB / DeWIS-Anbindung | P2 | Backlog | player-data | owner | – | post-1.0 |
| STM-IE-004 | FIDE-Namenssuche | P2 | Backlog | player-data | either | [#25](https://github.com/Randspringer90/SchachTurnierManager/issues/25) | v1.0.0 |
| STM-UX-001 | i18n vervollständigen | P2 | Backlog | ui | either | – | v1.0.0 |
| STM-UX-002 | PWA / Offline / Sync-Konflikte | P2 | Backlog | pwa | owner | – | v1.0.0 |
| STM-UX-003 | Backup/Restore-UX | P2 | Backlog | ui | either | – | v1.0.0 |
| STM-UX-004 | BYOK-KI-Provider | P3 | Backlog | ai | owner | – | post-1.0 |
| STM-REL-001 | Setup-EXE (Klick-Installation) | P1 | Done | release | friend | Original-PR [#33](https://github.com/Randspringer90/SchachTurnierManager/pull/33) (Marcel), sichere Adoption [#34](https://github.com/Randspringer90/SchachTurnierManager/pull/34), Merge `b263925` | v1.0.0 |
| STM-REL-002 | Signierung & Update-Konzept | P1 | Backlog | release | owner | – | v1.0.0 |
| STM-REL-003 | Echter Kollegen-PC-Test | P1 | Backlog | release | owner | – | v1.0.0 |
| STM-REL-004 | Release Candidate v1.0.0 | P0 | Blocked | release | owner | – | v1.0.0 |
| STM-MOB-001 | Android-Begleit-App und installierbare APK | P2 | Blocked | mobile | either | [#43](https://github.com/Randspringer90/SchachTurnierManager/issues/43) (blockiert: Android SDK fehlt auf der Workstation) | post-1.0 |
| STM-MOB-002 | F-Droid-Readiness | P3 | Blocked | mobile | owner | – (blockiert: STM-MOB-001 + Lizenzentscheidung STM-SEC-004) | post-1.0 |
| STM-MOB-003 | Mobile Paarungsansicht | P2 | Backlog | mobile | friend | – (nach STM-MOB-001) | post-1.0 |
| STM-MOB-004 | Mobile Ergebniseingabe (Bestätigung, Undo, Audit) | P2 | Backlog | mobile | friend | – (nach STM-MOB-003) | post-1.0 |
| STM-MOB-005 | QR-Code-Verbindung zum Turnierrechner | P3 | Backlog | mobile | friend | – (keine Secrets im QR, Ablaufzeit) | post-1.0 |
| STM-MOB-006 | Zuschaueransicht (read-only) | P3 | Backlog | mobile | friend | – | post-1.0 |
| STM-MOB-007 | Offline-Ergebniswarteschlange mit Konfliktdialog | P3 | Backlog | mobile | friend | – (nach STM-MOB-004) | post-1.0 |
| STM-MOB-008 | Mobile Export-/Teilen-Funktion (Android Share Sheet) | P3 | Backlog | mobile | friend | – | post-1.0 |
| STM-MOB-009 | Tablet-Turnierleiteransicht | P3 | Backlog | mobile | friend | – | post-1.0 |
| STM-FACH-004 | Mannschaftsturniere (Bretter, Mannschafts-/Brettpunkte, Ersatzspieler) | P2 | Backlog | pairing | friend | – (nach STM-FACH-002) | post-1.0 |
| STM-FACH-005 | Beschleunigtes Schweizer System | P3 | Backlog | pairing | friend | – (nur nach offizieller Spezifikation, Golden-Tests) | post-1.0 |
| STM-FACH-006 | Flexible Tie-Break-Profile (FIDE-/Vereinsprofile, auditierbar) | P2 | Backlog | tiebreaks | friend | – (keine stillen Regeländerungen) | post-1.0 |
| STM-FACH-007 | Ergebniskorrektur und Runden-Neuberechnung mit Audit-Trail | P2 | Backlog | pairing | friend | – | v1.0.0 |
| STM-FACH-008 | Turnierabbruch, Rückzug und Wiedereinstieg (Statusübergänge) | P2 | Backlog | pairing | friend | – (baut auf STM-FACH-001) | post-1.0 |
| STM-IE-005 | CSV-/Excel-Spielerimport mit Mapping-Vorschau | P2 | Backlog | import-export | friend | – (Vorschau + explizite Bestätigung) | post-1.0 |
| STM-IE-006 | PDF-Turnierbericht | P3 | Backlog | import-export | friend | – | post-1.0 |
| STM-IE-007 | Exportpaket für Vereinswebsites (statisch, ohne PII) | P3 | Backlog | import-export | friend | – | post-1.0 |
| STM-IE-008 | Rundenergebnis-/Paarungsimport (Vorschau, Validierung, Audit) | P3 | Backlog | import-export | friend | – | post-1.0 |
| STM-UX-005 | Turnierassistent (schrittweises Anlegen) | P2 | Backlog | ui | friend | – | post-1.0 |
| STM-UX-006 | Spieler-Massenbearbeitung | P3 | Backlog | ui | friend | – | post-1.0 |
| STM-UX-007 | Duplikaterkennung (Name, FIDE-ID; nie automatisch löschen) | P2 | Backlog | player-data | friend | – | post-1.0 |
| STM-UX-008 | Rundenkontrollzentrum | P2 | Backlog | ui | friend | – | post-1.0 |
| STM-UX-009 | Benutzerhandbuch | P3 | Backlog | documentation | friend | – | post-1.0 |
| STM-UX-010 | Geräteübergreifende Testmatrix | P3 | Backlog | infrastructure | either | – | post-1.0 |
| STM-UX-011 | Barrierefreiheit (Tastatur, Screenreader, Kontrast, Fokus) | P3 | Backlog | ui | friend | – | post-1.0 |
| STM-FACH-009 | Vereinsmeisterschaftsmodus (Serien, Saisonwertung) | P3 | Backlog | pairing | friend | – | post-1.0 |
| STM-FACH-010 | Blitz-/Schnellschach-Vorlagen | P3 | Backlog | pairing | friend | – | post-1.0 |
| STM-UX-012 | Öffentliche Live-Anzeige im lokalen Netzwerk (read-only) | P3 | Backlog | ui | either | – | post-1.0 |
| STM-DOC-001 | Contributor-Doku verifizieren & abrunden | P3 | Done | documentation | friend | [#4](https://github.com/Randspringer90/SchachTurnierManager/issues/4) (Original-PR [#31](https://github.com/Randspringer90/SchachTurnierManager/pull/31), sichere Adoption [#36](https://github.com/Randspringer90/SchachTurnierManager/pull/36)) | v1.0.0 |

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

### STM-INFRA-004 · Safe-PR-Skripte gegen offenes stdin härten
- **Beschreibung:** `scripts/Invoke-SafePullRequestReview.ps1` weist in Zeile 147
  (`$input = if ($Offline) { ... }`) der automatischen PowerShell-Variablen `$input`
  zu. `$input` ist der Enumerator über die Pipeline-/stdin-Eingabe. Bei **offenem**
  stdin (interaktive Aufrufe, Agenten-Harness) blockiert das Skript dadurch
  unbegrenzt; mit geschlossenem stdin läuft derselbe Aufruf in unter 10 s durch.
  Reproduziert am 2026-07-17: gleicher Aufruf, `-RedirectStandardInput` auf eine
  leere Datei → Exit 0 nach 7 s; ohne Redirect → Timeout nach 180 s.
  `Test-PullRequestReviewReadiness.ps1` zeigt dasselbe Verhalten.
- **Priorität:** P2 · **Status:** Done · **Kategorie:** infrastructure · **Ziel-Bearbeiter:** owner · **Owner:** der Owner
- **GitHub-Issue:** [#38](https://github.com/Randspringer90/SchachTurnierManager/issues/38) · **Branch:** `integration/pr-38-safe-adoption`
- **Abhängigkeiten:** keine.
- **Akzeptanzkriterien:**
  - Eigene Variablen heißen nicht mehr wie automatische PowerShell-Variablen.
  - Review läuft mit offenem **und** geschlossenem stdin ohne Hänger.
  - StaticOnly- und Offline-Bundle-Pfad unverändert funktionsfähig.
  - Keine Abschwächung von Security-Policy oder Checks.
- **Tests:** `PowerShellScripts_DoNotAssignToAutomaticVariables` deckt die ganze
  Fehlerklasse ab; Nachweis mit offenem stdin (17 s statt Hänger) und 42/42
  synthetischen Risikofällen.
- **Zusatzfund:** Der Test hat zwei weitere Fundstellen derselben Klasse in
  `Import-TournamentPreset.ps1` aufgedeckt (`$matches`, `$args`) – mitbehoben.
- **Definition of Done:** DoD + Gates grün, eigener Branch und Owner-PR (nicht mit
  Contributor-Adoptionen vermischen).
- **Branchname:** Die CI verlangt bei Review-Entscheidung ≠ `SAFE_FOR_ISOLATED_BUILD`
  zwingend `integration/pr-<nr>-safe-adoption` (`ci.yml`, `Assert-OwnerExecutionApproval`).
  Für Owner-Pakete ohne Contributor-PR wird – wie bei #29/#32 etabliert – die
  Issue-Nummer verwendet. Siehe STM-INFRA-007.
- **PR:** [#39](https://github.com/Randspringer90/SchachTurnierManager/pull/39), Squash-Merge `4681e01` · **Ziel-Release:** v1.0.0

### STM-INFRA-007 · Branchnamen-Policy: sanktionierter Pfad für Owner-Pakete ohne Contributor-PR
- **Beschreibung:** `ci.yml` verlangt über `Assert-OwnerExecutionApproval` bei jeder
  Review-Entscheidung ≠ `SAFE_FOR_ISOLATED_BUILD` einen Branch nach dem Muster
  `integration/pr-<nr>-safe-adoption`. Dieses Muster bedeutet semantisch „sichere
  Adoption des Contributor-PRs Nr. N". Für **Owner**-Pakete, die sicherheitskritische
  Pfade anfassen, aber keinen Contributor-PR adaptieren (z. B. STM-INFRA-004), gibt es
  damit keinen semantisch korrekten Branchnamen. `branch-policy` erlaubt zwar
  `feature|fix|security|docs|refactor/*` nach `development`, `ci-static-prerequisite`
  lehnt diese Namen dann aber ab.
- **Belege:** PR #37 (`infra/…`) scheiterte an `branch-policy`; auch policy-konforme
  Namen wie `fix/…` scheitern an `ci-static-prerequisite`, sobald der Review
  `OWNER_REVIEW_REQUIRED` liefert. Die bisherige Praxis (#29, #32, #39) umgeht das,
  indem die **Issue**-Nummer in das Adoptions-Muster gesetzt wird.
- **Priorität:** P3 · **Status:** Backlog · **Kategorie:** infrastructure · **Ziel-Bearbeiter:** owner · **Owner:** der Owner
- **Warum das zählt:** Ein Branchname, der „Adoption von PR N" behauptet, obwohl es
  keinen PR N gibt, macht die Herkunft von Änderungen an sicherheitskritischen Pfaden
  unklar – genau dort, wo Nachvollziehbarkeit am wichtigsten ist.
- **Abhängigkeiten:** keine.
- **Akzeptanzkriterien:**
  - Ein sanktionierter Branchname für Owner-Pakete existiert (z. B.
    `owner/<backlog-id>-<slug>`) und ist in `branch-policy` **und**
    `Assert-OwnerExecutionApproval` konsistent zugelassen.
  - Die SHA-gebundene Owner-Freigabe bleibt für diesen Pfad zwingend.
  - Keine Aufweichung: Contributor-Branches erhalten den Pfad nicht.
  - `CONTRIBUTING.md`/`BRANCHING_STRATEGY.md` dokumentieren die Regel.
- **Definition of Done:** DoD + Gates grün.
- **PR:** – · **Ziel-Release:** v1.0.0

### STM-INFRA-006 · `Test-RoutedExecutionReadiness.ps1` ist flaky (checkpoint.json-Race)
- **Beschreibung:** Das Gate schlägt nichtdeterministisch fehl. Symptom ist immer
  `Cannot find path '<runRoot>/checkpoint.json'`, aber in **wechselnden** Szenarien
  (`run-budget`, `run-ratelimit`, `run-childerror`). Der Checkpoint wird von einem
  Kind-`pwsh` geschrieben und vom Elternprozess unmittelbar danach gelesen – der
  Fehler ist damit sehr wahrscheinlich ein Timing-/Flush-Race, keine Logikänderung.
- **Belege (2026-07-17, unveränderter Skriptstand):** drei aufeinanderfolgende lokale
  Läufe ergaben Exit 1 / 0 / 1 mit jeweils anderem betroffenen Szenario. In CI schlug
  derselbe Job auf einem reinen Doku-PR (#36, 4 Markdown-Dateien, 0 Skripte) fehl,
  während er Minuten zuvor auf PR #35 grün war.
- **Priorität:** P2 · **Status:** Backlog · **Kategorie:** infrastructure · **Ziel-Bearbeiter:** owner · **Owner:** der Owner
- **Warum P2:** Ein flakiges Pflicht-Gate erzeugt Fehlalarme und verleitet dazu, CI-Rot
  reflexhaft wegzudrücken. Das untergräbt die Aussagekraft aller anderen Gates.
- **Abhängigkeiten:** keine.
- **Akzeptanzkriterien:**
  - Ursache benannt (Schreib-/Lese-Race auf `checkpoint.json` bestätigt oder widerlegt).
  - Deterministisches Warten auf den geschriebenen Checkpoint statt impliziter Annahme.
  - 20 aufeinanderfolgende Läufe ohne Fehlschlag.
  - Keine Abschwächung der geprüften Zusicherungen, kein Aufweichen der Assertions.
- **Tests:** Wiederholungslauf als Nachweis; kein `-SkipFlaky`-Schalter.
- **Definition of Done:** DoD + Gates grün, eigener Branch und Owner-PR.
- **PR:** – · **Ziel-Release:** v1.0.0

### STM-INFRA-005 · Hart verdrahtetes `D:\Temp` auf `%TEMP%`-Fallback umstellen
- **Beschreibung:** Folgeaufgabe aus STM-REL-001. `New-RunLogBundle.ps1` ist bereits
  gefixt; dasselbe Muster steckt noch in 8 Skripten und lässt sie auf Maschinen ohne
  `D:`-Laufwerk hart abbrechen. Betroffen (unabhängig nachgezählt 2026-07-17):
  `Invoke-ClickInstallReadiness.ps1`, `Invoke-ColleagueFreshRunTest.ps1`,
  `Invoke-ColleagueInstallReadiness.ps1`, `Invoke-LoggingReadiness.ps1`,
  `Invoke-ReleaseCandidateReadiness.ps1`, `Invoke-SecretSafetyReadiness.ps1`
  (je Parameter-Default) sowie `New-ContributorTaskPrompt.ps1` (Zeile 187) und
  `Test-ContributorKickoffReadiness.ps1` (Zeilen 92/94, hartkodierte Pfadnutzung).
- **Priorität:** P3 · **Status:** Backlog · **Kategorie:** infrastructure · **Ziel-Bearbeiter:** either · **Owner:** der Owner
- **Abhängigkeiten:** keine (Muster aus `New-RunLogBundle.ps1` übernehmen).
- **Akzeptanzkriterien:**
  - Kein Skript setzt ein `D:`-Laufwerk mehr voraus.
  - Verhalten auf Maschinen **mit** `D:` bleibt unverändert (`D:\Temp`).
  - Vertragstest analog `RunLogBundle_BaseDirectoryFallsBackToTempWhenNoDDriveExists`.
- **Definition of Done:** DoD + Gates grün.
- **PR:** – · **Ziel-Release:** v1.0.0

### STM-IE-001 · Excel-/TRF-Export (FIDE-Turnierbericht)
- **Beschreibung:** Read-only-Export der Turnierdaten ins TRF(x)-Format (FIDE) und/oder Excel,
  ohne Änderung der Turnierlogik.
- **Priorität:** P1 · **Status:** Done · **Kategorie:** import-export · **Ziel-Bearbeiter:** friend · **Owner:** der Owner
- **GitHub-Issue:** [#3](https://github.com/Randspringer90/SchachTurnierManager/issues/3) · **Branch:** `feature/STM-IE-001-trf-export`
- **Abhängigkeiten:** `TournamentExportFormatter` (bereits vorhanden).
- **Akzeptanzkriterien:** alle erfüllt.
  - Gültige TRF16-Datei für ein abgeschlossenes Beispielturnier (Spaltenpositionen nach C.04 Annex 2).
  - Deterministische Ausgabe, keine PII über die Turnierteilnahme hinaus (Geburtsdatum bleibt leer).
- **Tests:** 13 Golden-Tests (Feldpositionen, Bye, Forfeits, offene Runde, Rückzug,
  Teilnehmerzahl, Unicode, Steuerzeichen, Dateiname, leeres Turnier, 12 Runden,
  Byte-Determinismus) plus Service- und Endpoint-Tests.
- **Security:** Ausgabe ohne lokale Pfade/Secrets; Dateiname sanitisiert; Steuerzeichen entfernt;
  FIDE-ID nur bei plausibler numerischer Form.
- **Doku-Bedarf:** `docs/IMPORT_EXPORT_ROADMAP.md`, `CHANGELOG.md` – erledigt.
- **Definition of Done:** DoD + Gates grün.
- **Verbleibende Scope-Grenzen (bewusst, dokumentiert):** Turnier-Metadaten (Ort 022,
  Föderation 032, Datum 042/052, Schiedsrichter 102) fehlen im Domainmodell und werden
  ausgelassen statt erfunden; kein automatischer Vor-/Nachname-Split.
- **PR:** Original [#30](https://github.com/Randspringer90/SchachTurnierManager/pull/30) ·
  **Sichere Adoption:** [#35](https://github.com/Randspringer90/SchachTurnierManager/pull/35),
  Squash-Merge `6a2d021` · **Ziel-Release:** v1.0.0

### STM-DOC-001 · Contributor-Doku verifizieren & abrunden
- **Beschreibung:** Onboarding-/Contributing-Doku praktisch nachvollziehen und Lücken/Fehler
  korrigieren (Befehle, Versionsangaben, Links).
- **Priorität:** P3 · **Status:** Done · **Kategorie:** documentation · **Ziel-Bearbeiter:** friend · **Owner:** der Owner
- **GitHub-Issue:** [#4](https://github.com/Randspringer90/SchachTurnierManager/issues/4) · **Branch:** `docs/STM-DOC-001-contributor-review`
- **Abhängigkeiten:** keine.
- **Akzeptanzkriterien:** erfüllt – alle in `CONTRIBUTING.md`/Onboarding genannten Befehle
  wurden auf einem frischen Klon real ausgeführt (`git clone` → `git switch development` →
  `dotnet build` → `dotnet test`, 235/235 grün); Links geprüft.
- **Tests:** Markdown-Linkcheck (8 relative Links OK), Skriptreferenzprüfung (4 Referenzen OK),
  frischer Clone, `Test-CollaborationReadiness.ps1` = OK.
- **Security:** keine Abschwächung von Sicherheitsregeln; keine lokalen Pfade, keine Secrets.
- **Doku-Bedarf:** die betroffenen Doku-Dateien – erledigt.
- **Ergebnis:** `gh` ist jetzt korrekt als optional dokumentiert (Web-UI-PR-Pfad inkl.
  Base-Branch-Fallstrick); Versionsangaben verweisen auf die kanonischen Quellen
  (`global.json`, Vite `engines`) und schließen neuere Versionen nicht mehr aus.
- **PR:** Original [#31](https://github.com/Randspringer90/SchachTurnierManager/pull/31) ·
  **Sichere Adoption:** [#36](https://github.com/Randspringer90/SchachTurnierManager/pull/36) ·
  **Ziel-Release:** v1.0.0

### STM-FACH-002 · Vollständigeres FIDE-Dutch-Schweizer-System
- **Beschreibung:** Ausbau des Basis-Schweizer-Systems zum vollständigeren FIDE-Dutch-System
  (Score Groups, Floater, Farbpräferenzen, Wiederholungsschutz, Bye-Regeln, deterministische
  Entscheidungsreihenfolge, Audit-Trail). Vollständige Spezifikation im Issue.
- **Priorität:** P1 · **Status:** Ready · **Kategorie:** pairing · **Ziel-Bearbeiter:** friend · **Owner:** der Owner
- **GitHub-Issue:** [#22](https://github.com/Randspringer90/SchachTurnierManager/issues/22) · **Branch:** `feature/STM-FACH-002-fide-dutch`
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
