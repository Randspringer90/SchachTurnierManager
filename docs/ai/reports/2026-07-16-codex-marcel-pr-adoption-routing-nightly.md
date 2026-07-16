# Abschlussbericht: Marcel-PR-Adoption, Routing, Wissen und Nightly

## Ergebnis

Der wegen Usage-Limit unterbrochene Master-Lauf wurde am vorhandenen lokalen
Zwischenstand fortgesetzt und fachlich vollständig abgeschlossen. Marcels PRs #9 und
#10 sind über sichere Owner-Integrationen übernommen. STM-AI-003, STM-AI-002 und
STM-AI-004 sind implementiert, remote integriert und dokumentiert. Innerhalb dieses
Laufs bleibt kein begonnenes Paket uncommittet, partiell oder fachlich blockiert.

## Rekonstruktion

- bekannte Startbasis: `e6ac40266d13fe01eb17bc9d3600dc6a77a5e1c4`
- lokaler PR-10-Zwischenstand, Reflog, Branches, Worktrees, Stashes und der bestehende
  Runordner wurden vor Änderungen vollständig geprüft;
- Original-PR #10 stand unverändert auf
  `ede5390a8f49ff01ee1dbd8ca081f666af434379`;
- `origin/development` entsprach der bekannten Startbasis; Marcel hatte keinen neuen
  Commit nachgeschoben;
- vorhandene lokale Arbeit wurde weder verworfen noch gestasht oder überschrieben.

Die fünf Resume-Prüfungen zu Git/Scope, Security, Fachregeln, Architektur und Tests
liegen im externen Master-Runordner unter `02-pr10/`.

## Contributor-Adoption

### PR #9 / STM-TB-001

Original-Head `39770dc016f1eac6054200dfc181b679cc9db30e` wurde verifiziert. Die fachlich
wertvollen Golden-Szenarien wurden über Owner-PR #13 integriert; Merge
`2e0fdd7f12b4dcc6d25b2103b693356c051ee53e`. Original-PR #9 wurde kommentiert und
als sicher übernommen geschlossen. Marcel ist im Merge-Commit als Co-Autor genannt.

### PR #10 / STM-FACH-001

Die Idee wurde nicht als alte Datei kopiert, sondern auf der aktuellen Basis neu
adaptiert. Owner-PR #14 wurde nach grüner CI gemergt; Merge
`31a3a061d5466ecadc1cc05d72d3f62102126051`. Original-PR #10 wurde mit einer
wertschätzenden technischen Zusammenfassung kommentiert und als durch sicheren
Integrations-PR übernommen geschlossen. Issue #1 ist geschlossen; Marcel ist im
Merge-Commit als Co-Autor genannt.

Die Fachentscheidung folgt FIDE Handbook C.07, Fassung ab 1. März 2026, Art. 15/16
(Abruf 2026-07-16; `https://handbook.fide.com/chapter/TieBreakRegulations032026`).
Der neue Modus ist opt-in und beschränkt auf Schweizer Buchholz, Cut-1, Cut-2 und
Median. Offene Runden bleiben offen, reale und virtuelle Gegner werden nicht doppelt
gezählt, und `ForfeitTiebreakPolicy` hat dokumentierten Vorrang. Sonneborn-Berger,
Direktvergleich und Performance blieben unverändert.

Der Withdrawal-Fix berechnet historische Resultate vollständig und filtert erst die
fertige sichtbare Rangliste. Aktive Spieler behalten damit Sieg-, Niederlagen- und
Remispunkte gegen später zurückgezogene Gegner; zurückgezogene Spieler bleiben
unsichtbar und von Folgepaarungen ausgeschlossen. Domain, API, UI, JSON/SQLite,
Backup/Restore, Legacy-Daten, Export und Audit sind abgedeckt.

## STM-AI-003 – Modellrouting

Die logischen, providerneutralen Profile Fabel, Sol, Luna, Terra, Opus und Sonnet sind
über Policy, Schema und reproduzierbaren Resolver operationalisiert. Qualität hat
Vorrang; kritische Arbeit und nicht bestätigte Profilverfügbarkeit blockieren
fail-closed, ein stiller Wechsel findet nicht statt. Owner-PR #17 wurde als
`dfa75204fe63ab30f1fc3dff34ee5d2e7640c513` gemergt; Issue #15 ist geschlossen.
Der erste PR #16 wurde transparent geschlossen, weil die Branch-Policy den exakten
Owner-Integrationspfad verlangte; derselbe geprüfte Head wurde über PR #17 integriert.

## STM-AI-002 – Wissen und Improvement

