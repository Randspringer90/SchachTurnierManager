# Laufender Integrationsbericht – 2026-10-28 / Fortschreibung 2026-10-29

**LOKALER KANDIDAT GEPRÜFT; EXTERNE GATES OFFEN; kein vollständiger Produktabschluss, kein unabhängiges READY.** Base und HEAD bleiben
`d168a5a12a65dd66af18829277b7dab02c4422db`; eigener Integrationsbranch
`integration/pr-133-safe-adoption`, Ziel zunächst development; Owner beauftragte am2026-10-29 zusätzlich die geschützte Quellintegration nach main. Veröffentlichung/Versionsbump bleiben nicht freigegeben. Änderungen
sind noch uncommittet. Der abschließende Quellnachweis bindet die konkreten Dateien.

## Umfang und Zustand

- 93 Aufgabenzeilen,91 eindeutige Leaves,57 v1; zwei Rollups ausgeschlossen.
  Historische31 Abnahmen getrennt erhalten;0 aktuelle vollständige Neuabnahmen.
- Letzter belegter allgemeiner DoD-Meilenstein14/19 (73,7 Prozent), ungewichtet.
  Das ist kein gewichteter Produktfertigstellungsgrad.
- Alle97Refs inventarisiert. Acht lokale attributierte Adoptionskandidaten aus
  #124/#126/#127/#128/#130/#131/#132/#133; kein fremder Head geändert.
  #125/#129 bleiben statisch BLOCKED_UNVERIFIED und wurden nicht ausgeführt.
- Persistenter versionierter Rundenturnierplan, alle Legacyrunden geprüft,
  gerade/ungerade Felder und SQLite-/Backup-/Neustartfälle; kontrollierter Audit-
  und Mehrdeutigkeitshinweis einschließlich doppelter Legacyerstrunde.
- Strukturierter Toolstatus statt Zahlensuche in erfolgreichem Text; Datenschutz,
  generische Backup-Parsefehler und zentrale CSV-Formelneutralisierung.
- Getrennte Create-Einstellungen, realer Create-Payload und Same-Tournament-
  Aktualisierung aller sechs Projektionen bei erhaltenen ungespeicherten Eingaben.
  Wiederholung fehlgeschlagener Lesevorgänge über vorhandenes Polling oder sichtbare
  Wiederholung nach echtem Browser-RED ergänzt; kein zusätzlicher Scheduler.
- Dauerhafte Ergebnisqueue mit SQLite-Epoche/Receipts, Replay, Idempotenz,
  Lost-ACK-Behandlung, sichtbaren Konflikten und Mehrfensterfällen.
- Lokale FIDE-Namenssuche aus ausdrücklich geladener offizieller TXT-Liste;
  begrenzter atomarer Cache, explizite Feldübernahme und Stale-Snapshot-Schutz.
- Host-/Origin-/LAN-Grenzen und geschlossener anonymer Devproxy; realer LAN-
  Betrieb verlangt konfigurierte Hosts, TLS und geschützten Zugang.
- Installation/Deinstallation auf Besitz/Pfade/Archive begrenzt. Keine neue
  Veröffentlichung, kein Setup-Release und keine Produktversionsänderung.

## Sprachen und Browser

Ownerkorrektur2026-10-29: ausschließlich Deutsch/Englisch erforderlich. DE/EN je538 Schlüssel, lokale Hilfethemen und Operator-/QR-Pfade erweitert. Die elf neu erzeugten zusätzlichen Katalogentwürfe sind vollständig aus dem Kandidaten entfernt und lokal gesichert. Ihre erweiterten Browserläufe sind kein aktueller DoD-Nachweis des reduzierten Kandidaten. Die vorhandenen16 Vorschaukataloge begründen keine zusätzliche Pflichtarbeit. Aktuelle Neuprüfung: DE/EN je538 Schlüssel, Frontend173, TypeScript/Vite und35 echte Firefox159-Operatorprüfungen bestanden. Verbleibende Produkt-/Fehlertexte und unabhängiger Review sind gesondert offen.

84 Domain-/Application-Codes, drei zusätzliche direkte API-Codes und vier bestehende FIDE-/Stale-Codes sind über strukturierte Metadaten angebunden. Originale Exceptiontypen, deutsche Details und HTTP-Status bleiben erhalten. Der Erfolgsmeldungsfehler wurde im echten Browser zuerst reproduziert und korrigiert. Kein unabhängiges READY aus Eigenprüfung.

