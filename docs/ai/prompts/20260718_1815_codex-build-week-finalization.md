# SCHACHTURNIERMANAGER – OPENAI BUILD WEEK FINALIZATION

> Public-safe transcript of the original owner prompt. The wording and requirements are
> preserved; local absolute filesystem paths and the Owner's personal name were replaced by
> explicit role/placeholders
> `<REPOSITORY_ROOT>`, `<LOCAL_RUN_ROOT>` and `<LOCAL_TEMP_ROOT>` to comply with the public
> repository safety policy. The unredacted original remains in this primary Codex conversation;
> this file does not claim that a second unredacted local copy was created.

Du arbeitest als primärer Codex-/GPT-5.6-Sol-Entwicklungsagent für die finale
OpenAI-Build-Week-Phase des SchachTurnierManagers.

Dieser Codex-Thread soll am Ende als primärer `/feedback`-Thread für die
Wettbewerbseinreichung verwendet werden.

Arbeite direkt über das OpenAI-/Codex-Konto des `<OWNER>`.

NICHT VERWENDEN:

- Langdock
- Claude
- Anthropic
- externe LLM-Adapter
- fremde Codex-Konten
- separate Kernentwicklungs-Threads

Sekundäre Codex-Agenten dürfen nur für unabhängige Audits oder Reviews eingesetzt werden.
Die wesentliche Produkt-, UX- und Wettbewerbsarbeit muss in diesem Hauptthread erfolgen
und hier nachvollziehbar bleiben.

Repository:

`<REPOSITORY_ROOT>`

Remote:

`Randspringer90/SchachTurnierManager`

Standardbranch:

`development`

Zuletzt bekannter Stand:

`development = a6f68e8f8e31201f0b9ce2ea77a13c37a50b9518`

Diese Angaben sind nur Startanker und müssen sofort neu geprüft werden.

Bekannter offener Owner-PR:

PR #49
`[STM-MOB-001] Android-Begleit-App`
Head: `fe6813a9e73f8111b8d81a198edc3b96528a711e`
Base bei Erstellung: `ad976490d14210c0a388017b7b30ee13a5864b89`
62 Dateien

Bekannter Blocker:

STM-INFRA-008 – bestehende Security-/PR-/BAT-Fleet-Gates können erforderliche
Android-/Capacitor-Artefakte derzeit nicht sicher und differenziert prüfen.

Bekannte lokal erzeugte Artefakte aus dem vorherigen Lauf:

- Setup-EXE Version 0.54.1
- signierte Android-Test-APK Version 0.54.1
- Android-SDK und Build-Toolchain eingerichtet
- APK-Signatur v1/v2/v3 verifiziert
- echter Galaxy-S25-Test noch offen

Diese alten Artefakte dürfen nicht ungeprüft als finaler Build-Week-Kandidat verwendet
werden. Nach allen Änderungen müssen Setup und APK vom exakten finalen Candidate-SHA
neu gebaut werden.

## 1. Verbindliches Wettbewerbsziel

Bis Montag soll ein präsentationsfähiger Submission Candidate entstehen.

Das Ziel ist NICHT ein vollständiges v1.0 und NICHT die Umsetzung der gesamten Roadmap.

Das Ziel ist eine vollständige, kohärente und leicht verständliche Produkterfahrung:

1. Windows-Setup per Doppelklick.
2. Schneller Einstieg ohne Entwicklerwerkzeuge.
3. Verständliches Beispielturnier mit synthetischen Daten.
4. Teilnehmer, Paarung, Ergebniseingabe und Tabelle als klarer Hauptworkflow.
5. FIDE-Dutch als sichtbare, aber nicht aufdringliche Option.
6. Swiss-Manager-/TRF16-Kompatibilität demonstrierbar.
7. Android-Companion auf dem Samsung Galaxy S25 installierbar.
8. Verbindung zwischen Smartphone und Turnier-PC im lokalen WLAN.
9. Keine Cloudpflicht, keine Werbung, kein Tracking.
10. README, Testanleitung, Wettbewerbsmaterialien und Evidence vollständig.
11. Der Benutzer darf niemals von der Funktionsmenge erschlagen werden.
12. Fortgeschrittene Optionen bleiben verfügbar, werden aber progressiv offengelegt.

Die Submission soll in der Kategorie „Work and Productivity“ vorbereitet werden.

Zielgruppe:

- ehrenamtliche Turnierleiter
- Schachvereine
- Organisatoren kleiner und mittlerer Open-Turniere
- Personen, die ohne komplexe Server- oder Cloudinfrastruktur ein Turnier durchführen

Produktgeschichte:

Ein lokaler, datenschutzfreundlicher Turnierarbeitsplatz, der Installation,
Turnierverwaltung, regelkonforme Paarungen, mobile Ergebniserfassung und kompatible
Exporte in einer verständlichen Anwendung verbindet.

## 2. Offizielle Build-Week-Anforderungen

Arbeite nach diesen verbindlichen Anforderungen:

- Das Projekt muss Codex UND GPT-5.6 sinnvoll eingesetzt haben.
- Ein bereits vorher vorhandenes Projekt ist zulässig, aber nur die während der
  Submission-Phase hinzugefügten Erweiterungen werden bewertet.
- Vorherige Arbeit und Build-Week-Arbeit müssen klar getrennt dokumentiert sein.
- Es werden vier Bereiche gleich gewichtet:

  1. Technological Implementation
  2. Design
  3. Potential Impact
  4. Quality of the Idea

