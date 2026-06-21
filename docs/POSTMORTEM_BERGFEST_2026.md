# Postmortem – Bergfest-Turnier 2026

**Datum Turnier:** Freitag, 2026-06-19 (abends)
**Analyse:** 2026-06-21
**Scope:** Ursachenanalyse und gezielte Stabilisierung nach dem realen Einsatz. Keine neuen
Komfortfeatures, keine Architektur-Neuschreibung. Alle Tests mit synthetischen Spielern.

> Hinweis: Echte Teilnehmerdaten, lokale Turnierdatenbanken und Logs werden **nicht** committet
> (`local-input/**`, `logs/`, `output/`, `tmp/`, `*.local.json` sind ignoriert). Dieses Dokument
> enthält ausschließlich synthetische Beispiele.

## TL;DR

Der Einsatz litt an zwei real belegbaren Problemen und mehreren testtechnischen Lücken:

1. **SQLite „disk I/O error" beim Backend-Start** (in den Logs belegt). Der Start war dadurch
   zeitweise nicht zuverlässig. → Robuster Start mit Vorabprüfung + verständlicher Klartext-
   Diagnose + sauberem Exit-Code.
2. **Round-Robin verformte sich bei nachträglichem Spieler/Rückzug still** (im Code-Review
   belegt, reproduziert). → Harte Sperre mit klarer Meldung statt rückwirkender Planänderung.
3. **Rundenlimit (keine 6. Runde nach geplanten 5):** Die harte Sperre existierte bereits **vor**
   dem Turnier und greift auf allen Pfaden. Nicht als Code-Defekt reproduzierbar; jetzt mit
   expliziten Szenario-Tests + HTTP-Smoke fest verankert. Wahrscheinlichste Vor-Ort-Ursache:
   `PlannedRounds` war höher gesetzt als die mündlich „geplanten" 5 Runden (Bedien-/Konfig-Ebene).
4. **QR/Handy:** Die Implementierung ist solide (LAN-Bindung, Laptop-IP-Feld, Warnungen,
   Browser-Fallback). Keine Code-Ursache belegbar; nicht vor Ort am realen Handy nachverifiziert.

## Ausgewertete Logs

Quelle: `logs/` und `tmp/` (lokal, ignoriert). Inhalt sind **Build-/Restore-/Startprotokolle**,
**keine Turnier-Aktionslogs** (keine Auslosungs-/Ergebnis-/Paarungsentscheidungen).

| Datei | Aussage |
|---|---|
| `logs/friday-startcheck/backend-dll-live.log` | **Unhandled exception: SQLite Error 10: 'disk I/O error'** bei `PRAGMA journal_mode = 'wal';` während `EnsureCreated()` (Program.cs). Backend-Start gescheitert. |
| `logs/friday-startcheck/backend-memory-live.log` | Erfolgreicher Start (Tabellen angelegt, `Now listening on http://localhost:5088`, Health 200). Beweist: Start funktioniert grundsätzlich, der Fehler ist umgebungs-/dateizustandsabhängig. |
| `logs/friday-startcheck/backend-live.log` | `dotnet run` brach mit „Fehler beim Buildvorgang" ab – typisch bei bereits laufender Instanz/gesperrten DLLs. |
| `logs/codex-build-*.log`, `restore-*.log` | MSBuild-/Restore-Diagnose vom 2026-06-18 (Pathmap/Apphost/Parallel-Build). Build-Hardening, kein Turnier-Laufzeitbezug. |

**Lücke:** Es existieren keine Laufzeitlogs zu konkreten Turnieraktionen. Dadurch sind die
gemeldeten Symptome „falsch ausgelost" und „6. Runde trotz geplanter 5" **nicht aus Logs**
rekonstruierbar. Das ist in „Offene Risiken / nächstes Mal" adressiert.

## Bestätigte Ursachen

### 1. SQLite disk I/O error beim Start (Logs)
`PRAGMA journal_mode = 'wal'` schlägt in bestimmten Umgebungen mit „disk I/O error" fehl (typisch:
Datenverzeichnis in OneDrive/Sync-Ordner, Antivirus-/Backup-Sperre, zweite laufende Instanz hält
`-wal`/`-shm` offen, Reststände). Der Fehler war ein **unbehandelter Stacktrace** – für die Person
am Turniertisch nicht interpretierbar.

