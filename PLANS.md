# Aktueller Zusatz 0.52.0

- RUN-52 ergaenzt den echten Frischordner-Test fuer das Kollegenpaket: ZIP entpacken, Checksums pruefen, Desktop-ZIP entpacken, WebApi auf freiem Loopback-Port starten, Health/Dashboard/API und isolierte SQLite-Datenbank pruefen.
- Der Test waehlt automatisch den naechsten freien Port ab dem Wunschport; manuelle 5098/5099-Fallbacks sollen nur noch bei echtem Port-/Startfehler noetig sein.
- Naechster Schritt: 0.52.0 testen, committen und pushen. Danach echten Kollegenrechner-Test oder Setup-EXE mit installiertem Inno Setup finalisieren.

---

# Aktueller Zusatz 0.51.1

- Hotfix fuer `scripts/Invoke-ColleagueInstallReadiness.ps1`: Run-Ordner und Upload-ZIP werden direkt/deterministisch berechnet, damit keine `System.Object[]`-Pfade mehr entstehen.
- RUN-51 bleibt der richtige naechste Release-Schritt: Kollegenpaket mit Desktop-ZIP, Portable-ZIP, optionalem Setup, README, Manifest und SHA256-Pruefsummen.
- Naechster Schritt: 0.51.1 testen; wenn gruen, lokal committen und pushen. Danach echten Kollegen-/Frisch-Windows-Test oder Inno Setup fuer echte Setup-EXE nachziehen.

---

# Aktueller Zusatz 0.51.0

- RUN-51 konkretisiert die Kollegeninstallation: eigenstaendiges `SchachTurnierManager_Kollegenpaket_<Version>.zip` mit Desktop-ZIP, Portable-ZIP, optionaler Setup-EXE, README, Manifest und SHA256-Pruefsummen.
- Der Standardlauf ist `scripts/Invoke-ColleagueInstallReadiness.ps1 -BuildInstaller -AllowMissingInnoSetup`; fehlendes Inno Setup bleibt ein dokumentierter Blocker, aber Desktop-/Portable-Auslieferung bleibt moeglich.
- Naechster Schritt: 0.51.0 testen, committen und pushen; danach echten Kollegen-/Frisch-Windows-Test oder weitere Fachfeatures (RUN-14 Tie-Breaks, RUN-12 FIDE-Dutch, RUN-15 Excel/TRF).

---

# Aktueller Zusatz 0.50.4

- Hotfix fuer den DPAPI-Secret-Roundtrip: `Get-LocalSecret.ps1` verwendet jetzt robuste `System.IO.Path`-Separatorzeichen statt der fehlerhaften `[char]'\\'`-Konvertierung.
- Damit sollte `secret-safety` im ReleaseCandidateReadiness-Lauf vollstaendig gruen werden.
- Naechster Schritt: 0.50.4 testen; wenn gruen, 0.50.x lokal committen und danach Setup/EXE/Kollegeninstallation konkretisieren.

---

# Aktueller Zusatz 0.50.3

- Hotfix fuer den DPAPI-Secret-Roundtrip: `Get-LocalSecret.ps1` trimmt serialisierte DPAPI-Blobs vor `ConvertTo-SecureString`; `Set-LocalSecret.ps1` schreibt ohne abschliessende neue Zeile.
- `SecretSafetyReadiness` erkennt leere/Whitespace-Secret-Dateien frueh und schreibt verstaendlichere Diagnosen ins Run-ZIP.
- Naechster Schritt: 0.50.3 testen; wenn gruen, lokal committen. Danach Release-/Kollegeninstallation weiter konkretisieren: Inno Setup/EXE, Portable-ZIP, Installationsanleitung und Frisch-Windows-Test.

---

# Aktueller Zusatz 0.50.2

- Hotfix fuer den RUN-50-Orchestrator: `SecretSafetyReadiness` erstellt den Run-Ordner jetzt selbst; `New-RunLogBundle` liefert Pfade maschinenlesbar; `ReleaseCandidateReadiness` schreibt `UPLOAD_ZIP=...` nicht mehr leer.
- Damit bleiben verschachtelte Run-Bundles unter `D:\Temp` robust und liefern bei Erfolg oder Fehler genau ein Upload-ZIP.
- Naechster Schritt: 0.50.2 testen; wenn gruen, lokal committen. Danach Installations-/Kollegen-Setup und ReleaseCandidate ohne Inno-Setup-Blocker weiter absichern.

---

# Aktueller Zusatz 0.50.1

