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
- `Sync-ClaudeAgentAdapters.ps1` – dünne Claude-Adapter aus `agents/**` synchronisieren (`-Check`/`-Apply`/`-WhatIf`/`-RepositoryRoot`).

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
- `New-RunLogBundle.ps1` – Run-Ordner unter `D:\Temp` anlegen bzw. Logs, Git-Status und Diff-Stat zu einem ZIP bündeln.
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
- `Invoke-ReleaseCandidateReadiness.ps1` bündelt ReleaseGate, SecretSafety, Desktop-Publish, portable Self-contained-Paketierung und optional Installer-Readiness in einem `D:\Temp`-Run-ZIP.

Beispiel:

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-ReleaseCandidateReadiness.ps1 -BuildInstaller -AllowMissingInnoSetup
```

Am Ende wird genau ein `UPLOAD_ZIP=...` ausgegeben.

- `Invoke-ColleagueInstallReadiness.ps1` erzeugt RUN-51: eigenstaendiges Kollegenpaket mit Desktop-ZIP, Portable-ZIP, optionaler Setup-EXE, README, Manifest und SHA256-Pruefsummen.
