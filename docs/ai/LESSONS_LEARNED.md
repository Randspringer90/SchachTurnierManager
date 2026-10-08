# Lessons Learned — SchachTurnierManager

Kumulativ, neueste zuerst. Jeder Eintrag: Datum, Kontext, Lesson, Konsequenz. Das Projekt
persistiert seine Lessons eigenständig in diesem Repository; externe lokale Wissenspfade sind
keine Voraussetzung.

## 2026-10-08 — Windows-Wurzeln nativ kanonisieren

- Kontext: Die Remote-CI verwendet einen anders geschriebenen Laufwerksbuchstaben
  als Git; eine strikte Stringprüfung lehnt dadurch dieselbe Repositorywurzel ab.
- Lesson: Beide bereits existierenden Pfade über das native Dateisystem auflösen,
  statt Pfadstrings pauschal ohne Beachtung der Dateisystemidentität umzuschreiben.
- Konsequenz: Regression für die identische Wurzel und die weiterhin abgewiesene
  Unterverzeichnis; derselbe native Vergleich schützt auch den CLI-Einstieg.

## 2026-10-08 — Laufzeitreserve ohne Semantikwechsel

- Kontext: Wiederholter Remote-Timeout, genauer Regelpfad noch unbekannt.
- Lesson: Ein positiver IsMatch-Lauf misst nicht die vollständige Match-Enumeration.
- Konsequenz: Identische Ausdrücke beibehalten, Kaltlauf und Vollenumeration
  vergleichen; auf ausdrücklichen Owner-Nachtrag weiterhin endliche Budgets
  angemessen erhöhen und ausschließlich geschlossene Diagnosecodes ausgeben.
## 2026-10-08 — Defensive Musterdefinitionen bleiben hashgebunden

- Kontext: Eine autorisierte Timeoutänderung verändert den Datei-Hash; der
  unveränderte Regextext im Diffkontext kann dadurch lexikalisch kritisch sein.
- Lesson: Alte Freigaben dürfen neue Bytes nicht pauschal legitimieren.
- Konsequenz: Vollständigen neuen Dateiblob separat reviewen und den vorhandenen
  exakten Kontextnachweis über einen selbst vollständig geprüften Policy-PR binden.

## 2026-10-08 — Native Scanzeit und Verwaltungsaufwand trennen

- Kontext: Identische Scanner-Eingaben ergeben auf verschiedenen Runnern eine
  zusaetzliche blockierende Klassifikation; alte Logs zeigen deren Code nicht.
- Lesson: Eine native Regex-Frist darf nicht versehentlich Initialisierung,
  Hunk-Suche und PowerShell-Verwaltung messen. Diese brauchen eigene feste Grenzen.
- Konsequenz: Native 100-ms-Regel unveraendert, separate begrenzte Enumeration und
  Trefferlimit; nur validierte blockierende Codes fuer leakfreie CI-Diagnose.
## 2026-10-08 — Scanner-Kontexte nur unveraenderlich klassifizieren

- Kontext: Harmlose vollstaendige Dateien enthalten lexikalisch kritische Signale.
- Lesson: Keine pauschale Dateityp-Ausnahme. Separater Volltextreview und exakte
  Pfad-/Modus-/Vorher-/Nachher-Blob-/Regelbindung begrenzen die Klassifikation.
- Konsequenz: HIGH-Finding und Owner-SHA-Freigabe erhalten; unbekannte Bytes,
  Metadaten, Header, strukturelle Fehler und Timeouts bleiben blockiert.
## 2026-10-08 — GitHub-Tree-Metadaten an den echten Tree-SHA binden

- Kontext: Der grosse Integrations-PR braucht den vollstaendigen Textpatch-Fallback.
- Lesson: Ein commit-ish am GitHub-Git-Tree-Endpunkt kann als Antwort-SHA wiederkehren.
- Konsequenz: Tree-SHAs aus validierter Commit-Metadatenbindung abfragen; die strikte
  Tree-Identitaetspruefung beibehalten und den Online-Adapter synthetisch regressieren.

## 2026-10-08 — Previewfreigabe muss den importierten Auftrag binden

- Auch Spieler-/Paarungsentwuerfe brauchen Turnier- und Generationsbindung.
  Kopierte Turniere duerfen dieselben Spieler-IDs besitzen; die Spieler-ID allein
  schuetzt deshalb nicht vor einem Edit im falschen Turnier. Neue Eingaben und
  Auswahlwechsel muessen alte Handler und spaete Antworten synchron entwerten.