- Hotfix fuer `scripts/Invoke-ReleaseCandidateReadiness.ps1`: Der Run-Ordner wird jetzt direkt im Skript erstellt und mit `RUN_DIR=...` angezeigt.
- Dadurch kann der Release-Candidate-Readiness-Lauf seine Logs, `FAILED.txt`, Artefaktmanifest und `UPLOAD_ZIP` auch dann sauber erzeugen, wenn ein nachgelagerter Check fehlschlaegt.
- Naechster Schritt: 0.50.1 testen; wenn gruen, lokal committen. Danach echten Installer-Test mit installiertem Inno Setup oder naechsten Release-/Featureblock fortsetzen.

---

# Aktueller Zusatz 0.50.0

- Release-/Betriebsunterbau wurde gestaerkt: Logging-Level, Request-Logging ohne Querystrings, DPAPI-Secret-Readback, Secret-Safety-Readiness, Release-Candidate-Readiness und Agenten-Skills.
- Neue Tests decken Logging-Konfiguration, Secret-Schutz, Release-Skripte und Agenten-/Skill-Struktur ab.
- Ziel bleibt: eigenstaendige, installierbare Release-Version fuer Kolleginnen/Kollegen ohne Abhaengigkeit zu anderen Projekten.

---

# Aktueller Zusatz 0.49.0

- RUN-15 Import/Export wurde als erster produktiver Ausbau umgesetzt: ein lokales Exportmanifest beschreibt die wichtigsten Downloads, Turnier-Metadaten, offene Bretter, kampflose Bretter, Byes und den empfohlenen Veroeffentlichungs-Workflow.
- Der neue API-Endpunkt `/api/tournaments/{id}/exports/manifest.json` ist bewusst read-only und local-only. Er laedt nichts hoch und enthaelt nur lokale Downloadpfade.
- Das Exportcenter bietet den Manifest-Download sichtbar neben CSV, Druckansicht und Backup an.
- Naechste sinnvolle Schritte: 0.49.0 testen und committen; danach RUN-14 Tie-Break-/Wertungs-Erklaerungen oder RUN-15 weiter mit Excel-/TRF-Vorbereitung fortsetzen.

---

# Aktueller Zusatz 0.48.1

- RUN-11-Hotfix: Das Knowledge-Base-Readiness-Skript parst jetzt korrekt, weil die Fehlermeldung `Topic ${index}: Feld ${field} fehlt.` verwendet.
- Der Fehler betraf nur das Pruefskript; die Wissensbasis-/UI-Implementierung aus 0.48.0 bleibt unveraendert.
- Naechster Schritt: 0.48.1 testen, danach 0.48.1 lokal committen und mit RUN-15 Import/Export oder RUN-14 Wertungen/Tie-Breaks weitermachen.

---

# Aktueller Zusatz 0.48.0

- RUN-11 wurde weiter umgesetzt: Die lokale Wissensbasis ist jetzt aus dem UI-Monolithen in `src/SchachTurnierManager.WebApp/src/knowledge/localKnowledgeBase.json` ausgelagert.
- Jeder Wissensartikel enthaelt `id`, `title`, `keywords`, `answer`, `steps` und `sources`; Schnellfragen, Stand, Source-Version und Privacy-Hinweis werden zentral gepflegt.
- Die Chat-Hilfe bleibt lokal-only: keine externe KI, keine API-Keys, keine Uebertragung von Turnierdaten.
- Neues `scripts/Invoke-KnowledgeBaseReadiness.ps1` prueft Build, JSON-Struktur, Provider-Grenze, Quellenregeln und UI-Import.

## Naechste sinnvolle Schritte

1. 0.48.0 lokal committen, wenn `Invoke-KnowledgeBaseReadiness.ps1` gruen ist.
2. RUN-15 Import/Export erweitern: CSV/Excel-Exportcenter fuer Teilnehmer, Paarungen und Tabellen vertiefen.
3. RUN-14 Tie-Break-/Wertungs-Erklaerungen im UI ausbauen.
4. RUN-10 Provider-Konzept erst danach: BYOK, `.secrets/local`, Datenschutz-Gates und keine destruktiven Tool-Aktionen.

---

# Aktueller Zusatz 0.47.0

