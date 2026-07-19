# SCHACHTURNIERMANAGER – BUILD WEEK INTEGRATION, REPOSITORY HYGIENE
# UND JURY-READINESS

Wir setzen den bisherigen primären Codex-/GPT-5.6-Sol-Thread fort.

Der vorherige Lauf endete bewusst fail-closed. Es darf nichts aufgrund alter
Todo-Listen oder Abschlussberichte blind als erledigt betrachtet werden.

HAUPTZIEL

Bis Montag entsteht ein sauberer, verständlicher, installierbarer und
präsentationsfähiger OpenAI-Build-Week-Candidate des SchachTurnierManagers.

Der Fokus liegt jetzt auf:

1. sicherer Integration der offenen Owner-PRs,
2. verständlicher UX und kohärentem Design,
3. sauberer Repository- und Quellcodestruktur,
4. klarer Codex-/GPT-5.6-Evidence,
5. vollständiger formaler Wettbewerbsvorbereitung,
6. reproduzierbarem Windows- und Android-Test,
7. einer konfliktarmen Arbeitsqueue für Marcel.

Keine Featurebreite um ihrer selbst willen.

Das Ziel ist kein vollständiges v1.0, kein Play-Store- oder F-Droid-Release und
keine öffentliche Veröffentlichung.

REPOSITORY

D:\KFM\KI-Projekte\sonstige\schach\SchachTurnierManager

REMOTE

Randspringer90/SchachTurnierManager

STANDARD-BRANCH

development

ZULETZT VERIFIZIERTER DEVELOPMENT-STAND

a6f68e8f8e31201f0b9ce2ea77a13c37a50b9518

Neu prüfen, nicht voraussetzen.

ERWARTETE OFFENE PRS

PR #50
STM-INFRA-008 – enge, fail-closed Android-Binärprüfung
zuletzt bekannter Head:
b52a54092c9529ea5cbc744f134ddc5fb15d6d87
Draft, Owner-Review erforderlich.

PR #49
STM-MOB-001 – Android-Companion
zuletzt bekannter Head:
5aecee91afd7959c0ad368a2b86bf33c55522580
Erst nach #50 erneut SHA-gebunden prüfen.

PR #51
STM-FACH-012 / Build-Week-UX und Demo
zuletzt bekannter Head:
6988a4e846ef378bfa5d4e54f67dfb80af62255e
UX_FREEZE_SHA:
8fbf021ef52c41392f047e76494d3b1f671ba48c
Draft, Owner-Review erforderlich.

Alle Daten direkt gegen GitHub verifizieren.

======================================================================
A. VERBINDLICHE SICHERHEITS- UND RECHTEREGELN
======================================================================

AGENTS.md bleibt die einzige verbindliche, providerneutrale Regelquelle.

Marcel ist Trusted Co-Developer, aber nicht Owner:

- kein direkter Push auf development oder main,
- kein eigener Merge,
- keine Branchschutz- oder Security-Änderungen,
- kein Force-Push,
- jeder PR wird vollständig statisch und fachlich geprüft.

Dieselben Prüfungen gelten auch für Owner- und Codex-PRs.

Kein:

- --no-verify
- git reset --hard
- git clean -fd
- git add .
- git add --all
- Blindmerge
- Abschalten oder pauschales Aufweichen eines Gates
- erfundene Evidence
- History-Rewrite
- Commit von APK, EXE, Keystore, Passwort oder echten Session-IDs
- öffentliche Veröffentlichung
- Tag oder GitHub Release
- Devpost-Einreichung

Dieser Auftrag autorisiert:

- lokale Änderungen und Commits,
- Updates der bereits vorhandenen Owner-PR-Branches #50, #49 und #51,
- Pushes auf diese Owner-Branches nach vollständig grünen lokalen Gates.

Dieser Auftrag autorisiert NICHT:

- Merge eines PR,
- GitHub Release,
- Tag,
- Upload von Binärartefakten,
- Devpost-Submission.

Bei einem erforderlichen Owner-Merge:

1. vollständige Review-Evidence erzeugen,
2. exakten Head-SHA nennen,
3. Merge-Empfehlung ausgeben,
4. mit einer einzigen klaren Owner-Aktion pausieren,
5. nach Bestätigung des Owners im selben Thread fortsetzen.

======================================================================
B. /feedback UND BUILD-WEEK-EVIDENCE
======================================================================

