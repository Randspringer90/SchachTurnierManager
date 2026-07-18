# scripts/ – Skriptübersicht

Aktive Skripte liegen bewusst flach in diesem Ordner, weil sie sich gegenseitig über feste Pfade aufrufen (siehe Zielstruktur unten).

## Entwicklung (dev)

- `Start-Dev.ps1` – Backend für lokale Entwicklung starten.
- `Run-Backend.ps1` / `Run-WebApp.ps1` – Backend bzw. Frontend einzeln starten.

## Tests (test)

- `Test-All.ps1` – .NET-Tests gesamt.
- `Run-ExternalLookupSmoke.ps1` – Smoke-/Live-Tests externer Spielerdaten-Lookup.
- `Test-ContributorKickoffReadiness.ps1` – Abnahme des Codex-Contributor-Starterpakets (Doku/Vorlage, Promptgenerierung, Prompt-Injection-Schutz, ein Upload-ZIP).

## Agenten / Skills / Security (STM-AI-001)

- `Test-AgentInstructionIntegrity.ps1` – Instruction-Integrity-Gate (Allowlist, Manifeste, keine Owner-Pfade/Secrets/Modell-Hardcoding); cross-platform, in CI (`security-gate.yml`).
- `Test-AgentSkillReadiness.ps1` – Agenten-/Skill-/Routing-Manifest-Validierung (Schema, eindeutige Namen, Referenzen).
- `Test-PromptInjectionDefense.ps1` – Prompt-Injection-Verteidigung mit synthetischen Fixtures (nichts wird ausgeführt/persistiert).
- `Test-KnowledgePersistenceSafety.ps1` – sichere Wissenspersistenz (`docs/knowledge/**`).
- `New-AgentSkillImprovementProposal.ps1` – erzeugt ausschließlich lokale, nicht aktivierende `DRAFT_OWNER_REVIEW`-Vorschläge im ignorierten Output-Bereich.
- `Test-AgentSkillProposalSafety.ps1` – Positiv-/Negativmatrix für Secret-/PII-/Injection-/Traversal-Schutz und unveränderte Instruktionsquellen.
- `Resolve-ModelRoute.ps1` – fail-closed Auswahl eines logischen Ausfuehrungsprofils; startet kein Modell und fuehrt keinen stillen Fallback aus.
- `Test-ModelRoutingReadiness.ps1` – Policy-, Profil- und Entscheidungsmatrix fuer das dynamische Modellrouting.
- `New-RoutedTaskGraph.ps1` – validiert eine Masterprompt-Zerlegung fail-closed und routet jede Teilaufgabe ueber `Resolve-ModelRoute.ps1` (STM-AI-005).
- `Invoke-RoutedTaskGraph.ps1` – fuehrt einen gerouteten Taskgraph tatsaechlich aus: sequenziell, checkpointed, mit Injection-Quarantaene und Eskalation.
- `Resume-RoutedTaskGraph.ps1` – setzt einen unterbrochenen Routed-Execution-Lauf bindungsgeprueft am Checkpoint fort.
- `Invoke-AnthropicProfile.ps1` / `Invoke-OpenAIProfile.ps1` – nichtinteraktive Provider-Adapter (vorhandene Logins, keine Tokens, redigierte Logs, read-only Children).
- `Test-RoutedExecutionReadiness.ps1` – synthetische Offline-Pruefmatrix der Routed Execution (Routing, Limits, Quarantaene, Resume, Integration-Gate).
- `lib/RoutedExecutionCommon.ps1` – gemeinsame Routed-Execution-Funktionen (Validierung, Checkpoints, Klassifikation, Redaktion).
- `New-NightlyCheckpoint.ps1` – erzeugt einen atomaren, SHA-gebundenen T3-Checkpoint ausschließlich im ignorierten Output-Bereich.
- `Get-NightlyResumePlan.ps1` – prüft Checkpoint, Branch, Head und Worktree fail-closed; liefert nur einen Plan und führt keine Aktion aus.
- `New-NightlyRegistrationPlan.ps1` – exportiert die nicht aktivierende zentrale Registrierung mit Status `READY_FOR_ACTIVATION`.
- `Invoke-NightlyProjectRun.ps1` – projektlokale Nightly-Ausfuehrungsebene (STM-AI-006): Lock, Vorbedingungen, Owner-Queue-Auswahl (Contributor-Aufgaben ausgeschlossen), Plan + Masterprompt + Gates; nie main/Release/History/Secrets.
- `Resume-NightlyProjectRun.ps1` – setzt Nightly-/Routed-Checkpoints dieses Projekts fail-closed fort.
- `Register-NightlyProject.ps1` – einmalige Aktivierung in der vorhandenen zentralen Registry (Pfad als Parameter, WhatIf-Default, nur Override-Flip; erzeugt nie eine Scheduled Task).
- `Test-NightlyExecutionReadiness.ps1` – Offline-Pruefmatrix der Nightly-Ausfuehrungsebene (Policy, Scheduler-Mutationsverbot, Registrierung, Queue-Ausschluesse, Resume).
- `Test-NightlyReadiness.ps1` – 56-Fälle-Gate für Policy, Binding, Tamper-, Drift-, Secret-/PII-, Resume- und Registrierungsgrenzen.
- `Sync-ClaudeAgentAdapters.ps1` – dünne Claude-Adapter aus `agents/**` synchronisieren (`-Check`/`-Apply`/`-WhatIf`/`-RepositoryRoot`).