- RUN-10/11 wurde als lokales, sicheres Fundament begonnen: Der Reiter **Assistent** enthaelt jetzt eine lokale Chat-Hilfe mit Wissensbasis fuer Turnierstart, Pairing, Wertungen, Backup, QR/Handy, Import/Export und KI-Datenschutz.
- Die Chat-Hilfe ist bewusst regelbasiert und sendet keine Turnierdaten, Logs, Personendaten oder Secrets an externe Anbieter.
- Antworten beruecksichtigen den aktuellen Turnierkontext und die aktuelle Assistenten-Empfehlung.
- Schnellfragen und Chat-Export sind vorbereitet, damit Turnierleiter die Hilfe am Turniertag schnell nutzen koennen.
- Provider-Anbindung fuer Claude/OpenAI bleibt offen und muss spaeter mit BYOK, sicherer lokaler Secret-Ablage, Quellenanzeige, Tool-Rechten und Datenschutz-Gates umgesetzt werden.

## Naechste sinnvolle Schritte

1. 0.47.0 lokal committen, wenn `Invoke-KnowledgeChatReadiness.ps1` gruen ist.
2. RUN-11 ausbauen: Markdown-/JSON-Wissensbasis aus UI-Code herausloesen und mit Quellen/Versionen pflegen.
3. RUN-10 Provider-Konzept: OpenAI/Claude-Adapter nur mit BYOK und ohne automatische destruktive Aktionen.
4. Danach RUN-15 Import/Export oder RUN-14 Tie-Break-Konfiguration weiter ausbauen.

---

# Aktueller Zusatz 0.46.0

- RUN-17 Turnierassistent im UI umgesetzt: neuer Hauptreiter `Assistent` mit lokalen,
  regelbasierten Empfehlungen fuer Szenario, Format, Rundenzahl, Zeitbedarf, Bretter,
  Setup-Schritte, Turniertag-Checkliste und Exportplan.
- Keine KI-API, keine externen Requests, keine Secrets: Der Assistent ist bewusst Produkt-/
  Bedienhilfe und bildet die Grundlage fuer spaetere KI-Chatbot-/Wissensbasis-Features.
- Neues `scripts/Invoke-TournamentAssistantReadiness.ps1` prueft ReleaseGate, Frontend-Build
  und zentrale UI-/Privacy-Merkmale und buendelt wieder ein Upload-ZIP unter `D:\Temp`.
- Naechste sinnvolle Schritte: 0.46.0 lokal committen, danach RUN-10/11 KI-Chatbot-/
  Wissensbasis-Konzept technisch vorbereiten oder RUN-14 Wertungs-/Tie-Break-Erklaerungen
  im UI vertiefen.

# Aktueller Zusatz 0.45.0

- RUN-08 PWA-/Handy-Basis umgesetzt: Manifest, SVG-Icons, Service Worker und PWA-Status
  im Header. Der Service Worker cached nur App-Shell/statische Assets und schliesst
  `/api/*` bewusst aus, damit Turnierdaten nicht versehentlich offline dupliziert werden.
- Neues `scripts/Invoke-PwaReadiness.ps1` prueft die Vite-Ausgabe und buendelt Logs/Reports
  wieder als `D:\Temp\...zip`.
- Naechste sinnvolle Schritte: 0.45.0 lokal committen, dann RUN-02 Release-Reife-Audit
  oder RUN-17 Turnierassistent im UI. Fuer echte Handy-Offline-Ergebnisaufnahme braucht
  es zuerst ein gesondertes Sync-/Konfliktkonzept.

# Aktueller Zusatz 0.44.2

- RUN-03-Hotfix: Die Manifest-Auflistung im Portable-Fresh-Folder-Test nutzt jetzt explizite
  `char[]`-Trimzeichen statt der fehleranfaelligen `TrimStart('\\','/')`-Variante.
  Damit sollte der Lauf nach `releasegate-skip-pack` und `pack-portable` in den eigentlichen
  Smoke-Test weiterlaufen.
- Nach erneut gruenem RUN-03: 0.44.x lokal committen, danach planmaessig RUN-02
  Release-Reife-Audit oder RUN-21 i18n-Bereichsextraktion fortsetzen.

# Aktueller Zusatz 0.44.1

- RUN-03-Hotfix: Das Portable-Fresh-Folder-Skript behandelt den leeren `data`-Ordner im
  ZIP jetzt als optional, weil `Compress-Archive` leere Ordner nicht verlaesslich ins ZIP
  uebernimmt. Der Smoke-Test nutzt weiterhin einen separaten isolierten Test-Datenordner
  unter `D:\Temp`.
- Portable-Root-Erkennung ist robuster und Manifest-Diagnose listet relevante Dateien auf.
- Nach erneut gruenem RUN-03: 0.44.x lokal committen, dann als naechsten Roadmap-Schritt
  RUN-02 Release-Reife-Audit oder RUN-21 i18n-Bereichsextraktion.