- Backupvalidierung muss verschachtelte Pflichtobjekte vor Normalisierung,
  Auditspiegel und Persistenz pruefen. Nullable C#-Annotationen verhindern keine
  expliziten JSON-Nullwerte. Ablehnungstests vergleichen gespeicherte und
  eingehende Daten vollstaendig und pruefen unveraenderte Auditspiegelschreibungen.

- CSV-Vorschauen brauchen Turnier-, Inhalts-, Options- und Generationsbindung.
  Abort allein ist kein Beweis; Tests muessen spaete Antworten auch bei ignoriertem Abort liefern.
- Identitaet unmittelbar vor Import pruefen und synchron verbrauchen. UI-Buttonzustand
  allein verhindert weder alte Event-Closures noch wiederholte Dispatches.
- Echte KI-Ausfuehrungsfreigabe als COMMENTED Review und menschliches APPROVED/CODEOWNER
  sind getrennte Mechanismen. Den aktuellen roten Check konkret lesen, bevor eine
  enge Scanner-Bootstrap-Ausnahme beansprucht wird.

## 2026-10-07 — Abschlussreview muss echte Erfolgsbedingungen pruefen

- Kontext: Getrennter Review des konsolidierten PR-Quellstands.
- Lesson: Das load-Ereignis eines ES-Moduls kann trotz Laufzeitfehler eintreten.
  Ein unveraenderter Worker loest nach einem neuen Vite-Bundle kein Update aus.
  Abgebrochene Requests allein verhindern keine verspaeteten UI-Antworten;
  CSV-Quoting allein verhindert keine Tabellenformeln.
- Konsequenz: Browser-Smoke mit erfolgreichem dynamischem Import und negativer
  Laufzeitfehlerprobe; Worker-Fingerabdruck ueber den ganzen aktuellen Shell;
  atomare ID-/Generationsbindung auch fuer Turnierlisten; gemeinsamer CSV-Encoder
  fuer alle Journaltexte. Jede semantische Korrektur verwirft den alten READY-Status.

## 2026-10-07 — Gemeinsame Integration braucht neue Nachweise

- Kontext: Viele parallele PRs und historische lokale Integrationsstände.
- Lesson: Ein lokaler Integrationscommit, ein grüner Alt-Lauf oder eine Done-Zeile
  beweist keinen aktuellen main-Abschluss. Gemeinsame Helper, Testbefehle und
  UI-Einstiege müssen semantisch zusammengeführt werden.
- Konsequenz: Pro PR Head-SHA, Inhalt, Befunde, Tests und konkreter main-Nachweis;
  nach jeder Korrektur Tests und Review erneuern. Fremde Binärartefakte bleiben
  außerhalb einer source-only Übernahme; fehlende Geräteprüfung bleibt sichtbar.

## 2026-10-07 — Snapshots, Offline-Shells und Runtime-Profile brauchen klare Grenzen

- Kontext: Review konkurrierender Turnieränderungen, Offline-Updates und AI-Harness.
- Lesson: Validierung und Mutation müssen atomar erfolgen; geklonte Snapshots
  schützen den Store vor externen Schreibzugriffen. Offline-HTML muss zum
  vollständig installierten Asset-Slot gehören. CLI-Präsenz und Subscription-Login
  beweisen noch keinen Modellzugriff.
- Konsequenz: Deterministische konkurrierende Storetests; HTML/Bundle-Regression;
  zentraler Modellkatalog, native fensterlose Auflösung und modellfreie Auth-Gates
  mit getrennten, wahrheitsgemäßen Verifikationsstufen.
## 2026-10-07 — Statische PR-Evidenz muss vollstaendig und effizient bleiben

- Kontext: GitHub lieferte fuer eine grosse App-Verschiebung keine kompletten
  Textpatches; eine generische Regex erreichte das unveraenderte Zeitlimit.
- Lesson: Ein fehlender API-Patch ist keine fehlende Datei. Vollstaendige
  Blob-/Tree-/Hunk-Bindung kann die Evidenz ergaenzen, ohne Kandidaten auszufuehren.
  Eine pauschal kompilierte Regex kann andere Regeln verlangsamen; jede Optimierung
  braucht ihren eigenen semantischen Beweis und unveraenderte Fehlergrenzen.