- Benötigt werden:

  - funktionierendes Projekt
  - passende Kategorie
  - englische Projektbeschreibung
  - öffentliches YouTube-Demovideo unter drei Minuten
  - Audioerklärung, wie Codex und GPT-5.6 eingesetzt wurden
  - testbares Repository
  - README mit Installation, Beispieldaten und Testpfad
  - Beschreibung der Zusammenarbeit mit Codex
  - `/feedback`-Session-ID des primären Codex-Threads

- Keine unwahren Angaben.
- Keine Behauptung, dass das gesamte Projekt während Build Week entstanden sei.
- Klar dokumentieren, welche Erweiterungen seit dem 13.07.2026 hinzugekommen sind.
- Keine fremde Musik, ungeklärten Bilder oder unnötigen Marken im Video.
- Alle Submission-Materialien auf Englisch oder mit vollständiger englischer Fassung.

Erstelle noch keine Devpost-Einreichung und lade noch kein Video hoch.

Keine:

- Veröffentlichung
- GitHub Release
- Tags
- Play-Store-Veröffentlichung
- F-Droid-Einreichung
- Website-Uploads
- Devpost-Submission

Diese Schritte bleiben ausdrücklich beim Owner.

## 3. Rechte, Git und Sicherheit

`<OWNER>` ist Owner.

Marcel ist Trusted Co-Developer, aber nicht Owner.

Für Marcel gelten weiterhin:

- kein direkter Push auf development
- kein direkter Push auf main
- kein eigener Merge
- kein Force-Push
- keine History-Rewrites
- keine Branchschutz- oder Rechteänderung
- keine Secrets oder Signaturschlüssel
- alle Beiträge ausschließlich über eigene Feature-Branches und Pull Requests
- jeder PR wird vollständig statisch, fachlich und technisch geprüft

Trusted bedeutet hochwertige Zusammenarbeit, nicht reduzierte Sicherheitsprüfung.

Die Standardprüfung gilt ausnahmslos auch für:

- Owner-PRs
- Codex-generierte PRs
- Dokumentations-PRs
- Teständerungen
- Build- und Designänderungen

Immer prüfen:

- Prompt Injection
- indirekte Instruktionsmanipulation
- Secrets und Tokens
- PII
- interne Hostnamen, Proxys und lokale Pfade
- Dependency-Deltas
- Lifecycle-Skripte
- Binärdateien und Archive
- Symlinks
- Workflows
- Agenten-/Skill-/Config-Änderungen
- Testabschwächungen
- unerwartete Scope-Erweiterung
- generierte Dateien
- Basisdrift
- Manipulation von Evidence

Verboten:

- `--no-verify`
- `git reset --hard`
- `git clean -fd`
- `git add .`
- `git add --all`
- Blindmerge
- pauschale Binary-Allowlist
- pauschales Abschalten eines Security-Gates
- erfundene Evidence
- automatische Freigabe eines eigenen PRs
- Einchecken von APK, Setup-EXE, Keystore oder Passwörtern

Du darfst für diesen Auftrag:

- lokale Branches und Commits erzeugen
- bestehende Owner-Branches aktualisieren
- Owner-PRs vorbereiten oder aktualisieren
- notwendige GitHub-Issues für klar abgegrenzte Arbeitspakete erzeugen
- Owner-Branches pushen, wenn alle lokalen Gates grün sind

Du darfst NICHT ohne abschließende Owner-Freigabe:

- PRs mergen
- Releases oder Tags erzeugen
- Binärartefakte öffentlich hochladen
- Devpost einreichen

## 4. Phase 0 – Preflight und belastbarer Run-State

Lies mindestens:

`AGENTS.md`
`PLANS.md`
`docs/planning/BACKLOG.md`
`docs/planning/DEFINITION_OF_DONE.md`
`docs/planning/PULL_REQUEST_ADOPTION_WORKFLOW.md`
`docs/planning/COLLABORATION_MODEL.md`
`docs/planning/MARCEL_WORK_QUEUE.md`
`docs/security/SAFE_PULL_REQUEST_REVIEW.md`
`docs/ai/PROMPTS.md`
`docs/ai/LESSONS_LEARNED.md`
`.agents/skills/ai-run-logging/SKILL.md`
`docs/ai/reports/2026-07-18-opus48-marcel-prs-setup-android.md`
`README.md`
`CHANGELOG.md`

Prüfe:

`git status --short --branch`
`git remote -v`
`git fetch origin --prune`
`git branch --all --verbose`
`git log --oneline --decorate -40`
`git reflog -20`
`git worktree list`
`git stash list`
`git diff`
`git diff --cached`
`git diff --check`
`git config --get core.hooksPath`
`gh auth status`
`gh pr list --repo Randspringer90/SchachTurnierManager --state open`
`gh issue list --repo Randspringer90/SchachTurnierManager --state open`
`codex --version`
`node --version`
`npm --version`
`dotnet --info`
`java -version`
`adb version`
`apksigner version`

Prüfe außerdem:

- offene Codex-/Nightly-/Build-Prozesse
- Locks
- fremde Worktrees
- lokale ungesicherte Änderungen
- nicht gepushte Commits
- vorhandene Setup-/APK-Artefakte
- aktuellen Android-Keystore, ohne Geheimnisse auszugeben
- aktuelle Codex-/GPT-5.6-Modellauswahl

