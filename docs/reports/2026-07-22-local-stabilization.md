# Lokale Stabilisierung: Bedienbarkeit und Startbereitschaft

Stand: 2026-07-22

## Ausgangslage

523 .NET-Tests und 24 Frontendtests waren grün, TypeScript und Vite ebenfalls –
und trotzdem meldete der manuelle Durchlauf im echten Browser, dass viele
Schaltflächen wirkungslos bleiben und „Turnier anlegen" mindestens zeitweise
defekt ist. Die vorhandene Testpyramide konnte das nicht sehen: sie prüft
Auslosungs-, Wertungs- und Formatlogik, aber keinen einzigen echten
Bedienschritt in einem echten Browser.

Dieser Lauf hat den Defekt reproduziert, die Ursache belegt, behoben und mit
Tests abgesichert, die den Fehler auch wirklich fangen können.

## Reproduktion

Aufbau: portables Paket (`Pack-Portable.ps1`), also genau das Binary, das ein
Anwender startet; headless Firefox 153 über Marionette; isoliertes
Datenverzeichnis; Instrumentierung von `console.error`, `window.onerror`,
`unhandledrejection` und `window.fetch` im Seitenkontext.

Ereignisprotokoll bei laufendem Backend:

```
dom:click BUTTON 'Jetzt anlegen'
dom:submit stack create-tournament-form
fetch:start  POST /api/tournaments
fetch:ok     POST /api/tournaments 201
```

Dasselbe nach dem Beenden des Backendprozesses:

```
dom:click BUTTON 'Jetzt anlegen'
dom:submit stack create-tournament-form
fetch:start  POST /api/tournaments
(nichts mehr – auch nach 6 Sekunden nicht)
```

Das ist die Ursache. Der `fetch` gegen 127.0.0.1 wird von Firefox weder erfüllt
noch abgelehnt. `createTournament` erreicht seinen `catch`-Block deshalb nie:
keine Meldung, kein Ladezustand, keine Konsolenausgabe. Für den Bediener
verhält sich die Schaltfläche exakt wie eine tote Schaltfläche – und zwar für
jede Aktion, nicht nur für das Anlegen.

## Befunde vorher / nachher

| # | Befund | Vorher | Nachher |
|---|--------|--------|---------|
| 1 | Anfrage ohne Zeitausfall | Hängende Anfrage endet nie, Aktion bleibt wirkungslos | Jede Anfrage hat eine Obergrenze und endet in `ApiTimeoutError` mit Handlungsanweisung |
| 2 | `async`-Handler ohne `catch` | 11 Handler erzeugten bei Fehlern eine unbehandelte Promise-Ablehnung | Jeder Handler meldet den Fehler sichtbar über `reportActionFailure` |
| 3 | Backend-Chip | Blieb nach einem gescheiterten Aufruf dauerhaft auf „online" | Wird bei Transportfehlern ehrlich auf „nicht erreichbar" gesetzt |
| 4 | Startbereitschaft | Genau eine Health-Abfrage beim Laden, danach nie wieder | Begrenzter Retry mit wachsender Wartezeit, Banner und „Erneut versuchen" |
| 5 | Startfehlermeldung | Rohe `Error.message` statt `describeApiError` | Einheitlich über `describeApiError` |
| 6 | Doppelklick auf „Jetzt anlegen" | Zwei identische Turniere (reproduziert) | Genau ein Turnier; Ref-Guard vor dem Request, Schaltfläche zeigt „Wird angelegt …" |
| 7 | Native `window.confirm` | 3 verbleibende Stellen (Auslosung trotz kritischer Hinweise, Chess960 überschreiben in Runden- und Brettdialog) | Alle über den In-App-`ConfirmDialog`; Firefox darf wiederholte native Dialoge unterdrücken und würde den Klick still verschlucken |
| 8 | `requestJson` mit eigenen Headern | Ein `headers`-Objekt des Aufrufers ersetzte den `Content-Type` komplett | Header werden korrekt zusammengeführt |

Befund 7 war vorher nur teilweise abgesichert: der Guard-Test filterte auf
Wörter wie „löschen"/„zurücksetzen" und ließ die drei übrigen Aufrufe durch.

## Teststrategie

| Ebene | Datei / Skript | Umfang | Deckt ab |
|-------|----------------|--------|----------|
| Unit (Transport) | `test/apiClientTimeout.test.ts` | 9 Tests | Zeitausfall, Fehlerklassifikation, Abbruch durch den Aufrufer, Header-Zusammenführung, Textqualität |
| Unit (Transport) | `test/apiClientErrors.test.ts` | 7 Tests | Bestehende Klassifikation von Transport- vs. Fachfehlern |
| Unit (Bereitschaft) | `test/backendReadiness.test.ts` | 10 Tests | Zustandsfolge, Backoff, kein Busy-Loop, kein aggressives Polling, keine Infrastrukturdaten im Text |
| Struktur (Guard) | `test/actionErrorHandling.test.ts` | 7 Tests | Jeder API-Handler hat `catch` **und** meldet sichtbar; Doppelklickschutz; ehrlicher Backend-Chip |
| Struktur (Guard) | `test/noNativeDialogs.test.ts` | 6 Tests | Kein nativer Browserdialog mehr, In-App-Dialoge verdrahtet |
| Unit (Domäne) | `test/assistant.test.ts`, `test/destructiveActions.test.ts` | 13 Tests | Unverändert |
| API/Integration | `TournamentCreationWorkflowTests.cs` | 13 Tests | Namensvalidierung, Trimmen, gleichnamige Turniere, Optionsübernahme, Fehlerform der WebApi |
| Persistenz | `TournamentRestartPersistenceTests.cs` | 3 Tests | Turnier, Teilnehmer, Runde, Ergebnis und Löschung über einen vollständigen Prozessneustart |
| Browser-E2E | `scripts/Smoke-FirefoxTournamentFlow.ps1` | 52 Prüfungen | Kompletter Bedienablauf im echten Firefox, siehe unten |