**Fix:** `Program.cs` prüft vor `EnsureCreated()` Verzeichnis-Existenz und Schreibrechte
(`DatabaseStartupDiagnostics.Probe`) und fängt Fehler ab. Ausgabe ist eine mehrzeilige Klartext-
Meldung (Pfad, Schreibbarkeit, Readonly-Status, konkrete Ursachen/Abhilfen) plus `Environment.Exit(2)`.
Keine Journal-/Schema-Migration (bewusst risikoarm gehalten).

### 2. Round-Robin: stille rückwirkende Planänderung (Code-Review, reproduziert)
`GetNextRoundRobinRound` rief bei **jeder** Auslosung `GenerateAllRounds(aktiveSpieler)` neu auf und
nahm `all[Rounds.Count]`. Bei stabilem Teilnehmerfeld deterministisch korrekt – aber bei einem
**Late Entry oder Rückzug nach Runde 1** ändert die Circle-Methode Seeding und Rundenanzahl, sodass
die „nächste" Runde nicht mehr zu den bereits gespielten passt (falsche Farben, Rematches, falsche
Byes). Reproduziert per Test und HTTP-Smoke (HTTP 400).

**Fix:** Harte Sperre – der aktive Teilnehmerkreis muss dem Teilnehmerkreis aus den bereits
ausgelosten Runden entsprechen; sonst klare Meldung „Im Jeder-gegen-jeden ist der Spielplan ab
Runde 1 fixiert … bewusste Neuplanung (Zurücksetzen/Neuanlage)". So wird nichts rückwirkend
verändert. (Swiss bleibt voll Late-Entry-fähig.)