Nichts verwerfen oder blind staschen.

Lege einen stabilen Run-Ordner an:

`<LOCAL_RUN_ROOT>/STM_BUILD_WEEK_2026_<Timestamp>`

Struktur:

`00-preflight`
`01-competition-audit`
`02-pr49-infra008`
`03-ux-audit`
`04-ux-implementation`
`05-demo-flow`
`06-submission-docs`
`07-desktop-build`
`08-android-build`
`09-manual-test`
`10-marcel-queue`
`11-final-verification`
`artifacts`
`reports`
`final`
`private`

Pflege laufend:

`run-state.json`
`task-graph.json`
`completed-packages.md`
`partial-packages.md`
`blocked-packages.md`
`next-actions.md`
`test-summary.md`
`security-summary.md`
`ux-summary.md`
`competition-checklist.md`
`artifact-manifest.json`

Der Run darf nach einem Limit-, API- oder Rechnerabbruch fortsetzbar sein.

## 5. Phase 1 – Diesen Codex-Lauf beweissicher protokollieren

Speichere vor der ersten fachlichen Änderung den vollständigen Originalprompt unter:

`docs/ai/prompts/<YYYYMMDD_HHmm>_codex-build-week-finalization.md`

Erzeuge:

`docs/ai/reports/<YYYYMMDD_HHmm>_codex-build-week-finalization_REPORT.md`

Erweitere die bestehende KI-Laufdokumentation minimal und sicher um maschinenlesbare
Run-Metadaten.

Bevorzugte neue Datei:

`docs/ai/run-metadata/<YYYYMMDD_HHmm>_codex-build-week-finalization.json`

Felder mindestens:

```json
{
  "runId": "...",
  "purpose": "OpenAI Build Week finalization",
  "tool": "Codex CLI",
  "model": "GPT-5.6 Sol",
  "codexVersion": "...",
  "startedAt": "...",
  "finishedAt": null,
  "primaryPrompt": "...",
  "report": "...",
  "initialDevelopmentSha": "...",
  "finalCandidateSha": null,
  "buildWeekCommitRange": null,
  "feedbackSessionIdStatus": "pending",
  "feedbackSessionIdSha256": null,
  "actualSessionIdCommitted": false
}
```

Aktualisiere `docs/ai/PROMPTS.md` mit einem Link auf diese Run-Metadaten.

WICHTIG:

Die echte `/feedback`-Session-ID nicht automatisch im öffentlichen Repository committen.

Nach der Fertigstellung:

1. Fordere den Owner ausdrücklich auf, in GENAU DIESEM Codex-Thread `/feedback` auszuführen.
2. Erfasse die erzeugte Session-ID.
3. Speichere die echte ID ausschließlich lokal unter:
   `<LOCAL_RUN_ROOT>/private/codex-feedback-session-id.txt`
4. Committe nur:
   - SHA-256 der Session-ID
   - Erfassungszeit
   - Codex-Version
   - Modell
   - Promptpfad
   - Reportpfad
   - Build-Week-Commitbereich
5. Die echte Session-ID wird später manuell in das Devpost-Formular eingetragen.

Beende den Hauptthread nicht, bevor diese Aktion mindestens klar vorbereitet ist.

## 6. Phase 2 – Wettbewerbs- und Repository-Audit

Erzeuge:

`docs/submission/BUILD_WEEK_REQUIREMENTS.md`
`docs/submission/BUILD_WEEK_CHANGELOG.md`
`docs/submission/CODEX_COLLABORATION.md`
`docs/submission/KNOWN_LIMITATIONS.md`
`docs/submission/THIRD_PARTY_NOTICES.md`
`docs/submission/SUBMISSION_CHECKLIST.md`

Prüfe und dokumentiere:

- Welche Funktionen vor dem 13.07.2026 vorhanden waren.
- Welche Funktionen seit dem 13.07.2026 entstanden.
- Welche Commits zu Build Week gehören.
- Welche Arbeiten über Codex/GPT-5.6 entstanden.
- Welche Arbeiten von Claude oder Marcel beigetragen wurden.
- Welche Entscheidungen der Owner getroffen hat.
- Wo Codex beschleunigt hat.
- Wo Codex-Vorschläge bewusst korrigiert oder abgelehnt wurden.
- Warum die Lösung technisch nicht trivial ist.
- Warum sie ein reales Vereinsproblem löst.
- Was noch nicht umgesetzt ist.

Die Darstellung muss ehrlich sein.

Keine Behauptung:

- „vollständig FIDE-zertifiziert“
- „offiziell von FIDE genehmigt“
- „vollständig offline auf Android“
- „öffentliche Release-Version“
- „F-Droid verfügbar“
- „produktiv signierte Windows-EXE“

Prüfe das Repository-Lizenzmodell.

Für ein öffentliches Wettbewerbsrepository muss eine passende Lizenz eindeutig vorhanden
sein. Falls keine klare Lizenz vorliegt:

- keine stillschweigende Lizenzwahl
- keine ungeprüfte Relizenzierung von Contributor-Code
- erstelle `docs/submission/LICENSE_DECISION.md`
- dokumentiere Optionen:
  - passende Open-Source-Lizenz mit geklärter Contributor-Zustimmung
  - oder privates Repository mit explizitem Juryzugriff
- markiere dies als Owner-Entscheidung
- arbeite an allen anderen Paketen weiter

