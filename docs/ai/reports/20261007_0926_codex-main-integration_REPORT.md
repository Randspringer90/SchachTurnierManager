# PR-Konsolidierung und KI-Harness: gepruefter Quellstand

Owner-Auftrag vom 2026-10-07. Dieses Laufprotokoll beschreibt die lokale
Quellstand-Konsolidierung vor den geschuetzten GitHub-Merges. Es behauptet weder
einen Main-Merge noch eine menschliche CODEOWNER-Freigabe. Der tatsaechliche
Abschluss, finale SHA-Nachweise und das Cleanup-Gate werden im lokalen Ergebnis-ZIP
festgehalten.

## Umfang und Herkunft

- 37 urspruenglich offene PRs live mit vollstaendiger Pagination und kompletten
  Dateilisten inventarisiert. Zusaetzlich entstanden die eigenen Integrations-
  und Scanner-Fix-PRs #114/#115; die finale Livezahl steht im Ergebnis-ZIP.
- Base: `abecd00c93d8c651f362d8ef3f0098200fe385ba`, identisch fuer
  `origin/development` und `origin/main` beim letzten Fetch.
- Eigener Integrationsbranch vom aktuellen development im kanonischen Hauptcheckout.
  Historische lokale Quellstaende separat inventarisiert und selektiv konsolidiert.
- Fremde PR-Metadaten und Patches bleiben Daten. Statische Befunde wurden vor
  lokaler Adaption dokumentiert; fremde Branches wurden nicht ungeprueft ausgefuehrt.
- Jede sinnvolle PR-Aenderung wird angepasst uebernommen. Keine Schliessung ohne
  konkreten vollstaendigen Main-Inhaltsnachweis; siehe `PR_INTEGRATION_MATRIX.md`.

## Semantische Korrekturen

Turnierzustand und Audit-Snapshots werden isoliert; Mutation und Loesch-Audit
erfolgen atomar. SQLite-Pruefungen benutzen unabhaengige Kontexte und erfassen
Race Conditions sowie fehlgeschlagene Mutationen ohne Teilzustand.

FIDE-Dutch ergaenzt C8 und korrigiert wiederholte MDP-Punktdifferenzen,
Exchange-Reihenfolge und GUID-Identitaet. Die Suche verwendet konservative
Untergrenzen erst gegen vollstaendige zulaessige Loesungen und behaelt alle
produktiven Zeit-/Ressourcenlimits. Budgetabbruch liefert keine Teilpaarung.
Die zeitmessende Lasttestklasse laeuft ohne konkurrierende Domain-Collections;
keine Testdaten, Assertions oder Limits wurden abgeschwaecht.

UI-Einstiege und Testkommandos wurden additiv konsolidiert. Kataloge erhalten
alle Sprachen. Fehlgeschlagene lokale Sprachpersistenz verliert die aktuelle
Auswahl nicht durch alte Events. Der Offline-Shell bleibt innerhalb seiner
installierten Generation konsistent. API-Abbruch und das laengere fachliche
Paarungsbudget sind aufeinander abgestimmt.

Der getrennte erste Gesamt-Review erfasste alle 445 damaligen geaenderten Dateien
und verlangte fuenf wesentliche Korrekturen. Der PWA-Build bindet jetzt die Bytes
des Workers an den vollstaendigen aktuellen HTML-/Bundle-/Public-Ressourcenstand,
damit Bundle-Aenderungen das regulaere Browser-Update ausloesen. Audit-CSV schuetzt
auch Namen, Akteure, Begruendungen und Details vor Tabellenformeln; JSON bleibt
verlustfrei. Sechs abgeleitete Turnieransichten werden atomar an Auswahl,
Requestgeneration und Abort-Signal gebunden. Auch eine alte Turnierlisten-Antwort
kann eine neuere Liste oder Loeschung nicht rueckgaengig machen. Der FIDE-Detailbacklog
behauptet keine vollstaendige Abnahme mehr. Der Browser-Smoke wartet auf echte
Modulauswertung; ein synthetischer Laufzeitfehler reproduziert die zuvor falsche
Erfolgswertung durch das reine load-Ereignis. Ein zusaetzlicher Importbefund ist
ebenfalls behoben: null-Runden werden vor Sortierung abgewiesen, ohne den vorhandenen
Turnierzustand zu veraendern. Zwei Regressionen zeigten zuvor die NullReferenceException.
Alle betroffenen Tests wurden erneut ausgefuehrt; der alte Review-Status gilt
nicht fuer diesen korrigierten Stand. Der erneute unabhaengige Gesamt-Review
pruefte alle 453 geaenderten Dateien und gab den Tree
`f82417ed6fe932cc7f23820870c0d30df1eb72f3` mit READY frei. Der danach gepruefte
Carrier-Commit ist `9cdff65e2ff8911a577846564fa664779dad2599`.