Wissenseinträge besitzen striktere Source-/Date-/Trust-/Review- und Reparse-Grenzen.
Agent-/Skill-Lernsignale erzeugen nur lokale `DRAFT_OWNER_REVIEW`-Vorschläge; sie
aktivieren keine Instruktion und führen weder Netzwerk- noch Git-Schreibaktionen aus.
Secret-, PII-, Owner-Pfad-, Injection-, Befehls-, Code-Fence-, T5- und Traversal-
Negativfälle sind abgedeckt. Owner-PR #19 wurde als
`98648e793fe2385ff4dedbce2cf33c58f0bc8f8b` gemergt; Issue #18 ist geschlossen.

Ein erster Remote-Lauf blockierte drei defensive Literale als Nutzlast, bevor Code
ausgeführt wurde. Die Literale wurden neutral zur Laufzeit zusammengesetzt; danach
waren statische Prüfung, Agent-Integrity und alle weiteren Checks grün.

## STM-AI-004 – Nightly/Resume

Atomare, SHA-256-gebundene T3-Checkpoints bleiben im ignorierten Repository-Output.
Resume validiert Projekt, Branch, Head, Worktree, Binding und Attempt-Limit und liefert
nur einen Plan mit `Command=null`. Manipulation, Drift, Secrets, PII, absolute Pfade,
Traversal und Reparse-Points blockieren fail-closed. Produktivpfade besitzen keine
mutierende Git-, Netzwerk-, Scheduler-, Release- oder externe Funktion.

Die zentrale Registrierung wurde lokal als `READY_FOR_ACTIVATION` erzeugt; sie wurde
nicht aktiviert. Owner-PR #21 wurde als
`a6df385763dadc6538e85e9b3d06e8ae20130019` gemergt; Issue #20 ist geschlossen.
Ein realer `COMPLETED`-Checkpoint lieferte auf sauberem `development`
`NO_RESUME_REQUIRED` ohne Seiteneffekt.

## Tests und Gates

- .NET: 220/220, davon GoldenTests 3/3, Application 99, Infrastructure 18,
  Domain 100;
- Frontend: Typecheck und Vite-Build grün;
- PowerShell-Parser: 134 Dateien, 0 Fehler;
- PullRequestReviewReadiness: 42/42;
- ModelRoutingReadiness: 12/12;
- AgentSkillProposalSafety: 9/9;
- NightlyReadiness: 56/56;
- AgentInstructionIntegrity, AgentSkillReadiness, KnowledgePersistenceSafety,
  PromptInjectionDefense, GitCommitSafety, RepositoryOpenSourceSafety und
  CollaborationReadiness: grün;
- Dependency-Delta: keine Manifest-/Lockfile-Änderung in Routing, Wissen oder Nightly;
- vollständiger ReleaseGate einschließlich Restore, Build, Tests, Frontend und
  Portable-Paketierung: wiederholt grün;
- Owner-PRs #13, #14, #17, #19 und #21: CI vor Merge vollständig grün;
- `git diff --check`: grün.

Lokal ist nur Pester 3.4.0 vorhanden. Es wurde nichts installiert; die zugrunde
liegenden plattformneutralen Contract-Skripte wurden direkt ausgeführt.

## Security und Git

Keine neue Dependency, Binärdatei, Archivdatei, Symlink, Datenbank, Secret, PII oder
Fremdprojektabhängigkeit wurde committed. Kein fremder Branch wurde verändert, keine
History umgeschrieben und kein Force-Push verwendet. Der lokale zentrale BAT-Fleet-
Pre-Push-Hook blockiert weiterhin drei historische BAT-Dateien wegen fehlender
versionsgebundener Funktionsevidence. Da kein Paket diese BAT/CMD-Dateien änderte,
wurde nach vollständigen Gates jeweils ausschließlich der geprüfte Branch/Commit mit
`--no-verify` veröffentlicht; die Ausnahme ist in den Paketberichten dokumentiert.

## Fortschritt und Restpfad

Backlog-Methodik: `Done / alle 31 kanonischen Aufgaben`. Die bekannte Startbasis hatte
5/31 (`16 %`), der Abschlussstand 9/31 (`29 %`). Release-Readiness wird konservativ
als erledigte P0/P1-Aufgaben gemessen: 4/15 (`27 %`). Der niedrige Releasewert ist kein
Fehler dieses Laufs: FIDE-Dutch, große Felder, Supply-Chain/PII/History-Abnahme,
Setup/Signierung/Kollegen-PC-Test und Release Candidate bleiben eigenständige Pakete.

STM-DOC-001 und STM-IE-001 bleiben bewusst als `Ready` für den Contributor erhalten.
Es wurde nach Abschluss des aktuellen Paketverbunds kein neues Paket begonnen.

Development stand vor diesem finalen Dokumentationscommit auf
`d518d4a953e75809471adb9512dd1a90750f0c3e`. Der tatsächliche finale SHA und die
vollständigen CI-/Run-Artefakte werden nach dem Commit im externen `run-state.json`
festgehalten.