# Aktueller Zusatz 0.44.0

- RUN-03 Portable-ZIP-Frischordner-Test automatisiert: `scripts/Invoke-PortableFreshFolderTest.ps1`
  baut optional ein self-contained Portable-ZIP, entpackt es in einen frischen Ordner unter
  `D:\Temp`, startet die WebApi isoliert auf einem Testport und prüft Health, Dashboard,
  Turnierlisten-API und SQLite-Datenpfad.
- Portable-Manifest mit ZIP-SHA256, Pflichtdateien und Backend-Logs landet im Upload-ZIP;
  Terminal bleibt kurz.
- RUN-03 ist damit technisch prüfbar; nächster sinnvoller Schritt bleibt wahlweise echter
  Inno-Setup-Test für RUN-05, RUN-02 Release-Reife-Audit oder RUN-21/i18n-Bereichsextraktion.

# Aktueller Zusatz 0.43.1

- CommitGuard/Safety-Hotfix: `NEXT_PROMPT.md` ist lokale Projekt-Registry-/Handoff-Datei und
  wird nicht mehr automatisch gestaged oder committet. Vor dem naechsten Commit einmalig
  `git reset` ausfuehren, damit der fehlgeschlagene Stage-Zustand geloest wird; lokale
  Aenderungen bleiben erhalten.
- `Test-GitCommitSafety.ps1` meldet bei internen Referenzen jetzt Datei und hinzugefuegte
  Zeile. Danach kann die 0.42.6/0.43.x-Basis erneut ueber `Commit-If-Green.ps1` gesichert
  werden.
- RUN-05-Readiness bleibt fachlich gueltig: ReleaseGate und Desktop-Publish OK; Installer-Build
  wartet auf lokal verfuegbares Inno Setup (`ISCC.exe`).

# Aktueller Zusatz 0.43.0

- RUN-05 Installer-Readiness ist jetzt als eigener, ruhiger Lauf automatisiert:
  `scripts/Invoke-InstallerReadiness.ps1` erzeugt Desktop-Paket, prueft Pflichtartefakte
  und baut bei vorhandenem Inno Setup optional die Setup-EXE.
- Installer-Testcheckliste und README liegen unter `docs/release/INSTALLER_TEST_CHECKLIST.md`
  bzw. `installer/README.md`; SmartScreen/Code-Signing bleibt bewusst dokumentierte spaetere
  Entscheidung.
- Inno Setup wird nicht automatisch installiert; falls `ISCC.exe` fehlt, wird das im Run-ZIP
  als Blocker dokumentiert. Keine Downloads/Kostenaktionen.
- Naechster Schritt nach erfolgreichem RUN-05-Readiness: echten Installer bauen/testen, wenn
  Inno Setup lokal verfuegbar ist; danach RUN-03 frischer Portable-ZIP-Test oder RUN-02
  Release-Reife-Pruefung.

# Aktueller Zusatz 0.42.6

- `Invoke-NpmSafe.ps1` nimmt fuer ruhige npm-Installationen jetzt `-NoAudit -NoFund` statt
  `-NpmArguments @('--no-audit','--fund=false')`. Damit werden PowerShell-Argumentfallen
  mit dash-beginnenden npm-Flags vermieden.
- Run-Log-Bundles unter `D:\Temp\<RunName>_<Zeit>.zip` bleiben ab jetzt Standard fuer
  lokale Verifikation und Uploads in den Chat.
- Nach erfolgreichem 0.42.6-Gate: grüne Basis committen, danach RUN-05 Installer-Test.

# Aktueller Zusatz 0.42.5

- `npm ci` ist auf der aktuellen Windows/npm-Kombination nicht belastbar; WebApp-
  Dependencies sind deshalb exakt gepinnt und ReleaseGate/Paketierung nutzen wieder
  `npm install` ueber `Invoke-NpmSafe.ps1`, ohne `latest`-Neuaufloesung.
- Neues Run-Logging: lange Befehle sollen kuenftig unter `D:\Temp\<Projekt>_<Run>_<Zeit>`
  gesammelt und per `New-RunLogBundle.ps1` als ZIP hochgeladen werden. Terminalausgaben
  bleiben kurz; Details stehen in Logs.
- Nächster fachlicher Schritt bleibt nach erneut grünem Release-Gate: RUN-05 Installer-Test
  oder RUN-02 Release-Reife-Prüfung.

# Aktueller Zusatz 0.42.4

