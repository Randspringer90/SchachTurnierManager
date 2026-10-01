# SCHACHTURNIERMANAGER – FINAL INTEGRATION, ARCHITECTURE,
# UX, BUILD-WEEK CANDIDATE UND GIT COMPLETION

Quelle: Owner, primaerer Codex-/GPT-5.6-Sol-Thread, 2026-07-19.

Setze den bestehenden SchachTurnierManager-Lauf fort.

Du erhältst für diesen Lauf weitgehende technische Entscheidungsfreiheit. Löse
Probleme eigenständig und zielorientiert. Warte nicht nach jedem Zwischenschritt auf
eine neue Freigabe.

Das Endziel ist ein technisch sauberer, verständlicher, installierbarer und
präsentationsfähiger OpenAI-Build-Week-Candidate bis Montag.

Die Anwendung soll nach diesem Lauf:

- auf Windows über eine Setup-EXE installierbar sein,
- auf dem Samsung Galaxy S25 als Android-Companion laufen,
- eine verständliche und nicht überladene Benutzeroberfläche besitzen,
- technisch sinnvoll strukturiert sein,
- vollständig in Git gesichert sein,
- für Jury, automatisierte Analyse und manuellen Test verständlich dokumentiert sein.

## 1. AUSDRÜCKLICHE FREIGABE UND AUTONOMIE

Der Owner erteilt für diesen Lauf die Freigabe, innerhalb der beschriebenen Projekte und
Ziele selbstständig:

- Dateien zu ändern,
- Architektur zu verbessern,
- Tests zu ergänzen,
- Fehler zu beheben,
- lokale Branches anzulegen,
- Commits zu erstellen,
- Owner-Branches zu pushen,
- bestehende Owner-PRs zu aktualisieren,
- neue Owner-PRs anzulegen,
- vollständig grüne Owner-PRs zu mergen,
- development nach jedem Merge zu aktualisieren,
- Dokumentation und Wettbewerbsevidence zu committen und zu pushen.

Die drei offenen Owner-PRs #50, #49 und #51 dürfen nach vollständiger Prüfung gemergt
werden, wenn ihre Änderungen fachlich korrekt, alle relevanten Tests und Gates grün,
keine Security-Findings offen, die Head-SHAs erneut geprüft und keine bekannten
Submission-Blocker erzeugt werden.

Keine erneute Freigabe ist nötig für Tests, Builds, Fehlerkorrekturen, Refactorings,
Commits, Pushes, PR-Aktualisierungen, Owner-Merges, Dokumentation, lokale Setup-/APK-
Erzeugung oder notwendige Anpassungen an der Workstation-Hook-Infrastruktur.

Bei roten Tests, Buildfehlern, Mergekonflikten oder unpassenden PRs: Ursache analysieren,
sicher lösen, gezielt und vollständig testen, committen, pushen und weiterarbeiten.
Veraltete PR-Logik darf auf einem frischen Owner-Integrationsbranch vom aktuellen
development semantisch übernommen werden; der alte PR ist nachvollziehbar zu ersetzen.

Pausieren nur bei nicht selbst lösbaren Secret-, Rechte-/Branch-Protection-, Lizenz-,
Veröffentlichungs-/Devpost- oder destruktiven Datenverlustrisiken. Unabhängige Pakete
werden trotz eines blockierten Pakets weiterbearbeitet.

## 2. REPOSITORIES UND STARTSTAND

Hauptrepository:
`D:\KFM\KI-Projekte\sonstige\schach\SchachTurnierManager`

Remote: `Randspringer90/SchachTurnierManager`, Standardbranch `development`, zuletzt
extern verifiziert `a6f68e8f8e31201f0b9ce2ea77a13c37a50b9518`.

Externe BAT-Fleet-/Commit-Hook-Zentrale: `Randspringer90/WS-KFM-Codex-Zentrale`,
Startanker `421f6d32af2030318e229e2bd42c06c434e16cd9`. Kanonischen Pfad ermitteln und
fremde lokale Registry-Änderungen nicht überschreiben.

Bekannte PRs:

- #50, `security/STM-INFRA-008-android-artifact-gates`, Head
  `b52a54092c9529ea5cbc744f134ddc5fb15d6d87`.
- #49, `integration/pr-43-safe-adoption`, Head
  `5aecee91afd7959c0ad368a2b86bf33c55522580`.
- #51, `feature/STM-FACH-012-build-week-ux`, Head
  `6988a4e846ef378bfa5d4e54f67dfb80af62255e`.

Bekannter PR-#50-Hardening-Patch: SHA-256
`5f33c21db2cd06d8caf1ed1efede8b17171177fb8e1f0717be300f64bb855c99`, Basis
`b52a54092c9529ea5cbc744f134ddc5fb15d6d87`. Evidence unter dem vorherigen RunRoot.
Alle Angaben erneut verifizieren.