## 7. Phase 3 – PR #49 und STM-INFRA-008 sauber lösen

PR #49 ist das erste technische Hauptpaket.

Prüfe erneut:

- aktuellen Base-SHA
- aktuellen Head-SHA
- vollständige Dateiliste
- vollständigen Patch
- alle Binary-Dateien
- Gradle-Wrapper-Version
- Capacitor-Versionen
- Android-Manifest
- Network-Security-Konfiguration
- Permissions
- APK-Inhalt
- Signing-Konfiguration
- Dependency-Lizenzen und Vulnerabilities
- BAT-Fleet-Interaktion
- aktuelle CI-Logs

Löse STM-INFRA-008 an der Wurzel.

Kein pauschaler Binary-Bypass.

Entwirf eine enge, fail-closed Verifikation für notwendige Android-Dateien.

Prüfe mindestens diese Lösungswege:

1. Gradle-Wrapper-JAR:
   - offizielle Herkunft
   - genaue Gradle-Version
   - SHA-256
   - reproduzierbare Generierung
   - Wrapper-Properties und Distribution-Checksum
   - nur exakter Pfad + exakter Hash + bekannte Provenienz
2. Android-Icons und Splash-Dateien:
   - erwartete Android-Resource-Pfade
   - Dateisignatur/MIME
   - Dimensionen
   - Größenlimits
   - keine unerwarteten Metadaten oder angehängten Payloads
   - möglichst eine versionierte Vektor-/SVG-Quelle
   - deterministische Generierung oder manifestgebundene Hashes
3. `gradlew.bat`:
   - als Gradle-Build-Wrapper klassifizieren, nicht als produktiver STM-Endnutzer-Launcher
   - Herkunft und Hash prüfen
   - nicht pauschal aus Sicherheitsprüfungen entfernen
   - BAT-Fleet-Regel fachlich zwischen Produktstarter und Drittanbieter-Buildwrapper unterscheiden

Eine Freigabe muss gebunden sein an:

- Pfad
- SHA-256
- Dateityp
- Provenienz
- Tool-/Generatorversion
- erwartete Größe beziehungsweise Dimension
- Owner-Review
- konkreten PR-Head-SHA

Jede Dateiänderung muss die Freigabe automatisch ungültig machen.

Halte STM-INFRA-008 als eigenes Owner-Paket getrennt von Android-Fachänderungen.

Nach dem Gate-Fix:

- PR #49 auf den aktuellen development-Stand bringen
- kein Force-Push
- alte SHA-Freigabe verwerfen
- statischen Review für den neuen Head erneut ausführen
- vollständige CI laufen lassen
- Android-Build und Signatur erneut prüfen
- PR #49 nicht automatisch mergen
- klare Merge-Empfehlung und offenen Rest ausgeben

## 8. Phase 4 – UX- und Design-Audit

Dies ist der wichtigste Produktteil des Laufs.

Bewerte nicht nur, ob Funktionen vorhanden sind, sondern ob ein neuer Turnierleiter sie
ohne Erklärung versteht.

Erzeuge zuerst:

`docs/submission/UX_AUDIT.md`
`docs/submission/UX_DECISIONS.md`

Prüfe die WebApp visuell und funktional auf:

- 320 px
- 360 px
- 390 px
- 412 px
- 768 px
- 1024 px
- 1440 px

Jeweils:

- Light Mode
- Dark Mode
- Hochformat
- Querformat, wo sinnvoll
- Tastaturbedienung
- Fokusführung
- Touchziele
- Fehlermeldungen
- Ladezustände
- Leerzustände
- Erfolgszustände
- kleine und große Datenmengen

Erstelle vor Änderungen Screenshots beziehungsweise visuelle Evidence im Run-Ordner.

Bewerte aus drei Nutzerperspektiven:

1. Neue Person, die erstmals ein Vereinsturnier anlegt.
2. Erfahrener Turnierleiter während einer laufenden Runde.
3. Helfer oder Schiedsrichter mit Smartphone.

Kernprinzipien:

- Progressive Disclosure
- wenige klare Hauptaktionen
- fachliche Begriffe nur dort, wo nötig
- verständliche Hilfetexte
- fortgeschrittene Funktionen unter „Erweitert“ oder „Mehr“
- keine Dashboard-Überladung
- keine lange Wand gleichwertiger Buttons
- klare visuelle Hierarchie
- konsistente Begriffe
- konsistente Buttonreihenfolge
- klare primäre Aktion je Ansicht
- gefährliche Aktionen optisch und räumlich trennen
- kein Funktionsverlust
- keine stille Verhaltensänderung

Bevorzugte Hauptnavigation:

- Übersicht
- Teilnehmer
- Runde
- Tabelle
- Mehr

Import, Export, Audit, technische Details und seltene Einstellungen dürfen nicht die
Hauptnavigation dominieren.

Prüfe und verbessere insbesondere:

### A. Erster Start

- verständlicher leerer Zustand
- klarer Button „Turnier anlegen“
- optional „Demo-Turnier öffnen“
- kein technisches Fachmenü als erste Ansicht

### B. Turnieranlage

- schrittweiser, kurzer Ablauf
- sinnvolle Defaults
- Format und Bedenkzeit verständlich erklärt
- erweiterte Einstellungen zunächst eingeklappt
- Zusammenfassung vor dem Anlegen
- keine unnötigen Pflichtfelder

### C. Laufendes Turnier

