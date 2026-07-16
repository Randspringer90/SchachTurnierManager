- 2026-07-09: ChatGPT RUN-11 Knowledge-Base-Readiness Parser-Hotfix (`scripts/Invoke-KnowledgeBaseReadiness.ps1`) -> 0.48.1.
# KI-Prompt-Log — SchachTurnierManager

Jeder relevante KI-Lauf (Claude Code, Codex, andere) traegt sich hier ein.
Volle Prompts liegen unter `prompts\`, Abschlussberichte unter `reports\`.

> **2026-07-12 (Claude Opus 4.8):** Kollaborations-Bootstrap – `development`-Branch als Standard,
> Merge des lokalen v0.41-Stands, kanonischer Backlog, GitHub-Rulesets/Templates/CI.
> Abschlussbericht: `reports/2026-07-12-claude-collaboration-development-branch.md`.
>
> **2026-07-12 (Claude Opus 4.8):** Codex-Contributor-Starterpaket (Anleitung, Promptvorlage
> `templates/CODEX_CHESS_FEATURE.md`, Generator `New-ContributorTaskPrompt.ps1`, Tests).
> Abschlussbericht: `reports/2026-07-12-claude-contributor-kickoff-pack.md`.
>
> **2026-07-12 (Claude Opus 4.8):** STM-AI-001 Agenten-/Skill-/Security-Grundlage (`agents/**`,
> Manifeste, Trust-Policies, Guards+Tests, Wissensmanagement `docs/knowledge/**`). Prompt:
> `prompts/20260712_2007_claude-agent-skill-security-foundation.md`. Bericht:
> `reports/2026-07-12-claude-agent-skill-security-foundation.md`.
>
> **2026-07-12 (Claude Opus 4.8):** STM-INT-001 v0.41-Reconcile – kanonische KI-Hilfe = Frontend,
> totes `Application.Ai`-Backend-Modul entfernt. Bericht:
> `reports/2026-07-12-claude-stm-int-001-reconciliation.md`.
>
> **2026-07-15/16 (Codex / GPT-5.6 Sol):** Owner-PR #8 unabhängig gehärtet und integriert;
> STM-SEC-005 für Base-SHA-gebundene statische PR-Prüfung, kontrollierte Adoption,
> Dependency-/Malware-Risiko, redigiertes Feedback und CI-Gate. Prompts:
> `prompts/20260715_1756_codex-sol-v1-completion-run.md` und
> `prompts/20260716_0638_codex-safe-pr-adoption-resume.md`. Bericht:
> `reports/2026-07-16-codex-safe-pr-adoption-and-v1-progress.md`.

| Datum | Tool/Modell | Kurzbeschreibung | Prompt | Report |
|---|---|---|---|---|
| 2026-07-16 | Codex / GPT-5.6 Sol | Sichere Adoption der Contributor-PRs #9/#10, dynamisches Modellrouting, Wissensmanagement und Nightly-/Resume-Unterbau | [prompts/20260716_1128_codex-marcel-pr-adoption-routing-nightly.md](prompts/20260716_1128_codex-marcel-pr-adoption-routing-nightly.md) | ausstehend |
| 2026-07-10 | Codex / GPT-5 | Stabilisierung nach RUN-54: manuelle Aenderungen reviewen, Public-/Secret-Gates haerten, Runtime-Logging-Fixes, synthetische Fixtures, Reports, Commit/Push | [prompts/20260710_0604_codex-stabilisation-public-gate.md](prompts/20260710_0604_codex-stabilisation-public-gate.md) | [reports/20260710_0604_codex-stabilisation-public-gate_REPORT.md](reports/20260710_0604_codex-stabilisation-public-gate_REPORT.md) |
| 2026-07-10 | ChatGPT / GPT-5.5 Thinking | RUN-54: Runtime-Logging mit logs-Verzeichnis, File-Logger, Health-Ausgabe, Starter-Anbindung, Readiness-Test und Guard-Tests | [prompts/2026-07-10-chatgpt-run54-runtime-logging.md](prompts/2026-07-10-chatgpt-run54-runtime-logging.md) | [reports/2026-07-10-chatgpt-run54-runtime-logging.md](reports/2026-07-10-chatgpt-run54-runtime-logging.md) |
| 2026-07-09 | ChatGPT / GPT-5.5 Thinking | Hotfix RUN-51: Kollegeninstallationslauf ohne `System.Object[]`-RunDirectory/UploadZip, deterministische RunBundle-Pfade, Version 0.51.1 | [prompts/2026-07-09-chatgpt-run51-colleague-install-rundir-hotfix.md](prompts/2026-07-09-chatgpt-run51-colleague-install-rundir-hotfix.md) | [reports/2026-07-09-chatgpt-run51-colleague-install-rundir-hotfix.md](reports/2026-07-09-chatgpt-run51-colleague-install-rundir-hotfix.md) |
| 2026-07-09 | ChatGPT / GPT-5.5 Thinking | RUN-51: Kollegeninstallationspaket mit Desktop-ZIP, Portable-ZIP, optionaler Setup-EXE, Manifest, Checksums und Readiness-Lauf | [prompts/2026-07-09-chatgpt-run51-colleague-install-kit.md](prompts/2026-07-09-chatgpt-run51-colleague-install-kit.md) | [reports/2026-07-09-chatgpt-run51-colleague-install-kit.md](reports/2026-07-09-chatgpt-run51-colleague-install-kit.md) |
| 2026-07-09 | ChatGPT / GPT-5.5 Thinking | Hotfix RUN-50: DPAPI-Pfadtrim in Get-LocalSecret.ps1 plattformrobust, SecretSafety-Roundtrip stabilisieren, Version 0.50.4 | [prompts/2026-07-09-chatgpt-run50-dpapi-path-trim-hotfix.md](prompts/2026-07-09-chatgpt-run50-dpapi-path-trim-hotfix.md) | [reports/2026-07-09-chatgpt-run50-dpapi-path-trim-hotfix.md](reports/2026-07-09-chatgpt-run50-dpapi-path-trim-hotfix.md) |
| 2026-07-09 | ChatGPT / GPT-5.5 Thinking | Hotfix RUN-50: DPAPI-Blob robust lesen/schreiben, SecretSafety-Roundtrip stabilisieren, Version 0.50.3 | [prompts/2026-07-09-chatgpt-run50-dpapi-blob-trim-hotfix.md](prompts/2026-07-09-chatgpt-run50-dpapi-blob-trim-hotfix.md) | [reports/2026-07-09-chatgpt-run50-dpapi-blob-trim-hotfix.md](reports/2026-07-09-chatgpt-run50-dpapi-blob-trim-hotfix.md) |
| 2026-07-09 | ChatGPT / GPT-5.5 Thinking | Hotfix RUN-50: SecretSafety-RunDirectory, maschinenlesbares New-RunLogBundle und nicht-leeres UPLOAD_ZIP, Version 0.50.2 | [prompts/2026-07-09-chatgpt-run50-secret-safety-rundir-hotfix.md](prompts/2026-07-09-chatgpt-run50-secret-safety-rundir-hotfix.md) | [reports/2026-07-09-chatgpt-run50-secret-safety-rundir-hotfix.md](reports/2026-07-09-chatgpt-run50-secret-safety-rundir-hotfix.md) |
| 2026-07-09 | ChatGPT / GPT-5.5 Thinking | Hotfix ReleaseCandidateReadiness: RunDirectory wird direkt im Skript erstellt, FAILED/Manifest/UPLOAD_ZIP robust, Version 0.50.1 | [prompts/2026-07-09-chatgpt-run50-release-candidate-rundir-hotfix.md](prompts/2026-07-09-chatgpt-run50-release-candidate-rundir-hotfix.md) | [reports/2026-07-09-chatgpt-run50-release-candidate-rundir-hotfix.md](reports/2026-07-09-chatgpt-run50-release-candidate-rundir-hotfix.md) |
| 2026-07-06 | Claude Code / Fable 5 | Desktop-Installation (self-contained + Klick-Start), Installer-Vorbereitung (Inno Setup), i18n-Fundament 18 Sprachen, Codex-Roadmap RUN-01…21 | [prompts/2026-07-06-fable-installation-i18n.md](prompts/2026-07-06-fable-installation-i18n.md) | [reports/2026-07-06-fable-installation-i18n.md](reports/2026-07-06-fable-installation-i18n.md) |
| 2026-07-09 | ChatGPT / GPT-5.5 Thinking | Build-Fix nach Pull auf 0.42.0: Legacy-obj/bin aus MSBuild-Globs ausschließen, Clean-Generated erweitern, Version 0.42.1 | [prompts/2026-07-09-chatgpt-buildfix-legacy-obj.md](prompts/2026-07-09-chatgpt-buildfix-legacy-obj.md) | [reports/2026-07-09-chatgpt-buildfix-legacy-obj.md](reports/2026-07-09-chatgpt-buildfix-legacy-obj.md) |
| 2026-07-09 | ChatGPT / GPT-5.5 Thinking | Lokale Secret-/npm-Auth-Härtung: `.secrets/local`, DPAPI-Helfer, isolierter npm-Safe-Runner, Release-/Paketierungsskripte verdrahtet, Version 0.42.2 | [prompts/2026-07-09-chatgpt-secrets-npm-auth.md](prompts/2026-07-09-chatgpt-secrets-npm-auth.md) | [reports/2026-07-09-chatgpt-secrets-npm-auth.md](reports/2026-07-09-chatgpt-secrets-npm-auth.md) |
| 2026-07-09 | ChatGPT / GPT-5.5 Thinking | Hotfix npm-Safe-Runner: Argumentbindung fuer `npm run build` korrigiert, Release-/Paketierungsskripte angepasst, Version 0.42.3 | [prompts/2026-07-09-chatgpt-npmsafe-argumentbinding.md](prompts/2026-07-09-chatgpt-npmsafe-argumentbinding.md) | [reports/2026-07-09-chatgpt-npmsafe-argumentbinding.md](reports/2026-07-09-chatgpt-npmsafe-argumentbinding.md) |
| 2026-07-09 | ChatGPT / GPT-5.5 Thinking | Hotfix: ReleaseGate/Paketierung nutzen bei Lockfile `npm ci` statt `npm install`, um Windows-Fehler durch erneute `latest`-Aufloesung zu vermeiden | [prompts/2026-07-09-chatgpt-npm-ci-lockfile.md](prompts/2026-07-09-chatgpt-npm-ci-lockfile.md) | [reports/2026-07-09-chatgpt-npm-ci-lockfile.md](reports/2026-07-09-chatgpt-npm-ci-lockfile.md) |
| 2026-07-09 | ChatGPT / GPT-5.5 Thinking | Hotfix: npm-Dependencies exakt gepinnt, ReleaseGate zurueck auf `npm install` ueber NpmSafe, Run-Log-Bundler fuer ruhige Terminalausgaben ergaenzt | [prompts/2026-07-09-chatgpt-npm-pinning-runlogs.md](prompts/2026-07-09-chatgpt-npm-pinning-runlogs.md) | [reports/2026-07-09-chatgpt-npm-pinning-runlogs.md](reports/2026-07-09-chatgpt-npm-pinning-runlogs.md) |
| 2026-07-09 | ChatGPT 5.5 Thinking | Hotfix: NpmSafe-Schalter `-NoAudit`/`-NoFund` statt dash-beginnender `-NpmArguments`; Release-/Paketierungsskripte angepasst, Run-Log-Bundle-Standard beibehalten | [prompts/2026-07-09-chatgpt-npmsafe-flags.md](prompts/2026-07-09-chatgpt-npmsafe-flags.md) | [reports/2026-07-09-chatgpt-npmsafe-flags.md](reports/2026-07-09-chatgpt-npmsafe-flags.md) |
| 2026-07-09 | ChatGPT 5.5 Thinking | RUN-05: Installer-Readiness, Desktop-/Installer-Manifeste, Inno-Setup-Testcheckliste, Build-Installer-Pfadoption, Version 0.43.0 | [prompts/2026-07-09-chatgpt-run05-installer-readiness.md](prompts/2026-07-09-chatgpt-run05-installer-readiness.md) | [reports/2026-07-09-chatgpt-run05-installer-readiness.md](reports/2026-07-09-chatgpt-run05-installer-readiness.md) |
| 2026-07-09 | ChatGPT | CommitGuard-Hotfix: NEXT_PROMPT.md lokal-only, bessere GitSafety-Trefferdiagnose | [prompts/2026-07-09-chatgpt-commitguard-next-prompt-local-only.md](prompts/2026-07-09-chatgpt-commitguard-next-prompt-local-only.md) | [reports/2026-07-09-chatgpt-commitguard-next-prompt-local-only.md](reports/2026-07-09-chatgpt-commitguard-next-prompt-local-only.md) |
| 2026-07-09 | ChatGPT 5.5 Thinking | RUN-03: Portable-ZIP-Frischordner-Test mit self-contained Paket, Manifest, Health/Dashboard/API-Smoke und Run-ZIP | [prompts/2026-07-09-chatgpt-run03-portable-fresh-folder.md](prompts/2026-07-09-chatgpt-run03-portable-fresh-folder.md) | [reports/2026-07-09-chatgpt-run03-portable-fresh-folder.md](reports/2026-07-09-chatgpt-run03-portable-fresh-folder.md) |

- 2026-07-09 ChatGPT: RUN-03 Hotfix 0.44.1 fuer Portable-Fresh-Folder-Test; leerer data-Ordner ist optional, Manifest/Root-Erkennung robuster.
| 2026-07-09 | ChatGPT 5.5 Thinking | RUN-03-Hotfix: Portable-Manifest verwendet robuste char[]-Trim-/Pfadsegmentlogik statt fehleranfaelligem TrimStart-Aufruf, Version 0.44.2 | [prompts/2026-07-09-chatgpt-run03-portable-trimstart-hotfix.md](prompts/2026-07-09-chatgpt-run03-portable-trimstart-hotfix.md) | [reports/2026-07-09-chatgpt-run03-portable-trimstart-hotfix.md](reports/2026-07-09-chatgpt-run03-portable-trimstart-hotfix.md) |
- 2026-07-09: RUN-08 PWA-Readiness via ChatGPT-Patch `docs/ai/prompts/2026-07-09-chatgpt-run08-pwa-readiness.md`.
| 2026-07-09 | ChatGPT 5.5 Thinking | RUN-17: lokaler Turnierassistent im UI mit Format-/Runden-/Zeit-/Brett-Empfehlung, Checklisten, Exportplan und Readiness-Skript, Version 0.46.0 | [prompts/2026-07-09-chatgpt-run17-turnierassistent-ui.md](prompts/2026-07-09-chatgpt-run17-turnierassistent-ui.md) | [reports/2026-07-09-chatgpt-run17-turnierassistent-ui.md](reports/2026-07-09-chatgpt-run17-turnierassistent-ui.md) |
| 2026-07-09 | ChatGPT 5.5 Thinking | RUN-10/11: lokale Chat-Hilfe/Wissensbasis im Assistenten, Schnellfragen, Kontextantworten, Chat-Export, keine externe KI/API, Version 0.47.0 | [prompts/2026-07-09-chatgpt-run10-11-local-knowledge-chat.md](prompts/2026-07-09-chatgpt-run10-11-local-knowledge-chat.md) | [reports/2026-07-09-chatgpt-run10-11-local-knowledge-chat.md](reports/2026-07-09-chatgpt-run10-11-local-knowledge-chat.md) |
| 2026-07-09 | ChatGPT 5.5 Thinking | RUN-11: lokale Wissensbasis als JSON/README aus UI-Code ausgelagert, Struktur-/Privacy-Readiness-Skript, Version 0.48.0 | [prompts/2026-07-09-chatgpt-run11-knowledge-base-externalized.md](prompts/2026-07-09-chatgpt-run11-knowledge-base-externalized.md) | [reports/2026-07-09-chatgpt-run11-knowledge-base-externalized.md](reports/2026-07-09-chatgpt-run11-knowledge-base-externalized.md) |

- 2026-07-09: RUN-15 Exportmanifest (`docs/ai/prompts/2026-07-09-chatgpt-run15-exportmanifest.md`)

- 2026-07-09 ChatGPT RUN-50: Release-/Betriebsunterbau mit Logging-Leveln, DPAPI-Secret-Selftest, ReleaseCandidateReadiness, Agenten-Skills und Unit-/Contract-Tests.

| 2026-07-09 | ChatGPT 5.5 Thinking | RUN-52: Kollegenpaket-Frischlauf-Test mit Checksums, Desktop-ZIP-Entpackung, Auto-Port, Health/Dashboard/API-Smoke und isoliertem Datenpfad, Version 0.52.0 | [prompts/2026-07-09-chatgpt-run52-colleague-fresh-run-test.md](prompts/2026-07-09-chatgpt-run52-colleague-fresh-run-test.md) | [reports/2026-07-09-chatgpt-run52-colleague-fresh-run-test.md](reports/2026-07-09-chatgpt-run52-colleague-fresh-run-test.md) |

## 2026-07-09 RUN-53 Klick-Installation

Kollegenpaket nach RUN-52 um einen Doppelklick-Installationspfad, Uninstall, Shortcut-Erzeugung, Frischinstallations-Smoke-Test, Doku, Skill und Guard-Test erweitern. Keine Secrets oder externen Projektabhaengigkeiten in das Paket aufnehmen.