### 3. Rundenlimit (bereits abgesichert, jetzt verankert)
`EnsureCanCreateNextRound` blockiert jede Auslosung, sobald `Rounds.Count >= PlannedRounds`
(Commit `e72f631` vom 2026-06-18, also **vor** dem Turnier). Greift identisch für `next-round`,
Preview, Swiss und Round-Robin. Nicht als Defekt reproduzierbar; jetzt durch Szenario-Tests
(12 Spieler / 5 bzw. 6 Runden) und HTTP-Smoke (HTTP 400 „maximale Rundenzahl") fest verankert.

## Nicht belegbare Vermutungen

- **„6. Runde trotz geplanter 5":** Keine Log- oder Code-Evidenz für eine Über-Limit-Auslosung.
  Plausibelste Erklärung: `PlannedRounds` war beim Anlegen höher gesetzt als die mündlich geplanten
  5 Runden (Default ist 5; im Einstellungsdialog frei wählbar). → Bedien-/Konfig-Ebene, kein
  Code-Bug. Empfehlung: vor Start `PlannedRounds` gegen die geplante Rundenzahl gegenprüfen.
- **„Mehrfach falsch ausgelost":** Ohne Pairing-Audit-Laufzeitlogs nicht rekonstruierbar. Die
  Swiss-Engine ist eine dokumentierte, auditierbare Greedy-Heuristik (noch kein vollständiges
  FIDE-Dutch) – Floater/Scoregruppen-Abweichungen sind möglich und werden protokolliert, sind aber
  keine „falsche" Auslosung im Sinne eines Defekts. Die Audit-Hinweise stehen bereits pro Runde zur
  Verfügung; siehe „nächstes Mal" zur Sicherung der Entscheidungsdaten.
- **QR/Handy „nicht zuverlässig":** Keine Code-Ursache gefunden. Häufigste reale Ursachen liegen
  außerhalb des Codes (Laptop-IP nicht eingetragen, Handy nicht im selben Hotspot, Windows-Firewall
  blockiert Port 5173). Diagnose dafür ist in der UI vorhanden.

## Umgesetzte Fixes (Code)

| Bereich | Datei | Änderung |
|---|---|---|
| Round-Robin Late Entry/Rückzug | `src/SchachTurnierManager.Application/TournamentService.cs` | Roster-Konsistenz-Sperre in `GetNextRoundRobinRound`. |
| DB-Start-Robustheit | `src/SchachTurnierManager.WebApi/Program.cs` | Vorabprüfung + try/catch um `EnsureCreated()`, Klartext-Report, Exit 2. |
| DB-Start-Diagnose | `src/SchachTurnierManager.Infrastructure/Persistence/DatabaseStartupDiagnostics.cs` | Neuer, testbarer Diagnose-Helfer (Probe + Report). |
| Version | `Program.cs` (Health), `WebApp/package.json`, `CHANGELOG.md` | `0.40.2` → `0.40.3`. |

## Neue Tests

`tests/SchachTurnierManager.Application.Tests/PostmortemBergfestScenarioTests.cs` (17 Fälle):
- Swiss 12 Spieler / 5 Runden → 6. Runde hart blockiert (Generate **und** Preview).
- Swiss 6 Runden / 12 Spieler → genau 6 Runden, 7. blockiert.
- Late Entry nach Runde 2: 0 Punkte vor Auslosung, Spielt ab nächster Runde, Altrunden unverändert.
- Late Entry nach Runde 4 bei max. 5 Runden → spielt Runde 5, dann Limit greift.
- Rückzug → nicht mehr gepaart; Reaktivierung → erst künftig gepaart, Altrunden unverändert.
- Doppelte FIDE-ID blockiert.
- Manuelle Paarung: Persistenz + als gespielt gewertet (kein Rematch bei 6 Spielern); Schutz gegen
  Spieler auf zwei Brettern und gegen inaktive Spieler.
- Round-Robin 4/5/6/12/13 Spieler: jede Paarung genau einmal, Byes korrekt (gerade=0, ungerade=1/Spieler),
  exakte Rundenzahl, Über-Limit blockiert.
- Round-Robin Late Entry / Rückzug nach Start → blockiert mit klarer Meldung.

`tests/SchachTurnierManager.Infrastructure.Tests/DatabaseStartupDiagnosticsTests.cs` (3 Fälle):
- Schreibbares Verzeichnis → healthy, Verzeichnis wird angelegt.
- Readonly-DB-Datei → unhealthy.
- Failure-Report enthält Pfad + handlungsorientierte Hinweise (OneDrive, disk I/O error).

**Gesamtstand:** Domain 71, Application 71, Infrastructure 15, Golden 1 → **158 Tests grün**
(Release, `--no-build`). Zusätzlich HTTP-Smoke (isoliertes Datenverzeichnis, Port 5099):
Rundenlimit → HTTP 400, Round-Robin-Late-Entry-Sperre → HTTP 400.

## Build / Frontend / API / Safety

- `dotnet build -c Release`: 0 Warnungen, 0 Fehler.
- `dotnet test -c Release --no-build`: 158 grün.
- `npm run build` (WebApp): `tsc --noEmit` + `vite build` ohne Fehler.
- HTTP-Smoke gegen isoliertes Datenverzeichnis bestätigt Rundenlimit und RR-Sperre.
- `git diff --check` und PII-/Secret-Scan der hinzugefügten Zeilen sauber; keine
  `local-input/logs/output/tmp/bin/obj/dist/node_modules` gestaged.

## Offene Risiken

- **Keine Turnier-Laufzeitlogs vorhanden.** Symptome „falsch ausgelost"/„6. Runde" sind ohne
  Aktions-/Pairing-Audit-Trail nicht forensisch rekonstruierbar. (Audit-Journal existiert in der
  DB, wurde aber nicht exportiert/gesichert.)
- **Swiss-Engine ist Greedy-Heuristik**, kein vollständiges FIDE-Dutch. Späte Rematches sind in
  Engpässen möglich (mit Critical-Flag protokolliert).
- **Round-Robin nach Start nicht erweiterbar** (bewusste Sperre). Late Entry/Rückzug im RR erfordert
  Reset/Neuanlage – akzeptierter MVP-Trade-off zugunsten Datenintegrität.
- **QR nicht am realen Handy vor Ort verifiziert.**

## Was beim nächsten Turnier anders laufen muss

1. **Vor Start:** `PlannedRounds` explizit gegen die geplante Rundenzahl prüfen; Format (Swiss vs.
   Jeder-gegen-jeden) bewusst wählen – nach Runde 1 ist das Format gesperrt.
2. **DB-Pfad:** Datenverzeichnis auf einem lokalen, nicht-synchronisierten Pfad halten (kein
   OneDrive/Dropbox); nur eine Instanz starten. Bei DB-Fehler liefert der Start jetzt eine klare
   Anleitung.
3. **Nach jeder Runde** ein lokales Backup ziehen (`scripts/Backup-BergfestTournament.ps1`) **und**
   das Audit-Journal exportieren, damit spätere Analysen möglich sind.
4. **QR vorab testen:** Laptop-IP eintragen, Handy im selben Hotspot, Firewall-Port 5173 freigeben;
   im Zweifel am Laptop würfeln (Browser-Fallback ist immer verfügbar).
5. **Late Entry / Rückzug:** im Swiss problemlos ab nächster Runde; im Round-Robin nur über bewusste
   Neuplanung.