- ReleaseGate/Paketierung nutzen bei vorhandener `package-lock.json` deterministisch
  `npm ci` statt `npm install`. Das verhindert erneute `latest`-Aufloesungen und den
  beobachteten Windows-Fehler durch `n@10.2.0`.
- Nächster fachlicher Schritt bleibt nach erneut grünem Release-Gate: RUN-05 Installer-Test
  oder RUN-02 Release-Reife-Prüfung.

# Aktueller Zusatz 0.42.3

- Hotfix fuer `Invoke-NpmSafe.ps1`: mehrteilige npm-Befehle werden nicht mehr ueber
  `-NpmArguments @('run','build')` uebergeben, sondern robust als `-NpmCommand run
  -NpmScript build`. ReleaseGate, Portable- und Desktop-Publish nutzen diese Syntax.
- Nächster fachlicher Schritt bleibt nach erneut grünem Release-Gate: RUN-05 Installer-Test
  oder RUN-02 Release-Reife-Prüfung.

# Aktueller Zusatz 0.42.2

- Lokale Secret-/Auth-Struktur nachgeschaerft: bevorzugt `.secrets/local/`, legacy
  `secrets/local/` bleibt lesbar; echte Werte bleiben gitignored und werden nicht geloggt.
- npm-Aufrufe laufen im Release-/Paketierungsweg ueber `Invoke-NpmSafe.ps1` mit isolierter
  temporaerer npmrc. Das reduziert globale `.npmrc`-Nebenwirkungen wie `always-auth`-Warnungen.
- Nächster fachlicher Schritt bleibt nach erneut grünem Release-Gate: RUN-05 Installer-Test
  oder RUN-02 Release-Reife-Prüfung.

# Aktueller Zusatz 0.42.1

- Build-Fix nach Pull auf 0.42.0: alte lokale `src/**/obj`-/`tests/**/obj`-Ordner werden
  durch MSBuild-Globs nicht mehr kompiliert; `Clean-Generated.ps1` räumt sie aktiv weg.
- Nächster fachlicher Schritt bleibt erst nach grünem Release-Gate: RUN-05 Installer-Test
  oder RUN-02 Release-Reife-Prüfung.

# Aktueller Zusatz 0.42.0

- Desktop-Variante: `scripts/Publish-DesktopApp.ps1` (self-contained, Klick-Start,
  Daten unter AppData) fertig und smoke-getestet; Installer (Inno Setup) unter
  `installer/` vorbereitet, Kompilieren/Test offen (Inno Setup lokal installieren, RUN-05).
- i18n-Fundament in der WebApp: 18 Sprachen registriert, de/en/es Kern-Schluessel,
  Sprachumschalter, Fallback en→de; vollständige String-Extraktion offen (RUN-21).
- Codex-Roadmap-Prompts unter `docs/ai/prompts/codex-roadmap/` (RUN-01…RUN-21 +
  PROMPT_BASE); Folgearbeit läuft über diese Prompts, ein Lauf = ein Arbeitspaket.
- Offen (unverändert): kein vollständiges FIDE-Dutch, Felder > 20 Spieler Greedy-Fallback.

# Aktueller Zusatz 0.41.1

- Operator-Smoke `scripts/Smoke-OperatorWorkflow.ps1`: ein hängesicherer End-to-End-Lauf gegen
  ein isoliertes, frisch gebautes Backend (Health, Swiss 12/5, RR-Late-Entry-Sperre, manuelle
  Paarung, Backup/Restore, Chess960/QR-Daten) mit Timeouts, Heartbeat, klarem Exit-Code und
  zuverlässigem Teardown. Runbook/Checklist/Operator-Card und QR-Vorabtest dokumentiert.
- Offen (unverändert): kein vollständiges FIDE-Dutch, Felder > 20 Spieler Greedy-Fallback,
  QR-Anzeige am realen Handy bleibt manueller Vorabtest.

# Aktueller Zusatz 0.41.1

- Operator-/Release-Candidate-Haertung ohne neue Pairing-Architektur:
  `scripts\Smoke-OperatorWorkflow.ps1` prueft synthetisch Health, Swiss 12/5,
  Rundenlimit, Audit-Export, Round-Robin, Manual-Pairing-Guards, Backup/Restore und
  Chess960/QR-URL-Form.
- Runbook/Checklisten geschärft fuer Turniertag: QR-Vorabtest, Audit nach jeder Runde,
  Backup/Restore, MaxRounds, Late Entry je Format, Swiss-Grenzen und Notfallablauf.