## Verifikation und Bestand

- .NET1026 PASS: Domain683, Application256, Infrastructure74, Golden13.
  Aktuell mit Adapter4.0.1 und Analyzer2.2.0; Build0 Warnungen/0 Fehler.
- Frontend173 PASS; TypeScript/Vite grün. Aktuell Operator35 plus Validierung5 nativ in Firefox159: erfolgreicher Save auf Englisch, echter Stale-Client-Fehler, gespeicherte Runden/Ergebnisse/Audit unverändert und ungespeicherter Entwurf erhalten.
- Breite Node-Suite auf dem aktuellen DE/EN-/Regelfehler-/Bedientextstand erneut
 1916 PASS/4 SKIP nach allen aktuellen Quelländerungen; keine Wiederholungen zu neuen Fällen addiert.
- Weitere native Scopebelege: Strategie/Restore27, FIDE24, Offline41,
  Hauptablauf54, Paket-API14 und Projektionserholung5. Wiederholungen werden
  nicht zu zusätzlichen Produktfällen aufsummiert.
- Native endliche Lastmessung20/100/200 mit zwei Runden und SQLite3.54.1,
  Export/Neustart.200er-Zweitrunde12533ms, Peak176992256Bytes; keine erfundene SLA.
- Isolierte selbständige Windows-Klickinstallation samt Healthcheck/Deinstallation
  bestanden. Kein Kollegen-PC-, Geräte-, Setup-EXE-, Signatur- oder Release-PASS.
- Routed-Readiness20 aufeinanderfolgende Läufe mit je53/53;14 Eingabehashes
  nach den neuesten Änderungen erneut unverändert. Synthetische Adapter sind
  keine tatsächlichen Workerläufe.
- .NET SDK10.0.403/Runtime10.0.14, Node24.22.2/npm11.19.1, React19.3.1,
  Vite8.3.5, TypeScript6.0.3, SQLite3.54.1; portable Git2.56.0(4),
  PowerShell7.6.9 und Firefox159 geprüft. Keine systemweite Installation.
- 36 aktive NuGet-Pakete,44 Cacheversionen mit Signatur-/Quellen-/Hashbelegen:
 36 App-Lockpakete, zwei ausgelieferte und ein nicht ausgeliefertes Frameworkpack,
 fünf historische Cacheversionen. Testadapter4.0.1/Analyzer2.2.0 vor Restore
 statisch/signaturgeprüft; restaurierte Archive bytegleich, kanonische Hashes
 passen zu Metadaten und Locks. Nur zwei Versionswechsel in vier Testprojekten.
 xUnit2.9.3 bleibt laut Hersteller in Wartung für kritische Korrekturen.
- Nach dem Testwerkzeugupdate: offizielle NuGet-Abfrage über acht Projekte ohne
  gemeldete betroffene Pakete; npm zuvor null bekannte Schwachstellen.48 externe
  npm-Lockpakete,23 aktuell installiert, keine fremden Install-Lifecycles ausgeführt.
  Kein PHP im geprüften Projektumfang; keine Aussage über Nachbarprojekte.

## Offene Gates und Ownership

Der unveränderte zentrale BAT-Fleet-Hook hat den tatsächlichen Commitversuch
abgewiesen. Die neueste read-only Prüfung mit der vollständigen35er-Registry
scheitert weiterhin an einem Reparse-Pfad. STM-only-MATCH ersetzt keine Freigabe.
Push-URL-Sperre bleibt aktiv; kein Commit, Push, Merge oder finaler Remote-CI-Lauf.

Aktuelle CORE-KI-Aufnahme: Private-Task6730d924-319b-db76-7ee5-0e1df78f6a60 und Claude-Task0715c35a-81b3-4efc-2708-f8065d2c1fa9 sind über die offiziellen Headless-Routen angenommen. Die Runstores melden RUNNING, aber resultVerified=False und providerTurnCompleted=UNKNOWN; noch kein abschließend belegter zusätzlicher Providerlauf oder unabhängiger Reviewabschluss. Der aktuelle lokale Startversuch liefert WINDOWS_AGENT_UNAVAILABLE ohne Task-ID; zuvor war das vorhandene warme Modell als fremd verwaltet und nicht zugelassen ausgewiesen. Kein direkter Provider-/Modellaufruf oder fremder Modellzugriff. Koordination und konkrete Reviewpakete wurden über den vorhandenen Bus angefragt; Antwort offen.