- Konsequenz: Exakter Textfallback mit negativen Tests und begrenzten Prozessen;
  gezielte Engine-Optimierung, frische vertrauenswuerdige Typebindung pro Reload.
  Generierte Patches vor Anwendung komplett parsen: JavaScript-Ersetzungen mit
  Regex-Ankern benoetigen Literal-Callbacks, damit Ersetzungsmetazeichen nicht
  die Vorlage veraendern. Ein eigener Kandidat darf keine neue Runtime aktivieren.

## 2026-10-04 — Modellpflege braucht eine einzige Variantenquelle

- Kontext: Versionsvorgaben in Runtime-Policy und historischen Lauftexten drifteten auseinander.
- Lesson: Stabile Aufgabenprofile und konkrete Anbieter-IDs getrennt halten. Profilnamen
  sind keine Modellfamilien; ein effizientes Modell darf grosse Implementierung nicht herabstufen.
- Konsequenz: Ein zentraler, offiziell verifizierter Katalog; Schema-/Provider-Grenzen,
  versionsneutrale Dokumentation und ein Vertragstest fuer Updates an genau einer Stelle.
  Relative PowerShell-Pfade ueber die PowerShell-Path-API statt Prozess-CWD aufloesen.
## 2026-07-18 — Dateiinventare brauchen dieselbe Pfadnormalisierung wie der Git-Index