- aktuelle Runde und offene Aufgaben sofort sichtbar
- klare nächste Aktion
- offene Ergebnisse deutlich, aber nicht alarmistisch
- Auslosung nur möglich, wenn Voraussetzungen verständlich erfüllt sind
- Fehler erklären, nicht nur blockieren

### D. Teilnehmer

- Suche
- klarer Hinzufügen-Workflow
- Import als sekundäre Aktion
- Rückzug/Löschen deutlich unterscheiden
- keine automatische Datenvernichtung
- Duplikatwarnungen statt automatischer Löschung

### E. Paarung und Ergebnisse

- Brettnummern, Farben und Spieler gut lesbar
- Ergebnisbuttons touchfreundlich
- schreibende Aktion bestätigen
- Korrektur oder Undo nachvollziehbar
- aktive Runde klar erkennbar
- mobile Bedienung ohne horizontales Chaos

### F. Tabelle und Exporte

- Tabelle zuerst lesbar
- Tie-Break-Spalten erklärbar
- seltene Spalten optional
- Exportfunktionen gruppieren
- TRF16 und Swiss-Manager nicht als Hauptaktion vor normalen Nutzern präsentieren

### G. FIDE-Dutch

Backend, API und Persistenz sind vorhanden.

Prüfe STM-FACH-012:

- verständliche UI-Auswahl zwischen Standard und FIDE-Dutch
- bestehende Optimal-V2-Strategie bleibt Default
- Anfangsfarbe nur sichtbar, wenn relevant
- kurze Erklärung
- keine stille Umstellung bestehender Turniere
- keine ungeklärten Fachbegriffe im Hauptworkflow

### H. Sprache

Für den Wettbewerb muss der komplette Demo-Pfad mindestens auf Deutsch und Englisch
vollständig verständlich sein.

Nicht versuchen, bis Montag alle 18 registrierten Sprachen vollständig auszubauen.

- Deutsch und Englisch vollständig für den Demo-Pfad
- Spanisch nur erhalten beziehungsweise verbessern, wenn ohne Risiko
- unfertige Sprachen nicht als gleichwertig fertig darstellen
- experimentelle Sprachen gegebenenfalls unter „Weitere/Preview“

### I. Barrierefreiheit

- ausreichender Kontrast
- sichtbarer Fokus
- semantische Labels
- Tastaturnavigation
- Screenreader-Namen
- keine alleinige Farbcodierung
- Touchziele mindestens ungefähr 44×44 px
- reduzierte Bewegung respektieren
- verständliche Fehlermeldungen

### J. Designsystem

Bevorzuge das bestehende React-/CSS-Fundament.

Keine neue große UI-Framework-Dependency, außer sie ist zwingend notwendig und vollständig
begründet.

Definiere konsistente:

- Abstände
- Radien
- Typografie
- Farben
- Statusfarben
- Buttons
- Inputs
- Karten
- Dialoge
- Tabellen
- mobile Navigation

Das Ergebnis soll ruhig, professionell und vereinstauglich wirken, nicht verspielt oder
überladen.

## 9. Phase 5 – Build-Week-Demo-Pfad

Erzeuge einen reproduzierbaren Demo-Pfad mit ausschließlich synthetischen Daten.

Keine realen Vereinsmitglieder oder FIDE-Daten.

Beispiel:

- 8 synthetische Spieler
- unterschiedliche Ratings
- mindestens eine abgeschlossene Runde
- nächste Runde auslosbar
- FIDE-Dutch sichtbar demonstrierbar
- Ergebnis per Smartphone eintragbar
- Tabelle aktualisiert sich
- TRF16-/Swiss-Manager-Export vorführbar

Bevorzugt:

- ein versioniertes Demo-Preset oder eine kleine synthetische Importdatei
- expliziter Button oder klar dokumentierter Import
- kein automatisches Einspielen ohne Nutzeraktion
- Demo jederzeit sicher zurücksetzbar
- keine Vermischung mit realen Turnierdaten

Erzeuge:

`docs/submission/JUDGE_QUICKSTART.md`
`docs/submission/DEMO_DATA.md`
`docs/submission/DEMO_SCRIPT_EN.md`
`docs/submission/DEMO_SCRIPT_DE.md`
`docs/submission/SCREENSHOT_SHOTLIST.md`
`docs/submission/VIDEO_SHOTLIST.md`

Der Jury-Testpfad muss in höchstens fünf Minuten funktionieren.

Das Video muss unter drei Minuten bleiben.

Empfohlener Videoablauf:

- 0:00–0:20: Problem und Zielgruppe.
- 0:20–0:45: Windows-Setup und übersichtlicher Start.
- 0:45–1:20: Demo-Turnier, Teilnehmer und FIDE-Dutch-Auslosung.
- 1:20–1:50: Android-Companion verbindet sich mit dem Turnier-PC und trägt ein Ergebnis ein.
- 1:50–2:15: Tabelle und kompatible Exporte.
- 2:15–2:40: Local-first, Datenschutz, keine Cloud, kein Tracking.
- 2:40–2:55: Wie GPT-5.6 und Codex die Build-Week-Erweiterungen umgesetzt und geprüft haben.

Erzeuge eine englische Voice-over-Fassung ohne Marketingübertreibungen.

## 10. Phase 6 – README und Submission-Materialien

Die aktuelle README ist veraltet und muss gegen den echten aktuellen Stand geprüft werden.