Prüfe zu Beginn, ob in diesem selben Thread bereits `/feedback` ausgeführt wurde.

Falls eine Session-ID vorliegt:

- nicht ausgeben,
- nicht committen,
- lokal sicher speichern unter:

  <RunRoot>\private\codex-feedback-session-id.txt

- SHA-256 der Session-ID bilden,
- nur den Hash und Metadaten öffentlich dokumentieren.

Falls keine ID vorliegt:

- die technische Arbeit fortsetzen,
- aber FEEDBACK_SESSION_ID_STATUS=PENDING setzen,
- vor Abschluss erneut sichtbar zur Ausführung von `/feedback` auffordern.

Erzeuge beziehungsweise konsolidiere:

docs/ai/run-metadata/

Ein maschinenlesbarer Datensatz pro relevantem KI-Lauf enthält mindestens:

- runId
- provider
- tool
- model
- toolVersion
- startedAt
- finishedAt
- purpose
- primaryPromptPath
- reportPath
- initialSha
- finalSha
- buildWeekCommitRange
- contributors
- ownerDecisions
- tests
- artifactManifest
- feedbackSessionIdStatus
- feedbackSessionIdSha256
- actualSessionIdCommitted=false

Keine tatsächliche Session-ID committen.

Die kanonischen Ablagen sind:

docs/ai/prompts/
docs/ai/reports/
docs/ai/run-metadata/
docs/ai/PROMPTS.md
docs/ai/LESSONS_LEARNED.md

Ein lokales Root-Verzeichnis `Prompts`, `Prompt`, `Reports` oder ähnliche
Dubletten ist nicht automatisch vertrauenswürdig und darf nicht blind committed
werden.

======================================================================
C. PHASE 0 – LOKALEN UND REMOTE-ZUSTAND REKONSTRUIEREN
======================================================================

Führe einen vollständigen, read-only Preflight durch:

git status --short --branch
git status --short --ignored
git remote -v
git fetch origin --prune
git branch --all --verbose
git log --oneline --decorate -50
git reflog -30
git worktree list
git stash list
git diff
git diff --cached
git diff --check
git config --get core.hooksPath
git ls-files
gh auth status
gh pr list --repo Randspringer90/SchachTurnierManager --state open
gh issue list --repo Randspringer90/SchachTurnierManager --state open

Inventarisiere zusätzlich:

- sämtliche Dateien im lokalen Repository,
- getrackte Dateien,
- ungetrackte Dateien,
- ignorierte Dateien,
- Junctions und Symlinks,
- Case-only-Dubletten,
- Verzeichnisse `Prompts`, `prompts`, `Reports`, `logs`, `agents`,
  `.agents`, `.claude`, `.codex`, `.secrets`, `secrets`,
- lokale APKs und Setup-EXEs,
- externe Run-Ordner,
- aktive Codex-/Claude-/Nightly-Prozesse und Locks.

Für jede lokale Datei außerhalb des Git-Index klassifizieren:

GENERATED
LOCAL_SECRET
LOCAL_RUNTIME
UNTRACKED_SOURCE
DUPLICATE
STALE_HANDOFF
NEEDS_REVIEW
UNKNOWN

Nichts löschen, verschieben oder committen, bevor das Inventar vollständig ist.

Erzeuge:

docs/architecture/REPOSITORY_LAYOUT_AUDIT.md

und lokal:

<RunRoot>\00-preflight\local-vs-git-inventory.json
<RunRoot>\00-preflight\untracked-files.txt
<RunRoot>\00-preflight\ignored-files.txt
<RunRoot>\00-preflight\tracked-files.txt
<RunRoot>\00-preflight\local-remote-differences.md

Beantworte nachvollziehbar:

- Welche lokalen Dateien fehlen in Git?
- Welche davon sollten tatsächlich versioniert werden?
- Welche sind nur Build-, Lauf-, Secret- oder Übergabedaten?
- Welche Dateien existieren remote, aber lokal nicht?
- Gibt es doppelte oder historisch überholte Verzeichnisse?
- Ist der aktuelle Klon vollständig und gesund?

======================================================================
D. PHASE 1 – OFFENE PRS IN SICHERER REIHENFOLGE
======================================================================

Vorgesehene Reihenfolge:

1. PR #50 prüfen und Owner-Entscheidung vorbereiten.
2. Nach bestätigtem Merge von #50 development aktualisieren.
3. PR #49 gegen den neuen Base-SHA und unveränderten Head vollständig neu prüfen.
4. PR #49 nur nach erneuter SHA-gebundener Freigabe zur Owner-Entscheidung vorlegen.
5. Nach bestätigtem Merge von #49 development aktualisieren.
6. PR #51 gegen den neuen Stand kontrolliert aktualisieren oder auf einem frischen
   Owner-Integrationsbranch übernehmen.
7. PR #51 erneut vollständig prüfen und zur Owner-Entscheidung vorlegen.

Keine vermischten Integrationscommits.

PR #50 besonders prüfen auf:

- enge Bindung an PR, Head, Pfad, Blob-SHA und SHA-256,
- PNG-Signaturen, CRC, Dimensionen, Chunks und trailing bytes,
- Gradle-Wrapper-Provenienz und Checksums,
- fail-closed bei jeder Drift,
- keine generelle Binary-Allowlist,
- BAT-Fleet unterscheidet eng zwischen STM-Produktstarter und offiziellem
  Drittanbieter-Buildwrapper,
- keine Testabschwächung.

PR #49 besonders prüfen auf:

- Capacitor- und Gradle-Abhängigkeiten,
- keine Tracker,
- keine feste IP,
- nur minimale Permissions,
- Test-HTTP nur für den klar dokumentierten LAN-Testmodus,
- keine globale Abschaltung der Zertifikatsprüfung,
- sichere lokale URL-Speicherung,
- kein Secret und kein privater Host in der APK,
- stabile Application-ID,
- Signing nur außerhalb des Repositories.

PR #51 besonders prüfen auf:

- kein stiller Wechsel bestehender Pairing-Strategien,
- Optimal V2 bleibt Default,
- FIDE Dutch explizit und verständlich,
- synthetische Demo ohne reale Personen,
- deutsche und englische Demo-Flows vollständig,
- mobile und Desktop-UX,
- keine versteckte Funktionsentfernung,
- keine bloße Testanpassung an fehlerhaftes Verhalten,
- README und Aussagen stimmen mit dem wirklichen Stand überein,
- geschütztes Prompt-Tooling vollständig durch Owner geprüft.

======================================================================
E. PHASE 2 – REPOSITORY-STRUKTUR KONSOLIDIEREN
======================================================================

Diese Arbeit erfolgt erst nach einem stabilen Integrationsstand und in einem
eigenen Owner-Paket.

Keine großflächige kosmetische Verschiebung kurz vor der Submission.

Ziel ist eine klare, dokumentierte Struktur mit möglichst wenig Dateibewegungen.

KANONISCHE STRUKTUR

1. `AGENTS.md`
   - einzige verbindliche KI-Regelquelle,
   - providerneutral,
   - keine Codex-/Claude-Dublette.

2. `agents/`
   - providerneutrale Agentenrollen,
   - weiterhin über `config/agent-manifest.json` referenziert.

3. `.agents/skills/`
   - providerneutrale Skills,
   - keine zweite Skillkopie in `.claude` oder `.codex`.

4. `.claude/`
   - nur dünner Claude-Code-Adapter,
   - keine eigenen widersprechenden Regeln.

5. `.codex/`
   - neuen dünnen, getrackten Codex-Adapter anlegen,
   - mindestens `.codex/README.md`,
   - optional `config.example.toml`, aber niemals echte lokale Konfiguration,
     Tokens oder maschinenspezifische Werte,
   - verweist ausschließlich auf `AGENTS.md`, `agents/`,
     `.agents/skills/`, Projektorchestrierung und Security-Regeln,
   - Codex-spezifische Wettbewerbshinweise dürfen dokumentiert werden,
     aber keine zweite Regelwahrheit erzeugen.

6. `.secrets/`
   - einziger kanonischer dokumentierter Secret-Ort,
   - nur README getrackt,
   - `.secrets/local/**` ignoriert.

7. `secrets/`
   - als Legacy klassifizieren,
   - alle Code- und Dokumentreferenzen inventarisieren,
   - Skripte kontrolliert auf `.secrets/local/` migrieren,
   - Abwärtskompatibilität nur so lange beibehalten, wie sie real nötig ist,
   - anschließend `secrets/README.md` entfernen oder in einen klaren
     Deprecation-Hinweis überführen,
   - niemals Secretdateien bewegen oder committen.