- Offen vor echtem Release: realer Handytest im Veranstaltungs-WLAN/Hotspot, keine Tags/Releases
  ohne ausdrueckliche Freigabe.

# Aktueller Zusatz 0.41.0

- Schweizer-System V2: global optimale Minimum-Penalty-Paarung (≤ 20 Spieler) ersetzt die
  Greedy-Gegnerauswahl. Vermeidbare Rematches sind eliminiert (Invariantentest über mehrere
  Feldgrößen/Seeds). Bye/Farben/Forensik unverändert. Details `docs/SWISS_PAIRING_ENGINE.md`.
- Offen (Swiss v2/FIDE-Dutch): Bracket-/Floater-/Erstrunden-Setzungsregeln, austauschbare
  Pairing-Strategien, polynomiales Matching für große Opens.

# Aktueller Zusatz 0.12.0

- Externe Profile können auf Dubletten geprüft und als neuer oder bestehender Teilnehmer angewendet werden.
- DSB/DeWIS bleibt nächster Integrationsblock nach Klärung der offiziellen Schnittstelle.

# PLANS.md

## v0.1 – Projektbasis
- [x] Solution-Struktur mit Domain/Application/Infrastructure/WebApi/WebApp.
- [x] Testprojekte für Domain/Application/Golden Tests.
- [x] Round-Robin-Pairing.
- [x] Basis-Schweizer-System.
- [x] Standings mit Kernwertungen.
- [x] Armageddon-Bidding-Grundlage.
- [x] Lokale Start-/Buildskripte.

## v0.2 – Bedienbares persistentes MVP
- [x] Teilnehmer im Dashboard anlegen.
- [x] Turnier im Dashboard anlegen.
- [x] Runde auslosen und Ergebnisse erfassen.
- [x] Tabelle anzeigen.
- [x] SQLite-Persistenz für Turnier-Snapshots.
- [x] Frontend-Build-Fix für TypeScript/Vite.
- [x] Persistenztest.

## v0.3 – Turnierleiter-Funktionen
- [x] Teilnehmer bearbeiten und zurückziehen im Dashboard.
- [x] Kreuztabelle anzeigen.
- [x] Kategorien U10/U12/U14/U16/U18/U25, Frauen, Senioren und Heldenpokal im UI.
- [x] CSV-Import Teilnehmer.
- [x] CSV-/JSON-Export und JSON-Backup/Restore.
- [x] Bessere Fehler-/Auditansicht im Dashboard.

## v0.4 – Regelhärte
- [x] Swiss-Pairing in Richtung FIDE Dutch vorbereitend ausbauen: Scoregroups, Floater-Audit, Bye-Schutz, Farbhistorie.
- [x] Golden-/Unit-Tests mit Pairing-Fällen für Bye, Rematch und Farben.
- [ ] Buchholz-Feinheiten, kampflose Partien, Cut-Wertungen sauber spezifizieren.
- [x] Druck-/CSV-Export für Tabelle und Paarungen als lokale Adaptergrundlage.
- [ ] Import/Export-Adapter für Swiss-/Chess-Results-Ökosystem untersuchen.

## v0.5 – Installation
- [x] Portable Publish inklusive Frontend-Auslieferung über Backend (v0.8, `Pack-Portable.ps1`).
- [x] Start-BAT/PowerShell ohne Entwicklerwerkzeuge (`Start-Portable.bat`, `Start-Desktop.bat`).
- [x] Datenpfad unter AppData oder Projektdata konfigurierbar (Backend-Default AppData, Override per `SchachTurnierManager__DataDirectory`).
- [x] Windows-Installer evaluieren (Entscheidung: Inno Setup 6; Skript unter `installer/`, Readiness/Checkliste automatisiert; echter lokaler Build/Test haengt von installiertem Inno Setup ab).


## Nächster Fokus ab 0.4.0

- Schweizer-System weiter Richtung FIDE Dutch entwickeln: Bracket-/Scoregroup-Transpositionslogik, absolute Kriterien, detaillierte Floater-Verwaltung.
- Buchholz-/kampflos-/Cut-Wertungsdetails präzisieren und testen.
- Swiss-Chess/Swiss-Manager/Chess-Results-Adapter als Import-/Export-Schicht vorbereiten.
- Portable Paket und spätere Windows-Installation ausbauen.


## Abgeschlossen in 0.6.0

- v0.5-Testkompilierung stabilisiert.
- Checkpoint-Skript stoppt jetzt bei fehlgeschlagenen Checks.

## Abgeschlossen in 0.5.0