Korrigiere insbesondere:

- FIDE-Dutch ist inzwischen integriert.
- Swiss-Manager-/TRF16-Import ist integriert.
- Android-Companion ist mindestens als Candidate/PR vorhanden.
- alte Versions- und Begrenzungsangaben nicht stehen lassen.
- keine unfertigen Features als fertig darstellen.

Die README soll oben einen leicht verständlichen Wettbewerbseinstieg bieten.

Empfohlene Struktur:

1. Ein-Satz-Nutzenversprechen
2. Screenshot oder kurze visuelle Übersicht
3. Was das Projekt löst
4. Hauptfunktionen
5. Zwei-Minuten-Schnellstart
6. Windows-Setup
7. Android-Companion
8. Demo-Daten
9. Architektur
10. Local-first / Datenschutz / Security
11. How Codex and GPT-5.6 were used
12. Build-Week-Erweiterungen seit 13.07.2026
13. Tests und Qualität
14. Bekannte Grenzen
15. Roadmap
16. Lizenz

README und Jury-Anleitung mindestens auf Englisch.

Deutsch darf ergänzend vorhanden bleiben.

Erzeuge:

`docs/submission/DEVPOST_DRAFT.md`

Mit mindestens:

- Project Name
- Tagline
- Category
- Inspiration
- What it does
- How we built it
- How Codex was used
- How GPT-5.6 was used
- Challenges
- Accomplishments
- What we learned
- What is next
- Installation
- Testing instructions
- Known limitations
- Repository URL placeholder
- Demo video URL placeholder
- `/feedback` Session ID placeholder

Die zukünftigen Punkte F-Droid, vollständiger Android-Offlinebetrieb und öffentliche
Distribution nur als Roadmap darstellen.

## 11. Phase 7 – Windows- und Android-Candidate

Nach Abschluss der UX-/Fachänderungen:

1. aktuellen Candidate-SHA festhalten
2. Versionierung konsistent aktualisieren
3. keine beliebige Versionsnummer erfinden
4. Versionsquelle im Repository bestimmen
5. Setup-EXE neu bauen
6. Desktop-Paket neu bauen
7. signierte Android-Test-APK neu bauen
8. dieselbe bestehende Signatur weiterverwenden
9. keine Secrets oder Passwörter ausgeben
10. Signatur und Hashes verifizieren

Windows:

- ReleaseGate
- Desktop-Publish
- Installer-Readiness
- isolierter Installer-Smoke
- Installation ohne Adminrechte
- Neustart-Persistenz
- Uninstaller
- reale Nutzerdaten nicht verändern

Android:

- npm ci
- TypeScript
- Vite-Build
- Capacitor-Sync
- Gradle assembleDebug
- Gradle assembleRelease
- Android Lint
- apksigner verify
- Manifestprüfung
- Permissionprüfung
- Secret-/Trackerprüfung
- interne-Pfad-/Hostprüfung
- Network-Security-Prüfung
- versionCode/versionName

Erzeuge lokal:

`<LOCAL_RUN_ROOT>/artifacts/windows/`
`<LOCAL_RUN_ROOT>/artifacts/android/`
`<LOCAL_RUN_ROOT>/artifacts/checksums/`
`<LOCAL_RUN_ROOT>/artifacts/submission-candidate/`

Keine Binärdateien committen.

Erzeuge ein Manifest mit:

- Candidate-SHA
- Version
- Buildzeit
- vollständige Dateinamen
- Dateigrößen
- SHA-256
- Zertifikatsfingerabdruck
- Signaturstatus
- Toolversionen
- Buildstatus

## 12. Phase 8 – manueller Owner-Test am Sonntag

Erzeuge eine sehr klare Testanleitung:

`<OWNER_MANUAL_TEST_FILE>`

Zusätzlich lokal:

`<LOCAL_RUN_ROOT>/09-manual-test/<OWNER_MANUAL_TEST_FILE>`
`<LOCAL_RUN_ROOT>/09-manual-test/MANUAL_RESULTS_TEMPLATE.md`

Reihenfolge:

### A. Windows

1. alte Testinstanz sauber erkennen
2. Setup-EXE starten
3. Installationspfad dokumentieren
4. App starten
5. Demo-Turnier laden
6. Teilnehmer prüfen
7. Runde auslosen
8. Ergebnis eingeben
9. Tabelle prüfen
10. App schließen und neu starten
11. Persistenz prüfen
12. Export erzeugen
13. Logs prüfen
14. Deinstallation prüfen
15. Datenerhalt dokumentieren

### B. Galaxy S25

1. APK-Hash prüfen
2. Installation aus unbekannter Quelle gezielt erlauben
3. APK installieren
4. App starten
5. Companion-Hinweis prüfen
6. PC und Handy in dasselbe WLAN bringen
7. PC-Serveradresse eingeben
8. Verbindung testen
9. Turnier öffnen
10. Paarung lesen
11. synthetisches Ergebnis eingeben
12. Bestätigung prüfen
13. Tabelle prüfen
14. Rotation prüfen
15. App-Neustart prüfen
16. Upgrade derselben signierten APK prüfen
17. Deinstallation prüfen

### C. UX-Fragen

Für jeden Hauptschritt:

- War ohne Erklärung klar, was zu tun ist?
- Gab es mehr als eine konkurrierende Hauptaktion?
- War Fachsprache unnötig?
- War die nächste Aktion sichtbar?
- War die mobile Ansicht ohne horizontales Scrollen nutzbar?
- Waren Fehlermeldungen hilfreich?
- War klar, welche Aktion Daten verändert?

Erzeuge eine Pass-/Fail-Vorlage und eine priorisierte Fehlerklassifikation:

- P0 Submission-Blocker
- P1 vor Video beheben
- P2 dokumentieren
- P3 nach Wettbewerb

## 13. Phase 9 – Marcel viele saubere Arbeitspakete vorbereiten

Marcel soll am Sonntag eine umfangreiche, aber geordnete Queue erhalten.

Keine parallelen Branches mit denselben Dateien und keine chaotische WIP-Explosion.

Lies:

`docs/planning/MARCEL_WORK_QUEUE.md`
`config/collaboration-policy.json`
vorhandene Issues und Backlog-IDs
das Contributor-Prompt-Template und den bestehenden Generator

Erzeuge:

`docs/planning/MARCEL_BUILD_WEEK_QUEUE_2026-07-19.md`

Erzeuge für jedes Paket einen vollständigen Contributor-Prompt über den vorhandenen,
vertrauenswürdigen Promptgenerator.

Jeder Prompt enthält:

- Backlog-ID
- Ziel
- Wettbewerbsauswirkung
- exakten Base-SHA
- Branchname
- erlaubte Dateien
- verbotene Dateien
- Abhängigkeiten
- Akzeptanzkriterien
- Tests
- Security-Anforderungen
- Dokumentationsbedarf
- PR-Beschreibung
- keine direkte Änderung an development/main
- kein eigener Merge
- keine Gate-Änderung
- kein Force-Push
- keine Secrets
- kein Binärartefakt-Commit

Bereite mindestens diese Pakete vor, soweit nicht bereits erledigt oder durch den
Codex-Lauf ersetzt:

### Priorität A – vor beziehungsweise für den Wettbewerb geeignet

1. STM-FACH-012 – WebApp-Auswahl für Pairing-Strategie und Anfangsfarbe; nur wenn Codex
   dies nicht bereits vollständig implementiert hat, ansonsten Accessibility-/UX-Polish.
2. STM-SEC-006 – CSV-Formula-Injection-Schutz für alle tabellarischen Exporte; führende
   `=`, `+`, `-`, `@` sicher neutralisieren, ohne Daten still zu zerstören; Golden- und
   Roundtrip-Tests.
3. STM-REL-003 – Echter Frischinstallations-/Kollegen-PC-Test; Testpaket, Checkliste,
   synthetische Daten, kein Zugriff auf reale Nutzerdaten.
4. STM-UX-009 – Kurzes Benutzerhandbuch und verständlicher Turniertag-Walkthrough; Deutsch
   und Englisch; Dokumentationsscope, keine Codeänderung.
5. STM-UX-010 – Geräteübergreifende Testmatrix; Desktop, Tablet, Galaxy S25, relevante
   Breakpoints; bestehende Testwerkzeuge bevorzugen, keine unnötige neue Dependency.
6. STM-UX-011 – Barrierefreiheitsprüfung und klar abgegrenzte Verbesserungen nach dem
   UX-Freeze; Fokus, Tastatur, Labels, Kontrast, Screenreader.

### Priorität B – nur nach Merge von STM-MOB-001 und UX-Freeze

7. STM-MOB-003 – Mobile Paarungs- und Tabellenansicht; keine neue Backendlogik.
8. STM-MOB-004 – Mobile Ergebniseingabe mit Bestätigung, Undo und Audit; baut auf
   STM-MOB-003.

### Priorität C – nach dem Submission-Freeze

9. STM-FACH-003 – Große Schweizer Felder 21–200 Spieler; keine Regelabschwächung zugunsten
   von Performance.
10. STM-IE-004 – Read-only FIDE-Namenssuche mit Bestätigung, Rate Limit und Cache; nicht vor
    dem Wettbewerb in den Candidate übernehmen, wenn zusätzliche Risiken oder
    Netzwerkabhängigkeiten entstehen.

WIP-Regel:

- maximal 2 In Progress
- maximal 3 Ready
- weitere Pakete Backlog oder Blocked
- trotzdem für alle Pakete vollständige Prompts vorbereiten

Reserviere während des Codex-UX-Laufs die zentralen UI-Shell-Dateien.

Veröffentliche einen eindeutigen:

`UX_FREEZE_SHA=<sha>`

Marcel darf UI-Aufgaben erst auf Basis dieses SHA beginnen.

Falls Marcel während dieses Laufs neue PRs eröffnet:

- nur inventarisieren
- SHA erfassen
- statisch prüfen
- nicht ungeprüft ausführen
- keine automatische Adoption
- klare Empfehlung für nach dem Submission-Freeze geben

## 14. Phase 10 – Vollständige Qualitätsprüfung

Gezielte Tests zuerst, vollständige Tests anschließend.

Mindestens:

- `git diff --check`
- PowerShell-Parser
- Test-GitCommitSafety
- Test-RepositoryOpenSourceSafety
- Test-PromptInjectionDefense
- Test-AgentInstructionIntegrity
- Test-PullRequestReviewReadiness
- Test-PullRequestDependencyDelta
- Test-CollaborationReadiness
- Test-RoutedExecutionReadiness mehrfach
- `dotnet restore`
- `dotnet build`
- `dotnet test`
- `npm ci`
- TypeScript
- Vite-Build
- Android-Lint
- Gradle-Build
- `apksigner verify`
- Installer-Readiness
- Portable-/Desktop-Frischlauf
- ReleaseGate

