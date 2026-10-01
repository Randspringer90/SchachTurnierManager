# STM-INFRA-009 - Read-only PR-Sammelpruefung

Issue #64 / PR #65. Beobachtung offener PRs, niemals Merge- oder DoD-Freigabe.

## Aufruf und Grenzen

Voraussetzung: Node 22+, vorhandene GitHub CLI mit eingerichteter Anmeldung und Leserechten.

```sh
node scripts/Get-PrReadiness.mjs --repo Randspringer90/SchachTurnierManager
```

Nur feste GitHub-GET-Endpunkte ueber gh mit Argumentliste statt Shell-String. Keine Datei-/Git-/PR-Schreibaktionen, keine Anmeldung/Tokenausgabe, kein Checkout und keine Ausfuehrung fremden PR-Codes. Phasen-/Zaehlerfortschritt auf stderr; redigierter JSON-Bericht separat auf stdout.

Beobachtet werden offene PRs, Check-Runs, Commit-Statuses und Reviews. Maximal 50 PRs, 100 Datensaetze/Seite, 10 Seiten/Sammlung, 300 Requests, 20 Sekunden und 4 MiB je Antwort. Begrenzungen und Fehler werden sichtbar, nie als leere/gruene Daten interpretiert.

## Semantik

`BLOCKED` bedeutet beobachtete Blocker wie Draft/Konflikt/rote Checks/Aenderungswuensche. `INCOMPLETE` steht fuer fehlende/mehrdeutige/ungeklaerte Daten, Pagination oder Ref-Drift. `OBSERVED_REMOTE_CHECKS_CLEAR` bedeutet nur, dass das beobachtete Remote-Teilbild unauffaellig ist. `NO_OPEN_PRS` ist lediglich eine vollstaendig gelesene leere Liste.

`definitionOfDone=NOT_EVALUATED` und `mergeAuthorized=false` gelten IMMER. Lokale Gates, Codequalitaet, CODEOWNERS, Review-Thread-Aufloesung und effektive Branchschutzregeln bleiben gesondert zu pruefen. Exit 0 bedeutet klares Remote-Teilbild/keine offenen PRs, Exit 2 Blocker/unvollstaendige Beobachtung, Exit 1 Eingabe-/Dateifehler; keiner autorisiert einen Merge.

Die acht erwarteten Check-Namen stammen aus Baseline cc47f1101983d3f3272a893dbf54bd66fa2355b4. Gleichnamige Commit-Statuses oder fremde Apps ersetzen keine erwarteten Actions-Checks; Mehrdeutigkeit wird nicht geraten. Zusaetzliche rote Checks/Statuses bleiben sichtbar. skipped/neutral/pending/missing sind nie PASS.

Ein vorhandener SHA-gebundener Owner-Marker wird exakt erkannt. Sein Fehlen allein ist KEIN Blocker, denn SAFE_FOR_ISOLATED_BUILD braucht ihn nicht. Die Ursache eines roten Gates muss separat aus dessen Logs ermittelt werden. Dieses Werkzeug schreibt niemals einen Marker.

PR-Head/Base werden vor und nach Unterabfragen, development am Anfang und Ende gelesen. Drift wird sichtbar; spaetere Aenderungen nach Abschluss des Laufs sind damit nicht ausgeschlossen. Vor Entscheidungen frisch lesen.

## Datenminimierung und Tests

Keine PR-Titel, Review-Bodies, Benutzernamen, E-Mails, Logauszuege oder rohe gh-Fehler im Bericht. Nur bekannte Check-Namen, IDs, Statuscodes und kanonische PR-URLs.

```sh
node --test tests/scripts/pr-readiness.test.mjs tests/scripts/pr-readiness-progress.test.mjs
```

70/70 Tests mit Node 22.16.0 am 2026-10-01 PASS: Analyzer, Check-Quellen, Status-/Review-Historie, Drift, Pagination, Limits, Fehler, gh-GET-Vertrag, Offline-/Live-Adapterpfad mit injiziertem Transport sowie Fortschritt. Ein neuer xUnit-Wrapper ruft beide Testdateien auf; Node muss im PATH verfuegbar sein. Echter gh-Netzwerklauf und .NET-Wrapper hier NOT_RUN.

Optional: `--snapshot FILE` liest das synthetisch testbare Schema stm.pr-readiness.snapshot.v1. Ausgabe bleibt OFFLINE_UNVERIFIED_INPUT, niemals Echtheitsnachweis. Vollstaendige Projekt-Gates, unabhaengiger Review und kanonische Backlog-/Changelog-Synchronisierung sind noch offen.

API-Referenzen (2026-10-01):
- https://docs.github.com/en/rest/checks/runs
- https://docs.github.com/en/rest/commits/statuses
- https://docs.github.com/en/rest/pulls/reviews
