## Unreleased (development)

- STM-IE-002: Swiss-Manager-CSV-Import/-Export und TRF16-Import ergänzt (Import-
  Richtung zu STM-IE-001s Export). `SwissManagerCsvCodec` (Domain) liest/schreibt
  das offizielle Swiss-Manager-Layout aus dem User's Guide, Anhang C, akzeptiert
  kombinierte oder getrennte Name-Spalten in beliebiger Reihenfolge sowie die
  Datumsformate `JJJJ/MM/TT`, `TT.MM.JJJJ` und reines Geburtsjahr.
  `TournamentExportFormatter.ImportTrf16Players` liest TRF16-Stammdatenzeilen
  zurück (nur Name/Rating/Föderation/FIDE-ID, keine Paarungen/Ergebnisse). Neuer
  `ImportTextDecoder` versucht zuerst striktes UTF-8 und fällt bei ungültigen Bytes
  auf Windows-1252 zurück (`System.Text.Encoding.CodePages`), damit ältere
  Swiss-Manager-Exporte korrekt gelesen werden. Import über die API nimmt Datei-**Bytes**
  (kein Dateipfad, damit kein Pfad-Traversal); `ReplaceExisting` ist explizit (Default
  false, kein stilles Überschreiben); Format-Fehler werden pro Zeile gesammelt statt
  beim ersten Fehler abzubrechen (`PlayerImportOutcome`). Neue Endpoints:
  `GET .../players/export-swissmanager.csv`, `POST .../players/import-swissmanager.csv`,
  `POST .../players/import-trf16`; neuer WebApp-Bereich "Swiss-Manager / TRF16
  (Spieler-Stammdaten)". Scope bewusst auf Spieler-Stammdaten begrenzt; `Birth` beim
  Export nur als Jahr (PII-Minimierung); Felder ohne Domainmodell-Entsprechung werden
  ausgelassen statt erfunden. Ursprung: Marcel-Mente (PR #44), sicher adaptiert. Neue
  Dependency `System.Text.Encoding.CodePages` (Microsoft-First-Party, MIT) im
  Owner-Review geprüft und genehmigt. Details in `docs/IMPORT_EXPORT_ROADMAP.md`.
- STM-FACH-002: **FIDE-Dutch-Schweizer-System** als eigene, auswählbare Paarungsstrategie
  ergänzt (C.04.3 in der ab **01.02.2026** gültigen Fassung). Die bestehende
  Optimal-V2-Engine bleibt unverändert und **Standard**; FIDE-Dutch wird über
  `TournamentSettings.PairingStrategy` bewusst gewählt. Umgesetzt sind Score
  Groups/Brackets (Art. 1.3, 1.9.2), homogene und heterogene Bracket-Behandlung
  inkl. Limbo (Art. 3.2), Floater- und Float-Historie (Art. 1.4, [C14]–[C21]),
  Farbpräferenzen absolut/stark/mild (Art. 1.7) mit vollständiger Farbzuteilung
  (Art. 5), Wiederholungsschutz ([C1]), Bye-Regeln inkl. kampfloser Ergebnisse
  ([C2], [C5], [C9]), Backtracking für das Vollständigkeitsgebot ([C4]) und ein
  Audit-Trail, der zu jeder Entscheidung die Artikelnummer nennt (C.04.1 Art. 9).
  Neu: `TournamentSettings.SwissInitialColour` — die nach Art. 5.1 vor Runde 1
  **ausgeloste** Anfangsfarbe. Sie ist Eingabe des Turnierleiters, nicht Zufall der
  Engine, sonst wäre die Auslosung nicht reproduzierbar (C.04.2 Art. 1.4).
  Validiert durch drei Golden-Turniere über je fünf Runden (inkl. Freilos, kampflosem
  Ergebnis und erzwungenen Floats), deren Erwartungswerte von Hand aus dem Regeltext
  hergeleitet und zusätzlich gegen die zugelassene Referenz-Engine bbpPairings 6.0.0
  gegengeprüft wurden, sowie durch Property-Tests der absoluten Kriterien über sechs
  Feldgrößen. Regelgrundlage mit allen Fundstellen: `docs/FIDE_DUTCH_REFERENCE.md`.
  Ursprung: Marcel-Mente (PR #40), sicher an den aktuellen development-Stand adaptiert;
  FIDE-C.04.3-Fassung 2026, Artikelstruktur 1–5 und Kriterien [C1]–[C21] wurden im
  Owner-Review unabhängig gegen die Primärquelle (`handbook.fide.com/chapter/C0403202602`)
  bestätigt. **Offen (Folgearbeit):** Die WebApp-UI bietet noch keine Auswahl für
  `PairingStrategy`/`SwissInitialColour` — das Backend ist vollständig und über API/Persistenz
  nutzbar, die Oberfläche folgt separat. Performance für Felder über 20 Spieler bleibt
  STM-FACH-003.
- STM-INFRA-006: Nichtdeterministischen Graph-Hash in der Routed-Execution behoben.
  `Get-TaskGraphHash` serialisierte den Graph direkt per `ConvertTo-Json`; dessen
  Property-Reihenfolge ist bei Hashtables nicht garantiert und variiert zwischen
  Prozessen (randomisierter Hash-Seed). Derselbe logische Graph konnte dadurch zwei
  verschiedene Hashes ergeben, worauf `Invoke-RoutedTaskGraph` fälschlich
  „Manipulation" meldete und abbrach – nicht nur im Gate `Test-RoutedExecutionReadiness.ps1`
  (reproduzierbar flaky, 9/20 Fehlschläge), sondern potenziell auch bei einem echten
  Resume. Der Hash normalisiert die Eingabe jetzt über einen JSON-Roundtrip und
  serialisiert kanonisch mit rekursiv sortierten Schlüsseln; damit ist er unabhängig
  von Objektform (Hashtable beim Erstellen vs. JSON-Objekt beim Lesen) und
  Property-Reihenfolge. Zusätzlich gehärtet: atomarer Checkpoint-Austausch mit
  begrenztem Move-Retry gegen transiente Datei-Locks, und einheitliches
  deterministisches Warten auf den Checkpoint in den Testassertions (fail-closed).
  Nachweis: **20/20 aufeinanderfolgende Läufe grün**. Keine Assertion abgeschwächt,
  kein Skip-Schalter.
- STM-INFRA-004: Safe-PR-Skripte gegen offenes stdin gehärtet.
  `Invoke-SafePullRequestReview.ps1` wies der automatischen PowerShell-Variablen
  `$input` (Pipeline-/stdin-Enumerator) einen eigenen Wert zu und blockierte
  dadurch bei offenem stdin unbegrenzt – betroffen war auch
  `Test-PullRequestReviewReadiness.ps1`, das das Review aufruft. Umbenannt in
  `$reviewInput`. Der neue Test `PowerShellScripts_DoNotAssignToAutomaticVariables`
  deckt die gesamte Fehlerklasse ab (nicht nur `$input`) und hat dabei zwei weitere
  echte Fundstellen in `Import-TournamentPreset.ps1` aufgedeckt: `$matches` (wird vom
  `-match`-Operator überschrieben) und `$args` – beide umbenannt.
  Messbar: `Test-PullRequestReviewReadiness.ps1` läuft mit offenem stdin jetzt in
  17 s durch (vorher Hänger > 12 min); alle 42 synthetischen Risikofälle bestehen
  unverändert, keine Security-Prüfung wurde abgeschwächt.
- STM-DOC-001: Contributor-Onboarding auf einem frischen Klon verifiziert und
  korrigiert. Die GitHub CLI (`gh`) ist jetzt als **optional** ausgewiesen: Der
  Pull-Request-Weg über die GitHub-Weboberfläche ist vollständig dokumentiert,
  inklusive des Hinweises, dass GitHub dort oft `main` statt `development` als
  Base vorschlägt. Die Node-Angabe nennt weiterhin 22 LTS als Empfehlung, verweist
  für die verbindliche Mindestversion aber auf die kanonische Quelle (Vite
  `engines`, aktuell `^20.19.0 || >=22.12.0`) und schließt neuere Versionen nicht
  mehr aus – mit Node 24 verifiziert. Ursprung: Marcel-Mente (PR #31), sicher an
  den aktuellen development-Stand adaptiert. Verifiziert über frischen Clone
  (`git clone` → `git switch development` → `dotnet build` → `dotnet test`,
  235/235 grün), Markdown-Linkcheck, Skriptreferenzprüfung und
  `Test-CollaborationReadiness.ps1` (OK).
- STM-IE-001: Read-only-Export ins FIDE-TRF16-Format (`ExportTrf16` in
  `TournamentExportFormatter`, Endpoint `GET /api/tournaments/{id}/standings/export.trf16`,
  WebApp-Button "TRF16 (FIDE-Turnierbericht)" im Export-Center). Spaltenpositionen
  exakt nach offizieller FIDE-Spezifikation (C.04 Annex 2), Zeilenenden CR gemäß
  Remark 1. Der Export enthält alle Turnierteilnehmer inklusive zurückgezogener
  Spieler (`StandingsCalculator.Calculate(includeInactive: true)`), damit die
  STM-FACH-001-Withdrawal-Filterung der sichtbaren Rangliste keine Spieler aus dem
  FIDE-Bericht entfernt; die Kopfzeilen 062/072 zählen konsistent die exportierten
  Zeilen. Feldüberlängen werfen statt Folgespalten zu verschieben, Steuerzeichen
  werden entfernt, und eine FIDE-ID wird nur bei plausibler numerischer Form
  übernommen. 13 Golden-Tests (Feldpositionen, Bye, alle Forfeit-Fälle, offene
  Runde, Rückzug, Teilnehmerzahl, Unicode, Steuerzeichen, Dateiname, leeres
  Turnier, 12 Runden, Byte-Determinismus) plus Service- und Endpoint-Tests.
  Ursprung: Marcel-Mente (PR #30), sicher an den aktuellen development-Stand
  adaptiert. Verbleibende Scope-Grenzen in `docs/IMPORT_EXPORT_ROADMAP.md`.
- STM-REL-001: Kritischen Startfehler der Desktop-/Portable-Variante behoben.
  `Program.cs` bindet `ContentRootPath` jetzt explizit an `AppContext.BaseDirectory`
  statt am aktuellen Arbeitsverzeichnis. Die Launcher starten die EXE über `start`,
  ohne das Arbeitsverzeichnis zu setzen; dadurch wurde `wwwroot` nicht gefunden und
  jeder normale Start per Verknüpfung/Doppelklick landete still auf der
  API-Fallback-Seite statt im Dashboard (`embeddedDashboard: false`). Nach dem Fix
  meldet `/api/health` unter denselben Startbedingungen `embeddedDashboard: true`.
  Zusätzlich fällt der `BaseDirectory`-Default in `New-RunLogBundle.ps1` auf `%TEMP%`
  zurück, wenn kein `D:`-Laufwerk existiert (vorher harter Abbruch auf Maschinen ohne
  Datenpartition). Beide Änderungen sind durch Vertragstests abgesichert
  (`WebApi_BindsContentRootToApplicationDirectoryNotCurrentWorkingDirectory`,
  `RunLogBundle_BaseDirectoryFallsBackToTempWhenNoDDriveExists`).
  Ursprung: Marcel-Mente (PR #33) – Bug auf einer frischen Maschine reproduziert,
  Installer-Testmatrix (Inno Setup 6: Installation, Start, Testturnier,
  Neustart-Persistenz, Deinstallation mit Datenerhalt) real durchlaufen.
  Sicher an den aktuellen development-Stand adaptiert.
  Bewusst nicht mitgefixt: dasselbe hart verdrahtete `D:\Temp`-Muster steckt noch in
  8 weiteren Skripten (`Invoke-ClickInstallReadiness`, `Invoke-ColleagueFreshRunTest`,
  `Invoke-ColleagueInstallReadiness`, `Invoke-LoggingReadiness`,
  `Invoke-ReleaseCandidateReadiness`, `Invoke-SecretSafetyReadiness`,
  `New-ContributorTaskPrompt`, `Test-ContributorKickoffReadiness`) – als eigene
  Folgeaufgabe erfasst. Weiterhin offen: Portable-ZIP, Upgrade über Vorversion,
  Sandbox-Frischmaschinentest, echte Code-Signierung.
- STM-AI-006: projektlokale Nightly-Ausführungsebene ergänzt und zentrale
  Nightly-Aufnahme vorbereitet. `Invoke-NightlyProjectRun.ps1` (Lock,
  Vorbedingungen, kanonische Owner-Queue aus BACKLOG mit striktem Ausschluss von
  Contributor-/Marcel-Aufgaben, Plan + Masterprompt + Gates),
  `Resume-NightlyProjectRun.ps1` (fail-closed Fortsetzung),
  `Register-NightlyProject.ps1` (einmalige Aktivierung in der **vorhandenen**
  zentralen Registry per Override-Flip; WhatIf-Default; erzeugt nie eine
  Scheduled Task) sowie `Test-NightlyExecutionReadiness.ps1` (19 Offline-Checks,
  zusätzlich in CI). Die plan-only Checkpoint-Ebene aus STM-AI-004
  (`config/nightly-run.json`) bleibt unverändert nicht selbstaktivierend; die
  Aktivierung erfolgt ausschließlich zentral durch den Owner.

- STM-AI-005: providerübergreifende Promptzerlegung und Routed Execution ergänzt.
  Masterprompts (Fabel/Sol) werden in validierte Taskgraphen zerlegt
  (`New-RoutedTaskGraph.ps1`), Teilaufgaben tatsächlich an kleinere logische Profile
  delegiert (`Invoke-RoutedTaskGraph.ps1` + Anthropic-/OpenAI-Adapter) und
  bindungsgeprüft fortgesetzt (`Resume-RoutedTaskGraph.ps1`). Kritische Kategorien
  werden nie automatisch herabgestuft, Children sind read-only ohne Commit-/Push-Rechte,
  Child-Ausgaben bleiben T3 mit Injection-Quarantäne, Rate-/Usage-Limits und
  Tokenbudgets checkpointen zustandserhaltend. Neue Policies
  (`task-decomposition-policy`, `provider-runtime-policy` + Schemas), Agentenrollen
  (Task-Decomposer, Routing-Supervisor, Result-Integrator), vier Skills sowie ein
  34-Fälle-Offline-Gate (`Test-RoutedExecutionReadiness.ps1`). Live-Smoke-Test:
  Anthropic-Delegation real grün; OpenAI-Adapter funktional, Modellantwort durch
  externes Nutzungskontingent (bis 2026-07-23) blockiert und korrekt klassifiziert.

- Der fortgesetzte Owner-Lauf hat Marcels PRs #9/#10 über die sicheren
  Integrations-PRs #13/#14 übernommen und anschließend STM-AI-003, STM-AI-002 und
  STM-AI-004 über PRs #17/#19/#21 abgeschlossen. Alle Originalbeiträge wurden
  attributiert und wertschätzend als integriert geschlossen; Routing, Knowledge-
  Improvement und Nightly/Resume sind nun durch eigene fail-closed Gates abgesichert.

- STM-AI-004: projektlokalen Nightly-/Resume-Unterbau ergänzt. Atomare Checkpoints
  bleiben unter dem ignorierten `output/`, sind an Projekt, Branch und Head gebunden
  und enthalten weder Kommandos noch Secrets/PII. Der Resume-Plan blockiert bei
  Manipulation, Branch-/Head-Drift, dirty Worktree oder erreichtem Attempt-Limit.
  Die zentrale Registrierung wird nur als `READY_FOR_ACTIVATION`-Plan exportiert;
  automatische Ausführung sowie Git-, Netzwerk-, Scheduler- und externe Mutationen
  bleiben deaktiviert. Ein 56-Fälle-Gate läuft zusätzlich in CI.

- STM-AI-002: repo-internes Wissensmanagement mit strikteren Metadaten-, Trust- und
  Data-only-Prüfungen abgeschlossen. Wiederholte Lernsignale können nun ausschließlich
  als lokale, redigierte `DRAFT_OWNER_REVIEW`-Vorschläge vorbereitet werden; der
  Generator aktiviert oder ändert keine Agenten, Skills oder Policies und führt weder
  Netzwerk- noch Git-Schreibaktionen aus. Ein eigener Sicherheits-Gate prüft Secret-/
  PII-/Injection-/Traversal-Fälle und unveränderte Instruktionsquellen; die KI-CI führt
  die Agent-, Skill-, Routing-, Knowledge- und Prompt-Injection-Gates gemeinsam aus.

- STM-AI-003: providerneutrales Modellrouting ueber die logischen Profile Fabel, Sol,
  Luna, Terra, Opus und Sonnet operationalisiert. Eine schema-validierte Policy und ein
  reproduzierbarer Resolver erzwingen Risiko-, Determinismus- und Qualitaetsgrenzen sowie
  die explizite Verfuegbarkeitsbestaetigung. Fehlende Profile oder unklare Regeln blockieren
  fail-closed; es gibt weder konkrete Modellversionspins noch stille Fallbacks. Ein eigener
  Readiness-Gate prueft Policy und Entscheidungsmatrix.

- STM-FACH-001: Marcels Freilos-/Forfeit-Idee aus PR #10 auf aktuellem
  `development` sicher adaptiert. Ein opt-in FIDE-C.07/03-2026-Modus behandelt
  ungespielte Runden in Schweizer Buchholz/Cut/Median mit Art.-16.3-Caps,
  Art.-16.4-Dummys und Art.-16.5-VUR-Streichern; Default und andere Wertungen
  bleiben unverändert. Die bestehende Forfeit-Policy hat Vorrang und verhindert
  reale/virtuelle Doppelzählung. Der von Marcel entdeckte Withdrawal-Bug ist
  behoben: aktive Gegner behalten historische Punkte, zurückgezogene Spieler
  bleiben aus Rangliste und Folgepaarungen entfernt. Domain, API, UI, Persistenz,
  Backup/Restore, Legacy-Daten, Export/Audit und die vollständige Matrix sind
  durch neue Regressionstests abgesichert.

- STM-TB-001: Marcels zwei handgerechnete Tie-Break-Szenarien aus PR #9 auf dem
  aktuellen `development` im bestehenden Golden-Testprojekt sicher adaptiert. Die Tests
  decken Buchholz, Cut-1, Cut-2, Median-Buchholz, Sonneborn-Berger, die konfigurierte
  Tie-Break-Reihenfolge, exakte Rangnummern und den bisherigen Freilos-Default ab; die
  produktive Wertungslogik bleibt unveraendert.

- STM-AI-001 (Agenten-/Skill-/Security-Grundlage): providerneutrale, kanonische Agentenstruktur (`agents/**`, 14 Rollen), Manifeste (`config/agent-manifest.json`, `config/skill-manifest.json`, `config/agent-routing.json` mit Qualitätsklassen statt Modellnamen), Trust-/Toolrechte-Policies (`config/agent-trust-policy.json`, `config/tool-permission-profiles.json`, `config/trusted-instruction-paths.json`), 6 neue kanonische Sicherheits-/KI-Skills (SKILL.md), dünne Claude-Adapter (`.claude/agents/**`), projektlokales Wissensmanagement (`docs/knowledge/**`) und Prompt-Injection-/Trust-Boundary-Doku. Neue Guards `Test-AgentInstructionIntegrity`, `Test-AgentSkillReadiness`, `Test-PromptInjectionDefense` (synthetische Fixtures), `Test-KnowledgePersistenceSafety`, `Sync-ClaudeAgentAdapters` (Check/Apply/WhatIf) + Pester-Contract-Tests; Instruction-Integrity als CI-Gate. Grundlage für STM-AI-002 (Wissensmanagement) und STM-SEC-001 (Prompt-Injection). Keine Schachlogik/Secrets/PII berührt.

- STM-INT-001 (v0.41-Reconcile): kanonische lokale KI-Hilfe ist die Frontend-Wissensbasis (offline, providerlos); das tote, nirgends referenzierte Backend-Modul `Application.Ai` samt isoliertem Test wurde entfernt (kein Endpunkt/keine DI betroffen). Export (`TournamentExportFormatter`) und Health-/Dashboard bleiben unverändert kanonisch. Neue Tests sichern die kanonische Wissensbasis (gültig, providerlos, ohne Secrets/Owner-Pfade). Analyse: `docs/architecture/V041_RECONCILIATION.md`.
- Codex-Contributor-Starterpaket ergänzt: einfache Anleitung `docs/onboarding/CODEX_CHESS_CONTRIBUTOR.md`, wiederverwendbare Promptvorlage `docs/ai/templates/CODEX_CHESS_FEATURE.md`, Generator `scripts/New-ContributorTaskPrompt.ps1` (Backlog-kanonisch, nur Ready/In-Progress, Offline-Fallback, Issue-Text als untrusted Daten, Owner-Pfad-/Secret-Redaktion, friend-Pfadausschlüsse) und Abnahme `scripts/Test-ContributorKickoffReadiness.ps1` + Pester-Contract-Tests.

## 0.54.1 - Stabilisierung, Public-Gate und Runtime-Logging-Hotfixes

- RUN-54 stabilisiert: relative Development-Logpfade werden am Repo-Root-Anker ausgerichtet; installierte/portable Starts nutzen weiterhin explizite Logordner.
- Public-Gate nachgeschaerft: bekannte personenbezogene Test-/Doku-Anker im aktuellen Arbeitsstand forward-redacted und kuenftig im GitSafety/OpenSourceSafety-Scan blockiert.
- Externe Lookup-Live-Smokes verlangen jetzt eine bewusst gesetzte FIDE-ID per Parameter oder Environment; Offline-Tests verwenden synthetische Fixtures.
- `docs/reports/` als dauerhafte Gate-/Statusreport-Ablage freigeschaltet; generische Report-/Artefaktordner bleiben blockiert.
- `scripts/Invoke-LoggingReadiness.ps1` startet die isolierte App-Instanz ohne sichtbares Fenster.
- Public-History-Gate dokumentiert: aktuelle Dateien forward-safe; direkte Public-Freischaltung bleibt wegen Git-Historie nur per Clean Snapshot erlaubt.
- Version auf `0.54.1` angehoben.

## 0.54.0 - RUN-54 Runtime-Logging und logs-Verzeichnis

- Projektinternes `logs/`-Verzeichnis mit `README.md` und `.gitkeep` als dokumentierter Anker ergaenzt; echte Logdateien bleiben gitignored.
- WebApi um lokalen `BoundedFileLoggerProvider` erweitert: taegliche Logdateien, Groessenlimit, Retention und einfache Redaction typischer Secret-Muster.
- `appsettings.json` und `appsettings.Development.json` um FileLogging-Konfiguration erweitert; Development schreibt standardmaessig nach `logs/`.
- Desktop- und Portable-Starter setzen `SchachTurnierManager__LogDirectory`, erzeugen den Logordner und zeigen den Pfad bei Startproblemen an.
- `/api/health` meldet File-Logging-Status, Logordner, Retention und Maximalgroesse.
- `scripts/Invoke-LoggingReadiness.ps1` prueft isolierten App-Start, Health/Dashboard/API, erzeugte Logdateien und Querystring-Schutz in einem Upload-ZIP.
- `Clean-Generated.ps1` entfernt den fehlerhaften Altordner `System.Object[]` und loescht im `logs/`-Ordner nur generierte Dateien, nicht README/.gitkeep.
- Doku/Skills ergaenzt: `docs/architecture/RUNTIME_LOGGING.md`, `.agents/skills/runtime-logging.md`, README, AGENTS und Skriptuebersicht.
- Version auf `0.54.0` angehoben.

# Changelog

## 0.52.0 - RUN-52 Kollegenpaket-Frischlauf-Test

- **Frischlauf:** Neues `scripts/Invoke-ColleagueFreshRunTest.ps1` prueft das erzeugte Kollegenpaket in einem frischen Ordner: Entpacken, SHA256-Pruefsummen, Desktop-ZIP, Starter, WebApi-EXE, eingebettetes Dashboard, Health/API-Smoke und isolierten Datenpfad.
- **Portwahl:** Das Skript prueft den gewuenschten Loopback-Port und weicht automatisch auf den naechsten freien Port aus, statt unnoetige manuelle Fallback-Kommandos zu verlangen.
- **Release:** Neue Doku `docs/release/COLLEAGUE_FRESH_RUN_TEST.md` beschreibt den Kollegentest vor Weitergabe des Pakets.
- **Agenten/Skills:** Neuer Skill `.agents/skills/colleague-fresh-run.md` fuer Codex/Claude-Code-Releasechecks.
- **Qualitaet:** `OperationalGuardTests` prueft Frischlauf-Vertrag, Checksums, isolierten Datenpfad und Upload-ZIP-Konvention.
- **Version:** `0.51.1` → `0.52.0` (Health, `package.json`, `package-lock.json`).


## 0.51.1 - RUN-51 Kollegeninstallation RunBundle-Hotfix

- **Bugfix:** `scripts/Invoke-ColleagueInstallReadiness.ps1` erzeugt den Run-Ordner jetzt selbst und berechnet das Upload-ZIP deterministisch, statt Pipeline-Ausgaben von `New-RunLogBundle.ps1` in Variablen zu uebernehmen. Dadurch entstehen keine `System.Object[]`-Pfade mehr.
- **Readiness:** `RUN_DIR=...`, `KOLLEGENPAKET=...` und `UPLOAD_ZIP=...` bleiben maschinenlesbar; Fehler werden weiterhin im Run-ZIP dokumentiert.
- **Qualitaet:** `OperationalGuardTests` pruefen die robuste RunDirectory-/UploadZip-Behandlung im Kollegeninstallationslauf.
- **Scope:** Keine fachliche Turnierlogik geaendert.
- **Version:** `0.51.0` → `0.51.1` (Health, `package.json`, `package-lock.json`).

## 0.51.0 - RUN-51 Kollegeninstallation und Release-Paket

- **Kollegenpaket:** Neues `scripts/Invoke-ColleagueInstallReadiness.ps1` baut ein eigenstaendiges Paket mit Desktop-ZIP, Portable-ZIP, optionaler Setup-EXE, `README_START_HIER.txt`, Manifest und SHA256-Pruefsummen.
- **Installation:** Neue Doku `docs/release/COLLEAGUE_INSTALLATION.md` beschreibt Doppelklick-Start, Setup-Fallback, Healthcheck und Datenpfade fuer Kollegenrechner.
- **Agenten/Skills:** Neuer Skill `.agents/skills/colleague-installation.md`; `AGENTS.md` und `installer-packaging.md` verweisen auf die eigenstaendige Distribution ohne externe Projektabhaengigkeiten.
- **Qualitaet:** `OperationalGuardTests` prueft den Kollegeninstallationslauf, Artefaktregeln, Checksums und Dokumentation.
- **Version:** `0.50.4` → `0.51.0` (Health, `package.json`, `package-lock.json`).


## 0.50.4 - RUN-50 DPAPI-Pfadtrim-Hotfix

- **Bugfix:** `scripts/Get-LocalSecret.ps1` nutzt fuer relative Secret-Anzeigepfade jetzt `System.IO.Path.DirectorySeparatorChar`/`AltDirectorySeparatorChar` statt einer fehleranfaelligen `[char]'\\'`-Konvertierung. Dadurch bricht der DPAPI-Roundtrip nicht mehr beim Anzeigen von `.secrets/local/...`-Pfaden ab.
- **Qualitaet:** `OperationalGuardTests` schuetzen gegen eine Rueckkehr der PowerShell-`TrimStart`-Variante und pruefen die plattformrobuste Pfadtrim-Logik.
- **Scope:** Keine fachliche Turnierlogik geaendert.
- **Version:** `0.50.3` → `0.50.4` (Health, `package.json`, `package-lock.json`).

## 0.50.3 - RUN-50 DPAPI-Blob-Trim-Hotfix

- **Bugfix:** `scripts/Get-LocalSecret.ps1` liest lokale DPAPI-Dateien jetzt robust: abschliessende Zeilenumbrueche/Whitespace werden vor `ConvertTo-SecureString` entfernt, leere Dateien liefern eine klare Fehlermeldung.
- **Bugfix:** `scripts/Set-LocalSecret.ps1` schreibt den `ConvertFrom-SecureString`-Blob ohne abschliessende neue Zeile (`-NoNewline`).
- **Readiness:** `scripts/Invoke-SecretSafetyReadiness.ps1` prueft, dass die erzeugte `.dpapi.txt`-Datei nicht leer ist, bevor der Roundtrip gelesen wird.
- **Qualitaet:** `OperationalGuardTests` prueft DPAPI-Trim, Leerdatei-Diagnose und newlinefreie Speicherung.
- **Scope:** Keine fachliche Turnierlogik geaendert.
- **Version:** `0.50.2` → `0.50.3` (Health, `package.json`, `package-lock.json`).

## 0.50.2 - RUN-50 SecretSafety/UploadZip-Hotfix

- **Bugfix:** `scripts/Invoke-SecretSafetyReadiness.ps1` erstellt seinen Run-Ordner jetzt selbst und ist nicht mehr von der Host-/Pipeline-Ausgabe von `New-RunLogBundle.ps1 -CreateOnly` abhaengig. Dadurch bleibt der DPAPI-/Secret-Safety-Selftest auch im Release-Candidate-Orchestrator stabil.
- **Bugfix:** `scripts/New-RunLogBundle.ps1` gibt Run-/ZIP-Pfade maschinenlesbar ueber die Pipeline aus. Direkte Aufrufe zeigen den Pfad weiterhin an, verschachtelte Skripte koennen ihn aber korrekt in Variablen uebernehmen.
- **Bugfix:** `scripts/Invoke-ReleaseCandidateReadiness.ps1` validiert den erzeugten Upload-ZIP-Pfad und schreibt `UPLOAD_ZIP=...` nicht mehr leer aus.
- **Qualitaet:** `OperationalGuardTests` prueft jetzt die robuste RunDirectory-/UploadZip-Behandlung fuer ReleaseCandidateReadiness, SecretSafety und New-RunLogBundle.
- **Scope:** Keine fachliche Turnierlogik geaendert.
- **Version:** `0.50.1` → `0.50.2` (Health, `package.json`, `package-lock.json`).

## 0.50.1 - ReleaseCandidateReadiness RunDirectory-Hotfix

- **Bugfix:** `scripts/Invoke-ReleaseCandidateReadiness.ps1` erstellt den Run-Ordner jetzt selbst und gibt `RUN_DIR=...` aus, statt sich auf die Pipeline-Ausgabe von `New-RunLogBundle.ps1 -CreateOnly` zu verlassen. Dadurch bleibt `$runDirectory` auch innerhalb des Skripts gesetzt.
- **Fehlerbehandlung:** `FAILED.txt`, Artefaktmanifest und `UPLOAD_ZIP=...` werden auch bei Folgefehlern sauber in den Run-Ordner geschrieben.
- **Qualitaet:** `OperationalGuardTests` prueft die robuste RunDirectory-Erzeugung und verhindert eine Rueckkehr zur fehlerhaften Capture-Variante.
- **Scope:** Keine fachliche Turnierlogik geaendert.
- **Version:** `0.50.0` → `0.50.1` (Health, `package.json`, `package-lock.json`).

## 0.50.0 - RUN-50 Release/Ops, Logging und lokale Secrets

RUN-50 staerkt den Betriebs- und Release-Unterbau, bevor weitere Fachfeatures gestapelt werden.

- **Logging:** WebApi nutzt konfigurierte LogLevel, Single-Line-Konsole und Request-Logging ohne Querystrings/Secrets.
- **Konfiguration:** `appsettings.json` und `appsettings.Development.json` definieren sinnvolle LogLevel fuer Microsoft, EF Core und `SchachTurnierManager`.
- **Secrets:** `Get-LocalSecret.ps1` ergaenzt DPAPI-Readback; `Invoke-SecretSafetyReadiness.ps1` prueft lokalen DPAPI-Roundtrip und GitSafety.
- **Release:** `Invoke-ReleaseCandidateReadiness.ps1` prueft ReleaseGate, SecretSafety, Desktop, Portable, optional Installer und schreibt ein Release-Artefaktmanifest mit SHA256.
- **Agenten/Skills:** Neue Skills fuer Release Operations, Logging/Observability und Repository Security plus `docs/architecture/RELEASE_OPERATIONS.md`.
- **Tests:** Contract-/Guard-Tests pruefen Logging-Konfiguration, Secret-/Git-Safety, Release-Skripte und Agenten-Struktur.
- **Version:** `0.49.0` → `0.50.0` (Health, `package.json`, `package-lock.json`).

# Changelog

## 0.49.0 - RUN-15 Exportmanifest fuer Turnierleiter

RUN-15 erweitert Import/Export um ein maschinenlesbares Exportmanifest. Turnierleiter bekommen damit einen lokalen Downloadplan fuer Teilnehmer, Tabelle, Paarungen, Druckansicht und Audit-Bundles.

- **Exportmanifest:** Neuer Domain-Formatter `ExportDownloadManifestJson` erzeugt `*_Exportmanifest.json` mit Turnier-Metadaten, Checks, Downloadpfaden, Workflow und Privacy-Hinweis.
- **API:** Neuer Endpunkt `/api/tournaments/{id}/exports/manifest.json`.
- **UI:** Exportcenter bietet `Exportmanifest JSON` neben CSV, Druckansicht, Audit und Backup an.
- **Qualitaet:** Domain-Test prueft Schema, Downloads, Checks und lokale Datenschutzgrenze.
- **Readiness:** Neues `scripts/Invoke-ExportManifestReadiness.ps1` prueft ReleaseGate, Frontend-Build, API-/UI-Verdrahtung und Tests/Quellmerkmale.
- **Version:** `0.48.1` → `0.49.0` (Health, `package.json`, `package-lock.json`).

## 0.48.1 - RUN-11 Knowledge-Base-Readiness Parser-Hotfix

- **Bugfix:** `scripts/Invoke-KnowledgeBaseReadiness.ps1` nutzt bei Fehlermeldungen jetzt `${index}`/`${field}`, damit PowerShell Text wie `Topic 1:` nicht als fehlerhafte Variablenreferenz parst.
- **Scope:** Keine fachliche Aenderung an Chat-Hilfe, Wissensbasis, Pairing, Wertungen oder Datenmodell.
- **Version:** `0.48.0` → `0.48.1` (Health, `package.json`, `package-lock.json`).

## 0.48.0 - RUN-11 lokale Wissensbasis auslagern

RUN-11 trennt die lokale Chat-Hilfe weiter vom UI-Code: Die Wissensartikel und Schnellfragen liegen jetzt als gepflegte JSON-Wissensbasis unter `src/SchachTurnierManager.WebApp/src/knowledge/`.

- **Wissensbasis ausgelagert:** `localKnowledgeBase.json` enthaelt Topics, Keywords, Schritte, Quellen, Schnellfragen, Stand und Privacy-Hinweis.
- **UI entkoppelt:** `main.tsx` importiert die Wissensbasis statt lange Artikel direkt im Komponenten-Code zu halten.
- **Quellen/Version sichtbar:** Der Assistent zeigt Stand/Version der Wissensbasis und nutzt den Privacy-Hinweis aus der JSON-Datei.
- **Datenschutz-Grenze:** README-Regeln verhindern echte Turnierdaten, Logs, Secrets oder private Notizen in der Wissensbasis.
- **Readiness-Skript:** `scripts/Invoke-KnowledgeBaseReadiness.ps1` prueft JSON-Struktur, lokale Provider-Grenze, UI-Import und Frontend-Build.
- **Version:** `0.47.0` → `0.48.0` (Health, `package.json`, `package-lock.json`).

# Changelog

## 0.47.0 - RUN-10/11 lokale Chat-Hilfe und Wissensbasis

- Neuer lokaler Hilfe-Chat im Reiter **Assistent**.
- Regelbasierte Wissensbasis fuer Turnierstart, Pairing, Wertungen, Backup, QR/Handy, Import/Export und KI-Datenschutz.
- Kontextantworten beruecksichtigen ausgewaehltes Turnier und aktuelle Assistenten-Empfehlung.
- Schnellfragen und Chat-Export ergaenzt.
- Bewusst keine Claude/OpenAI/API-Anbindung, keine externen Requests, keine Secrets.
- Neues Readiness-Skript `scripts/Invoke-KnowledgeChatReadiness.ps1`.
- **Version:** `0.46.0` → `0.47.0` (Health, `package.json`, `package-lock.json`).

## 0.46.0 - RUN-17 lokaler Turnierassistent

RUN-17 fuegt einen ersten produktiven Turnierassistenten in der WebApp hinzu. Der Assistent
ist bewusst lokal und regelbasiert: Er nutzt Teilnehmerzahl, Zeitfenster, Bretter und Szenario,
sendet keine Daten an KI-Anbieter und benoetigt keine API-Keys.

- **Neuer Reiter:** `Assistent` als eigener Hauptbereich zwischen Uebersicht und Teilnehmern.
- **Formatempfehlung:** lokale Empfehlung fuer Schweizer System oder Jeder-gegen-Jeden,
  geplante Runden, benoetigte Bretter, Zeitbedarf und Punktesystem.
- **Szenarien:** Vereinsabend, Jugendturnier, Open, Blitz/Schnellschach, Chess960/Freestyle
  und Team/Mannschaft als klar markiertes Planungsszenario.
- **Turniertag-Hilfe:** Setup-Schritte, Turniertag-Checkliste, Export-/Veroeffentlichungsplan
  und Warnungen bei knapper Zeit, zu wenigen Brettern, grossen Feldern oder gewerteten Turnieren.
- **Uebernahme:** Empfehlung kann Neuanlage und Turniereinstellungen vorbefuellen; bestehende
  Turniere muessen Einstellungen danach bewusst speichern.
- **Readiness-Skript:** `scripts/Invoke-TournamentAssistantReadiness.ps1` prueft ReleaseGate,
  Frontend-Build und Assistenten-Quellmerkmale in einem Run-ZIP.
- **Version:** `0.45.0` → `0.46.0` (Health, `package.json`, `package-lock.json`).

## 0.45.0 - RUN-08 PWA-/Handy-Installationsbasis

RUN-08 beginnt die PWA-/Handy-Faehigkeit als echte Produktfunktion: Die WebApp wird
installierbar, bekommt ein Manifest, Icons, einen Service Worker und eine Readiness-Pruefung.
Die Turnierdaten-API bleibt bewusst network-only; es werden keine privaten Turnierdaten
offline im Service-Worker-Cache gespiegelt.

- **PWA-Manifest:** `public/manifest.webmanifest` mit App-Name, Standalone-Modus,
  Theme-Farbe, Kategorien und Icons.
- **Icons:** SVG-App-Icon und maskierbares Icon unter `public/icons/`.
- **Service Worker:** App-Shell-/statische Asset-Caches, aber expliziter Ausschluss von
  `/api/*`, damit Turnierdaten nicht unkontrolliert gecacht werden.
- **UI-Hinweis:** Header zeigt PWA-Status und, wenn der Browser es anbietet, einen
  Installieren-Button.
- **Readiness-Skript:** `scripts/Invoke-PwaReadiness.ps1` baut die WebApp, prueft
  Manifest, Icons, Service Worker und `index.html` und buendelt alles als Run-ZIP.
- **Version:** `0.44.2` → `0.45.0` (Health, `package.json`, `package-lock.json`).

## 0.44.2 - RUN-03 Portable-Manifest PowerShell-TrimStart-Hotfix

Hotfix zum RUN-03-Frischordner-Test: Der Portable-Build war weiterhin OK, aber die
Manifest-Auflistung brach auf Windows/PowerShell 7 ab, weil `TrimStart('\\','/')`
versehentlich einen zweizeiligen Backslash-String statt einzelner `char`-Werte uebergab.
Keine fachliche Turnier-, Pairing-, Persistenz- oder UI-Logik geaendert.

- **Manifest-Fix:** `scripts/Invoke-PortableFreshFolderTest.ps1` nutzt jetzt explizite
  `char[]`-Trimmzeichen und eine robuste Pfadsegment-Zaehllogik fuer die Tiefe-3-Liste.
- **RUN-03 bleibt Ziel:** frischer Portable-Ordner, Healthcheck, eingebettetes Dashboard,
  Turnierlisten-API und isolierter SQLite-Datenpfad werden weiter automatisch geprueft.
- **Version:** `0.44.1` → `0.44.2` (Health, `package.json`, `package-lock.json`).

## 0.44.1 - RUN-03 Portable-Manifest toleriert leere Datenordner

Hotfix zum RUN-03-Frischordner-Test: Das Portable-ZIP wurde korrekt gebaut, aber der
Test behandelte den leeren `data`-Ordner als zwingenden ZIP-Inhalt. `Compress-Archive`
uebernimmt leere Ordner unter Windows nicht verlaesslich; der Runtime-Smoke nutzt ohnehin
einen separaten isolierten Test-Datenordner. Keine fachliche Turnier-, Pairing-,
Persistenz- oder UI-Logik geaendert.

- **Manifest-Fix:** `scripts/Invoke-PortableFreshFolderTest.ps1` wertet `data` jetzt als
  optionalen leeren Ordner und schreibt einen klaren WARN-Hinweis statt den Lauf hart
  abzubrechen.
- **Robustere ZIP-Erkennung:** Der Test erkennt die Portable-Root anhand
  `Start-SchachTurnierManager.bat`, auch falls ein ZIP spaeter doch mit zusaetzlichem
  Wurzelordner erzeugt wird.
- **Bessere Diagnose:** Das Manifest listet den erkannten Portable-Root und relevante
  Dateien bis Tiefe 3 auf.
- **Version:** `0.44.0` → `0.44.1` (Health, `package.json`, `package-lock.json`).

## 0.44.0 - RUN-03 Portable-ZIP-Frischordner-Test

RUN-03 macht das Portable-Paket als Endnutzer-Artefakt belastbarer: nicht nur bauen,
sondern in einen frischen Ordner entpacken, isoliert starten und gegen Health/Dashboard/API
prüfen. Keine fachliche Turnier-, Pairing-, Persistenz- oder UI-Logik geändert.

- **Fresh-Folder-Smoke:** `scripts/Invoke-PortableFreshFolderTest.ps1` erzeugt einen
  Run-Ordner unter `D:\Temp`, führt optional ReleaseGate `-SkipPack`, baut das Portable-ZIP
  self-contained, entpackt es in einen frischen Testordner und startet die WebApi auf einem
  Testport.
- **Artefaktprüfung:** Manifest mit ZIP-Größe/SHA256, Pflichtdateien (`Start-...bat`,
  README, WebApi-EXE, `wwwroot/index.html`, `data`-Ordner) und Hashes.
- **Runtime-Smoke:** Healthcheck, eingebettetes Dashboard, Turnierlisten-API und SQLite-
  Datenpfad im isolierten Testdatenordner werden geprüft; Backend-stdout/stderr landen im
  Upload-ZIP.
- **Run-Log-Standard:** Der Lauf gibt am Ende nur `UPLOAD_ZIP=...` aus; Details liegen im
  ZIP.
- **Version:** `0.43.1` → `0.44.0` (Health, `package.json`, `package-lock.json`).

## 0.43.1 - CommitGuard lokal-only Handoff und Safety-Diagnose

Hotfix/Folgearbeit nach RUN-05: Der 0.42.6-Commit wurde nicht erstellt, weil ein bereits
lokal vorhandenes `NEXT_PROMPT.md` aus der externen Projekt-Registry automatisch mitgestaged
wurde. Diese Datei ist kein Produktartefakt und kann lokale Maschinenpfade oder interne
Blocker-Hinweise enthalten. Keine fachliche Turnier-, Pairing-, Persistenz- oder UI-Logik
geaendert.

- **Local-only Handoff:** `NEXT_PROMPT.md` wird nun in `.gitignore` ausgeschlossen und vom
  CommitGuard nicht automatisch gestaged. Bereits gestagte Altzustaende muessen einmalig per
  `git reset` entstaged werden; die Arbeitsdatei bleibt dabei erhalten.
- **GitSafety-Diagnose:** Staged-Content-Pruefung meldet kuenftig Datei und hinzugefuegte
  Zeile statt nur einen Sammelfehler. Das macht echte Treffer und False Positives schneller
  nachvollziehbar.
- **Safety-Grenze:** `NEXT_PROMPT.md` ist zusaetzlich als verbotener Commit-Pfad markiert;
  lokale Folgeprompt-/Registry-Dateien bleiben ausserhalb von Git.
- **Version:** `0.43.0` → `0.43.1` (Health, `package.json`, `package-lock.json`).

## 0.43.0 - RUN-05 Installer-Readiness und Testcheckliste

RUN-05 macht den vorbereiteten Inno-Setup-Installer pruefbar, ohne automatisch Downloads,
Installationen, Releases oder Kostenaktionen auszufuehren. Keine fachliche Turnier-,
Pairing-, Persistenz- oder UI-Logik geaendert.

- **Installer-Readiness:** `scripts/Invoke-InstallerReadiness.ps1` erzeugt einen ruhigen
  Run-Ordner unter `D:\Temp`, fuehrt optional ReleaseGate `-SkipPack`, Desktop-Publish und
  Installer-Build aus und buendelt Logs/Manifeste/Git-Status als Upload-ZIP.
- **Desktop-/Installer-Manifeste:** Der Readiness-Lauf prueft BAT, README, WebApi-EXE und
  eingebettetes `wwwroot/index.html`; bei Installer-Build werden Setup-EXE, Groesse und
  SHA256 dokumentiert.
- **Installer-Konfiguration:** `installer/SchachTurnierManager.iss` nutzt jetzt explizit
  `%LocalAppData%\Programs\SchachTurnierManager` als Per-User-Installationspfad und
  fuehrt Versionsmetadaten.
- **Build-Skript:** `scripts/Build-Installer.ps1` akzeptiert optional `-InnoSetupCompiler`
  und gibt bei erfolgreichem Build den SHA256 der Setup-EXE aus.
- **Doku:** `docs/release/INSTALLER_TEST_CHECKLIST.md` und `installer/README.md` beschreiben
  Readiness-Lauf, manuellen Installationstest, Datenpersistenz nach Neustart/Deinstallation
  und SmartScreen-Grenze fuer unsignierte EXE.
- **Version:** `0.42.6` → `0.43.0` (Health, `package.json`, `package-lock.json`).

## 0.42.6 - npm-Safe-Flags ohne PowerShell-Argumentfallen

Hotfix fuer den 0.42.5-Run-Log-Lauf: Der neue Run-Log-Bundler funktioniert, aber
PowerShell wertete `--fund=false` beim Skriptaufruf als Parametername statt als npm-Argument.
Keine fachliche Turnier-, Pairing-, Persistenz- oder UI-Logik geaendert.

- **NpmSafe:** `Invoke-NpmSafe.ps1` hat nun explizite Schalter `-NoAudit` und `-NoFund`.
  Das Skript erzeugt daraus intern die npm-Argumente `--no-audit` und `--fund=false`;
  aufrufende Skripte muessen keine dash-beginnenden Array-Werte mehr uebergeben.
- **Release-/Paketierungsskripte:** `Invoke-ReleaseGate.ps1`, `Pack-Portable.ps1` und
  `Publish-DesktopApp.ps1` verwenden `-NoAudit -NoFund`.
- **Run-Logging:** Das neue Log-ZIP-Verfahren bleibt unveraendert und soll fuer die naechsten
  Laeufe als Standard genutzt werden.
- **Version:** `0.42.5` → `0.42.6` (Health, `package.json`, `package-lock.json`).

## 0.42.5 - npm-Versionen pinnen und Run-Log-Bundles ergaenzen

Hotfix/Folgearbeit nach 0.42.4: Auf der Windows-Workstation funktioniert der direkte
Frontend-Build ueber `Invoke-NpmSafe.ps1`, aber `npm ci` landet bei der npm-config-Hilfe.
Keine fachliche Turnier-, Pairing-, Persistenz- oder UI-Logik geaendert.

- **npm-Reproduzierbarkeit:** WebApp-Abhaengigkeiten sind nun exakt auf den Lockfile-Stand
  gepinnt (`react`/`react-dom` 19.2.7, `vite` 8.0.16, `typescript` 6.0.3,
  `@vitejs/plugin-react` 6.0.2, Typings passend). Dadurch kann `npm install` verwendet
  werden, ohne erneut gegen `latest` aufzuloesen.
- **Release-/Paketierungsskripte:** `Invoke-ReleaseGate.ps1`, `Pack-Portable.ps1` und
  `Publish-DesktopApp.ps1` nutzen wieder `npm install`, aber weiter ueber
  `Invoke-NpmSafe.ps1` und mit `--no-audit --fund=false` fuer ruhigere Logs.
- **Run-Logging:** `Invoke-LoggedCommand.ps1` und `New-RunLogBundle.ps1` ergaenzt.
  Zukuenftige lokale Laeufe koennen ihre Detailausgaben in einem Run-Ordner unter
  `D:\Temp` sammeln und am Ende als ZIP hochladen.
- **Version:** `0.42.4` → `0.42.5` (Health, `package.json`, `package-lock.json`).

## 0.42.4 - npm-Installationsweg deterministisch auf package-lock umstellen

Hotfix fuer den Release-Gate-Abbruch unter Windows: `npm install` konnte wegen `latest`-
Abhaengigkeiten trotz vorhandener Lockdatei erneut Registry-Aufloesungen anstossen und dabei
ein nicht Windows-kompatibles Paket (`n@10.2.0`) ziehen. Keine fachliche Turnier-, Pairing-,
Persistenz- oder UI-Logik geaendert.

- **ReleaseGate:** nutzt bei vorhandener `package-lock.json` nun `npm ci` statt `npm install`.
  Dadurch wird exakt der eingecheckte Lockfile-Stand installiert und nicht neu gegen `latest`
  aufgeloest. Ohne Lockfile bleibt `npm install` der Fallback.
- **Paketierung:** `Pack-Portable.ps1` und `Publish-DesktopApp.ps1` verwenden denselben
  deterministischen npm-Installationsweg.
- **npm-Safe bleibt aktiv:** alle npm-Aufrufe laufen weiter ueber `Invoke-NpmSafe.ps1` mit
  isolierter temporaerer npmrc und lokaler `.secrets/local`-/`secrets/local`-Unterstuetzung.
- **Version:** `0.42.3` → `0.42.4` (Health, `package.json`, `package-lock.json`).

## 0.42.3 - npm-Safe-Runner Argumentbindung korrigiert

Hotfix fuer den 0.42.2-npm-Safe-Runner. Keine fachliche Turnier-, Pairing-,
Persistenz- oder UI-Logik geaendert.

- **Bugfix:** `Invoke-NpmSafe.ps1` nutzt nun explizite Parameter `-NpmCommand`,
  `-NpmScript` und optional `-NpmArguments`. Dadurch werden mehrteilige npm-Befehle wie
  `npm run build` nicht mehr teilweise als positionaler `Root`-Parameter gebunden.
- **Skriptaufrufe angepasst:** `Invoke-ReleaseGate.ps1`, `Pack-Portable.ps1` und
  `Publish-DesktopApp.ps1` verwenden die neue robuste Syntax.
- **Sicherheit bleibt erhalten:** npm laeuft weiter mit isolierter temporaerer `user.npmrc`,
  lokaler `.secrets/local`-/`secrets/local`-Erkennung und ohne `always-auth`-Altlasten.
- **Version:** `0.42.2` → `0.42.3` (Health, `package.json`, `package-lock.json`).


## 0.42.2 - Lokale Secret-/npm-Auth-Haertung

Sicherheits- und Build-Hygiene-Folgearbeit nach dem gruenen 0.42.1-Release-Gate.
Keine fachliche Turnier-, Pairing-, Persistenz- oder UI-Logik geaendert.

- **Lokale Secrets:** `.secrets/README.md` ergaenzt und `.gitignore` so erweitert, dass
  `.secrets/local/` genauso strikt lokal bleibt wie `secrets/local/`. `secrets/README.md`
  verweist auf `.secrets/local/` als bevorzugten Ort, bleibt aber als Legacy-Ablage dokumentiert.
- **DPAPI-Helfer:** `scripts/Set-LocalSecret.ps1` speichert lokale Werte Windows-Benutzer-
  gebunden unter `.secrets/local/<Name>.dpapi.txt`, ohne den Wert auszugeben.
- **npm-Safe-Runner:** `scripts/Invoke-NpmSafe.ps1` fuehrt npm mit einer isolierten temporaeren
  `tmp/npm-safe/user.npmrc` aus. Dadurch werden globale/userweite `.npmrc`-Altlasten nicht in
  Release-Gate, Portable- und Desktop-Publish hineingezogen; lokale npmrc aus `.secrets/local/`
  oder legacy `secrets/local/` wird bei Bedarf sicher verwendet. Veraltete `always-auth`-Zeilen
  werden entfernt.
- **Skripte verdrahtet:** `Invoke-ReleaseGate.ps1`, `Pack-Portable.ps1` und
  `Publish-DesktopApp.ps1` nutzen den npm-Safe-Runner.
- **CommitGuard:** blockiert getrackte oder gestagte lokale Secret-Ablagen unter
  `.secrets/local/` und `secrets/local/`.
- **Version:** `0.42.1` → `0.42.2` (Health, `package.json`, `package-lock.json`).

## 0.42.1 - Build-Fix nach Pull: Legacy-obj/bin sicher ausschließen

Fix für rote Release-Gate-Basis nach dem Pull auf 0.42.0. In bestehenden Worktrees konnten
alte `src/**/obj`-Dateien aus früheren Builds von den SDK-Compile-Globs wieder erfasst
werden, nachdem die aktiven MSBuild-Ausgaben nach `tmp/dotnet-*` umgeleitet wurden. Dadurch
entstanden doppelte Assembly-Attribute im Domain-Projekt.

- **Build-Fix:** `Directory.Build.props` schließt `**/bin/**` und `**/obj/**` nun explizit
  über `DefaultItemExcludes` und `DefaultItemExcludesInProjectFolder` aus. Stale
  `*.AssemblyInfo.cs`/`*.AssemblyAttributes.cs` unter alten Projekt-`obj`-Ordnern werden nicht
  mehr kompiliert.
- **Wartung:** `scripts/Clean-Generated.ps1` entfernt zusätzlich alte `bin`/`obj`-Ordner unter
  `src/` und `tests/` und schreibt eine kurze Abschlusszusammenfassung.
- **Version:** `0.42.0` → `0.42.1` (Health, `package.json`, `package-lock.json`).
- **Hinweis:** Nach dem Patch zuerst `Clean-Generated.ps1`, dann Release-Gate `-SkipPack`
  ausführen. Kein Feature-Scope, kein Push/Release.

## 0.42.0 - Desktop-Installation, Installer-Vorbereitung, i18n-Fundament, Codex-Roadmap

Installations- und Mehrsprachigkeits-Grundlagen ohne Aenderung an Auslosungs-, Wertungs-
oder Persistenzlogik. Alle 175 Tests bleiben gruen; Release-Gate (-SkipPack) vor und nach
den Aenderungen gruen.

- **Desktop-Variante (neu):** `scripts/Publish-DesktopApp.ps1` erzeugt ein self-contained
  win-x64-Paket unter `output\desktop` (kein .NET beim Endnutzer noetig), Frontend eingebettet
  in `wwwroot`, Klick-Start ueber `SchachTurnierManager.bat` (`scripts/Start-Desktop.bat`),
  Daten unter `%LocalAppData%\SchachTurnierManager` (Backend-Default). Smoke-getestet
  (Health + eingebettetes Dashboard aus dem publizierten Paket).
- **Installer vorbereitet:** `installer/SchachTurnierManager.iss` (Inno Setup 6, Per-User ohne
  Adminrechte, Desktop-/Startmenue-Verknuepfung, Uninstaller, Daten bleiben bei Deinstallation
  erhalten) plus `scripts/Build-Installer.ps1`. Kompilieren/Testen offen, da Inno Setup auf dem
  Build-Rechner noch nicht installiert ist (RUN-05).
- **Mehrsprachigkeit (Fundament):** dependency-freies i18n-Modul unter
  `src/SchachTurnierManager.WebApp/src/i18n/` mit `I18nProvider`, `useI18n()`/`t()`,
  Sprachumschalter im Header, localStorage-Persistenz, Browsersprach-Erkennung und RTL fuer
  Arabisch. 18 Sprachen registriert (de/en/es uebersetzt fuer Kern-Schluessel; fr, it, pt, nl,
  pl, cs, sv, da, hu, ru, uk, tr, ar, zh, ja als Stubs mit Fallback en→de). Hero/Statuskarte
  als Umstellungs-Muster auf `t('…')`; Rest folgt bereichsweise (RUN-21).
- **Bugfix UI:** veraltete hartcodierte Version „v0.40.0" im Hero-Header entfernt; dort wird
  jetzt die Backend-Version aus dem Health-Endpoint angezeigt.
- **Regel-Reconciliation:** `.gitignore` und CommitGuard (`scripts/Test-GitCommitSafety.ps1`)
  blockierten pauschal jeden `reports/`-Pfad und widersprachen damit dem KI-Lauf-Standard aus
  `AGENTS.md` („Abschlussberichte … werden mit committet"). Jetzt ist gezielt nur
  `docs/ai/reports/` commitfaehig (negative Lookbehind); generische `reports/`-Ordner und der
  Public-Clean-Snapshot schliessen Reports weiterhin aus.
- **Codex-Roadmap-Prompts (neu):** `docs/ai/prompts/codex-roadmap/` mit `PROMPT_BASE.md`
  (Arbeitsregeln), Index/Statustabelle und RUN-01 bis RUN-21 (Audit, Release-Reife, Portable,
  Desktop, Installer, Clean Snapshot, Website-Paket, PWA, Hosting-Konzept, Chatbot,
  Wissensbasis, FIDE-Dutch, grosse Turniere, Tie-Breaks, Import/Export, Formate, Assistent,
  QA, Doku, Release Candidate, i18n).
- **Version:** `0.41.1` → `0.42.0` (Health, `package.json`).
- **Bekannt/Offen:** GitHub war waehrend dieses Laufs nicht erreichbar (kein Pull/Push
  moeglich); beide lokale Checkouts standen synchron auf `dc8d0e1`. Vor dem naechsten Push
  zuerst `git pull` und PUBLIC-Gate.

## 0.41.1 - Operator-Smoke und haengesicherer Verifikationslauf

Turniertags-Reife: ein einziger, **haengesicherer** Skript-Lauf verifiziert die wichtigsten
Operator-Workflows end-to-end gegen ein frisches Backend. **Keine Aenderung an Auslosungs-,
Wertungs- oder API-Logik** – ausschliesslich Verifikation, Timeouts und Doku. Alle Spieler
synthetisch; keine echten Daten/Exporte committet (`output/**` ist ignoriert).

- **`scripts/Smoke-OperatorWorkflow.ps1` (neu):** startet optional ein isoliertes Backend
  (eigener Port 5099, Temp-Datenverzeichnis aus dem frischen Release-Binary), prueft Health,
  Swiss 12/5 (genau 5 Runden, keine 6., **keine vermeidbaren Rematches** direkt aus den
  Paarungen, Audit-Export), Round-Robin-Late-Entry-Sperre, manuelle Paarung (gueltig/
  Self-Pairing/Doppelspieler), Backup/Restore (Export→Delete→Import) und Chess960-Wuerfeln
  hinter dem QR-Flow. Liefert `OK/FEHLER`-Summe und klaren Exit-Code (0/1/2).
- **Haenge-Schutz:** jeder HTTP-Aufruf hat ein TimeoutSec; der Backend-Start wartet maximal
  `-StartTimeoutSeconds` mit Heartbeat und sauberem Exit-Code; das selbst gestartete Backend
  wird im `finally` als Prozessbaum beendet (kein zurueckbleibender Listener) und das Temp-
  Datenverzeichnis entfernt. **Pre-Flight-Port-Check:** ist der Port belegt, bricht der Smoke
  bewusst ab, statt sich still gegen ein fremdes/veraltetes Backend zu verbinden.
- **Doku:** Runbook (Generalprobe), Friday-Checklist (Startcheck) und Operator-Card um den
  Smoke-Lauf und das Timeout-/Stop-Verhalten ergaenzt; QR-Vorabtest dort verankert.
- **Version:** `0.41.0` → `0.41.1` (Health, `package.json`). 175 Tests bleiben gruen.

## 0.41.1 - Operator-Readiness-Smoke und Runbook-Haertung

Release-Candidate-Vorbereitung nach der Swiss-Engine-Haertung. Fokus: Turniertagsfaehigkeit,
Startpaket, lokale Verifikation und klare Grenzen. Keine neue Pairing-Architektur, keine
Auslosungs- oder Wertungslogik geaendert. Alle Smoke-Daten sind synthetisch.

- **Operator-Smoke-Skript:** `scripts\Smoke-OperatorWorkflow.ps1` startet isolierte lokale
  API-Prozesse, prueft Health, Swiss 12/5 inkl. Audit-Export und Rundenlimit, Round-Robin 6
  vollstaendig, Round-Robin-Late-Entry-Sperre, Manual-Pairing-Guards, Backup/Restore in zweitem
  Datenpfad sowie Chess960-Einzelbrett/QR-URL-Form. Artefakte landen unter `output\...` und sind
  ignoriert; API-Daten liegen in temporaeren synthetischen Datenpfaden.
- **Runbook/Checklisten:** Turniertagsablauf geschärft: `PlannedRounds`/MaxRounds vor Start
  gegenpruefen, Audit-Bundle nach jeder Runde exportieren, Backup/Restore klarer trennen,
  QR/Chess960-Vorabtest vor Ort dokumentieren, Late Entry je Format erklaeren, Swiss-Grenzen
  (kein vollstaendiges FIDE-Dutch, >20 Spieler Greedy-Fallback) sichtbar halten.
- **Portable-Paket robuster lokal baubar:** `Pack-Portable.ps1` und `Invoke-ReleaseGate.ps1`
  nutzen vorhandene `node_modules`, statt bei jedem Paketbau ein `npm install` zu erzwingen.
  Das vermeidet Windows-`EPERM unlink` bei gesperrten Node-Dateien; in sauberer Umgebung
  installieren sie weiterhin per `npm ci`/`npm install`. `dotnet publish` nutzt vorhandene
  Restore-Artefakte mit `--no-restore`.
- **Startpaket-Grenzen:** Dev-Start und Portable-Paket bleiben lokale Werkzeuge; keine Cloud,
  keine Uploads, keine Releases/Tags.

## 0.41.0 - Schweizer-System V2: global optimale Paarung (vermeidbare Rematches eliminiert)

Folgearbeit zum Bergfest-Postmortem („falsche/wiederholte Paarungen"). Die Schweizer-Engine
war eine reine Greedy-Heuristik, die sich früh festlegte und spätere Spieler in **vermeidbare
Rematches** zwingen konnte. Reproduziert über viele zufällige Verläufe: schon ab 8 Spielern
trat das Problem ab Runde 4 in der Mehrzahl der Fälle auf. Details: `docs/SWISS_PAIRING_ENGINE.md`.
Alle Tests mit synthetischen Spielern.

- **Global optimales Minimum-Penalty-Matching:** Statt Spieler nacheinander zu paaren, minimiert
  die Engine jetzt die Gesamtstrafe über alle Bretter (exakte Maximum-Weight-Matching-Suche per
  Bitmasken-DP für Felder bis 20 Spieler). Die Strafmodelle (Punktdifferenz, Farbbilanz/Präferenz/
  dritte gleiche Farbe) bleiben; die Rematch-Strafe dominiert nun sicher alles andere.
- **Rematch nur wenn unvermeidbar:** Garantie – ein Rematch entsteht ausschließlich, wenn es
  keine rematchfreie Gesamtauslosung mehr gibt. Genau dann meldet das Audit „Rematch unvermeidbar
  (global optimiert …)". Bye-Vergabe, Farbentscheidung und die komplette Pairing-Forensik bleiben
  unverändert und beschreiben automatisch das verbesserte Ergebnis.
- **Große Felder (> 20 Spieler):** bewusster, im Audit gekennzeichneter Greedy-Fallback, bis ein
  vollständiges FIDE-Dutch verfügbar ist (Roadmap „Swiss v2" in `docs/SWISS_PAIRING_ENGINE.md`).
- **Algorithmuskennung:** `Swiss-ScoreGroup-Greedy-V2` → `Swiss-ScoreGroup-Optimal-V2`.
- **Tests:** Neue Invariante `SwissPairingOptimalMatchingTests` über 8/10/12/13/16 Spieler und
  6–7 Runden × 60 Seeds: nie ein vermeidbares Rematch (reproduzierte den alten Greedy-Defekt und
  sichert den Fix). Bestehende Swiss-Golden-/Regression-/Advanced-Tests bleiben grün.
- **Version:** `0.40.4` → `0.41.0` (Health, `package.json`). Runbook 5a und Roadmap aktualisiert.

## 0.40.4 - Audit-Journal-Forensik: Pairing-Diagnostik, Datei-Spiegel und Export-Bundle

Folgearbeit zum Bergfest-Postmortem: Die dort benannte Forensik-Lücke („Audit-Journal existiert
in der DB, wurde aber nicht exportiert/gesichert") ist geschlossen. **Keine Änderung an
Auslosungs- oder Wertungslogik** – ausschließlich Diagnose, Persistenz und Export. Details in
`docs/AUDIT_JOURNAL.md`. Alle Tests mit synthetischen Spielern; keine echten Daten/Exporte committet.

- **Pairing-Forensik je Runde (`PairingForensics`):** Bei Vorschau und Auslosung wird ein
  unveränderlicher Entscheidungs-Snapshot aus dem Stand **vor** der Runde festgehalten – Format,
  geplante/aktuelle Runde, aktive/inaktive Spielerzahl, offene Vorrundenergebnisse, Bretter/Byes/
  manuelle Paarungen, Rematches, Scoregruppen-Abweichungen, Farbfolgerisiken, Qualitätswert sowie
  die vorgeschlagenen Paarungen je Brett (Punkte vor der Runde, Differenz, Flags). Reine Diagnose
  über den bestehenden `PairingQualityAnalyzer`.
- **Mehr auditierte Ereignisse:** Runde-Vorschau erzeugt, Turnier gelöscht, **blockierte
  Auslosungen** (Rundenlimit, Round-Robin-Roster-Sperre, offene Vorrunde, zu wenige Spieler) und
  Audit-Export werden jetzt protokolliert. So taucht z. B. der Rundenlimit-Blocker beim Versuch
  einer zu vielen Runde nachvollziehbar im Journal auf.
- **Append-only Datei-Spiegel (`FileAuditJournalSink`):** Jedes Audit-Ereignis wird zusätzlich zur
  DB in eine JSONL-Datei pro Turnier unter `%LocalAppData%\SchachTurnierManager\audit\` geschrieben
  (außerhalb des Repos). Der Spiegel überlebt DB-Verlust und `Reset`. **Fehlertolerant:** Ein
  Schreibfehler bricht den Turnierschritt nie ab, sondern erzeugt einen sichtbaren
  `AuditJournalMirrorFailed`-Warneintrag.
- **Forensisches Export-Bundle:** Neue Endpunkte
  `GET /api/tournaments/{id}/audit-journal/export.jsonl` und `…/export.json` liefern ein in sich
  geschlossenes Bundle (Manifest, vollständiger Turnier-Snapshot, Pairing-Forensik je Runde, alle
  Audit-Ereignisse). Dateiname `Turniername_round{n}_{Zeitstempel}_audit.jsonl/json`. WebApp:
  Buttons „Audit-Bundle (JSONL)/(JSON)" in der Audit-Karte. Skript:
  `scripts\Export-TournamentAudit.ps1` (speichert lokal nach `output\audit\`, kein Upload).
- **Tests (+12 → 170 gesamt):** Audit deckt create/add-player/preview/next-round/result/
  manual-pairing/chess960/reset/delete ab; Schreibfehler im Spiegel wirft nicht und liefert eine
  Warnung; Rundenlimit-Blocker und Round-Robin-Late-Entry-Blocker sind auditierbar; Late-Entry-
  Swiss ist auditierbar; Export-Bundle (JSONL/JSON) ist self-contained. Plus
  `FileAuditJournalSink`-Tests (append-only, Verzeichnis-Anlage). HTTP-Smoke (Port 5099, isoliertes
  Datenverzeichnis): Export 200 mit korrektem Dateinamen, Rundenlimit-Blocker im Bundle, Datei-Spiegel
  geschrieben.
- **Version:** `0.40.3` → `0.40.4` (Health, `package.json`).

## 0.40.3 - Bergfest-Postmortem: Stabilisierung Rundenlimit, Late Entry, Round-Robin, DB-Start

Nach dem realen Bergfest-Turnier (Freitag, 2026-06-19): harte Ursachenanalyse und gezielte
Stabilisierung statt neuer Features. Details in `docs/POSTMORTEM_BERGFEST_2026.md`.

- **Jeder-gegen-jeden / Round-Robin – Late Entry & Rückzug nicht mehr stillschweigend
  rückwirkend:** `TournamentService.GetNextRoundRobinRound` berechnete bei jeder Auslosung den
  kompletten Spielplan aus den aktuell aktiven Spielern neu. Kam ein Spieler nach Runde 1 dazu
  (oder zog sich zurück), verschob das die Circle-Methode und machte bereits gespielte Runden
  inkonsistent (falsche Farben, Rematches, falsche Byes, abweichende Rundenzahl). Jetzt **harte
  Sperre mit klarer Meldung**: Der Teilnehmerkreis ist ab Runde 1 fixiert; nachträgliche
  Änderungen erfordern bewusste Neuplanung (Zurücksetzen/Neuanlage). Bestätigt per Domain-/
  Application-Test und HTTP-Smoke (HTTP 400 mit Hinweis „Spielplan ab Runde 1 fixiert").
- **SQLite-Start robust + verständliche Diagnose:** Der Backend-Start (`Program.cs`) prüft das
  Datenverzeichnis jetzt vorab auf Existenz/Schreibrechte (`DatabaseStartupDiagnostics.Probe`)
  und fängt Fehler bei `EnsureCreated()` ab. Statt eines kryptischen Stacktraces
  („SQLite Error 10: 'disk I/O error'" beim WAL-Pragma, real am Turniertag aufgetreten) gibt es
  eine mehrzeilige, handlungsorientierte Klartextmeldung (Pfad, Schreibbarkeit, Ursachen wie
  OneDrive/Antivirus/zweite Instanz/Reststände) und einen sauberen Exit-Code (2), den das
  Startskript erkennen kann. Keine riskante Schema-/Journal-Migration.
- **Rundenlimit zusätzlich abgesichert:** Die bestehende harte Sperre `EnsureCanCreateNextRound`
  (keine Runde über `PlannedRounds` hinaus – greift bei `next-round`, Preview, Round-Robin und
  Swiss gleichermaßen) ist nun durch explizite Szenario-Tests (Swiss 12 Spieler / 5 Runden und
  6 Runden) und einen HTTP-Smoke (HTTP 400 „maximale Rundenzahl") fest verankert.
- **Neue Tests (Application/Infrastructure):** Postmortem-Szenarien mit synthetischen Spielern –
  Rundenlimit (Swiss 5/6 Runden), Late Entry nach Runde 2/4 mit 0 Punkten und unveränderten
  Altrunden, Rückzug, Reaktivierung, doppelte FIDE-ID, manuelle Paarung (Persistenz + als
  gespielt gewertet + Schutz gegen Doppelpaarung/inaktive Spieler), Round-Robin 4/5/6/12/13
  Spieler (jede Paarung genau einmal, Byes korrekt, Rundenlimit), Round-Robin Late Entry/Rückzug
  blockiert. Plus DB-Startdiagnose-Tests (schreibbar, readonly, Hinweistexte).
- Keine Änderung an Schweizer-Paarungs-, Wertungs-, Such-/Dedupe- oder Chess960-Logik. Versionen
  auf `0.40.3`.

## 0.40.2 - Chess960-Würfeln pro Brett (Modal mit Reitern, lokaler QR-Code)

- Neuer **„🎲 Würfeln"-Button pro Brett** in der Rundentabelle (Chess960-Spalte). Öffnet ein
  Popup für genau dieses Turnier/Runde/Brett mit Turniername, Runde, Brettnummer, Paarung,
  aktuell gespeicherter Stellung und Überschreib-Warnung. Der bestehende Button für alle
  Bretter einer Runde bleibt unverändert.
- **Interne Reiter im Popup:** „Browser würfeln" (Default) und „QR / Handy" – ohne neuen
  Browser-Tab für die Hauptnavigation, auch bei schmaler Breite bedienbar.
- **Schritt-für-Schritt-Würfel:** Der 3D-Würfel arbeitet die acht Felder der Grundreihe von
  links nach rechts ab und zeigt die Figuren (König, Dame, Turm, Läufer, Springer). Danach
  „Für Brett speichern", „Nochmal würfeln" oder „Abbrechen". Die Animation ist Visualisierung;
  gespeichert wird die vorab gewürfelte Positionsnummer, die der Domain-Service
  `Chess960PositionService` erneut als gültige Stellung ableitet (Läufer verschiedenfarbig,
  König zwischen den Türmen). Vorhandene Stellungen werden nur nach Rückfrage überschrieben.
- **QR / Handy lokal:** QR-Code (eingebetteter, abhängigkeitsfreier Generator – kein Cloud-
  Dienst, kein Tunnel, kein externer Upload) plus kopierbare LAN-URL und Feld für die
  Laptop-IP. Eigene mobile Würfelseite über `/?dice=<id>&round=<r>&board=<b>`, die nur dieses
  Brett anzeigt und denselben Backend-Endpunkt nutzt. Schlägt die QR-Erzeugung fehl, bleiben
  URL-/Kopier-Funktion und die Browser-Würfelfunktion uneingeschränkt nutzbar.
- **Backend:** Neuer Single-Board-Endpunkt
  `POST /api/tournaments/{id}/rounds/{round}/chess960/start-positions/{board}`
  (optional `overwriteExisting`, `seed`, `positionNumber`). Nutzt weiterhin den bestehenden
  `Chess960PositionService`; ändert nur das gewählte Brett, lässt andere Bretter und Ergebnisse
  unberührt. Neue Tests für gültige Stellung, Isolierung anderer Bretter, Persistenz und
  Überschreib-Schutz.
- **LAN/Start:** `vite --host 0.0.0.0` (localhost bleibt erreichbar) für Handy-Zugriff im
  gleichen WLAN/Hotspot; `Start-Dev.ps1` zeigt nur lesend die möglichen Laptop-IPv4-Adressen
  und Firewall-/`localhost`-Hinweise an. Keine Firewall-/Systemänderung, kein Prozess-Kill.
- Keine Änderung an Auslosungs-, Wertungs-, Such-, Dedupe- oder Ergebnislogik. Versionen auf
  `0.40.2`.

## 0.40.1 - Turniertag-Startfix (Ein-Klick-BAT, Operator-Leiste nicht mehr fixiert)

- Neue klickbare Startdatei `RUN_TURNIERMANAGER.bat` im Repo-Root: startet Backend,
  Frontend und Browser. Nutzt `pwsh`, sonst `powershell`, jeweils mit `-ExecutionPolicy
  Bypass` nur prozesslokal (keine Änderung der globalen ExecutionPolicy, keine Adminrechte).
  Behebt das Problem, dass `Start-Dev.ps1` wegen fehlender Signatur direkt blockiert wurde.
- `scripts/Start-Dev.ps1` robuster: pwsh-/powershell-Fallback für die Teilfenster und
  Port-Prüfung für 5088/5173 (läuft ein Dienst bereits, wird er weiterverwendet statt hart
  zu crashen oder Prozesse aggressiv zu killen).
- Operator-Leiste ist nicht mehr `sticky`/fixiert: sie bleibt oben im normalen
  Dokumentfluss und blockiert beim Scrollen keinen Platz mehr. Schnellaktionen (Backup,
  Turnierpaket drucken, Rundenblatt drucken, nächster Schritt) und der Turniertag-Modus
  bleiben unverändert funktionsfähig.
- Keine Änderung an Auslosungs-, Wertungs-, Such-, Dedupe-, Chess960- oder Persistenzlogik.
  Versionen auf `0.40.1`.

## 0.40.0 - Turniertag-Härtung (Outdoor-Modus, Sticky-Leiste, Backup-Hinweise)

- Neuer „Turniertag-Modus" (Outdoor): ein CSS-Klassen-Umschalter in der Operator-Leiste
  vergrößert Schrift und Buttons und erhöht den Kontrast für den Einsatz draußen.
  Die Einstellung wird lokal (localStorage) gespeichert und wirkt ohne Reload.
- Operator-Leiste bleibt jetzt beim Scrollen oben sichtbar (sticky) und bietet
  Schnellaktionen: Backup erstellen, Turnierpaket drucken, Rundenblatt drucken.
- Neuer Backup-Status-Chip („Letztes Backup" / „Backup empfohlen"). Nach Auslosung
  und Chess960-Würfeln erscheint ein klarer Backup-Hinweis. „Jetzt Backup erstellen"
  lädt einen lokalen JSON-Snapshot mit Turniername, Runde und Zeitstempel (keine Cloud);
  der Zeitpunkt des letzten Backups wird pro Turnier lokal gemerkt.
- Ergebnis-Eingabe robuster: sichtbare „Speichere …" / „✓ Ergebnis gespeichert"-Bestätigung
  und klare Fehlermeldung, wenn das Speichern fehlschlägt. Auslosungs-Blocker bei offenen
  Ergebnissen bleibt unverändert.
- Reset/Delete sicherer: Bestätigungsdialoge nennen den Turniernamen und den Unterschied
  (Reset behält Teilnehmer/Einstellungen, löscht Runden/Ergebnisse/Chess960; Delete entfernt
  das ganze Turnier). Delete verlangt zusätzlich die exakte Eingabe des Turniernamens.
- Aufklappbare „Vor-Ort-Checkliste & Laptop-Hinweise" in der Operator-Leiste (rein statisch).
- Neues schreibgeschütztes Skript `scripts/Show-EventReadiness.ps1`: prüft nur lesend
  Backend, Frontend-Port, DB-Pfad, Backup-Ordner und Git-Status. Keine Systemänderung.
- QR/LAN bewusst noch nicht implementiert (Roadmap-Hinweis im UI).
- Keine Änderung an Auslosungs-, Wertungs- oder Dedupe-Logik. Versionen auf `0.40.0`.

## 0.39.0 - Operator-Bedienleiste und Druck-/Backup-Polish

- Neue Operator-Bedienleiste oben im Dashboard: Backend-Status, gewähltes Turnier,
  aktuelle Runde, offene Ergebnisse und ein klarer „Nächster Schritt" mit Direkt-Aktion
  (Runde 1 auslosen / Ergebnisse eintragen / Vorschau erzeugen / Abschluss prüfen).
- Health-Endpunkt liefert zusätzlich den vollständigen Datenbankpfad; die Bedienleiste
  zeigt Pfad, Autosave-Hinweis und Backup-Erinnerung vor Runde 1.
- Rundenblatt-Druck und Turnierbericht zeigen jetzt das Druckdatum; offene Bretter
  erhalten auf dem Rundenblatt ein leeres, beschreibbares Ergebnisfeld.
- Teilnehmerliste in der Druckansicht enthält jetzt FIDE-ID, Jahrgang und ca.-Alter.
- Neues lokales Backup-Skript `scripts/Backup-BergfestTournament.ps1` (nur lokaler
  JSON-Export nach `D:\Schach\Backups`, keine Cloud, keine echten Beispieldaten).
- Versionen auf `0.39.0` angehoben.

## 0.38.7 - Bergfest-Operatorunterlagen und Dry-run-CLI-Fix

- Freitag-Unterlagen ergänzt/geschärft: Operator Card, 09:30-Startcheck, Backup,
  Papier-/CSV-Fallback und Vorgehen bei Rematch-Warnungen.
- `scripts/New-DemoTournament.ps1` akzeptiert zusätzlich den freitags verwendeten
  Parameteralias `-Players`.
- WebApi-Start nutzt explizit Console-Logging, damit lokale Startfehler nicht vom
  Windows-EventLog-Provider verdeckt werden.
- Kleiner Testvertrag dokumentiert den `-Players`-Alias im Demo-Skript.

## 0.38.6 - Tie-Break-Roadmap und Virtual-Opponent-Modell für ungespielte Runden

- `docs/FEATURE_ROADMAP.md` (P1–P5) und `docs/IMPORT_EXPORT_ROADMAP.md` ergänzt.
- Reines, getestetes Domain-Modell `UnplayedRoundTiebreak` mit `UnplayedRoundBuchholzMode`
  für die FIDE-Behandlung eigener ungespielter Runden (C.07/2024 Art. 16.4, virtueller Gegner).
- Unit-Tests für gespielte Partie, kampflosen Sieg, Bye, konfigurierbare Wertung und
  vorbereitete Buchholz-Cut-Liste.
- `docs/TIEBREAK_UNPLAYED_ROUNDS.md` dokumentiert Modell, Annahmen und Integrationspfad.
- Bewusst noch nicht in `StandingsCalculator` verdrahtet (Default = bisheriges Verhalten,
  keine Wertungs-Regression).

## 0.38.7-struktur (Parallelstand D:\Schach) - Projektstruktur und KI-Agentenarchitektur

- Gliedert `docs/` in `architecture/`, `planning/` und `handoffs/`; verschiebt 67 historische Handoff-Dokumente nach `docs/handoffs/` (per `git mv`, nichts gelöscht).
- Verschiebt 70 historische After-Apply-Skripte nach `scripts/archive/after-apply/`; aktive Skripte bleiben bewusst flach unter `scripts/` (Zielstruktur `dev/test/release/git/security/maintenance` dokumentiert).
- Zieht die Pfadmuster in `Test-GitCommitSafety.ps1`, `Test-RepositoryOpenSourceSafety.ps1` und `New-OpenSourceSnapshot.ps1` auf die neuen Archivpfade nach; `docs/handoffs/` und `scripts/archive/` sind vollständig vom Public Snapshot ausgeschlossen.
- Ergänzt `docs/architecture/AI_AGENT_ARCHITECTURE.md` (providerneutrale Agentenregeln, austauschbare Ausführende, Skills als Wissensebene, Security-Gate, Clean-Snapshot-Pflicht) und `docs/planning/PROJECT_ORCHESTRATION.md` (Aufgaben→Skripte/Skills, Release-Gate, CommitGuard, Clean Snapshot, Handoff-Erzeugung).
- Macht `AGENTS.md` explizit providerneutral und ergänzt eine Projektstruktur-Sektion; `.claude/CLAUDE.md` als reiner Adapter ohne eigene Regeln.
- Ergänzt Übersichts-READMEs für `docs/`, `docs/handoffs/`, `scripts/` und `scripts/archive/after-apply/`; README um Projektstruktur erweitert.

## 0.38.6-commitguard (Parallelstand D:\Schach) - CommitGuard ohne blindes Stage und Clean Snapshot

- Härtet `scripts/Commit-If-Green.ps1`: kein blindes `git add --all` mehr, sondern explizites Staging zuvor angezeigter und geprüfter Pfade.
- Härtet `scripts/Test-GitCommitSafety.ps1` und `scripts/Test-RepositoryOpenSourceSafety.ps1` gegen False Positives aus eigenen Patternquellen.
- Blockiert zusätzlich `.codex`, `.vs`, Logs, Reports und typische lokale Artefaktpfade.
- Ergänzt Repository-Art-Prüfung, damit Arbeits-/TFS-Remotes nicht versehentlich mit dieser privaten Commit-Automation bearbeitet werden.
- Ergänzt `scripts/New-OpenSourceSnapshot.ps1` als Grundlage für einen späteren Public Snapshot ohne Git-Historie.
- Ergänzt Repository-Sicherheitsregeln in `AGENTS.md` und als Skill `.agents/skills/repository-security.md`.
- Behebt einen False Positive: Eigene Security-/Detection-Skripte (Marker `SECURITY-PATTERN-FILE`, u. a. `scripts/New-OpenSourceSnapshot.ps1`) werden nicht mehr als Credential-Leak gemeldet; echte Secrets in normalen Projektdateien werden weiterhin erkannt.
- `scripts/Test-GitCommitSafety.ps1` führt den Tracked-File-Scan jetzt auch bei sauberem Arbeitsbaum aus (kein Frühabbruch mehr).
- `scripts/Test-RepositoryOpenSourceSafety.ps1` ist nun ein eigenständiger, strengerer Public-Snapshot-Auditor mit maschinen- und menschenlesbarem Report unter `output/repo-open-source-safety/`.
- Dokumentiert, dass externe Toolfehler in PowerShell nicht über Semikolon-Ketten verdeckt werden dürfen (`a; git commit` committet trotz Fehler); für manuelle Abläufe einzelne Befehle, `&&` oder `Commit-If-Green.ps1` nutzen.

## 0.38.5 - Commit-Guard-Fix und Clean-Current-Baseline

- Entfernt fehlgeschlagene v0.38-Zwischenpatch-Dateien aus dem aktuellen Arbeitsstand.
- Repariert den Git-Sicherheitscheck, damit er eigene Prüfpattern nicht mehr selbst als Treffer blockiert.
- Prüft staged Diffs nur auf neu hinzugefügte Zeilen, damit Löschungen alter belasteter Dateien möglich bleiben.
- Hält lokale Audit-/Backup-Verzeichnisse und Paket-Backups konsequent aus künftigen Commits heraus.
- Bestätigt weiterhin: Das private Repo wird wegen der Historie nicht direkt öffentlich geschaltet; Open Source erfolgt später als Clean Snapshot.
## 0.38.4 - Commit-Guard-Härtung und Lockfile-Fix

- Repariert die v0.38.3-Anwendung bei package-lock.json-Dateien mit leerem Root-Package-Key.
- Erzwingt public npm Registry im WebApp-Projekt und blockiert interne Registry-URLs im Lockfile.
- Härtet Commit-If-Green und Git-Safety-Prüfungen gegen lokale Audits, Backups, Artefakte, interne URLs und typische Secret-Muster.
- Aktualisiert README auf den aktuellen Stand und dokumentiert Clean-Snapshot-Empfehlung für Open Source.

## 0.38.0 - README und Safe Commit Guard

- README/GitHub-Startseite auf den aktuellen Funktionsstand bis 0.37.6 aktualisiert.
- `.gitignore` um typische Build-Artefakte, lokale Daten, Logs, Dumps, Archive und Secret-Dateien erweitert.
- `scripts/Test-GitCommitSafety.ps1` ergänzt: prüft geänderte Dateien vor Commit auf Artefakte, große Dateien und typische Secret-Muster.
- `scripts/Commit-If-Green.ps1` ersetzt: Release-Gate, Sicherheitsprüfung vor/nach Stage, Dateiübersicht und erst danach Commit/Push.
## 0.37.3

- Fix: fehlerhaft eingefügten Audit-Journal-Query-Endpunkt entfernt und syntaktisch robust neu eingefügt.
- Queryparameter werden über HttpRequest gelesen, damit die Minimal-API-Signatur stabil bleibt.
- Release-Gate bleibt verpflichtend: Restore, Build, Tests, Frontend-Build und Portable-Paket.

## 0.37.2

- Fix: Audit-Journal-Query-API-Fixscript repariert; keine PowerShell-Backtick-/Unicode-Escape-Falle mehr in eingebetteten Markdown-Texten.
- Query-Endpunkt wird robust vor stabilen WebApi-Tokens eingefügt, notfalls vor app.Run().
- Release-Gate bleibt verpflichtend: Restore, Build, Tests, Frontend-Build und Portable-Paket.
## 0.36.1 - Audit-Journal Query Testfix

- Fehlendes `using Xunit;` in den AuditJournalQueryServiceTests ergänzt.
- v0.36.0-Query-Fundament bleibt fachlich unverändert; der Fix behebt nur den Test-Build.
## 0.36.0 - Audit-Journal Query Foundation

- AuditJournalQueryService ergänzt, um das persistente Audit-Journal nach Schweregrad, Aktion, Runde, Brett, Spieler und Freitext zu filtern.
- AuditJournalStatistics ergänzt für Info-/Warn-/Kritisch-Zählungen sowie Runden-, Brett- und Spielerbezüge.
- Regressionstests für Sortierung, Paging, Suche und Statistikzählungen ergänzt.
## 0.35.3 - Audit Journal Dashboard Fix 2

- Repariert den teilweise angewendeten Audit-Journal-Dashboard-Stand nach 0.35.0 bis 0.35.2.
- Fügt Audit-Exportfunktionen über tokenbasierte Einfügepunkte ein statt über zeilenbasierte Spezialanker.
- Ergänzt Audit-Journal-Dashboardkarte und Styles idempotent.
- Keine Änderung an Auslosungslogik, Wertungsberechnung oder Speicherformat.
## 0.34.1 - Audit Journal Round Review Fix

- Auditjournal-Einträge für `SetRoundLock` und `SetRoundVerified` ergänzt.
- Runden-Sperren, Entsperren, Prüfen und Zurücksetzen werden nun dauerhaft im Auditjournal protokolliert.
- Behebt den roten `AuditJournal_TracksManualCorrectionsAndRoundReview`-Regressionstest aus 0.34.0.
- Keine Änderung an Auslosungslogik, Wertungsberechnung oder UI.
## 0.34.0 - Persistent Audit Journal Foundation

- Persistierbares Auditjournal im `TournamentState` ergänzt.
- Neue Domain-Typen `AuditJournalEntry`, `AuditJournalAction` und `AuditJournalSeverity` ergänzt.
- Zentrale Turnierleiteraktionen werden nun dauerhaft protokolliert: Turnier/Spieler/Runden/Ergebnisse/manuelle Paarungen/Rundenprüfung.
- Neuer API-Endpunkt `GET /api/tournaments/{id}/audit-journal`.
- Neue Application-Regressionstests für Kernworkflow, manuelle Korrekturen und Snapshot-Persistenz.
- Keine Änderung an Auslosungslogik oder Wertungsberechnung.
## 0.33.0 - Forfeit/Bye Regression Gate

- Zusätzliche Domain-Regressionstests für kampflose Ergebnisse und Bye/Spielfrei ergänzt.
- Forfeit-Tiebreak-Policies `ExcludeForfeitsFromTiebreaks`, `CountForfeitOpponentForBuchholzOnly` und `CountForfeitsAsNormalGames` werden in Mehr-Runden-Szenarien abgesichert.
- Bye mit `CountByeAsWin` wird als Sieg gezählt, bleibt aber ohne Gegnerwertung, Sonneborn-Berger, Gegnerschnitt und Performance.
- Keine Änderung an Auslosungslogik, Wertungsberechnung, Speicherformat oder UI.
## 0.32.0 - Swiss-Regression-Gate

- Zusätzliche Domain-Regressionstests für grundlegende Swiss-Pairing-Invarianten ergänzt.
- Gerade und ungerade erste Runde prüfen jetzt eindeutige Spielerzuordnung, Bye-Anzahl und fortlaufende Brettnummern.
- Zweite Runde nach entschiedener erster Runde prüft keine direkten Rematches und keine kritische Pairing-Qualität.
- xUnit2031-Warnung aus `SwissRegressionScenarioTests` bereinigt.
- Keine Änderung an Auslosungslogik, Wertungsberechnung oder Speicherformat.
## 0.31.0 - Swiss-Regression-Szenarien

- Zusätzliche Application-Regressionstests für echte Schweizer-System-Turniersituationen ergänzt.
- Ungerade Teilnehmerzahl mit Bye und temporärer Auslosungsvorschau abgesichert.
- Kampflose Ergebnisse werden inklusive Rundenabschluss und Diagnosewirkung geprüft.
- Rückzug nach gespielter Runde wird abgesichert: zurückgezogene Spieler dürfen in der nächsten Vorschau nicht gepaart werden.
- Keine Änderung an Auslosungslogik, Wertungsberechnung oder Speicherformat.
## 0.30.0 - Release-Gate und Commit-Guard

- Release-Gate `scripts/Invoke-ReleaseGate.ps1` ergaenzt.
- Commit-Guard `scripts/Commit-If-Green.ps1` ergaenzt.
- Bekannte versehentliche Datei `tatus` wird vor Release/Commit geblockt.
- Node.js-Engine-Hinweis fuer Vite/Rolldown integriert.
- Ziel: rote Zwischenstaende wie 0.29.0/0.29.1 kuenftig vor Commit/Push erkennen.

## 0.29.2

- Fix: doppelte `openLatestRoundPrint`-Funktion im Korrekturjournal-Stand entfernt.
- Nachkontrolle: Backend-Build, Tests, Frontend-Build und Portable-Paket laufen wieder grün.
## 0.29.1 - Korrekturjournal-Buildfix

- Korrekturjournal-Helfer in den richtigen React-App-Scope verschoben.
- TypeScript-Buildfehler aus v0.29.0 behoben.
- Keine Änderung an Auslosungslogik, Wertungsberechnung oder Speicherformat.
## 0.29.0 - Korrektur- und Eingriffsübersicht

- Dashboard-Panel fuer Turnierleiter-Korrekturen ergaenzt.
- Manuelle Paarungen, gesperrte/gepruefte Runden, inaktive Teilnehmer und Sonderergebnisse werden zentral sichtbar.
- Status-Badges und Schnellzugriffe auf letzte Runde, Turnierbericht und Paarungs-CSV ergaenzt.
- Keine Aenderung an Auslosungslogik, Wertungsberechnung oder Speicherformat.
## v0.28.0
- Dashboard um eine Auslosungsfreigabe erweitert.
- Offene Ergebnisse, ungeprüfte vollständige Runden, aktive Spielerzahl und kritische Vorschauhinweise werden vor der nächsten Auslosung zentral geprüft.
- Schnellaktionen für Auslosungsvorschau, nächste Runde, aktuelle Runde und Turnierbericht ergänzt.
- Version auf 0.28.0 angehoben.
## v0.27.0

- Dashboard um ein Bye- und Kampflos-Audit erweitert.
- Spielfreie und kampflose Bretter werden inklusive Wertungswirkung sichtbar gemacht.
- Anzeige für Buchholz-, Direkt-/Sonneborn-Berger- und Performance-Wertung ergänzt.
- Schnellaktionen für aktuelle Runde, Paarungen-CSV und Turnierbericht ergänzt.
- Version auf 0.27.0 angehoben.
## v0.26.0

- Dashboard um eine Rundenabschluss-Checkliste erweitert.
- Offene Ergebnisse, kampflose Bretter, ungeprüfte vollständige Runden und Diagnosehinweise werden zentral sichtbar.
- Schnellaktionen für aktuelle Runde, Turnierbericht und Tabellen-CSV ergänzt.
- Version auf 0.26.0 angehoben.
## 0.25.0

- Ergänzt ein Turnierleiter-Exportcenter im Dashboard.
- Bündelt Aushänge, Tabellen-, Paarungs-, Vorschau- und Backup-Exporte an einer Stelle.
- Zeigt Schnellkennzahlen zu Teilnehmern, aktiven Spielern, Runden, offenen Brettern und kampflosen Partien.
- Ergänzt Warnhinweise für offene Ergebnisse und kritische Auslosungsvorschauen.
- Baut das Portable-Paket als `SchachTurnierManager_Portable_0.25.0.zip`.
## 0.24.1

- Vervollständigt die Dashboard-Integration der Auslosungsvorschau-Exports.
- Ergänzt die fehlenden Buttons für Druckansicht und CSV-Export in der Vorschaukarte.
- Ergänzt deutliche Warnboxen für kritische oder nicht speicherbare Vorschauen.
- Baut das Portable-Paket nach der Korrektur neu.
## 0.23.0 - Auslosungsvorschau im Dashboard

- Die Next-Round-Auslosungsvorschau ist jetzt direkt im Dashboard sichtbar.
- Die Vorschau zeigt Pairing-Qualität, Warnungen, Bretter, Byes, Rematches, Scoregruppen-Abweichungen, Farbfolge-Risiken und Audit-Details.
- Turnierleiter können die Vorschau schließen oder danach bewusst die Runde wirklich auslosen.
## 0.22.2

- Stabilisiert den abgebrochenen v0.22.1-Patchlauf.
- Entfernt defekte Zwischenstandsdateien aus v0.22.0 und v0.22.1.
- Behält die Auslosungsvorschau ohne Persistenz aus v0.22 bei.
- Nachkontrolle bricht bei fehlgeschlagenem Restore, Build, Test, Frontend-Build oder Portable-Packaging hart ab.
## 0.21.0 - Pairing-Audit mit Qualitätsbericht

- Pairing-Qualität wird nach jeder automatisch erzeugten Runde direkt in das Runden-Audit geschrieben.
- Audit nennt Qualitätswert, Rematches, Scoregruppenabweichungen, Farbfolgenrisiken und Byes.
- Zusätzliche Application-Workflow-Tests sichern die Verbindung von Rundenerzeugung, Qualitätsbericht und Audit.
- Neue Swiss-Pairing-Golden-Szenarien prüfen Zwei-Runden-Verläufe und Bye-Audit.
## 0.20.5 - Export-Test für erweiterte Wertungen stabilisiert

- CSV-Export-Test auf den tatsächlich exportierten erweiterten Tabellenkopf angepasst.
- Fehlgeschlagene lokale Zwischenstandsartefakte aus v0.20.3/v0.20.4 werden beim Fix-Forward entfernt.
- Nachkontrolle bricht weiterhin hart ab, wenn Build, Tests, Frontend-Build oder Portable-Paket fehlschlagen.

## 0.20.2 - Teststabilisierung erweiterte Wertungen

- Stabilisiert den CSV-Export-Test nach der Erweiterung der Tabellenwertungsspalten in 0.20.1.
- Versionen auf `0.20.2` angehoben.
- Nachkontrollskript bricht nun hart ab, sobald `dotnet test`, Frontend-Build oder Packaging fehlschlagen.

## 0.19.0 - Swiss-Chess-Paritätsroadmap

- Funktionsmatrix für Swiss-Chess-/Swiss-Manager-artige Turnierverwaltung ergänzt.
- Offene Blöcke für Schweizer System, Mannschaftsturniere, Import/Export, Ratingauswertung, Druck, Betrieb und Support dokumentiert.
- Priorisierte Roadmap für die nächsten Entwicklungsphasen ergänzt.
## 0.18.1 - Pairing-Qualität im Dashboard

- Fix-Forward für das v0.18.0-Nachkontrollskript.
- Application-Endpunkt für Pairing-Qualität pro Runde ergänzt.
- WebApi-Endpunkt `/api/tournaments/{id}/rounds/{roundNumber}/pairing-quality` ergänzt.
- Dashboard zeigt Pairing-Qualitätswert, Schweregrad, Rundenhinweise und brettweise Erklärungen.
- Tests für den Application-Workflow der Pairing-Qualitätsberichte ergänzt.
## 0.17.0 - Pairing-Qualitätsbericht

- Pairing-Qualitätsmodell für Schweizer-System-Runden ergänzt.
- Analyzer erkennt Rematches, Scoregruppen-Unterschiede, dritte gleiche Farbe in Folge und Bye/Spielfrei.
- Qualitätswert und Schweregrad für spätere UI-Erklärung „Warum wurde so gelost?“ ergänzt.
- Golden-nahe Tests für Pairing-Qualität ergänzt.
## 0.16.1 - CSV-Import bewusst bestätigen und Vorlagen

- CSV-Import mit Warnungen muss im Dashboard bewusst bestätigt werden, bevor der Import ausgeführt werden kann.
- CSV-Beispielvorlage kann direkt im Dashboard eingefügt werden.
- Änderungen an CSV-Inhalt oder Ersetzen-Option verwerfen Vorschau und Warnungsbestätigung automatisch.
- Importstatus und Bedienhinweise im Dashboard präzisiert.
## 0.12.0 - Externe Spielerdaten anwenden und Dublettenprüfung

- Dublettenprüfung für externe Spielerdaten ergänzt: FIDE-ID, DSB-/National-ID, Name+Geburtsjahr und Name-only-Hinweis.
- Externe Treffer können direkt als neuer Teilnehmer gespeichert oder auf bestehende Teilnehmer angewendet werden.
- Dashboard zeigt mögliche Dubletten und bietet Aktionen zum Ergänzen oder Überschreiben bestehender Teilnehmer.
- API-Endpunkte für Dublettenprüfung und Apply-Workflow ergänzt.
- Tests für FIDE-ID `99900123`, Name+Geburtsjahr-Matching und externe Aktualisierung ergänzt.

## 0.11.3 - FIDE-Testassert endgültig stabilisiert

- FIDE-Provider-Test prüft die Request-URI jetzt tolerant auf das Suffix `profile/99900123`.
- Nachkontrollskript ersetzt alte Assert-Zeilen per Regex und bricht ab, falls der alte Assert weiterhin vorhanden ist.
- Versionen auf `0.11.3` angehoben.

## 0.11.2 - FIDE-Testassert robust fixiert

- FIDE-Provider-Test endgültig auf absolute/relative Profil-URI tolerant gemacht.
- Nachkontrollskript korrigiert die alte Assert-Zeile vorsorglich, falls ein vorheriger Patch nicht sauber überschrieben wurde.
- Versionen auf `0.11.2` angehoben.

## 0.11.1 - FIDE-Test und Ticket-Vorbereitung stabilisiert

- Korrigiert den FIDE-Provider-Test: `HttpClient` liefert bei gesetzter BaseAddress eine absolute `RequestUri`; der Test prüft nun robust auf `/profile/99900123`.
- GitHub-Issue-Templates für Bugreports und Feature-Wünsche ergänzt.
- Ticket-/Feedback-Workflow dokumentiert: GitHub Issues für öffentliche Nutzer, optional später In-App-Link mit Diagnosepaket.
- Versionen auf `0.11.1` angehoben.

## 0.11.0 - FIDE-Adapter testbar gemacht

- FIDE-Provider akzeptiert jetzt einen injizierten `HttpClient`, bleibt aber per Standardkonstruktor produktiv nutzbar.
- Offline-Parser-Test für FIDE-ID `99900123` ergänzt.
- Invalid-ID-Test für den FIDE-Provider ergänzt.
- Externe Lookup-Tests sind damit stabiler und weniger abhängig von Live-Webseiten.

## 0.10.4 - Stabilisierung externe Lookup-Tests

- Infrastructure-Live-Tests entkoppelt von konkreter DSB-/ThSB-Provider-Sichtbarkeit.
- FIDE-Live-Test bleibt optional über `STM_RUN_LIVE_LOOKUP_TESTS=1`.
- Offline-Snapshots für FIDE/DSB/ThSB bleiben als stabiler Testanker erhalten.
- Versionsanzeige auf `0.10.4` vereinheitlicht.

## 0.10.0 - Externe Spielersuche (FIDE-Grundlage)

- Provider-Struktur für externe Spielerdatenquellen ergänzt.
- FIDE-ID-Suche über `ratings.fide.com/profile/{id}` als erster aktiver Adapter.
- DSB/DeWIS und ThSB als vorbereitete Provider mit klarer Unsupported-Rückmeldung.
- Dashboard-Bereich „Spielerdaten suchen“ ergänzt; Treffer können ins Teilnehmerformular übernommen werden.
- Teilnehmerformular um Federation, Land, Rapid-/Blitz-Elo und DWZ-Index erweitert.
- Tests für Lookup-Routing und Profil-zu-Teilnehmer-Mapping ergänzt.

## 0.9.2 - Versions-/Packaging-Fix und externe Spielerdatenplanung

- Portable-Paket liest Version automatisch aus `package.json`.
- Nachkontrollskript `After-Apply-V0.9.2.ps1` ergänzt.
- Planungsdokument und Agenten-Skill für FIDE-/DSB-/ThSB-Spielerdaten-Anbindung ergänzt.

## 0.9.1 - Stabilisierung Turniereinstellungen

- Fix-Forward für den v0.9.0-Patch: `TournamentService.UpdateSettings(...)` ist in der Application-Schicht enthalten.
- Nachkontrollskript `After-Apply-V0.9.1.ps1` ergänzt.



## 0.9.1 - Turniereinstellungen und Wertungskette

- Turniereinstellungen im Dashboard bearbeitbar gemacht.
- Punktesystem, TWZ-Quelle, Forfeit-Policy, Bye-als-Sieg, Seniorenjahr und Heldenpokal-Mindestpartien konfigurierbar gemacht.
- Wertungskette im Dashboard auswählbar und sortierbar gemacht.
- Backend-Endpunkt zum Speichern der Turniereinstellungen ergänzt.
- Tabellenberechnung nutzt jetzt die konfigurierte Wertungskette nach Punkten.
- Tests für Settings-Workflow und konfigurierbare Wertungskette ergänzt.

## 0.8.0 - Portable App / lokale Auslieferung

- Backend kann das gebaute React-Dashboard direkt aus `wwwroot` ausliefern.
- Portable Paket erzeugt jetzt `output\portable` mit `app`, `data`, Start-BAT und README.
- `Pack-Portable.ps1` baut Frontend, publisht Backend und kopiert `dist` in das veröffentlichte `wwwroot`.
- `Start-Portable.bat` startet die lokale API auf `http://127.0.0.1:5088` und öffnet das eingebettete Dashboard.
- Healthcheck meldet, ob ein eingebettetes Dashboard gefunden wurde.
- Neues Nachkontrollskript `After-Apply-V0.8.ps1`.


## 0.7.1 - Stabilisierung Druckansichten

- Korrigiert Buildfehler im HTML-Export: Rundenprüfung nutzt `RoundDiagnostics.Warnings` statt einer nicht existierenden `Messages`-Eigenschaft.
- Ergänzt Handoff und Nachkontrollskript für den grünen v0.7.1-Stand.

## 0.7.0 - Druckansichten und Exportpaket

- CSV-Export für Gesamtwertung ergänzt.
- CSV-Export für alle Paarungen oder eine einzelne Runde ergänzt.
- HTML-Druckansicht für kompletten Turnierbericht ergänzt.
- HTML-Druckansicht für einzelne Rundenblätter ergänzt.
- Dashboard-Buttons für Tabelle, Paarungen, Turnierbericht und Rundenblätter ergänzt.
- Export-Formatter mit Tests für CSV/HTML-Ausgaben ergänzt.

## 0.6.0 - Stabilisierung Workflow-Tests und Checkpoint-Skripte

- Fehlendes `using Xunit;` in `RoundWorkflowTests` ergänzt.
- `After-Apply-V0.5.ps1`, `After-Apply-V0.6.0.ps1` und `Commit-Checkpoint.ps1` brechen jetzt zuverlässig bei fehlgeschlagenen nativen Befehlen ab.
- Checkpoint-Commits werden nicht mehr ausgeführt, wenn Build/Test/Frontend-Build fehlschlagen.

## 0.6.0 - Manuelle Paarungen und Rundensperren

- Manuelle Paarungskorrekturen pro Brett ergänzt.
- Rundensperre und Prüfstatus ergänzt.
- Ergebnisänderungen in gesperrten/geprüften Runden werden verhindert.
- Nächste Runde erfordert vollständig eingetragene vorherige Runde.
- Dashboard zeigt Rundenzustand und erlaubt Paarungskorrekturen mit Notiz.
- Checkpoint-Skript für regelmäßige grüne Commits ergänzt.

## 0.4.1 – 2026-06-07

### Fixed
- `Start-Dev.ps1` prüft und öffnet das Frontend jetzt über `http://127.0.0.1:5173`, passend zur Vite-Bindung.
- Vite-Proxy verwendet `http://127.0.0.1:5088` als Backend-Ziel.
- CORS erlaubt zusätzlich `http://127.0.0.1:5173`.
- Startskript wartet länger und protokolliert den letzten Verbindungsfehler, falls Backend oder Frontend nicht rechtzeitig erreichbar sind.

# Changelog
## 0.20.5 - Export-Test für erweiterte Wertungen stabilisiert

- CSV-Export-Test auf den tatsächlich exportierten erweiterten Tabellenkopf angepasst.
- Fehlgeschlagene lokale Zwischenstandsartefakte aus v0.20.3/v0.20.4 werden beim Fix-Forward entfernt.
- Nachkontrolle bricht weiterhin hart ab, wenn Build, Tests, Frontend-Build oder Portable-Paket fehlschlagen.

## 0.20.2 - Teststabilisierung erweiterte Wertungen

- Stabilisiert den CSV-Export-Test nach der Erweiterung der Tabellenwertungsspalten in 0.20.1.
- Versionen auf `0.20.2` angehoben.
- Nachkontrollskript bricht nun hart ab, sobald `dotnet test`, Frontend-Build oder Packaging fehlschlagen.

## 0.19.0 - Swiss-Chess-Paritätsroadmap

- Funktionsmatrix für Swiss-Chess-/Swiss-Manager-artige Turnierverwaltung ergänzt.
- Offene Blöcke für Schweizer System, Mannschaftsturniere, Import/Export, Ratingauswertung, Druck, Betrieb und Support dokumentiert.
- Priorisierte Roadmap für die nächsten Entwicklungsphasen ergänzt.
## 0.18.1 - Pairing-Qualität im Dashboard

- Fix-Forward für das v0.18.0-Nachkontrollskript.
- Application-Endpunkt für Pairing-Qualität pro Runde ergänzt.
- WebApi-Endpunkt `/api/tournaments/{id}/rounds/{roundNumber}/pairing-quality` ergänzt.
- Dashboard zeigt Pairing-Qualitätswert, Schweregrad, Rundenhinweise und brettweise Erklärungen.
- Tests für den Application-Workflow der Pairing-Qualitätsberichte ergänzt.
## 0.17.0 - Pairing-Qualitätsbericht

- Pairing-Qualitätsmodell für Schweizer-System-Runden ergänzt.
- Analyzer erkennt Rematches, Scoregruppen-Unterschiede, dritte gleiche Farbe in Folge und Bye/Spielfrei.
- Qualitätswert und Schweregrad für spätere UI-Erklärung „Warum wurde so gelost?“ ergänzt.
- Golden-nahe Tests für Pairing-Qualität ergänzt.
## 0.4.0 – 2026-06-07

### Added
- Schweizer-System-Auslosung V2 mit scoregruppenorientierter Gegnerwahl.
- Pairing-Audit mit Scoregruppen, Floatern und Farbhistorie-/Farbpräferenz-Hinweisen.
- Erweiterte Swiss-Golden-Tests für Bye-Schutz, Rematch-Vermeidung, Farbpräferenz und Audit.
- Auditanzeige im Dashboard direkt an jeder Runde.
- `scripts\After-Apply-V0.4.ps1` für die lokale Nachkontrolle.

### Changed
- Swiss-Pairing vermeidet Wiederholungen robuster und dokumentiert unvermeidbare Wiederholungen explizit.
- Bye-Vergabe bevorzugt die niedrigste Scoregruppe ohne bisheriges Bye.
- Farbvergabe berücksichtigt Farbbilanz, letzte Farben und drohende dritte gleiche Farbe.
- Dashboard-Version auf 0.4.0 angehoben.

## 0.3.1 – 2026-06-07

### Fixed
- Behebt die Kompilierfehler in `CrossTableCalculatorTests` und `HeroCupCalculatorTests`: `TournamentRound.Pairings` ist `IReadOnlyList<Pairing>` und muss in Tests per Array/Collection-Initializer gesetzt werden.
- `scripts\Test-All.ps1` und `scripts\After-Apply-V0.3.ps1` brechen jetzt bei fehlgeschlagenen externen Befehlen zuverlässig ab.

### Changed
- `scripts\Start-Dev.ps1` wartet nun kurz auf Backend und Frontend, bevor der Browser geöffnet wird. Dadurch werden anfängliche Vite-Proxy-Fehler durch noch nicht gestartetes Backend reduziert.
- Zusätzliches Skript `scripts\After-Apply-V0.3.1.ps1` für die Stabilisierungskontrolle.

## 0.3.0 – 2026-06-07

### Added
- Turnierleiter-MVP: Teilnehmer im Dashboard bearbeiten, löschen, zurückziehen und reaktivieren.
- Erweiterte Teilnehmerfelder im UI: Geburtsjahr, Geschlecht, DWZ, Elo, manuelle TWZ, FIDE-ID, DSB-ID, Titel, Status und Notizen.
- Kategorieauswertungen für Frauen, U10/U12/U14/U16/U18/U25 und Senioren.
- Kreuztabelle mit Ergebnisanzeige aus Spielersicht.
- Heldenpokal-Auswertung auf Basis tatsächlicher Punkte minus erwarteter Punkte gegen Gegner-TWZ.
- CSV-Import/-Export für Teilnehmer.
- JSON-Backup/-Restore für ganze Turniere.
- API-Endpunkte für Kreuztabelle, Kategorien, Heldenpokal und Import/Export.
- Unit-Tests für Kreuztabelle, Kategorien, Heldenpokal und CSV-Import/-Export.

### Changed
- Dashboard auf Version 0.3.0 erweitert und Tabellenbereiche für große Turniere scrollbar gemacht.
- Rundenturnier-Auslosung berücksichtigt nur aktive Spieler.

## 0.2.1 – 2026-06-07

### Fixed
- Stabilisiert den SQLite-Persistenztest: Testdatenbank liegt jetzt in einem eigenen temporären Verzeichnis, SQLite-Pooling ist deaktiviert, Connection-Pools werden vor dem Cleanup geleert und der Cleanup wiederholt Datei-/Ordnerlöschungen kurz.
- Behebt den lokalen Testfehler `IOException: ... sqlite ... used by another process` in `SqliteTournamentStoreTests`.

## 0.2.0 – 2026-06-07

### Added
- SQLite-/EF-Core-basierter `SqliteTournamentStore` in `Infrastructure`.
- Lokale Datenbankanlage beim API-Start unter `%LOCALAPPDATA%\SchachTurnierManager`.
- API-Endpunkte für Turnierliste, Turnierdetails, Teilnehmeranlage/-änderung/-entfernung, nächste Runde, Ergebnis, Tabelle und Audit.
- Bedienbares React-Dashboard für Turnieranlage, Teilnehmererfassung, Auslosung, Ergebniseingabe und Live-Tabelle.
- Persistenztest für Speichern/Laden eines Turniers mit Runde und Ergebnis.
- `.gitattributes` und erweiterte `.gitignore`-Regeln für stabile Zeilenenden und generierte Dateien.
- `scripts\Start-Dev.ps1` und `scripts\Clean-Generated.ps1`.

### Changed
- Frontend-Build von `tsc -b` auf `tsc --noEmit` umgestellt.
- TypeScript `moduleResolution` von veraltetem `Node` auf `Bundler` umgestellt.
- `scripts\Test-All.ps1` prüft jetzt zusätzlich den Frontend-Build.
- `Pack-Portable.ps1` baut vor dem Publish auch das Frontend.

### Fixed
- xUnit-Warnung `xUnit2031` in `SwissPairingEngineTests` behoben.
- TypeScript-Fehler `TS5107` im Frontend behoben.

## 0.1.0 – 2026-06-07

### Added
- .NET-10-Solution mit Domain, Application, Infrastructure und WebApi.
- React/TypeScript/Vite-Dashboard-Grundlage.
- Round-Robin-Pairing-Engine.
- Basis-Schweizer-Pairing-Engine mit Audit-Hinweisen.
- StandingsCalculator mit Punkten, Siegen, Direktvergleich, Buchholz, Buchholz Cut-1, Sonneborn-Berger, Performance und Heldenpokal-Grundlage.
- Armageddon-Bidding-Service mit Commitment-Hash und Entscheidungslogik.
- Unit-Test-Projekte und erste Tests.
- Codex-/Agenten-/Skill-Dokumente.
- Build-/Test-/Run-/Portable-Pack-Skripte.




## 0.37.4

- Repariert den Audit-Journal-Query-API-Patch durch Wiederherstellung der Program.cs aus dem letzten gruenen Git-Stand.
- Ergaenzt die Query-Route als kurze MapGet-Zeile und verlagert die Logik in einen statischen Handler, damit die einzeilige Program.cs nicht erneut syntaktisch zerstoert wird.
- Behaelt das gruenes-Gate-vor-Commit-Prinzip bei.
## 0.37.5

- Repariert den Audit-Journal-Query-API-Patch durch Reset der Program.cs aus dem letzten gruenen Git-Stand.
- Ergaenzt den Query-Endpunkt als Inline-Minimal-API-Handler mit HttpRequest-Query-Auswertung.
- Fuegt kleine Parser-Helfer fuer optionale int- und Guid-Queryparameter hinzu.
## 0.37.6

- Repariert den Audit-Journal-Query-API-Patch erneut durch Reset der Program.cs aus dem letzten gruenen Git-Stand.
- Entfernt die separate Helper-Funktionsstrategie der vorherigen Fixes.
- Ergaenzt den Query-Endpunkt als eigenstaendigen Inline-Minimal-API-Handler ohne zusaetzliche lokale Helfer.


## 0.50.0 - Release Operations, Logging, Secrets und Agenten-Skills

- WebApi-Logging auf konfigurierbare Single-Line-Console-Logs umgestellt (`appsettings.json`, `appsettings.Development.json`).
- HTTP-Request-Logging ergänzt, ohne Querystrings/Secrets zu loggen.
- `/api/health` zeigt die aktiven Logging-Grundlevel.
- `Get-LocalSecret.ps1` ergänzt, um DPAPI-Secrets aus `.secrets/local/` oder legacy `secrets/local/` sicher zu laden.
- `Invoke-SecretSafetyReadiness.ps1` ergänzt: GitSafety + temporärer DPAPI-Roundtrip + Gitignore-Prüfung in einem Upload-ZIP.
- `Invoke-ReleaseCandidateReadiness.ps1` ergänzt: ReleaseGate, SecretSafety, Desktop-Publish, portable Self-contained-Paketierung, optionale Installer-Readiness und SHA256-Artefaktmanifest.
- Agenten-Skills ergänzt: Release Operations, Logging/Observability und Repository Security.
- Release-/Betriebsdokumentation unter `docs/architecture/RELEASE_OPERATIONS.md` ergänzt.
- Unit-/Contract-Tests für Logging-Konfiguration, Secret-Schutz, Release-Skripte und Agenten-Skills ergänzt.

## 0.53.0 - Klick-Installation fuer Kollegen

- Kollegenpaket erweitert um `Install-SchachTurnierManager.cmd` und `Uninstall-SchachTurnierManager.cmd` als Doppelklickpfad.
- Neue Skripte `Install-ColleagueDesktopApp.ps1` und `Uninstall-ColleagueDesktopApp.ps1` installieren die Desktop-Variante nach `%LocalAppData%\Programs\SchachTurnierManager`, erzeugen einen Startmenue-Shortcut und halten Nutzerdaten getrennt.
- `Invoke-ColleagueInstallReadiness.ps1` legt Install-/Uninstall-Bootstrapper, Manifest und Checksums direkt ins Kollegenpaket.
- `Invoke-ClickInstallReadiness.ps1` prueft Paket, Checksums, Installation, Shortcut, App-Smoke-Test, isolierte SQLite-Daten und Uninstall in einem frischen Testordner.
- Doku und Skill fuer Klick-Installation/Release-Rollout ergaenzt.
- Unit-/Guard-Test fuer Bootstrapper, Readiness-Skript und Kollegenpaket ergänzt.