- Manuelle Paarungsänderungen mit Audit.
- Runden sperren/entsperren und als geprüft markieren.
- Ergebnisänderungen in geschlossenen Runden blockieren.
- Checkpoint-Commit-Skript.

## Nächster Fokus 0.6.0

- Kampflos-/Bye-Wertungen fachlich schärfen.
- Buchholz/SB/Cut-Wertungen für kampflose Ergebnisse präzisieren.
- Erweiterte Ergebnisvalidierung und Rundenabschluss-Workflow.


## Abgeschlossen in 0.7.1

- Tabellen-CSV und Paarungs-CSV ergänzt.
- HTML-Druckansicht für Turnierbericht und einzelne Rundenblätter ergänzt.
- Dashboard-Druck-/Exportbereich erweitert.

## Nächster Fokus 0.8.0

- Portable Publish inklusive statischem Frontend über Backend.
- Startskript für Nicht-Entwickler.
- Optionaler Datenpfad/Backup-Ordner im UI.


## v0.8.0 - Portable App / Auslieferung

- Backend liefert gebaute WebApp aus `wwwroot` aus.
- Portable Paket unter `output\portable` mit Start-BAT, app-Ordner, data-Ordner und README.
- Optional später: Self-contained Paket und echter Windows-Installer.

## v0.9.1 - Nächster Vorschlag

- Installations-/Update-Erlebnis verbessern.
- Datenbank-Backup/Restore im Portable-Kontext sichtbarer machen.
- Erste Release-Checkliste und manuelle QA-Szenarien.


## Abgeschlossen in 0.9.1

- Turniereinstellungen im Dashboard bearbeitbar.
- Wertungskette konfigurierbar und in der Tabellenberechnung wirksam.
- Punktesystem/TWZ/Forfeit-/Bye-/Kategorie-/Heldenpokal-Regeln im UI.

## Nächster Fokus 0.10.0

- UI-Qualität: Turnierassistent, bessere Validierung, Importvorschau und Exportcenter.


## v0.10.0 - Externe Spielerdaten

- Provider-Modell für FIDE, DSB/DWZ und ThSB-Kontext.
- FIDE-ID-Direktabruf als erster realer Provider.
- DSB/DWZ über offizielle API/Wertungsportal vorbereiten.
- UI-Vorschau und Übernahme ins Teilnehmerformular.
- Tests mit Fixtures statt Live-Netzwerk.


## v0.10.0 umgesetzt

- FIDE-ID-Lookup-Grundlage aktiv.
- DSB/ThSB-Provider vorbereitet.
- Nächster Schritt: robuste DSB/DeWIS-Klärung, FIDE-Namenssuche und Import-Vorschau verbessern.

## Open-Source-Sicherheitsfreigabe vor Veröffentlichung

Status: OFFEN, vor Public Release zwingend erledigen.

Dieses private Entwicklungsrepo darf nicht direkt öffentlich geschaltet werden, solange die bestehende Git-Historie nicht vollständig geprüft oder bereinigt wurde.

Begründung:
- In der privaten Historie gab es interne Registry-/Package-Feed-Referenzen.
- Zwischenstände enthielten zeitweise lokale Audit-/Backup-Dateien.
- Für ein öffentliches Open-Source-Projekt soll niemand über die Git-Historie interne, private oder unpraktische Informationen finden.

Bevorzugter Zielweg:
- Privates Entwicklungsrepo bleibt privat.
- Öffentliches Repository wird später aus einem geprüften Clean Snapshot ohne alte Git-Historie erzeugt.
- Snapshot darf keine .git-Historie, .codex, .vs, output, bin, obj, dist, node_modules, security-audit, .local-backups, Logs, Dumps, ZIPs, Datenbanken, lokale Configs oder interne Registry-/TFS-/ECKD-Begriffe enthalten.

Security-Agent/Skill-Aufgabe:
- Vor Commits/Pushes staged files prüfen.
- Vor Public Release vollständige Repository-/History-/Snapshot-Prüfung durchführen.
- Zwischen lokalem Git, privatem GitHub und beruflichem TFS-Git unterscheiden.
- Bei TFS-/Arbeitsrepos besonders restriktiv agieren.
- Bei privaten GitHub-Open-Source-Repos Clean-Snapshot-Strategie bevorzugen.

## v0.38.6 - CommitGuard und Clean-Snapshot-Folgearbeit