Zusätzlich:

- README-Linkcheck
- englische Demo-Texte
- keine personenbezogenen Daten
- keine internen Pfade
- keine Proxydaten
- keine Secrets
- keine realen Spielernamen
- keine ungeklärten Binärdateien
- keine Testabschwächung
- keine veralteten Funktionsbehauptungen
- keine unerfüllte Submission-Anforderung als erledigt markieren

Führe einen unabhängigen finalen Review durch:

A. Technik
B. UX/Design
C. Datenschutz/Security
D. Wettbewerbskriterien
E. Jury-Testbarkeit

Bewerte jedes der vier offiziellen Wettbewerbskriterien auf einer ehrlichen Skala von
0 bis 10 und begründe verbleibende Abzüge.

Ziel vor Montag:

- Technological Implementation >= 8
- Design >= 8
- Potential Impact >= 8
- Quality of the Idea >= 8

Keine Scores schönrechnen.

## 15. Submission-Freeze

Erzeuge einen klaren Candidate-Stand.

Keine neuen Features mehr nach dem Freeze.

Nach dem Freeze nur:

- P0-Fehler
- reproduzierbare P1-Fehler
- Doku-Korrekturen
- Submission-Evidence
- Build-/Packaging-Fixes

Erzeuge:

`docs/submission/FINAL_READINESS_REPORT.md`
`docs/submission/FINAL_KNOWN_LIMITATIONS.md`
`docs/submission/FINAL_MERGE_ORDER.md`
`docs/submission/OWNER_ACTIONS_BEFORE_SUBMISSION.md`

Empfohlene Merge-Reihenfolge explizit ausgeben.

Keine PRs automatisch mergen.

## 16. Abschluss und /feedback

Erzeuge einen public-safe Abschlussbericht.

Erzeuge eine bereinigte Übergabe-ZIP:

`<LOCAL_TEMP_ROOT>/STM_BUILD_WEEK_2026_<Timestamp>.zip`

Nicht enthalten:

- Keystore
- Passwörter
- echte `/feedback`-Session-ID
- APK-Signierpasswort
- interne Hostnamen
- Proxydaten
- reale Turnierdaten
- personenbezogene Daten
- private Logs
- private lokale Pfade

Am Ende zuerst diese Statusausgabe:

```text
BUILD_WEEK_RUN=<OK|PARTIAL|FEHLER>
INITIAL_DEVELOPMENT=<sha>
CURRENT_DEVELOPMENT=<sha>
COMPETITION_CANDIDATE_SHA=<sha oder NOT_CREATED>
PR49_HEAD=<sha>
STM_INFRA_008=<OK|PARTIAL|BLOCKED>
PR49_CI=<Status>
PR49_MERGE_RECOMMENDATION=<YES|NO>
UX_AUDIT=<Pfad>
UX_IMPLEMENTATION=<OK|PARTIAL|BLOCKED>
DEMO_FLOW=<OK|PARTIAL|BLOCKED>
README=<OK|PARTIAL|BLOCKED>
ENGLISH_QUICKSTART=<OK|PARTIAL|BLOCKED>
LICENSE_STATUS=<OK|OWNER_DECISION_REQUIRED|BLOCKED>
BUILD_WEEK_COMMIT_RANGE=<von..bis>
CODEX_MODEL=<Modell>
CODEX_VERSION=<Version>
CODEX_PROMPT=<Pfad>
CODEX_REPORT=<Pfad>
FEEDBACK_SESSION_ID_STATUS=<PENDING_USER_COMMAND|CAPTURED_LOCAL>
FEEDBACK_SESSION_ID_HASH=<Hash oder NOT_AVAILABLE>
SETUP_EXE=<vollständiger Pfad oder NOT_CREATED>
SETUP_VERSION=<Version>
SETUP_SHA256=<Hash oder NOT_AVAILABLE>
APK_RELEASE=<vollständiger Pfad oder NOT_CREATED>
APK_VERSION=<Version>
APK_SHA256=<Hash oder NOT_AVAILABLE>
APK_SIGNATURE=<VERIFIED|NOT_VERIFIED>
DEVICE_TEST=<MANUAL_READY|OK|BLOCKED>
OWNER_TEST_GUIDE=<Pfad>
MARCEL_QUEUE=<Pfad>
MARCEL_PROMPTS=<Anzahl>
DEVPOST_DRAFT=<Pfad>
VIDEO_SCRIPT=<Pfad>
SUBMISSION_CHECKLIST=<Pfad>
TESTS=<Status und Anzahl>
SECURITY=<Status>
OPEN_BLOCKERS=<Liste>
UPLOAD_ZIP=<vollständiger Pfad>
NEXT_ACTION=<eine konkrete Aktion>
```

Danach:

- Falls die Kernarbeit fertig ist, fordere den Owner mit genau dieser sichtbaren Zeile auf:

  `ACTION_REQUIRED: Bitte jetzt in diesem selben Codex-Thread /feedback ausführen.`

- Nach Ausgabe der Session-ID:
  - echte ID nur lokal speichern
  - Hash und Metadaten dokumentieren
  - keine echte ID committen
  - finalen Report aktualisieren

Beginne jetzt mit PHASE 0.