## 3. SOFORTIGER PREFLIGHT

In beiden Repositories Branch, HEAD, Remote-HEAD, Arbeitsbaum, staged/untracked/ignored,
Stashes, Worktrees, offene PRs, Prozesse, Locks, unpushed Commits, Hooks und CI prüfen.
Im SchachTurnierManager mindestens alle vorgegebenen Git-/gh-Kommandos ausführen.
Nichts unbesehen löschen oder überschreiben; lokale Arbeit rekonstruieren. Stabilen
Run-Ordner `D:\KFM\logs\SchachTurnierManager\runs\STM_FINAL_BUILD_WEEK_<Timestamp>`
anlegen. Checkpoints sind keine Stopppunkte.

## 4. LINKED-WORKTREE-/BAT-FLEET-PROBLEM

Zuerst den Commit-Blocker in WS-KFM-Codex-Zentrale beheben. Linked Worktrees unter
`D:\KFM\logs\...` müssen über Git-Common-Directory beziehungsweise echte Worktree-
Metadaten eindeutig dem registrierten Hauptrepository zugeordnet werden. Normale Repos
bleiben unverändert; fremde Repos werden nicht zugeordnet; Junctions/Symlinks sicher
behandeln; bei Uneindeutigkeit fail-closed; fremde Registry-Änderungen nicht überschreiben.
Tests für Hauptrepo, Linked Worktree, fremdes Repo und manipulierte Pfade. Separater
Branch, Tests, Commit, Push und Merge bei grünen Gates. Danach real am isolierten
Schach-Worktree testen. Kein `--no-verify`, kein Pfad-Bypass.

## 5. PR #50

Nach dem Hook-Fix Patch-Bindung erneut prüfen, Patch committen und auf PR #50 pushen,
Evidence/PR aktualisieren, Draft aufheben, CI abwarten und bei vollständigem Grün nach
development mergen. Weiter fail-closed, ohne allgemeine Binary-Allowlist; Bindung an PR,
Head, Pfad, Blob, SHA-256, Größe und Typ; echte PNG-/Metadaten- und Gradle-Provenienz-
Prüfung; Drift invalidiert; gradlew.bat eng als Drittanbieter-Buildwrapper; normale
Produktstarter bleiben streng. Merge-SHA und GitHub-Sichtbarkeit dokumentieren.

## 6. PR #49

Nach #50 vollständig gegen neues development prüfen: Diff, Dependencies, Capacitor 7.4.3,
Gradle, Ressourcen, Manifest, Network Security, Permissions, feste IPs/interne Hosts,
Secrets, Tracker, URL-Speicherung, Launcher-UX, Flavors, Signing, APK. Passenden PR
aktualisieren oder saubere semantische Neuübernahme; testen, pushen, CI, mergen,
development aktualisieren. APK erst nach allen Candidate-Änderungen final nennen.

## 7. PR #51

Nach #49 gegen aktuelles development prüfen und bei Bedarf auf frischem Owner-
Integrationsbranch übernehmen. Pairing-Strategie, Anfangsfarbe, Demo, README/Submission,
Prompt-Tooling und UX-Freeze fachlich prüfen. Optimal V2 bleibt Standard; FIDE Dutch
explizit; keine stille Migration; Anfangsfarbe verständlich; synthetische Daten; ruhige
Navigation; fortgeschrittene Funktionen sekundär; Deutsch/Englisch vollständig;
Prompt-Tooling sicher. Commit, Push, Draft aufheben, CI, Merge, development aktualisieren.

## 8. NEUE PRS

GitHub regelmäßig prüfen. Jeden neuen PR SHA-gebunden statisch prüfen und nach Stabilität,
Security, UX, Doku, Accessibility, Demo und Testbarkeit bewerten. Rechtzeitig sichere
Beiträge integrieren; sonst sinnvoll extrahieren/aktuell neu implementieren und Attribution
erhalten. Keine Featurewelle vor Freeze.

## 9. REPOSITORY UND QUELLCODE AUFRÄUMEN

Nach Integration vollständiges Datei-/Ordnerinventar. Kanonisch: `AGENTS.md`, `agents/`,
`.agents/skills/`, dünne `.claude/`- und `.codex/`-Adapter, `.secrets/` als bevorzugter
Ort, `secrets/` deprecaten, `docs/ai/{prompts,reports,run-metadata}`, `logs/` nur README
und `.gitkeep`. Architekturübersicht erstellen. Keine Secrets, lokale Configs oder
Session-IDs committen; nur echte Quellen/Doku/Metadaten aufnehmen.

## 10. FRONTEND-ARCHITEKTUR