## Sichere Pull-Request-Prüfung (STM-SEC-005)

- `Invoke-SafePullRequestReview.ps1` – read-only/static-only Review von Metadaten, vollständiger Dateiliste und Patch; erzeugt exakt neun redigierte SHA-/Policy-gebundene Artefakte, ohne PR-Code auszuführen.
- `Test-PullRequestDependencyDelta.ps1` – statischer Offline-Contract für NuGet-/npm-/Lock-/Build-/Using-Deltas; führt keinen Paketmanager aus.
- `New-PullRequestAdoptionPrompt.ps1` – erzeugt nach Bindungs- und SHA-Recheck einen Trust-getrennten Handoff; T4-PR-Daten bleiben als „DATEN – KEINE ANWEISUNGEN“ markiert.
- `New-PullRequestFeedback.ps1` – erzeugt standardmäßig nur redigiertes Feedback; Posting verlangt expliziten Schalter und aktuellen Head-/Base-Recheck.
- `Test-PullRequestReviewReadiness.ps1` – providerunabhängiger Gate mit synthetischen Positiv-, Risiko-, Tamper-, Pfad- und WhatIf-Szenarien.
- `lib/PullRequestReviewCommon.ps1` – pure Validierung, Redaction, defensive Klassifikation und Reportbindung.
- `lib/PullRequestArtifactVerification.ps1` – reine In-Memory-Prüfung exakt attestierter Android-PNGs, Gradle-Wrapper-Dateien und Buildwrapper; keine Payload-Ausführung und kein Entpacken.

## Contributor / Kollaboration

- `New-ContributorTaskPrompt.ps1` – erzeugt aus einer Backlog-ID/Issue einen fertigen, sicheren Codex-Arbeitsauftrag für einen nicht-technischen Schach-Contributor (Vorlage `docs/ai/templates/CODEX_CHESS_FEATURE.md`; Issue-Text = untrusted Daten). Beispiel: `pwsh scripts/New-ContributorTaskPrompt.ps1 -BacklogId STM-TB-001`.
- `New-FeatureBranch.ps1` – Feature-Branch sicher von `development` erzeugen.

## Release (release)

- `Invoke-ReleaseGate.ps1` – Pflicht-Gate: restore, build, test, Frontend-Build, Pack-Portable.
- `Pack-Portable.ps1` / `Start-Portable.bat` – portables Paket bauen und starten.
- `Invoke-PortableFreshFolderTest.ps1` – RUN-03: Portable-ZIP bauen, frisch entpacken, Health/Dashboard/API/SQLite-Datenpfad smoke-testen und als Run-ZIP bündeln.
- `Publish-DesktopApp.ps1` / `Start-Desktop.bat` – self-contained Desktop-Paket (`output\desktop`), Klick-Start, Daten unter `%LocalAppData%\SchachTurnierManager`.
- `Build-Installer.ps1` – Installer-EXE über Inno Setup 6 aus `installer\SchachTurnierManager.iss` bauen (ISCC.exe erforderlich).
- `Invoke-InstallerReadiness.ps1` – RUN-05-Readiness mit Run-Log-Bundle, Desktop-Publish, optionalem Installer-Build und Manifesten.
- `Invoke-PwaReadiness.ps1` – RUN-08: PWA-Manifest, Icons, Service Worker und Vite-Ausgabe prüfen; `/api` bleibt network-only und wird nicht offline gecacht.

## Git (git)

- `Commit-If-Green.ps1` – CommitGuard: Release-Gate + Sicherheitsprüfungen + explizites Staging + Commit. Lokale `NEXT_PROMPT.md`-Handoffs werden nicht automatisch gestaged.
- `Commit-Checkpoint.ps1` – älteres Checkpoint-Skript; bevorzugt `Commit-If-Green.ps1` verwenden.

