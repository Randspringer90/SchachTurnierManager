# STM-REV-001 – Gesamt-Review und begrenzte Korrekturen

## Ergebnis und Prüfstand

Das Review findet mehrere auch bei gewöhnlicher Bedienung erreichbare Fehler in
Ergebnisvalidierung, Backupimport, asynchronen Dialogen und fachlicher Historie.
Hinzu kommen konkrete Fehler im lokalen npm-/Agenten-Tooling. Der PR korrigiert
abgrenzbare Ursachen und ergänzt Regressionen. Die zwei zusammenhängenden
Round-Robin-Planungsfehler und die CI-Vertrauensarchitektur benötigen eigene
Folgearbeiten; eine vollständige Betriebs- oder FIDE-Freigabe wird nicht behauptet.

| Merkmal | Geprüfter Stand |
| --- | --- |
| Repository | [Randspringer90/SchachTurnierManager](https://github.com/Randspringer90/SchachTurnierManager), öffentlich |
| Ausgangsbasis | `development`, `d168a5a12a65dd66af18829277b7dab02c4422db` |
| Releasebranch beim Review | `main`, `3f7171890566d88201ac65fc23197c38d8be35a0`; identischer Dateibaum, zusätzlicher Merge-Commit |
| Produktversion | `0.54.1`; Produktversion sowie NuGet-/npm-/SDK-Pins unverändert; neuer PowerShell-Mindeststand siehe unten |
| Inventar | 1.138 getrackte Dateien in der Ausgangsbasis |
| Arbeitsbranch | `fix/STM-REV-001-project-review`, Ziel `development` |
| Pull Request | [#133](https://github.com/Randspringer90/SchachTurnierManager/pull/133), offen als Draft; Quellkorrekturen in `33a37050296f7483830ee2ffa8e2297bc88d3a5e` |
| Auftrag | Gesamtes Projekt prüfen und einen GitHub-PR erstellen |
| Ausführung | Aktuelle ChatGPT-Sitzung mit drei parallelen Fachreviews; anschließend getrennte Nachprüfung der Änderungen |
| Abnahme | Review- und Quellkorrektur, kein Release-/Merge-/Installer-Nachweis |

Der Auftrag ist im [Prompt](../prompts/20261018_0918_project_review.md)
redigiert festgehalten. Tatsächlich verfügbare Reviewinstanzen wurden verwendet;
ein Lauf über andere Modellprofile oder den projektinternen Provider-Router wird
nicht behauptet. Historische Sonderfreigaben wurden nicht übernommen.

## Architektur und Abdeckung

| Bereich | Reviewumfang und Einordnung |
| --- | --- |
| Domain | Alle 60 C#-Produktionsdateien: Modelle, Schweizer Strategien einschließlich Dutch, Round Robin, Wertungen, Rating/Heldenpokal, Import/Export, Chess960 und Diagnosen. |
| Application | Alle sechs C#-Produktionsdateien: Use Cases, Mutation, Backupvalidierung, InMemory-Snapshots, Audit und Abfragen. |
| Infrastructure / WebApi | Persistenz und SQLite-Transaktionen, externe Spielerdaten, API-Verträge/-Endpunkte, Startdiagnose, Dateilogger, lokale Konfiguration. |
| WebApp | React-Zustandsführung, Mutationen, Dialoge, Eingabe-/Antwortguards, Import/Export, Ratinganzeige, Assistent, API-Transport, PWA/Service Worker und lokale Public-Werkzeuge. |
| Mobile | Alle fünf Java-Quellen und Dokumentation der Android-Begleit-App statisch geprüft; keine APK-/Geräteabnahme. |
| Tooling / CI | Alle vier Workflows, CODEOWNERS, DoD, Routing-/Trust-/Provider-Konfiguration, aktive npm-/Commit-/Release-/Desktop-/Installer-/Nightly-Einstiege und wichtige gemeinsame Bibliotheken. Live-Ruleset von `development` gelesen. |
| Tests / Dokumentation | Vorhandene .NET-/Frontend-/Node-Suiten ausgeführt bzw. unten ausdrücklich eingeschränkt; neue Gegenbeispiele vor den Fixes. Backlog, Architektur, Sicherheits-/Betriebsregeln und offene PRs abgeglichen. |

Die Schichtung ist grundsätzlich brauchbar: Die Fachlogik liegt in Domain und
Application, SQLite speichert isolierte Snapshots mit atomaren Änderungen, und
die Oberfläche besitzt bereits Schutzmechanismen gegen veraltete Antworten.
Die gefundenen Fehler liegen häufig dort, wo ein vorhandener Schutz nur für
einige Aufrufpfade gilt oder eine formale Typprüfung eine fachliche Invariante
nicht abdeckt.

Dies ist ein risikobasierter Gesamt-Review. Historische After-Apply-Skripte wurden
inventarisiert, aber nicht erneut ausgeführt oder vollständig zeilenweise
bewertet. Die QR-Matrix und sämtliche Kataloginhalte wurden nicht neu fachlich
zertifiziert; ihre bestehenden Regressionen bleiben maßgeblich. Die Größe von
`App.tsx` ist bereits als STM-FE-015 bekannt und wird nicht als zusätzlicher
reproduzierter Fehler gezählt.

## Korrigierte Daten- und Bedienungsfehler

Die genannten Dateistellen beziehen sich auf die oben festgehaltene
Ausgangsbasis; die Testnamen und Änderungsdateien im PR zeigen den Fixstand.
P1 bedeutet vorrangige Datenintegrität, Vertraulichkeit oder Turnierfairness;
P2 bedeutet einen konkreten fachlichen oder betrieblichen Fehler. Es wurden
keine realen Turniere, Zugangsdaten oder externen Modellkonten für Repros benutzt.

| ID / Prio | Ausgangsfehler und Reproduktion | Korrektur / Nachweis |
| --- | --- | --- |
| D7 / P1 | `TournamentService.cs:675–682,1259–1297`: Ein normales Brett mit zwei Spielern akzeptiert `Bye`; dieselbe widersprüchliche Struktur wird importiert. Die UI bietet den Wert an und sperrt danach die Eingabe. | Gemeinsame Ergebnis-/Teilnehmerinvariante für Ergebniseingabe und Backupimport. Zwei-Spieler-Bretter dürfen kein Bye sein, Einspieler-Bretter müssen Bye sein. Vor Mutation ablehnen; Snapshot und Audit bleiben bei Ablehnung unverändert. UI entfernt die unzulässige Auswahl. |
| F01 / P1 | `App.tsx:1575–1594`: Export erstellen, weitere Ergebnisse erfassen, denselben alten Text importieren – sofortiger Ersatz mit `overwriteExisting=true`, ohne Entscheidung über den Datenverlust. Auch eine andere im JSON enthaltene Turnier-ID ist betroffen. | Neue Imports standardmäßig ohne Ersetzung; bestehendes Ziel mit Namen und Umfang anzeigen, ausdrücklich bestätigen und bestätigten Auftrag an Inhalt, Ziel und Generation binden. API-DTO verwendet ebenfalls standardmäßig `false`. |
| F02 / P1 | `App.tsx:1003–1029`: In A Chess960 würfeln, Dialog schließen und B wählen. Späte Antwort öffnet As Dialog unter B; erneutes Würfeln kann an B gesendet werden. | Dialog-/Anfragegeneration und Turnieridentität vor Antwort, Folgeaktion und Finalizer prüfen. Wechsel A→B→A oder Schließen entwertet alte Vorgänge; verspätete Ergebnisse öffnen keinen alten Dialog. |
| F03 / P2 | `App.tsx:736–750`: Settings für A speichern, zu B wechseln; As späte Antwort setzt die Auswahl zurück und verwirft Bs Entwurf. | Settingsoperationen erhalten eigene Generationen. Antworten ändern nicht mehr die Auswahl und überschreiben keinen neueren Entwurf. Bereits versandte zulässige Mutation an A darf abschließen. |
| F05 / P2 | `playerForms.ts:12–14`: Teilnehmeranzeige ignoriert Elo-/Rapid-Präferenz; manuelle TWZ 0 verhindert den Fallback. Anzeige und Paarungs-/Wertungsberechnung widersprechen sich. | Anzeigehelper folgt derselben Priorität positiver Werte wie `RatingProfile` und erhält die tatsächlich gewählte TWZ-Quelle. Tests für manuell, DWZ/Elo, Rapid und Null-/Nullwertfälle. |
| F06 / P2 | `tournamentAssistant.ts:33–40`: Sieben Teilnehmer ergeben sechs Rundenturnierrunden und vier benötigte Bretter. Tatsächlich sind sieben Runden und drei gleichzeitig gespielte Bretter erforderlich. | Bei ungerader Zahl n Runden, bei gerader n−1; Zeitbudget und Zahl physischer Bretter folgen derselben Planung. Gerade/ungerade Felder und Zeitgrenzen geprüft. |
| D8 / P2 | `TournamentService.cs:698–740`: Manuelle Paarungsänderung gelingt trotz `AllowManualPairingOverrides=false`. | Serverseitige Prüfung vor Mutation/Audit und entsprechende UI-Sperre. Nachträgliches Deaktivieren wird ebenfalls respektiert. |
| A1 / P2 | `SaveImportedTournament`: Ein korrektes Backup mit vorhandener ID und verweigerter Ersetzung schreibt bereits „Turnier importiert“ in den externen Auditspiegel, bevor der Store die Kollision ablehnt. | Importvorbereitung auf isoliertem Snapshot; Auditspiegel erst nach erfolgreicher Speicherung. Kollision, Storefehler, normaler Import, bewusste Ersetzung und Mirrorfehler gesondert geprüft. |

Die Importänderung ist eine bewusst strengere API-Voreinstellung. Clients, die
vorhandene Turniere ersetzen wollen, müssen dies ausdrücklich angeben. Das
JSON-Backupformat selbst ändert sich nicht. Widersprüchliche Altbackups werden
kontrolliert abgewiesen, statt ihre Partien still umzudeuten.

### Fachliche Historie und Schweizer Paarungen

| ID / Prio | Ausgangsfehler und Reproduktion | Korrektur / Nachweis |
| --- | --- | --- |
| D3 / P2 | `FideDutchColourAllocator.cs:41–43`: TPN 1 mit 0 Punkten und TPN 2 mit 1 Punkt haben gleiche Farbpräferenz; die niedrigere TPN erhält Vorrang, obwohl die Punkte höher gewichtet werden müssen. | Rangordnung für die Farbentscheidung: Punkte absteigend, danach TPN aufsteigend. Beide Aufrufreihenfolgen und die beiden betreffenden Farbregeln sind getestet. |
| D4 / P2 | `FideDutchProfileBuilder.cs:144–169`: Nach kampflosem Sieg fehlt der Downfloat. Das beeinflusst die Floatkriterien der folgenden Runden. | Weiß-/Schwarz-Forfeitsieger erhalten den Downfloat im richtigen der beiden Historienfenster; keine gespielte Farbe oder Gegnerhistorie wird erfunden. |
| D5 / P2 | `FideDutchProfileBuilder.cs:32–44,83–90`: Rückzug von B verändert As unveränderte vergangene Paarung von gleichpunktig zu Downfloat, weil Bs frühere Punkte nicht mehr akkumuliert werden. | Historische Punkte für alle Teilnehmer rekonstruieren; nur die ausgegebenen aktuellen Profile auf aktive Spieler begrenzen. |
| D6 / P2 | `HeroCupCalculator.cs:11–12,58–65`: A gewinnt gegen B. Nach Bs Rückzug verliert A diese gewertete Partie samt Erwartung und kann unter die Mindestspielzahl fallen. | Historische Gegner bleiben in der Berechnung erhalten; erst fertige Ergebniszeilen nach Aktivstatus filtern. |
| D9 / P2 | `PairingQualityAnalyzer.cs:140–175`: Auf eine kampflose Dutch-Begegnung folgt zulässig eine gespielte Partie derselben Spieler; Qualitätsbericht meldet dennoch kritische Wiederholung und zählt ungespielte Farben. | Für Dutch nur gespielte Historie zählen. Der gespeicherte Rundenalgorithmus bestimmt die Semantik, damit ein späterer Strategiewechsel alte Berichte nicht umdeutet. Bei importierten Altrunden ohne Algorithmuskennzeichnung gilt die aktuelle Turniereinstellung als Fallback. Optimal-V2 bleibt kompatibel; echte Wiederholungen werden weiterhin erkannt. |

Fachliche Grundlage: [offizielle FIDE-Dutch-Regeln, gültig ab 1. Februar 2026](https://handbook.fide.com/chapter/C0403202602),
insbesondere Art. 1.2, 1.4.3 und 5.2.4/5.2.5; gelesen/verifiziert am
18. Oktober 2026. Der vorhandene Dutch-Vertrag für ungespielte Begegnungen
folgt [C.04.2 Art. 3.4/3.5](https://handbook.fide.com/chapter/GeneralHandlingRulesForSwissTournaments202602). Die Korrekturen schreiben keine bereits ausgelosten
Partien um; künftig erzeugte Farben/Paarungen und erneut berechnete Berichte
können sich bei den betroffenen Konstellationen sachlich begründet ändern.

## Korrigiertes Tooling, Logging und Recovery

| ID / Prio | Ausgangsfehler und Reproduktion | Korrektur / Nachweis |
| --- | --- | --- |
| T01 / P1 | `Invoke-NpmSafe.ps1:86–110,144–148`: Entschlüsselte npm-Konfiguration bleibt nach Exit 0 und Exit 17 in einer gemeinsamen Klartextdatei liegen; parallele Aufrufe überschreiben denselben Pfad. | Eigener restriktiver temporärer Bereich pro Invocation und Cleanup auch bei Fehlern vor npm. Prozess-Environment und Exitcode bleiben erhalten. Verschachtelte/parallele Aufrufe und synthetische Konfigurationsfehler getestet. |
| T02 / P2 | `RoutedExecutionCommon.ps1:449–484`: Checkpoint mit anderem HEAD auf demselben Branch wird akzeptiert; nur der Branch wird verglichen. | Gespeicherten und aktuellen vollständigen HEAD sowie Git-Exitcodes prüfen. Drift und nicht auflösbarer Commit blockieren; der bestehende ausdrücklich benannte Skip-Schalter bleibt explizit. |
| T03 / P1 | `RoutedExecutionCommon.ps1:251–265`: Task-ID mit Elternpfadsegmenten besteht die Validierung; daraus abgeleitete Prompt-/Log-/Artefaktpfade verlassen den Laufbereich. | Kurze kanonische Dateinamenssyntax, Windows-Gerätenamen und Case-Kollisionen berücksichtigen; unzulässigen Graph vor Invocation/Laufanlage ablehnen. Keine fremden Pfade oder echten Provider angesprochen. |
| A2 / P1 | `BoundedFileLoggerProvider.cs:110–146`: Whitespace nach Schlüssel/Trennzeichen lässt den eigentlichen Geheimwert im Log; quotierte Schlüssel oder Werte mit Leerzeichen sind ebenfalls betroffen. | Schlüsselgrenzen, Whitespace, einfache/doppelte Quotes und escaped Quotes berücksichtigen. Reale Loggerdateien mit synthetischen Werten prüfen Nachrichten und Exceptions, mehrere Werte sowie unveränderte harmlose Felder. |
| A3 / P1 | `DatabaseStartupDiagnostics.cs:100–105`: Bedienhinweis empfiehlt das Löschen von WAL/SHM, sobald kein Prozess mehr läuft. Das ist nach einem Abbruch kein Nachweis eines abgeschlossenen Checkpoints. | Hinweis erhält WAL/SHM und empfiehlt eine gemeinsame Sicherung nach Beenden aller Instanzen. Es wird keine automatische Recovery-/Löschaktion eingeführt. |

SQLite beschreibt die WAL-Datei als Teil des persistenten Datenbankzustands:
Trennung bzw. Verlust kann bestätigte Transaktionen verlieren oder die Datenbank
beschädigen. Quelle: [SQLite Write-Ahead Logging](https://sqlite.org/wal.html),
am 18. Oktober 2026 geprüft. Deshalb ist der frühere Löschhinweis eine relevante
Datenintegritätsfrage und keine reine Textkorrektur.

Die Logredaktion schützt die genannten Schlüssel-/Wertmuster. Sie ist keine
allgemeine Geheimnis- oder Personendatenerkennung und legitimiert nicht das
absichtliche Loggen von Zugangsdaten. Der Tooling-HEAD-Check ersetzt keinen
Fingerabdruck uncommitteter Arbeitsdateien. Historische Klartextreste aus früheren
npm-Wrapper-Läufen werden nicht rückwirkend entfernt; der neue Lifecycle gilt
für neue Aufrufe. Ein erzwungener Prozess-/Hostabbruch kann `finally` verhindern.
Der Aufgabenvalidator begrenzt die
unvertrauenswürdige ID; dies ist kein vollständiger Schutz gegen eine separat
kompromittierte lokale Dateisystem-/Linkstruktur.

### Bewusste Tooling-Kompatibilitätsänderung

`Invoke-NpmSafe.ps1` verlangt jetzt ausdrücklich **PowerShell 7.3 oder neuer**.
Die sichere temporäre Verzeichniserzeugung und Rechteverwaltung verwenden
.NET-7-APIs. Die zuvor lediglich als PowerShell 7+ beschriebenen 7.0–7.2-Läufe
werden damit nicht mehr unterstützt; das Skript meldet den Mindeststand vor
Ausführung, und Onboarding/Betriebsanleitung nennen ihn. Diese Änderung ist im
Draft zur Ownerprüfung sichtbar. Die vorhandene Lösung wurde nicht um einen
ungeprüften alternativen Rechte-/Tempdateipfad erweitert. NuGet-/npm-/SDK-Pins
und Produktversion bleiben unverändert. Primärnachweis: [PowerShell 7.3 auf .NET 7](https://learn.microsoft.com/en-us/powershell/scripting/whats-new/what-s-new-in-powershell-73) und [temporäre Verzeichnisse](https://learn.microsoft.com/en-us/dotnet/api/system.io.directory.createtempsubdirectory).

## Offene Befunde mit konkreter Folgearbeit

### D1 / D2 – P1: Rundenturnier braucht einen dauerhaft festgelegten Spielplan

**D1:** Die Farbformel in `RoundRobinPairingEngine.cs:55–58` gibt bei vier
Teilnehmern einem Spieler dreimal Weiß; die anderen erhalten jeweils einmal
Weiß. Das tritt schon ohne Eingriff auf. **D2:**
`TournamentService.cs:1450–1482` erzeugt den gesamten Plan bei jeder nächsten
Runde aus den dann aktuellen Rating-/Setz-/Namenswerten. Im Repro führt eine
TWZ-Änderung nach Runde 1 zu zwei Wiederholungspaarungen in Runde 2, obwohl sich
die Teilnehmermenge nicht geändert hat.

Diese beiden Fehler werden gemeinsam als **STM-REV-002** weitergeführt. Eine
isolierte Korrektur der Farben würde bei bereits begonnenen Turnieren die
noch nicht erzeugten Runden ändern. Erforderlich sind:

1. Für neue Turniere vollständigen Plan oder unveränderliche Teilnehmerreihenfolge
   samt Algorithmusversion beim Start speichern; ausgewogene Farbverteilung,
   Gegner-Eindeutigkeit und Freilosanzahl prüfen.
2. Bestehende Turniere mit ihrer ursprünglichen Planversion fortführen. Eine
   Rekonstruktion aus Runde 1 nur gegen alle vorhandenen unveränderten Runden
   validieren; bei manuellen Eingriffen oder Mehrdeutigkeit einen ausdrücklichen
   Reparaturweg verlangen.
3. Backup-/SQLite-Roundtrip, Rating-/Namensänderungen nach Start sowie ungerade
   und gerade Teilnehmerzahlen prüfen; eingegebene Ergebnisse erhalten.

Die [offiziellen Berger-Tabellen](https://handbook.fide.com/chapter/C05Annex1)
bieten Referenzpläne. Der bestehende Algorithmus wurde in diesem PR bewusst
nicht durch einen inkompatiblen Teilfix ersetzt.

### T05 – P1: Vertrauenswurzel der PR-Ausführung unabhängig durchsetzen

Die Workflows einschließlich Inline-Ausführungsfreigabe werden durch
`pull_request` geladen. Ein Base-Checkout bindet das später aufgerufene Skript,
nicht die darüberliegende, im PR veränderbare Workflowdefinition. Daraus folgt
statisch, dass die YAML allein nicht die behauptete unmodifizierbare Vorprüfung
vor jeder PR-Ausführung garantieren kann. Es wurde kein Angriff auf GitHub
ausgeführt und keine tatsächliche Tokenoffenlegung festgestellt.

Das live gelesene [Ruleset `collab-development`](https://github.com/Randspringer90/SchachTurnierManager/rules/18830718)
ist aktiv und verlangt eine Zustimmung, Codeowner-Review, veraltete Zustimmungen
verwerfen, aufgelöste Reviewthreads und sieben Statuskontexte. Diese Kontexte
sind im gelesenen JSON nur durch Namen definiert; eine unabhängige erforderliche
Workflowdefinition war dort nicht ersichtlich. Ein vorhandener Admin-Bypass
wurde nicht benutzt. Repository-/Organisations-Einstellungen außerhalb dieses
Ruleset-Reads wurden nicht als geprüft ausgegeben.

**STM-REV-003** soll Trust-Root und serverseitige Durchsetzung festlegen. Ein
Triggerwechsel auf `pull_request_target` braucht eine eigenständige Prüfung
von Token-, Secret- und Checkoutrechten und wird nicht beiläufig vorgenommen.
Quelle: [GitHub, Events that trigger workflows](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows),
Abschnitte `pull_request` / `pull_request_target`, geprüft am 18. Oktober 2026.

### Weitere P2-Folgearbeiten

| ID | Reproduzierbarer bzw. statisch vollständig verfolgter Fehler | Ziel und Akzeptanz |
| --- | --- | --- |
| F04 | `App.tsx:385–392,497–501`: Polling erneuert Turnierrunden, aber die sechs abgeleiteten Ansichten reagieren nur auf die ausgewählte ID. Änderungen im zweiten Fenster können neue Ergebnisse neben alten Wertungen/Readiness zeigen. | Ergänzung zum bestehenden STM-UX-002: relevante Snapshotrevision invalidiert Projektionen; unveränderter Poll erhält Entwürfe; keine blinde Abfrage aller sechs Ansichten bei jedem Poll. Echter Mehrfenstertest steht aus. |
| F07 | `App.tsx:591–600,616–623`: Assistent übernimmt sechs empfohlene Runden in `settingsForm`, Neuanlage sendet jedoch fünf Standardrunden aus `emptySettingsForm`. Erfolgstext verspricht zu viel. | Ergänzung zu STM-UX-005, bestehende Zuständigkeit erhalten: separater Neuanlageentwurf und Prüfung des tatsächlichen Create-Payloads; aktuelle Turniereinstellungen nicht verdeckt mit Neuanlage koppeln. |
| T04 | `RoutedExecutionCommon.ps1:164–185`: Erfolgreicher Text über 401 Tests wird als Authfehler, über 429 Fälle als Rate-Limit interpretiert, obwohl der Prozess Exit 0 liefert. | STM-REV-004: strukturierten Prozess-/Providerstatus von Antworttext trennen. Sowohl erfolgreiche Texte mit Zahlen als auch echte Auth-/Quota-/Timeoutfehler testen. |

### Weitere Beobachtungen, keine zusätzlich behaupteten Reproduktionen

- Der Import-Auditfix ersetzt keine transaktionale Outbox: Andere Mutationstypen
  spiegeln weiterhin innerhalb ihres Updatecallbacks vor dem DB-Commit. Beim
  Import wird ein Mirrorfehler atomar am aktuellen Snapshot vermerkt; scheitert
  auch dieses Warnungsschreiben, bleibt der gespeicherte Import erfolgreich und
  die Rückgabe benennt die nicht persistierte Warnung ausdrücklich. Vollständige
  Crashkonsistenz des externen Auditspiegels ist eine eigene Architekturaufgabe.
- Desktop-Publish verwendet noch `npm install`, außerhalb der Lockhash-Prüfung
  des vorgelagerten ReleaseGate. Reproduzierbarkeit mit dem bestehenden
  `npm ci`-Vertrag vereinheitlichen und den endgültigen Lockhash prüfen.
- Lock-Erwerb der Routed-/Nightly-Einstiege erfolgt über Existenzprüfung und
  anschließendes Schreiben. Atomaren Erwerb und Prozessidentität gesondert
  prüfen; ein Parallelstart wurde hierfür nicht provoziert.
- QR-Verbindungslinks verwenden fest `http`; ein regulär unterstützter
  HTTPS-Betrieb benötigt eine passende Origin-Ableitung.
- Ein ausgelöster Browserdownload beweist noch keine gespeicherte Sicherung.
  Besonders im Android-Companion mit gesperrten Downloads ist die derzeitige
  Erfolgsmeldung zu stark; native Export-/Teilenfunktion bleibt STM-MOB-008.
- Einige Architektur-/MVP-Sätze in AGENTS sind überholt, insbesondere SQLite
  als spätere Ergänzung. Diese Instruktionsquellen werden nicht nebenbei geändert.
- Supply-Chain-Strukturprüfung findet acht exakte NuGet-Pins, aber 16 npm-
  Einträge ohne vollständige Registry-/Integrity-Provenienz: **PARTIAL** bleibt
  sichtbar. Daraus folgt keine Behauptung konkreter Paketkompromittierung.

## Offene PRs vor diesem Review

Alle folgenden PRs zielten beim Abruf auf `development`. Fremde PR-Branches
wurden nur statisch verglichen und nicht zur Ausführung übernommen.

| PR | Inhalt | Abgrenzung |
| --- | --- | --- |
| [#124](https://github.com/Randspringer90/SchachTurnierManager/pull/124) | Datenschutzfreundliche ErrorBoundary | Bestehende Arbeit; kein Duplikatfix. |
| [#125](https://github.com/Randspringer90/SchachTurnierManager/pull/125) | Ursprüngliche Offline-Recovery | Durch #129 ersetzter Vorschlag; offen vorgefunden. |
| [#126](https://github.com/Randspringer90/SchachTurnierManager/pull/126) | Formelneutrale Turnier-CSV im Backend | CSV-Befund wird dort bereits adressiert. |
| [#127](https://github.com/Randspringer90/SchachTurnierManager/pull/127) | Lokale Harness-Zuarbeit / Dokumentation | Keine Übernahme in dieses Review. |
| [#128](https://github.com/Randspringer90/SchachTurnierManager/pull/128) | Kulturunabhängiges Manifestdatum | Eigenständiger vorhandener Releasefix; als einziger dieser PRs nicht Draft. |
| [#129](https://github.com/Randspringer90/SchachTurnierManager/pull/129) | Sichere Offline-Recovery-Adoption | Kein Überschneiden der hier korrigierten App-Handler. |
| [#130](https://github.com/Randspringer90/SchachTurnierManager/pull/130) | Fallback für lokale Laufverzeichnisse | Eigenständiger Infrastrukturfix. |
| [#131](https://github.com/Randspringer90/SchachTurnierManager/pull/131) | Neutraler Backup-Parsingfehler | Gleicher App-Bereich; bei späterer Integration mit der neuen Importbestätigung zusammenführen. |
| [#132](https://github.com/Randspringer90/SchachTurnierManager/pull/132) | Lokales Assistenzprofil | Gemeinsame Bibliothek `RoutedExecutionCommon.ps1`; HEAD-/ID-Fixes bei späterer Integration erhalten. |

Mehrere Tooling-Branches enthalten bereits vorgelagerte Änderungen aus #128
bzw. #127. Diese Abhängigkeiten sind bei ihrer späteren Integration weiterhin
zu berücksichtigen. Dieser PR startet direkt von der geprüften development-Basis.

## Tests und unabhängige Nachprüfung

### Baseline und Regressionen

Die vorhandenen .NET-Suiten bestehen nach korrekter Einrichtung von PowerShell
und lokalen Test-Sockets mit **848 PASS**: Domain 625, Application 184,
Infrastructure 26, Golden 13. Die anfänglichen fehlenden PowerShell-/Socket-
Voraussetzungen werden nicht als Produktfehler gezählt.

Vor den Produktionsfixes wurden die neuen Fehler gezielt sichtbar gemacht:

- Domain/Application: 47 neue erwartete Fehler; weitere neue Positivfälle
  bestätigten erlaubtes Verhalten. Danach 52 zusätzliche Fälle grün.
- API-/Logger-/Recovery-Grenzen: 16 isolierte Tests gegen ursprüngliche DLLs,
  davon 11 erwartete Fehler und fünf Positivfälle; danach alle 16 grün gegen
  die korrigierten Produktionsdateien. Zwei im unabhängigen Review ergänzte
  Fälle für verdoppelte Quotes wurden ebenfalls zuerst rot und danach grün.
- Import-Audit-Zusatz: acht neue Fälle zuerst rot, anschließend die vollständige
  Application-Suite mit 216 Fällen grün.
- Tooling: ursprünglicher fokussierter Lauf 44 erwartete Fehler / 11 PASS;
  danach um konkrete Vorstart-/Prozessfälle erweitert und grün.
- Frontend: verzögerte Originalhandler und produktive Helper mit synthetischen
  API-/State-Stubs geprüft; weder diese Repros noch die neuen Handlertests
  werden als echte Browser-E2E-Prüfung bezeichnet.

### Finaler Quellstand

| Prüfung | Tatsächliches Ergebnis |
| --- | --- |
| .NET Restore und Release-Build | PASS; finaler Build ohne Warnungen oder Fehler |
| Domain | 653 PASS / 0 FAIL |
| Application | 216 PASS / 0 FAIL |
| Infrastructure einschließlich API-/Logger-Grenzen | 44 PASS / 0 FAIL |
| Golden | 13 PASS / 0 FAIL; bestehende Erwartungen unverändert |
| .NET insgesamt | **926 PASS / 0 FAIL** |
| Frontend `npm test` | **148 PASS / 0 FAIL**, darunter 48 neue Handler-/JSX- und sieben neue TWZ-/Planungsfälle |
| Sämtliche 49 Node-Suiten unter `tests/scripts` | **1.816 PASS / 0 FAIL / 3 SKIP**; jede Suite einzeln mit vollständigem TAP-Abschluss geprüft |
| TypeScript / Vite / Frontend-Build | PASS; enthaltene PWA-/QR-/Katalogtests nicht zusätzlich zur Node-Gesamtzahl addiert |
| Routed-Execution-Readiness | 41/41 PASS; darin Runtime-Safety mit 39 Assertions, ohne Modellaufrufe |
| Agent-Instruction-Integrity | PASS |
| Dependency-Supply-Chain-Struktur | PASS; vorhandene Herkunftslücken bleiben ausdrücklich PARTIAL |
| Staged GitCommitSafety / OpenSourceSafety / Diff-Whitespace | PASS; alle 38 geänderten Dateien explizit gestaged, keine blockierenden Funde |

Damit sind **2.890 eindeutige automatisierte Testfälle bestanden**, zusätzlich
bleiben drei Plattformfälle übersprungen. Die separaten Readiness-Assertions
werden dieser Summe nicht zugeschlagen. Die Node-Skips betreffen fehlendes JDK
für reine Companion-Verträge und zwei Windows-spezifische Integrationsfälle.
Die temporäre Prüfumgebung verwendet den gepinnten .NET SDK, eine aktuelle
PowerShell und Node; keine neuen Produktpakete wurden aufgenommen.

Ein anfänglicher Node-Gesamtlauf lieferte einen Exitcode ohne vollständiges
TAP-Ende. Er gilt ausdrücklich nicht als vollständige Abnahme. Die finale
Auswertung verlangt vollständige Ergebnisse und zählt wiederholte Fälle nicht
doppelt. Rohlogs, TRX, temporäre Reproprojekte, Tokens, Datenbanken und gebaute
Artefakte sind kein Bestandteil dieses PRs.

### Unabhängige Nachprüfung

Die Domain-/Application-Korrekturen wurden getrennt vom Implementierer gelesen;
Root prüfte zusätzlich den später ergänzten Import-/Auditpfad. Tooling wurde
von einem anderen Fachreviewer nachgeprüft. Ein zunächst verdeckter Bedarf an
PowerShell 7.3 wurde dabei als ausdrückliche Kompatibilitätsänderung in Skript
und Dokumentation aufgenommen und die 59 betroffenen Toolingtests erneut ausgeführt.

Der unabhängige Loggerreview fand verdoppelte Quotes, der unabhängige
Frontendreview einen noch gültigen Callback nach Abbruch des Chess960-
Überschreiben-Overlays. Beide wurden mit eigenen roten Gegenbeispielen,
anschließender Korrektur und erneuter unabhängiger Probe geschlossen. Die
finale Overlayprobe weist null alte Schreibaufrufe nach Abbruch und genau einen
Schreibaufruf nach einer neuen bewussten Bestätigung nach. Der Berichtsreview
präzisierte die Legacy- und PowerShell-Grenzen. Es bleibt kein offener konkreter
Blocker innerhalb der korrigierten Teilumfänge; die oben ausdrücklich offenen
Befunde bleiben davon unberührt.

## Verbleibende Abnahme und Integrationshinweise

Der PR wird als prüfbarer Draft bereitgestellt. Die projektseitige an den
aktuellen Head gebundene Owner-Ausführungsfreigabe und die erforderlichen
Remote-Checks bleiben eigenständige Voraussetzungen. Es wird weder eine
solche Freigabe selbst gesetzt noch ein vorhandener Bypass genutzt.

Der Windows-spezifische vollständige `Commit-If-Green -SkipPack`-Ablauf konnte
hier nicht als Windows-Lauf nachgewiesen werden. Die unten bzw. im PR
ausgewiesenen Einzelgates sind echte Teilnachweise, keine behauptete
Windows-Äquivalenz. Native DPAPI-/Windows-ACL-, Installer-, Signatur-,
Android-Geräte- und reale PWA-Mehrfensterabnahme bleiben offen.

Vor Übernahme sind insbesondere die neuen Importbestätigungen praktisch zu
prüfen, die unveränderten Round-Robin-P1-Funde zu berücksichtigen und bei
anschließender Übernahme von #131/#132 die gemeinsamen Dateien erneut zu
reviewen. Das bestehende JSON-Schema, die Produktversion und NuGet-/npm-/SDK-Pins
bleiben erhalten; der PowerShell-Mindeststand für NpmSafe steigt auf 7.3. Es wurde keine Freigabe zum Merge, Release oder Deployment abgeleitet.