React/TypeScript gründlich prüfen: große Komponenten, Verantwortlichkeiten, API in UI,
Typ-/State-Duplikate, Effekte, Fehlergrenzen, Lade-/Leer-/Fehlerzustände, Navigation,
Testbarkeit, Mobile, Accessibility und Designkonsistenz. Schrittweise API-Client/Contracts,
App-Shell/Navigation, Featurelogik, UI-Komponenten, Hooks/Services und Design-Tokens
trennen. Keine unnötige State-/UI-Dependency. Refactorings mit Charakterisierungs-,
Komponenten- und Integrationstests absichern; nach größeren Schritten TypeScript,
Frontend, Vite, Backend und Demo-Smoke.

## 11. USABILITY UND DESIGN

Professionell, ruhig, sofort verständlich, nicht überladen. Perspektiven: neuer und
erfahrener Turnierleiter, Smartphone-Helfer und Fünf-Minuten-Jury. Klare Primäraktion,
Progressive Disclosure, seltene Funktionen unter Mehr/Erweitert, konsistente Hierarchie,
Begriffe und Buttons, touchfreundliche Ergebnisse, Mobile, Fokus, nicht nur Farbe,
verständliche Fehler-/Lade-/Leerzustände. Hauptworkflow: Start, Demo/Neuanlage,
Teilnehmer, Auslosung, Ergebnisse, Tabelle, optional Export. Prüfen bei 360, 390, 412,
768, 1024 und 1440 px, Light/Dark, Tastatur, Touch, Hoch-/relevantes Querformat.

## 12. BUILD-WEEK- UND JURY-READINESS

Vier gleich gewichtete Kriterien: Technological Implementation, Design, Potential Impact,
Quality of the Idea. Positionierung: “Audit-first tournament operations for local chess
clubs.” Repository erklärt Problem, Zielgruppe, technische Nichttrivialität,
Differenzierung, Build-Week-Neues, Codex/GPT-5.6, Owner-Entscheidungen, Marcel-/Claude-
Beiträge und Grenzen. Local-first, sichere auditierbare Aktionen, Paarungen, geführter
Workflow, Mobile, kompatible Exporte, keine Werbung/Tracking.

README, BUILD_WEEK und alle angegebenen Submission-Dateien aktualisieren/erzeugen,
einschließlich Index, Quickstart, Devpost-Entwurf, englischem Demo-Skript, Video-Shotlist,
Before/After, Codex-Zusammenarbeit, Human Decisions, Attribution, Limitations, Checklist
und Manifest. Keine Behauptung, das Gesamtprojekt sei erst in Build Week entstanden.

## 13. CODEX-SESSION-EVIDENCE

`/feedback`-Status prüfen. Echte ID nie ausgeben/committen/öffentlich loggen, nur lokal
sicher speichern; im Repo nur Status, Hash, Codex-Version, Modell, Prompt, Report und
Commitbereich. Fehlende ID blockiert Technik nicht; am Ende eine klare letzte Aktion.

## 14. TESTS, PUSH UND GIT-VOLLSTÄNDIGKEIT

Alle passenden Prüfungen: diff-check, PowerShell, Security, Prompt Injection, Instruction
Integrity, Open Source, Dependency, Collaboration, Routed mehrfach, dotnet restore/build/
test, npm ci/audit, TypeScript, Frontend-Tests, Vite, Android Lint/Gradle Debug+Release,
apksigner, Installer, Desktop/Portable, ReleaseGate, README-Linkcheck und synthetischer
Demo-E2E-Smoke. Fehler selbst lösen. Am Ende alle sinnvollen Quellen committed/gepusht,
integrierte PRs geschlossen, origin/development aktuell, lokales development identisch,
Arbeitsbaum sauber, keine unpushed Commits oder versteckte Source-Dateien. Binärartefakte,
Logs und Secrets bleiben außerhalb Git.

## 15. FINALER WINDOWS- UND ANDROID-CANDIDATE

Nach allen Merges/Refactorings Candidate-SHA festlegen und Windows-Desktop, Setup-EXE
und signierte Android-Test-APK exakt davon neu bauen. Version, SHA, Größe, SHA-256,
Buildzeit, Signatur, Fingerabdruck, Tools, Permissions und Grenzen dokumentieren. Klare
manuelle Windows- und Galaxy-S25-Testanleitung für Installation, Demo, Paarung, Ergebnis,
Tabelle, Neustart, Export/Verbindung, Rotation, Upgrade und Deinstallation.

## 16. CANDIDATE-FREEZE UND ABSCHLUSS

Bei stabilem Stand Freeze setzen, danach nur P0/P1 und notwendige Doku. Kritische
Jurybewertung je 25 Punkte, nicht schönrechnen. Finale Statusausgabe mit allen
vorgegebenen Feldern zu Git, Hook, PRs, Refactorings, Tests/CI/Security, Anforderungen,
Feedback, Candidate, Setup/APK, Device-Test, Jury, Blockern, Report, ZIP und höchstens
einer nächsten Aktion.

Beginne mit dem Preflight und arbeite autonom bis zum vollständigen Git-, Integrations-,
Architektur- und Candidate-Endzustand.