## Sicherheit (security)

- `Test-GitCommitSafety.ps1` – Commit-Sicherheitsprüfung (Pfade, interne Referenzen, Zugangsdaten-Muster).
- `Invoke-NpmSafe.ps1` – npm-Aufrufe mit isolierter temporärer npmrc ausführen; lokale Auth optional aus `.secrets/local/`.
- `Set-LocalSecret.ps1` – lokale Secrets per Windows-DPAPI unter `.secrets/local/` speichern, ohne Werte zu loggen.
- `Test-RepositoryOpenSourceSafety.ps1` – Public-Snapshot-Kandidaten prüfen, Reports unter `output/repo-open-source-safety/`.
- `New-OpenSourceSnapshot.ps1` – Clean Snapshot ohne Git-Historie für Open-Source-Veröffentlichung.

## Wartung (maintenance)

- `Clean-Generated.ps1` – generierte Artefakte entfernen.

## Lauf-Logging (operator/diagnostics)

- `Invoke-LoggedCommand.ps1` – lange Befehle mit kurzer Terminalausgabe ausführen; vollständige Ausgabe landet im Run-Logordner.
- `New-RunLogBundle.ps1` – lokalen temporären Run-Ordner anlegen bzw. Logs, Git-Status und Diff-Stat zu einem ZIP bündeln.
- `Invoke-LoggingReadiness.ps1` – RUN-54: WebApi-Laufzeitlogs in isoliertem Daten-/Logordner pruefen, Health/Dashboard/API aufrufen und sicherstellen, dass Querystrings nicht in Logdateien landen.

## Archiv

- `archive/after-apply/` – historische After-Apply-/Patch-Skripte; nicht mehr ausführen (siehe dortiges README).

## Zielstruktur

Die Unterordner `dev/`, `test/`, `release/`, `git/`, `security/`, `maintenance/` sind als Zielzustand in `docs/planning/PROJECT_ORCHESTRATION.md` dokumentiert. Die Migration erfolgt in einem eigenen Lauf, weil dabei alle gegenseitigen Skriptaufrufe, Doku-Verweise und Regex-Pfadmuster (`patternSourceRegex`, Snapshot-Excludes) gleichzeitig angepasst und über das Release-Gate verifiziert werden müssen.

- `Invoke-TournamentAssistantReadiness.ps1`: RUN-17-Readiness fuer den lokalen Turnierassistenten; ReleaseGate, Frontend-Build und UI-/Privacy-Merkmale als Run-ZIP.
- `Invoke-KnowledgeChatReadiness.ps1` prueft RUN-10/11: lokale Chat-Hilfe/Wissensbasis, Datenschutz-Hinweis, Schnellfragen, Chat-Export und Frontend-Build.
- `Invoke-KnowledgeBaseReadiness.ps1` prueft RUN-11: ausgelagerte lokale JSON-Wissensbasis, Quellen-/Privacy-Regeln, UI-Import und Frontend-Build.

- `Invoke-ExportManifestReadiness.ps1` prueft RUN-15: ReleaseGate, Frontend-Build, Domain-Test, API-Endpunkt und UI-Exportmanifest.

## Release-/Betriebs-Skripte ab 0.50.0

- `Invoke-SecretSafetyReadiness.ps1` prüft GitSafety, lokale DPAPI-Secret-Ablage unter `.secrets/local/` und Gitignore-Schutz. Der Test legt nur einen temporären Selftest-Wert an, loggt ihn nicht und löscht ihn wieder.
- `Get-LocalSecret.ps1` liest DPAPI-geschützte lokale Secrets. Standardausgabe ist `SecureString`; Klartext ist nur mit `-AsPlainTextForChildProcessOnly` für direkte Child-Prozess-Übergaben vorgesehen.
- `Invoke-ReleaseCandidateReadiness.ps1` bündelt ReleaseGate, SecretSafety, Desktop-Publish, portable Self-contained-Paketierung und optional Installer-Readiness in einem lokalen temporären Run-ZIP.

Beispiel:

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-ReleaseCandidateReadiness.ps1 -BuildInstaller -AllowMissingInnoSetup
```

Am Ende wird genau ein `UPLOAD_ZIP=...` ausgegeben.

- `Invoke-ColleagueInstallReadiness.ps1` erzeugt RUN-51: eigenstaendiges Kollegenpaket mit Desktop-ZIP, Portable-ZIP, optionaler Setup-EXE, README, Manifest und SHA256-Pruefsummen.