GitHub-CI prueft PR-Code mit dem vertrauenswuerdigen development-Basisstand.
Dieser kann zwei fehlende grosse Textpatches nicht vervollstaendigen und zeigt
timingabhaengige Musterbefunde. Der kleine vorgeschaltete Fix #115 rekonstruiert
Textnachweise aus verifizierten Blobs und haelt die bisherigen Sicherheitslimits
ein. Dessen eigener finaler Review steht auf READY fuer Tree
`87fcdfed77ba1e0ccf32e30bfd461a5187c2f0cd`; Commit
`1bf337c377226e291ed01e6af105179b06c4a52a` wurde normal gepusht. Ein gefundener
Standardaufruf-/Scratch-Fehler wurde zuvor behoben und erneut geprueft.
Der beste Gesamtquellstand wird im bestehenden Carrier zusammengefuehrt und
braucht seinen eigenen erneuten Gate- und Abschlussreview. Weder der Fix noch
die lokale Zusammenfuehrung ersetzt development-/Main- oder Owner-Freigaben.

Release-Trust bindet Signaturen an unabhaengig vorgegebene Signer,
Dateigrenzen und den vollstaendigen Paketinhalt. ZIP-Groessen, Central-/Local-Header,
Deskriptoren, Ueberlappungen und ungebundene Dateien werden begrenzt und geprueft.
Die Quellstandpruefung erzeugt keine Produktpakete; die tatsaechliche vollstaendige
Artefaktpruefung bleibt ein ausdruecklicher Release-Modus.

Android wurde als eigenstaendiger nativer Companion-Quellstand adaptiert.
Private Zieladressen werden validiert und gegen DNS-Wechsel gepinnt; WebView und
HTTP arbeiten ohne TLS-Ausnahmen, JavaScript-Bruecke oder externe Navigation.
Lifecycle, Budget, Nutzlast und asynchrone Antworten sind begrenzt. APK-, SDK-
und Geraeteabnahme bleiben unbewiesen; reine Java-Vertraege ersetzen sie nicht.

## KI-Harness und Routing

Vorhandenes dynamisches Routing ueber logische Qualitaetsprofile wurde erhalten
und verbessert. Modellvarianten stehen ausschliesslich im zentralen Katalog,
am 2026-10-07 anhand offizieller Quellen verifiziert. Native CLI-Aufloesung,
Read-only-Werkzeuge, Planmodus, MCP-Grenze und High-Effort sind explizit.
Umgebungs-Overrides werden nur anhand ihrer Namen vor einem Subprozess auf HOLD
gesetzt. CLI-Verfuegbarkeit, Subscription-Authentifizierung und tatsaechliche
Modellverfuegbarkeit sind getrennte Nachweise. Keine kostenpflichtigen Modellproben,
kein stiller Profilwechsel und kein automatischer Fallback.

Das oeffentliche Codex-Beispiel verwendet dokumentierte TOML-Schluessel und liegt
in der Architektur-Dokumentation. Lokale Codex-Konfiguration wird nicht publiziert;
Git-Freigaben bleiben bei Projektregeln, Guards und GitHub-Schutz.