- Kontext: Read-only Repository-Hygiene-Audit vor der Build-Week-Integration.
- Lesson: Git liefert kanonische Pfade mit `/`, während eine Windows-Dateisysteminventur zunächst
  `\` verwendet. Ein Mengenvergleich ohne Normalisierung kann tausende getrackte Dateien
  fälschlich als ungetrackte Quellen klassifizieren, obwohl `git ls-files --others` leer ist.
- Konsequenz: Beide Pfadmengen werden vor der Klassifizierung auf `/` normalisiert; Summen werden
  zusätzlich gegen Git-untracked und Git-ignored abgeglichen. Fehlerhafte Zwischenklassifizierungen
  werden verworfen und nicht als Evidence persistiert.

## 2026-07-18 — Erwartungswerte schützen nur innerhalb einer atomaren Schreibgrenze

- Kontext: Unabhängiger Technik-Review der bestätigten Desktop-/Companion-Ergebniseingabe.
- Lesson: Ein `expectedPreviousResult` verhindert sequenziell veraltete Änderungen, ist allein aber
  kein Compare-and-Swap. Zwei parallele Requests können denselben Snapshot lesen und beide eine
  scheinbar gültige Ganzzustands-Speicherung beginnen.
- Konsequenz: Prüfung, Audit und Speichern laufen für Ergebnisänderungen unter derselben
  Store-Operation; in-memory per Lock und in SQLite per serialisierter Transaktion. Ein
  deterministisch zuvor roter Test und ein echter SQLite-Parallelitätstest verlangen genau einen
  erfolgreichen Schreiber.

## 2026-07-18 — Vollständige SHAs werden von Git aufgelöst, nie von Hand ergänzt

- Kontext: Unabhängiger Competition-Audit der Build-Week-Queue und des UX-Freeze.
- Lesson: Eine plausible manuelle Erweiterung eines kurzen Commit-SHAs kann auf einen nicht
  existierenden Commit zeigen und dennoch in mehreren Dokumenten konsistent aussehen. Formale
  40-Zeichen-Prüfung allein beweist weder Existenz noch geeignete Herkunft als Arbeitsbasis.
- Konsequenz: Dokumentierte SHAs werden mit `git rev-parse` ermittelt. Der Contributor-Generator
  prüft Commit-Existenz und erlaubt startbare Prompts nur exakt vom aktuellen `development`;
  ungemergte Feature-SHAs bleiben Planning-only.

## 2026-07-18 — Submission-Qualität entsteht durch Fokus und beweisbare Grenzen

- Kontext: OpenAI Build Week finalization, STM-FACH-012, synthetischer Jury-Pfad und
  STM-INFRA-008.
- Lesson: Eine breite Funktionsliste wird nicht automatisch zu einer verständlichen
  Produkterfahrung. Hauptaktionen brauchen eine klare Hierarchie; Expertendetails bleiben
  erreichbar, dürfen aber den Einstieg nicht dominieren. Evidence ist ebenso ein Produktteil:
  ein fehlender Browser-/Gerätetest bleibt offen und wird nicht durch Quellinspektion oder alte
  Screenshots ersetzt.
- Konsequenz: Fünf Primärbereiche, explizites synthetisches Demo-Preset, bestätigte/umkehrbare
  Ergebniswrites und progressive Tie-Break-/Pairing-Optionen. Finale visuelle und Galaxy-Evidence
  bleibt SHA-gebundene Owner-Aufgabe.

## 2026-07-18 — Öffentliche Diagnoseverträge dürfen lokale Pfade nicht voraussetzen

- Kontext: Public-Health-Härtung und vollständiger ReleaseGate.
- Lesson: Ein statischer Test, der ein absolutes Logverzeichnis im Health-JSON erwartet, schützt
  zwar Observability, koppelt sie aber fälschlich an eine öffentliche Pfadoffenlegung. Eine
  Sicherheitskorrektur muss den Testvertrag präzisieren, nicht das lokale Logging entfernen.
- Konsequenz: File-Logging, Begrenzung und Querystring-Redaktion bleiben geprüft; der öffentliche
  Vertrag meldet nur `storage = local` und Negativtests verbieten Datenbank-/Logpfadfelder.

## 2026-07-16 — FIDE-Modi brauchen Versions-, Format- und Policy-Grenzen

- Kontext: STM-FACH-001, sichere Adoption von PR #10 gegen FIDE C.07/03-2026.
- Lesson: Ein „virtueller Gegner mit eigener Punktzahl“ reicht nicht als belastbare
  FIDE-Implementierung. Seit 2026 gehören angepasste Gegnerstände, Obergrenzen und
  VUR-Streicher dazu; zugleich gilt Art. 16 für Schweizer Turniere und darf eine
  vorhandene, ausdrücklich konfigurierte Forfeit-Policy nicht still überschreiben.
- Konsequenz: Eine kanonische Buchholz-Beitragsliste trägt VUR-Metadaten bis zu
  Cut/Median, reale Gegner werden vor Dummys entschieden, offene Runden bleiben
  ausgeschlossen und nicht modellierbare Bye-Kategorien werden offen dokumentiert.

## 2026-07-16 — Pull-Request-Vertrauen ist an Herkunft und SHA gebunden

- Kontext: STM-SEC-005, unabhängiger Security-Review der statischen PR-Pipeline.
- Lesson: Ein sicher wirkender Zielpfad macht PR-Inhalt nicht vertrauenswürdig. Auch Reports,
  Ausgabepfade und Base-/Head-SHAs brauchen fail-closed Bindung; statische Freigabe ist keine
  Merge-Freigabe.
- Konsequenz: Base-SHA-Code prüft vor jeder Ausführung; T4-Dateipfade werden nie automatisch
  als erlaubter Integrationsscope übernommen; Artefakte sind SHA-/Policy-/Hash-gebunden und
  WhatIf/StaticOnly werden durch Negativtests gegen Mutationen abgesichert.

## 2026-07-15 - KFM-FLEET-CORRECTION-CODEX-SOL-FINALIZE-20260715

- Kontext: Codex-Lauf zum BAT-/CMD-Gate; der Arbeitsbaum war sauber, eine Public-History-
  Entscheidung des Owners war aber noch offen (main-only Commit `53dba48`, 2026-10-01 nach
  development übernommen).
- Lesson: Ein grüner Arbeitsbaumscan ersetzt keine offene Public-History-Entscheidung.
- Konsequenz: History-Befunde werden als eigener Owner-Blocker geführt und nicht durch einen
  sauberen Arbeitsstand als erledigt gemeldet.

## 2026-07-10 — Public-nahe Testdaten und KI-Laufprotokolle

- Kontext: Stabilisierung, Public-Gate und Runtime-Logging.
- Lesson: Auch alte Offline-Fixtures, Handoff-Texte und KI-Promptlogs koennen personenbezogene oder lokale Details in den aktuellen Arbeitsstand tragen.
- Konsequenz: Public-nahe Repos verwenden synthetische Fixtures; echte Live-IDs werden nur bewusst per Parameter oder Environment gesetzt. KI-Laufprotokolle werden vor dem Commit bereinigt.