8. `logs/`
   - nur README und `.gitkeep` tracken,
   - dokumentieren, wann Entwicklungs-, Desktop- und Portable-Logs entstehen,
   - keine Laufzeitlogs committen.

9. `docs/ai/`
   - Prompts, Reports, Metadaten und Lessons eindeutig zusammenführen,
   - lokale Root-Dubletten nur nach Inhaltsprüfung migrieren,
   - keine sensiblen historischen Prompts ungeprüft veröffentlichen.

Erzeuge:

docs/architecture/REPOSITORY_LAYOUT.md
docs/architecture/AI_PROVIDER_ADAPTERS.md
docs/ai/README.md

Füge einen kurzen Abschnitt in die Haupt-README ein:

“AI-assisted development structure”

Dort Codex für die Build-Week-Arbeit klar priorisieren, aber frühere Beiträge
von Claude und Marcel korrekt attributieren.

KEINE unwahre Aussage, dass ausschließlich Codex den gesamten Quellcode
geschrieben habe.

Ermittle anhand von Promptlogs, Reports und Commits, welche Aussage zur
Codex-Nutzung tatsächlich belegbar ist.

======================================================================
F. PHASE 3 – QUELLCODESTRUKTUR UND FRONTEND-MODULARISIERUNG
======================================================================

Der Jurybericht kritisiert zu Recht die monolithische Frontendstruktur.

Vor jeder Extraktion:

- bestehende Charakterisierungs- und UI-Tests prüfen,
- fehlende Tests für den aktuellen Demo-Hauptpfad ergänzen,
- keine fachliche Verhaltensänderung mit einer Strukturänderung vermischen.

Nach Integration von PR #51 prüfen:

- Größe und Verantwortlichkeiten von `main.tsx`,
- Anzahl React-States,
- API-Aufrufe,
- eingebettete Typdefinitionen,
- Assistent,
- lokale Wissensbasis,
- QR-/Chess960-/PWA-Logik,
- Turnieranlage,
- Teilnehmer,
- Runde/Ergebnisse,
- Tabelle/Export.

Zielstruktur nur schrittweise:

src/SchachTurnierManager.WebApp/src/
  app/
    App.tsx
    AppShell.tsx
    navigation.ts
  api/
    client.ts
    contracts.ts
  features/
    tournaments/
    participants/
    rounds/
    standings/
    imports-exports/
    assistant/
    mobile-companion/
  components/
  hooks/
  i18n/
  styles/

Vorgaben:

- keine große neue UI-Framework-Dependency,
- keine neue State-Management-Library nur für die Bereinigung,
- API- und Domainverhalten unverändert,
- kleine nachvollziehbare Commits,
- jede Extraktion durch Tests abgesichert,
- keine tiefgreifende Umstellung, falls sie den Montagstermin gefährdet.

Priorität:

1. API-Contracts und Client extrahieren.
2. reine UI-Komponenten extrahieren.
3. unabhängige Feature-Hooks extrahieren.
4. App-Shell und Navigation trennen.
5. erst anschließend weitere State-Konsolidierung.

Abbruchkriterium:

Sobald der Code klarer strukturiert ist und der Demo-Pfad stabil bleibt,
keine zusätzliche Architekturarbeit nur zur optischen Perfektion beginnen.

======================================================================
G. PHASE 4 – JURY- UND AI-LESBARKEIT
======================================================================

Die offiziellen Regeln erlauben auch automatisierte AI-Analyse.

Ein Juror oder ein automatisches System muss in den ersten Dateien sofort
erkennen:

- welches Problem gelöst wird,
- für wen,
- was während Build Week neu entstand,
- wie Codex und GPT-5.6 eingesetzt wurden,
- was der Owner entschied,
- was Marcel beitrug,
- welche Teile Claude zuvor unterstützte,
- wie das Produkt in fünf Minuten getestet wird,
- welche Grenzen ehrlich bestehen.

Erzeuge im Root:

BUILD_WEEK.md

Erzeuge:

docs/submission/INDEX.md
docs/submission/submission-manifest.json
docs/submission/BUILD_WEEK_BEFORE_AFTER.md
docs/submission/CODEX_COLLABORATION.md
docs/submission/HUMAN_DECISIONS.md
docs/submission/CONTRIBUTOR_ATTRIBUTION.md
docs/submission/JUDGE_QUICKSTART.md
docs/submission/KNOWN_LIMITATIONS.md
docs/submission/FINAL_CHECKLIST.md