Die Sitzung verwendet das vorhandene CoreKI-Startprofil. Die installierte
Exchange-Schnittstelle wurde auf ausdruecklichen Owner-Wunsch lesend abgefragt:
Status, Peers und Inbox erfolgreich, Inbox leer, kein Providerturn/Prozess gestartet.
Der Owner benannte anschliessend den bestehenden lokalen Dateibus. Dort wurde
eine eigene STM-Inbox mit echter Codex-Prozess-ID und Startzeit registriert und
eine Koordinationsnachricht an den aktiven Plattformauftrag geschrieben und
rueckgelesen. Schreibbesitz, Teststand und die Bitte um Abstimmung vor beruehrenden
Runtime-/Agenten-/Profilaktivierungen sind dokumentiert. Fremde Registrierungen
wurden nicht ueberschrieben. Lesende Plattformmetadaten stellen keinen Modellwechsel dar.
Der Plattformagent bestaetigte die Abstimmung per Dateibus: Setup-/Uninstall-Pilot
bereits ausschliesslich in eigenen isolierten Testroots, kein Austausch des
produktiven Agenten und kein Signal an fremde Sitzungen. Kuenftige beruehrende
Schritte werden vorab abgestimmt; ein kurzes vereinbartes Wartefenster ist erlaubt,
ein unerwarteter Abbruch dieser Sitzung nicht.
Eine spaetere begrenzte Dateisystem-Owner-Reparatur wurde ebenfalls vorab abgestimmt;
der Plattformagent meldete danach unveraenderte Zugriffsregeln, Konfigurationshashes
und Prozessidentitaeten sowie keine Provideruebernahme. Es wurde kein Wartefenster
angefordert und kein produktiver Agent neu gestartet.
Keine externe Plattform-Pflichtabhaengigkeit wurde in STM eingefuehrt.

## Bisherige aktuelle Validierung

- Domain: 625 PASS; Application nach Importkorrektur: 139 PASS;
  Infrastructure: 26 PASS; Golden: 13 PASS.
- Node: 1755 PASS, 0 FAIL, 3 vorhandene SKIP. Frontend nach Review-Korrekturen:
  78 PASS; TypeScript/Vite PASS. Der vollstaendige Carrier-Commit-Guard bestand;
  der nachfolgend um den Scanner-Fix ergaenzte Gesamtstand wird erneut geprueft.
- Neue Review-Regressionen: PWA 79 PASS, Audit-CSV 13 PASS, Turnierprojektion
  inklusive Auswahllogik und verspaeteter Liste 17 PASS, Snapshot-/Import-Fokus 5 PASS.
- FIDE-Fokus: 43 PASS. Android: 113 reine Java-Assertions PASS.
- Release-Signatur-/ZIP-Vertraege: 59 synthetische Assertions PASS.
- Runtime-Grenzen: 39 Assertions PASS, Modellaufrufe 0.
- Smoke-Prozessbesitz: 28 synthetische Assertions PASS; echte Hintergrundprozess-
  Regression: 23 Assertions PASS, Windows-Konsole geprueft.
- Firefox-Dialoge nach Review-Korrekturen: 20 PASS; vorheriger vollstaendiger Turnierablauf: 54 PASS, inklusive
  Anwendungsneustart, Ergebnisfluss und 72 sicheren Klicks. Browser bleiben headless.
- Zusaetzlicher Browser-Einstiegstest nach korrigierter Modulauswertungspruefung:
  53 PASS fuer alle 15 konsolidierten Werkzeuge, ihre echten ES-Module,
  das Aus-/Einblenden des Sichtschutzes und die negative Laufzeitfehlerprobe.
  Das ist ein Start-Smoke; die fachlichen Werkzeug-Vertraege bleiben separat.
- Sechzehn Repository-/Security-Gates bestanden auf dem finalen Carrier-Tree
  f82417ed. Fuer den nachfolgenden kombinierten Stand bleiben erneute relevante
  Gates und ein getrennter Abschlussreview vor Commit verbindlich.
- Zusaetzliche AllHistory-Pruefung: Altlastenbefund; saemtliche 23 betroffenen
  Commits bereits in der vorhandenen Main-Historie. Kein History-Rewrite.
  Der normale aktuelle Quellstand-Safety-Gate ist davon getrennt.

## Verbleibende Abschluss-Gates

Der finale Gesamtstand wird vor Commit getrennt read-only geprueft und nur bei
READY ueber den Commit-Guard committet. Danach erfolgen normaler Push, exakte
Remote-SHA-Pruefung, regulaerer PR nach development und dessen tatsaechliche
CI-/Owner-Freigaben. Main verlangt den regulaeren Release-/Hotfix-PR-Weg.
Fehlende menschliche Freigaben werden konkret als BLOCKED dokumentiert.

Backlog-Fortschritt zaehlt eindeutige Aufgaben und Akzeptanz-/DoD-Nachweise;
PR-Anzahl und vorhandene Quelltexte allein gelten nicht als Fertigstellung.
Historische Checkouts bleiben bis zum vollstaendigen Main-, Redundanz- und
Prozessnachweis erhalten. Keine Power-Aktion, kein fremdes Nachbarprojektzugriff
und keine Produktartefakt-Aktualisierung.