- [x] Open-Source-Sicherheitsgate in `PLANS.md` auffindbar dokumentiert.
- [x] Repository-Security-Regeln in `AGENTS.md` und als Skill ergänzt.
- [x] CommitGuard auf explizites Staging geprüfter Pfade statt blindem `git add --all` umstellen.
- [x] Safety-Checks gegen False Positives aus eigenen Patternquellen härten.
- [x] Grundskript für Clean Snapshot ohne alte Git-Historie ergänzen.
- [ ] Vor echtem Public Release Snapshot auf einem frischen Klon prüfen und Report manuell abnehmen.

## v0.38.7 - Projektstruktur und KI-Agentenarchitektur

Dateiablage-Regeln: dauerhafte Konzepte nach `docs/architecture/`, Planung/Prozesse nach `docs/planning/`, historische Übergaben nach `docs/handoffs/`, aktive Skripte flach unter `scripts/` (Übersicht: `scripts/README.md`), historische After-Apply-Skripte unter `scripts/archive/after-apply/`. Agentenregeln zentral in `AGENTS.md`, Skills unter `.agents/skills/`, Provider-Adapter unter `.claude/`/`.codex/`.

- [x] `docs/` gegliedert in `architecture/`, `planning/`, `handoffs/` (Handoffs nur verschoben, nicht gelöscht).
- [x] `scripts/archive/after-apply/` für historische After-Apply-Skripte; Snapshot-/Safety-Pfadmuster nachgezogen.
- [x] `docs/architecture/AI_AGENT_ARCHITECTURE.md`: providerneutrale Agentenregeln, austauschbare Ausführende, Skills als Wissensebene, Security-Gate, Clean-Snapshot-Pflicht.
- [x] `docs/planning/PROJECT_ORCHESTRATION.md`: Aufgaben→Skripte/Skills, Release-Gate, CommitGuard, Clean Snapshot, Handoff-Erzeugung.
- [x] `.claude/CLAUDE.md` als reiner Adapter auf `AGENTS.md` und Skills.
- [ ] Aktive Skripte in `scripts/dev|test|release|git|security|maintenance/` migrieren (Zielzustand dokumentiert; eigener Lauf mit gleichzeitiger Anpassung aller Pfadverweise und Release-Gate-Verifikation).

## Zusatz 0.50.0 – Release-/Betriebsunterbau, Logging und Secrets

- Logging-Konfiguration über `appsettings.json` / `appsettings.Development.json` ergänzt: App-Logs steuerbar per Loglevel, Microsoft/EF standardmäßig reduziert.
- HTTP-Request-Logging ergänzt: Methode, Pfad ohne Querystring, Status und Laufzeit; `/api/health` nur Debug.
- Lokale Secret-Struktur ausgebaut: `Get-LocalSecret.ps1`, DPAPI-Roundtrip-Selftest und GitSafety-Integration.
- Release-Readiness-Skript ergänzt: ReleaseGate, SecretSafety, Desktop-Publish, portable Self-contained-Paket, optional Installer-Readiness, SHA256-Manifest und ein Upload-ZIP.
- Agenten-/Skill-Struktur erweitert: Release Operations, Logging/Observability, Repository Security.
- Unit-/Contract-Tests ergänzen Schutz gegen Regressionen bei Logging, Secret-Ablage, Release-Skripten und Skills.

Nächste Schritte:

1. 0.49.0 committen, dann 0.50.0 anwenden und `Invoke-ReleaseCandidateReadiness.ps1` testen.
2. Wenn Inno Setup lokal installiert werden darf: echten Setup-EXE-Build und Install/Uninstall-Test durchführen.
3. Danach fachlich weiter mit RUN-14 Tie-Breaks oder RUN-15 CSV/Excel-Import/Export vertiefen.

## 0.53.0 - Klick-Installation / Kollegen-Rollout

- [x] Kollegenpaket enthaelt Doppelklick-Bootstrapper fuer Installation und Deinstallation.
- [x] Installation nutzt `%LocalAppData%\Programs\SchachTurnierManager` und erzeugt Startmenue-Shortcut.
- [x] Nutzerdaten und DPAPI-Secrets bleiben benutzer-/rechnerlokal und werden nicht mit ausgeliefert.
- [x] Readiness-Test prueft Paket, Checksums, Installation, Shortcut, Healthcheck, Dashboard, Tournament-API, isolierte SQLite und Uninstall.
- [ ] Echten Test auf einem Kollegen-PC oder einer frischen Windows-VM ausfuehren und Ergebnis dokumentieren.
- [ ] Entscheidung treffen: unsignierter Bootstrapper bleibt ausreichend oder signierte Setup-EXE vorbereiten.