`submission-manifest.json` enthält mindestens:

- projectName
- tagline
- track
- primaryAudience
- uniqueValue
- buildWeekStart
- buildWeekCommitRange
- candidateSha
- version
- primaryCodexRun
- model
- codexVersion
- feedbackSessionIdStatus
- feedbackSessionIdSha256
- actualSessionIdCommitted=false
- demoData
- setupArtifact
- androidArtifact
- testSummary
- licenseStatus
- knownLimitations
- videoStatus

Positionierung:

“Audit-first tournament operations for local chess clubs.”

Nicht nur:

“Chess tournament manager.”

Klar herausarbeiten:

- Fehler werden vor der Auslosung sichtbar.
- Kritische Aktionen sind abgesichert.
- Entscheidungen und Korrekturen bleiben auditierbar.
- Betrieb ist lokal und ohne Cloudpflicht möglich.
- Smartphone und Turnier-PC bilden einen einfachen lokalen Workflow.

README – erste Bildschirmseite:

1. Ein-Satz-Nutzenversprechen.
2. Ein echtes Produktscreenshot.
3. Drei primäre Fähigkeiten.
4. Windows-Quickstart.
5. Demo-Datensatz.
6. Build-Week-Neuerungen.
7. Codex-/GPT-5.6-Nachweis.
8. bekannte Grenzen.

Veraltete Aussagen vollständig entfernen.

======================================================================
H. PHASE 5 – FORMALE BLOCKER
======================================================================

1. LIZENZ

Das öffentliche Repository hat derzeit keine klare Lizenz.

Keine Lizenz automatisch auswählen.

Prüfe:

- aktuelle Urheberschaft,
- Contributor-Beiträge,
- vorhandene Contributor-Vereinbarungen,
- externe Quellen und Assets,
- Abhängigkeiten,
- Möglichkeiten einer MIT-, Apache-2.0- oder anderen passenden Lizenz.

Erzeuge:

docs/submission/LICENSE_DECISION.md
docs/submission/CONTRIBUTOR_CONSENT_STATUS.md

Bereite für den Owner eine konkrete Entscheidungsmatrix und gegebenenfalls eine
kurze Einverständnisnachricht an Marcel vor.

LICENSE_STATUS bleibt OWNER_DECISION_REQUIRED, bis der Owner entscheidet und
notwendige Zustimmungen geklärt sind.

2. ÖFFENTLICHE HISTORIE

Kein History-Rewrite vor dem Wettbewerb.

Führe eine reine Auditprüfung der erreichbaren Historie auf:

- Secrets,
- interne Hosts,
- Registry-URLs,
- PII,
- große Binärdateien,
- private Logs.

Erzeuge bei Findings einen Clean-Snapshot-Plan.

Nichts automatisch öffentlich neu veröffentlichen.

3. CODEX-EVIDENCE

Stelle sicher:

- Prompt eingecheckt,
- Report eingecheckt,
- Run-Metadaten vorhanden,
- Build-Week-Commitbereich dokumentiert,
- `/feedback`-ID lokal gesichert,
- nur Hash im Repo,
- README beschreibt konkrete Beschleunigung und konkrete menschliche
  Entscheidungen.

======================================================================
I. PHASE 6 – WIRKUNGS- UND ORIGINALITÄTSNACHWEIS
======================================================================

Keine erfundenen Nutzerstimmen.

Erzeuge stattdessen belastbare synthetische Messungen:

- Zeit für Installation,
- Zeit bis zum ersten Demo-Turnier,
- Zeit bis zur ersten Auslosung,
- Zeit zur Ergebniseingabe per Smartphone,
- Anzahl erforderlicher Hauptaktionen,
- Fehler, die die Paarungsvorschau verhindert,
- Neustart- und Wiederherstellungsverhalten.

Erzeuge:

docs/submission/IMPACT_EVIDENCE.md
docs/submission/TOURNAMENT_DAY_DRY_RUN.md
docs/submission/COMPETITOR_DIFFERENTIATION.md

Vergleiche fair und ohne abwertende Aussagen:

- klassische lokale Turnierprogramme,
- browserbasierte Werkzeuge,
- Cloudlösungen.

Differenzierung:

- audit-first,
- local-first,
- guided workflow,
- sichere mobile Ergänzung,
- nachvollziehbare KI-gestützte Entwicklung.

======================================================================
J. PHASE 7 – MARCELS BUILD-WEEK-QUEUE
======================================================================

Bereite viele vollständige Aufgaben vor, aber starte nicht alles gleichzeitig.

Maximal:

- 2 In Progress
- 3 Ready
- Rest Backlog oder Blocked

Zentrale UX-Dateien bleiben bis zum finalen UX-Freeze reserviert.

Erzeuge:

docs/planning/MARCEL_BUILD_WEEK_QUEUE_2026-07-19.md
docs/ai/prompts/marcel-build-week/

Erzeuge vollständige Contributor-Prompts für:

PRIORITÄT A

1. STM-SEC-006
   CSV-Formula-Injection-Schutz für sämtliche tabellarischen Exporte.

2. STM-UX-009
   Benutzerhandbuch und Turniertag-Walkthrough auf Deutsch und Englisch.

3. STM-UX-010
   Geräte- und Breakpoint-Testmatrix mit dokumentierter Evidence.

4. STM-REL-003
   Frischinstallations-/Kollegen-PC-Test mit synthetischen Daten.

5. STM-UX-011
   fokussierter Accessibility-Audit nach UX_FREEZE_SHA.

6. STM-INFRA-009
   Link-, Verweis- und Dokumentationskonsistenzprüfung.
   Keine Agenten-, Security-, Skill-, Config- oder Secretänderung.

PRIORITÄT B – nach Candidate-Freeze

7. STM-FACH-003
   große Schweizer Felder, ohne Regelabschwächung.

8. STM-IE-004
   read-only FIDE-Namenssuche mit Bestätigung, Cache und Rate Limit.

9. STM-FACH-007
   Ergebniskorrektur und Neuberechnung mit Audit-Trail.

10. STM-UX-007
    Duplikaterkennung ohne automatische Löschung.

Für jeden Prompt:

- exakter Base-SHA,
- eigener Feature-Branch,
- erlaubte und verbotene Dateien,
- Akzeptanzkriterien,
- Tests,
- Security-Prüfungen,
- Doku,
- PR-Beschreibung,
- kein direkter Push auf development/main,
- kein eigener Merge,
- kein Force-Push,
- keine Gateänderung,
- keine Secrets,
- keine Binärartefakte.

Marcel soll bis zum Submission-Freeze bevorzugt Dokumentation, Testmatrix,
CSV-Sicherheit und klar abgegrenzte Accessibility-Pakete bearbeiten.

Keine parallelen Arbeiten an denselben zentralen Frontenddateien.

======================================================================
K. PHASE 8 – FINALER WINDOWS- UND GALAXY-S25-CANDIDATE
======================================================================

Erst nach vollständig bestätigter Merge-Reihenfolge:

1. exakten Candidate-SHA bestimmen,
2. Version konsistent aktualisieren,
3. Setup-EXE neu bauen,
4. Installer-Smoke isoliert ausführen,
5. Desktop-Neustart und Persistenz prüfen,
6. signierte Android-Test-APK neu bauen,
7. apksigner verify,
8. APK-Inhalt und Permissions prüfen,
9. Hashes erzeugen,
10. Artefaktmanifest erzeugen.

Keine alten Artefakte als final ausgeben.

Keine Binärdateien committen.

Erzeuge:

<RunRoot>\artifacts\windows\
<RunRoot>\artifacts\android\
<RunRoot>\artifacts\checksums\
<RunRoot>\artifacts\candidate-manifest.json

Bereite den manuellen Owner-Test für morgen vor:

- Windows-Installation,
- Demo-Turnier,
- Auslosung,
- Ergebnis,
- Tabelle,
- Neustart,
- Export,
- Deinstallation,
- Galaxy-S25-Installation,
- LAN-Verbindung,
- mobile Ergebniseingabe,
- Rotation,
- Neustart,
- Upgrade,
- Deinstallation.

======================================================================
L. FINALE JURY-SIMULATION
======================================================================

Bewerte den Candidate als kritischer Juror und als automatisches Analysemodell.

Vier Kriterien, je 25 Punkte:

- Technological Implementation
- Design
- Potential Impact
- Quality of the Idea

Zusätzlich Pass/Fail:

- funktionierendes Projekt,
- Lizenz oder gültiger Private-Repo-Plan,
- README,
- Demo-Daten,
- Testpfad,
- Videoentwurf,
- Codex-/GPT-5.6-Evidence,
- `/feedback`-Status,
- Candidate-Artefakte,
- bekannte Grenzen.

Keine Punkte schönrechnen.

Erzeuge:

docs/submission/FINAL_JURY_REVIEW.md

Bei weniger als 80/100:

- die drei größten verbleibenden Abzüge nennen,
- nur P0/P1-Maßnahmen vor dem Freeze empfehlen,
- keine neue Featurewelle beginnen.

======================================================================
M. ABSCHLUSSAUSGABE
======================================================================

BUILD_WEEK_RUN=<OK|PARTIAL|BLOCKED>
INITIAL_DEVELOPMENT=<sha>
CURRENT_DEVELOPMENT=<sha>
PR50_HEAD=<sha>
PR50_REVIEW=<Status>
PR50_OWNER_ACTION=<Aktion>
PR49_HEAD=<sha>
PR49_REVIEW=<Status>
PR49_OWNER_ACTION=<Aktion>
PR51_HEAD=<sha>
PR51_REVIEW=<Status>
PR51_OWNER_ACTION=<Aktion>
MERGE_ORDER=<Reihenfolge>
LOCAL_VS_GIT_AUDIT=<Pfad>
REPOSITORY_LAYOUT=<OK|PARTIAL|BLOCKED>
CODEX_ADAPTER=<OK|PARTIAL|NOT_CREATED>
LEGACY_SECRETS=<MIGRATED|DOCUMENTED|BLOCKED>
PROMPT_STORAGE=<OK|PARTIAL|BLOCKED>
PROMPT_METADATA=<OK|PARTIAL|BLOCKED>
FRONTEND_MODULARIZATION=<OK|PARTIAL|DEFERRED>
BUILD_WEEK_MD=<Pfad>
SUBMISSION_MANIFEST=<Pfad>
LICENSE_STATUS=<Status>
HISTORY_AUDIT=<Status>
FEEDBACK_SESSION_ID_STATUS=<Status>
FEEDBACK_SESSION_ID_HASH=<Hash oder NOT_AVAILABLE>
CANDIDATE_SHA=<sha oder NOT_CREATED>
SETUP_EXE=<Pfad oder NOT_CREATED>
SETUP_SHA256=<Hash oder NOT_AVAILABLE>
APK=<Pfad oder NOT_CREATED>
APK_SHA256=<Hash oder NOT_AVAILABLE>
APK_SIGNATURE=<Status>
DEVICE_TEST=<MANUAL_READY|OK|BLOCKED>
MARCEL_QUEUE=<Pfad>
MARCEL_PROMPTS=<Anzahl>
JURY_SCORE=<0-100>
P0_BLOCKERS=<Liste>
P1_BEFORE_VIDEO=<Liste>
REPORT=<Pfad>
UPLOAD_ZIP=<Pfad>
NEXT_OWNER_ACTION=<genau eine Aktion>

Beginne jetzt mit dem Preflight und ändere vor Abschluss des lokalen-vs-Git-
Inventars keine Datei.

Achte hierdrauf:
SchachTurnierManager/
├─ AGENTS.md                         # einzige verbindliche KI-Regelquelle
├─ BUILD_WEEK.md                     # kompakte Wettbewerbsgeschichte
├─ agents/                           # providerneutrale Rollen
├─ .agents/
│  └─ skills/                        # providerneutrale Skills
├─ .claude/
│  └─ CLAUDE.md                      # dünner Claude-Adapter
├─ .codex/
│  ├─ README.md                      # dünner Codex-Adapter / Einstieg
│  └─ config.example.toml            # nur sichere Beispielkonfiguration
├─ .secrets/
│  └─ README.md                      # einziger dokumentierter Secret-Ort
├─ docs/
│  ├─ ai/
│  │  ├─ prompts/
│  │  ├─ reports/
│  │  ├─ run-metadata/
│  │  ├─ PROMPTS.md
│  │  └─ LESSONS_LEARNED.md
│  ├─ architecture/
│  │  └─ REPOSITORY_LAYOUT.md
│  └─ submission/
│     ├─ INDEX.md
│     ├─ submission-manifest.json
│     └─ ...
├─ logs/
│  ├─ README.md
│  └─ .gitkeep
├─ src/
├─ tests/
└─ scripts/
