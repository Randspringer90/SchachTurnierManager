# STM-INFRA-009 - Read-only PR-Sammelpruefung

Issue #64. Dieses Werkzeug liefert Beobachtungen zu offenen GitHub-PRs, keine Merge- oder DoD-Freigabe.

## Aufruf

Voraussetzung: Node 22 oder neuer; fuer Online-Beobachtung vorhandene GitHub CLI mit bereits eingerichteter Anmeldung und Leserechten. Es wird keine Anmeldung angelegt und kein Token ausgegeben.

```sh
node scripts/Get-PrReadiness.mjs --repo Randspringer90/SchachTurnierManager
```

Der Befehl liest alle offenen PRs bis zu den dokumentierten Sicherheitsgrenzen, Check-Runs, Commit-Statuses und Reviews. Ausgabe: redigiertes JSON auf stdout. Keine Datei-/Git-/PR-Schreibaktion, kein Checkout und keine Ausfuehrung von PR-Code. Keine Freigaben, Kommentare, CI-Reruns oder Merges. Jeder gh-Aufruf ist explizit GET gegen github.com mit Argumentliste statt Shell-String.

## Aussagen des Berichts

- `BLOCKED`: beobachteter Draft, Konflikt, geschlossener PR, fehlgeschlagener Check oder aktiver Aenderungswunsch.
- `INCOMPLETE`: fehlende/unklare/mehrdeutige Daten, nicht vollstaendige Pagination, unbekannte Mergeability, nicht erfolgreiche Checks oder bewegte Referenzen.
- `OBSERVED_REMOTE_CHECKS_CLEAR`: nur die hier beobachteten Checks und erfassten Review-Blocker sind unauffaellig. Das ist ausdruecklich NICHT Done oder mergebereit.
- `NO_OPEN_PRS`: vollstaendig gelesene leere PR-Liste, keine Aussage zur Produktreife.

`definitionOfDone=NOT_EVALUATED` und `mergeAuthorized=false` gelten IMMER, auch beim gruenen Remote-Teilbild. Lokale Gates, Codequalitaet, CODEOWNERS, aufgeloeste Review-Threads und effektive Branchschutzregeln bleiben gesondert zu pruefen.

Die acht erwarteten Check-Namen stammen aus der gelesenen Projektbaseline `cc47f1101983d3f3272a893dbf54bd66fa2355b4`. Ein gleichnamiger Commit-Status oder eine fremde App ersetzt keinen erwarteten GitHub-Actions-Check. Mehrdeutige gleiche Check-Namen werden nicht willkuerlich aufgeloest. Auch zusaetzliche rote Checks/Statuses werden beruecksichtigt.

Die vorhandene Owner-Ausfuehrungsfreigabe wird exakt nach dem bestehenden Marker-/Head-/Owner-Vertrag als vorhanden oder nicht gefunden berichtet. Ihr Fehlen ist NICHT pauschal ein Blocker: SAFE_FOR_ISOLATED_BUILD benoetigt keinen solchen Marker. Ein roter Check allein beweist auch nicht, dass der Marker die Fehlerursache ist; dafuer muessen die Logs separat geprueft werden.

## Snapshot-Sicherheit

PR-Metadaten werden vor und nach den Unterabfragen gelesen; bewegte Head-/Base-Refs werden gemeldet. development wird am Anfang und Ende gelesen. Dies erkennt Drift waehrend des Laufs, verhindert aber keine Aenderung nach der letzten Abfrage. Vor einer spaeteren Entscheidung immer frisch lesen.

Es werden keine PR-Titel, Review-Bodies, Logauszuege, Benutzernamen, E-Mails oder rohe gh-Fehler ausgegeben. Berichtet werden IDs, bekannte Check-Namen, Statuscodes und kanonische PR-URLs.

Limits: maximal 50 PRs, 100 Datensaetze pro Seite, 10 Seiten pro Sammlung, 300 GET-Requests, 20 Sekunden/4 MiB je gh-Antwort. Begrenzte oder fehlerhafte Abfragen ergeben INCOMPLETE; sie werden nicht als leer/gruen ausgegeben. Exitcodes: 0 fuer ein klares Remote-Teilbild/keine offenen PRs, 2 fuer Blocker/unvollstaendige Beobachtung, 1 fuer Eingabe-/Dateifehler. Kein Exitcode autorisiert einen Merge.

## Offline-Tests

```sh
node --test tests/scripts/pr-readiness.test.mjs
```

67 deterministische Tests: Analyzer, Check-Quellen, neutrale/uebersprungene/pending Ergebnisse, Statushistorie, Review-Status, Drift, Pagination, Limits, partielle Fehler, gh-GET-Vertrag und CLI. Die Tests starten keine echte gh-Anfrage und lesen keine Kontodaten. Ein neuer xUnit-Wrapper bindet sie in das Application-Testprojekt ein; dort muss Node im PATH verfuegbar sein.

Optional akzeptiert die CLI `--snapshot FILE`. Das Eingabeschema ist `stm.pr-readiness.snapshot.v1` (Beispiele in den Tests). Solche Berichte sind immer `source=OFFLINE_UNVERIFIED_INPUT`; ein Snapshot ist kein Echtheitsnachweis.

## Verifikation und offene DoD

Node-Syntax und alle 67 Tests wurden am 2026-10-01 mit Node 22.16.0 ausgefuehrt: PASS. Der echte gh-Live-Lauf und der .NET-Wrapper wurden hier nicht ausgefuehrt: NOT_RUN. Vollstaendige Projekt-Gates, unabhaengiger Review und kanonische Backlog-/Changelog-Synchronisierung bleiben vor Merge offen. Neue Runtime-Dependencies wurden nicht hinzugefuegt.

API-Referenzen, geprueft 2026-10-01:
- https://docs.github.com/en/rest/checks/runs
- https://docs.github.com/en/rest/commits/statuses
- https://docs.github.com/en/rest/pulls/reviews