Frontendtests: 24 → **52**. .NET-Tests: 523 → **539**.

## Browser-End-to-End (`Smoke-FirefoxTournamentFlow.ps1`)

Läuft gegen das portable Paket, headless Firefox, isoliertes Datenverzeichnis,
ohne Netzwerkzugriff. Bewusst ohne Playwright/Selenium – der bestehende
Marionette-Client bleibt die Browser-Testinfrastruktur des Projekts.

1. Start, Healthcheck grün, Leerzustand, keine Konsolenfehler
2. „Turnier anlegen" reagiert beim ersten Klick; Pflichtfeld nachvollziehbar
   deaktiviert; Turnier erscheint in Liste, Statuszeile und Backend
3. Reload erhält das Turnier
4. Doppelklickschutz: zwei Submits erzeugen genau ein Turnier
5. Backend beendet: sichtbare, verständliche Meldung; kein `NetworkError`, kein
   Host/Port/Proxy im Text; Chip nicht mehr grün; Bereitschaftsbanner erscheint;
   keine hängenden Dialoge, kein weißer Bildschirm
6. Erholung: „Erneut versuchen" bei totem Backend meldet keinen Erfolg; nach dem
   Backendstart wird die Anwendung ohne Browserneustart wieder grün und erneutes
   Anlegen funktioniert; der abgebrochene Offline-Versuch hat nichts halb angelegt
7. Voller Turnierablauf: Demo mit acht synthetischen Teilnehmern, Runde 1,
   Ergebnisse, nächste Runde, Tabelle mit Punkten, Backup-Export
8. Anwendungsneustart: alle Turniere weiterhin vorhanden und wieder zu öffnen
9. Button-Crawl über acht Bereiche: **199** sichtbare Bedienelemente erfasst,
   **144** sichere Elemente geklickt, keine unbehandelte Ablehnung, kein
   Seitenfehler, kein nativer Dialog, Anwendung überlebt den Durchlauf

Ergebnis: 52 OK, 0 Fehler.

Der Crawl klickt bewusst nur lesende und navigierende Elemente. Schreibende und
zerstörende Aktionen (löschen, zurücksetzen, importieren, überschreiben,
auslosen, speichern, drucken, exportieren) sind ausgeschlossen, auch im
isolierten Datenverzeichnis.

Aufruf:

```powershell
pwsh -File scripts\Smoke-FirefoxTournamentFlow.ps1 -EvidenceDirectory <Ordner>
```

`-SkipPack` überspringt den Paketbau, wenn `output/portable` bereits aktuell
ist. `-EvidenceDirectory` schreibt Screenshots, `button-matrix.csv` und eine
Zusammenfassung. Wie `Smoke-FirefoxDialogs.ps1` ist der Test nicht Teil von
`Invoke-ReleaseGate.ps1`, weil er eine lokale Firefox-Installation braucht; vor
einem Release-Candidate manuell ausführen.

## Bewusst nicht geändert

- **Gleichnamige Turniere bleiben erlaubt.** An einem Turniertag entstehen
  durchaus zwei Gruppen mit gleichem Namen. Die Oberfläche unterscheidet über
  die Id; der Doppelklickschutz sitzt im Formular, nicht im Backend.
- **Kein Playwright.** Eine npm-Browserinfrastruktur wäre neue Abhängigkeit und
  neuer Netzwerkbedarf; der vorhandene Marionette-Client leistet dasselbe.
- **Chromium-E2E fehlt.** Auf dieser Maschine ist kein Chromium installiert. Die
  betroffene Ursache (hängender `fetch`, unterdrückte native Dialoge) ist
  browserunabhängig behoben – der Zeitausfall wirkt in jeder Engine –, aber ein
  belegter Chromium-Lauf steht aus.

## Offene Punkte

- **Chromium-Smoke**: nachziehen, sobald eine Chromium-Installation verfügbar
  ist. Das Skript ist über `-FirefoxPath` an Firefox gebunden und bräuchte für
  Chromium einen zweiten Treiber (CDP statt Marionette).
- **`App.tsx` bleibt mit rund 3.400 Zeilen der zentrale Klotz.** Die
  Feature-Extraktionen sind als STM-FE-015..018 im Backlog; dieser Lauf hat
  bewusst nur bedienrelevante Defekte behoben und keine Umstrukturierung
  begonnen.
- **Kein `data-testid` im Produktionscode.** Der E2E-Test adressiert über
  semantische Selektoren und Beschriftungen. Das ist robust genug, macht aber
  Umbenennungen von Beschriftungen zu Teständerungen.