Unabhängiger Source-/Security-/Schach-/Sprachreview, Owner/CODEOWNER,
unabhängige CI-Ausführungsaufnahme, branchbezogene Recoveryfreigabe, echte Geräte-
und Kollegenprüfung, Signaturbetrieb und historische Public-PII-/Lizenzentscheidungen
bleiben offen. Die exklusive Contributor-Aufgabe zur begründeten Ergebniskorrektur
wurde nicht übernommen; reproduzierte Alt/Neu-/Grundlücke separat vorbereitet.

Die115-Skriptmigration ist als konkreter Patch vorbereitet, nach Änderungen am
nativen Operator-Test aber wieder veraltet. Vor jeder Aktivierung neu erzeugen,
prüfen und Owner-/Trustroot-/Aufruferreview einholen; bisher keine Aktivierung.

Prompt: [redigierter Auftrag](../prompts/20261028_0815_safe-dod-integration.md).
Matrix: [vollständige Zustände](../../planning/DOD_MATRIX_2026-10-28.json).
Security: [Bestand und Herstellerquellen](../../security/SECURITY_AND_DEPENDENCIES_2026-10-28.md).

## Restgates und sichere Fortsetzung

- Bestehende zentrale Commitidentität/Registry muss durch den zuständigen Plattformowner korrigiert oder freigegeben werden; vollständige35er-Registry scheitert weiterhin am Reparse-Pfad. Pushsperre bleibt verbindlich. Keine Hook-/Registrymutation aus diesem Projekt.
- CORE-KI muss die gebundene Work-Sitzung, die beiden angenommenen Reviewjobs und deren tatsächliche terminale Ergebnisse klären. Alte Reviewpakete sind nach den Regelfehler-/Bedientextänderungen veraltet; endgültigen Quellhash neu reviewen. Lokales Modell bleibt fremd verwaltet und nicht zugelassen. Kein direkter Providerstart oder fremder Modellzugriff.
- Unabhängiger exakter Security-/Schach-/Quell-/DE/EN-Review und erforderlicher Owner/CODEOWNER-Review fehlen. #125/#129 verlangen gesonderte, konkrete SHA-/Dateifreigabe nach Auflösung der statischen Befunde.
- STM-REV-003 benötigt tatsächlich unabhängige Plattform-Ausführungsaufnahme. Vorbereitete Regeln sind kein aktiviertes Gate. Skriptmigration bleibt bis Owner-/Trustroot-/Aufruferreview ein lokaler, statisch geprüfter Patch.
- Contributor-Aufgabe STM-FACH-007 benötigt ausdrückliche Zuständigkeitsklärung bzw. Contributor-Umsetzung; reproduzierbare Akzeptanzfälle liegen vor. Lizenz-/historische Public-PII-Entscheidungen, reale Signierung und Kollegen-/Geräteabnahme benötigen die zuständigen Personen bzw. Geräte. Release und Produktversionsbump bleiben nicht freigegeben.
- Nach Gateklärung: Host, physischen Checkout, Remote, Prozesse und neuesten Checkpoint neu prüfen; eigenen Dirty-State erhalten; Base-/Head-/Policydrift neu reviewen. Betroffene Änderungen und Tests abschließen. Commit ausschließlich über die echten Projekt-/Hookgates, normalen eigenen Push und PR nach development. Finale CI an genau diesem Head verfolgen; anschließend regulärer release/0.54.1-Quell-PR nach main. Keine Branchlöschung, kein Tag/Release/Deployment.

NEXT_EXACT_STEP=INSPECT:EXTERNAL_GATES:COREKI_SESSION_JOB_PROOF_AND_CENTRAL_FLEET_IDENTITY

Kein Quota-/Resetzeitpunkt ist gemeldet. Technische Aufnahme-/Identitätsfehler sind keine Quotenpause; kein laufender Resume-Scheduler wird behauptet.
