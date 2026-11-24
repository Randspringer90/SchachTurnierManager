# Security- und Dependencyprüfung 2026-10-28

Status: **lokaler geprüfter Kandidat; unabhängiger Review und vollständige Abnahme offen**.
Base: `d168a5a12a65dd66af18829277b7dab02c4422db`, Ziel ausschließlich `development`.
Keine Veröffentlichung, kein main-Merge, kein Produktversionsbump, keine systemweite
Softwareinstallation und kein Workstationneustart wurden vorgenommen.

## Tatsächlicher Bestand

| Komponente | Projektbindung / Verwendung | Abgrenzung |
|---|---|---|
| Produkt | 0.54.1 unverändert | Kein Release erzeugt/veröffentlicht |
| .NET SDK | 10.0.403, exakte global.json-Bindung mit latestPatch | Hersteller-ZIP SHA-512 und Microsoft-Authenticode geprüft; nur portable Testumgebung |
| .NET / ASP.NET | 10.0.14 | Im temporären selbständigen Windows-Paket laut runtimeconfig enthalten; globale SDKs separat |
| EF Core / CodePages | 10.0.14 | Exakte zentrale Paketpins, acht Projekt-Lockfiles |
| SQLitePCLRaw / SQLite | 3.0.5 / **3.54.1** | Separater nativer SQLite-Pin; wirksame Engine im echten API-Healthcheck und SQLite-Roundtrip geprüft |
| Node / npm | 24.22.2 / 11.19.1 | Am 2026-10-29 erneut geprüft; offizieller Archivhash und gültige OpenJS-Authenticode-Signatur, nur portable Projektnutzung; konsistente Root-/CI-/Manifest-/Lockbindung |
| React / Vite / TypeScript | 19.3.1 / 8.3.5 / 6.0.3 | TypeScript7.0.2 ist verfügbar, hat laut Hersteller noch keine stabile programmatische API; die bestehenden AST-/Transpile-Regressionsharnesses benötigen die JS-API von6. Kein stiller Majorwechsel oder Prüflückenersatz |
| Git / Bash | 2.56.0.windows.4 / 5.3.15 | Vollständige portable Herstellerdistribution für Git- und Bash-Gates; MinGit allein enthält kein Bash |
| PowerShell | 7.6.9 auf .NET10.0.14 | Portable signierte Herstellerdistribution; vorhandene Installation7.6.6/.NET10.0.12 bleibt unverändert |
| Firefox | 159.0 für aktuelle native Prüfungen | Geprüftes Mozilla-Archiv nur entpackt; der vorhandene Standardbrowser158.0.1 wurde nicht systemweit ersetzt |
| Windows | Server2025 Datacenter24H2, Build26100.33650 | Tatsächliche native Testplattform; kein behaupteter Windows11-/Kollegen-PC-Test |
| Android | Native Quelladaption vorhanden | Keine APK-/SDK-/Geräteabnahme aus Quelltests abgeleitet; alte Binär-Heads bleiben gesperrt |
| PHP | Im relevanten Quell-/Build-/Runtimeumfang nicht vorhanden | Inventur von1138 ursprünglichen getrackten Pfaden ohne PHP-Dateien/-Manifeste; kein PHP-Stack ausgeführt |

Die PHP2Shell-Prüfung zu den im Auftrag genannten CVE-2026-109618/109619 ist damit
für diesen geprüften Projektumfang **nicht anwendbar**. Daraus folgt keine Aussage
über beliebige andere Software der Maschine. Kein Exploit-PoC wurde ausgeführt.

## Quellen, Integrität und Lizenzen

- 36 aktive NuGet-Paketversionen sind an die acht Lockfiles und die kanonischen
  NuGet-Inhaltshashes gebunden. Alle44 tatsächlich im isolierten Cache vorhandenen
  Pakete wurden signaturgeprüft:36 App-Pakete, zwei ausgelieferte Runtimepacks,
  ein erworbenes, im App-runtimeconfig nicht aufgeführtes WindowsDesktop-Pack und
  fünf historische Cachealtstände. Cachealtstände sind keine aktiven Dependencies.
- `NuGet.Config` erlaubt ausschließlich nuget.org, verlangt Signaturprüfung und
  führt die offiziellen Repository-Signer auf. Archiv-SHA512, Cachehash,
  `.nupkg.metadata` und Lock-Inhaltshash werden unterschieden: die signaturunabhängige
  NuGet-Inhaltshashfunktion ist kein naiver Hash des ZIP-Archivs.
- npm-Lockeinträge verwenden die offizielle Registry und SHA512-Integritäten.
  Installation erfolgte ohne Lifecycle-Skripte; eigene geprüfte Prebuild-Gates
  bleiben aktiv. Der Registry-Signatur-/Provenienzcheck meldete keine fehlenden
  oder ungültigen Signaturen für den installierten Plattformumfang.
- Neue NuGet-Buildtargets, native Paketdateien und Herstellerartefakte wurden als
  Daten geprüft. Die SQLite3.54.1-Targets enthalten plattformgebundene Copy-/NativeFileReference-
  Einträge; keine Shellstarts oder ausführbaren Downloads. Anbieter- und Registry-
  Signaturen ersetzen keinen nachgewiesenen reproduzierbaren Herstellerbuild.
- Die Paket-Lizenzdeklarationen werden im zugehörigen Inventar festgehalten.
  `xunit.abstractions2.0.3` hat nur einen historischen unversionierten Lizenzlink;
  der offizielle Tag2.0.3 (`489a2b3949a9ae8587201a22a8ecfc1d791fa1f3`)
  enthält keine Root-Lizenzdatei. Diese Evidenzlücke bleibt ausdrücklich offen.
- Für das Projekt selbst existiert weiterhin keine Root-Lizenz. Die vorhandene
  [Owner-Entscheidungsvorlage](../submission/LICENSE_DECISION.md) bleibt verbindlich
  offen. Es wird keine Lizenzwahl, Contributor-Zustimmung oder rechtliche Abnahme erfunden.
  Vor externer Paketverteilung sind außerdem vollständige erforderliche Lizenz-/Notice-
  Beilagen und deren Prüfung erforderlich; temporäre lokale Testpakete sind keine Freigabe dafür.

## Befunde und Grenzen

| Schwere / Scope | Befund und Evidenz | Zustand |
|---|---|---|
| BLOCKER · CI-Vertrauenswurzel | PR-veränderbare Workflows und kontextgebundene Checks gewährleisten keine unabhängige Ausführungsaufnahme | [Vorbereitung](CI_TRUST_ROOT.md), externe Durchsetzung fehlt; keine privilegierten Trigger oder Ruleset-Ausnahme |
| MAJOR · HTTP | Im synthetischen Vorher-Lauf fremder Origin:201, beliebiger Host:200. Neue serverseitige Host-/Origin-/Clientgrenzen: echte403/400 ohne Mutation | Korrigierter Kandidat, unabhängiger Review offen |
| MAJOR · Dev-Proxy | Tatsächlicher Vite-Proxy akzeptierte eine synthetische Mutation mit gespooftem localhost-Host. Wildcard-Dev-Bindung würde diesen Weg im LAN anbieten | Vite-Konfiguration, npm-Devstart und kontrollierter Windows-Start auf127.0.0.1 gebunden; realer Listener geprüft |
| MAJOR · Hostbrowser | Standardbrowser158.0.1 liegt vor dem Sicherheitsstand159 | Nicht systemweit geändert; aktuelle Tests mit portabler159, Hostaktualisierung bleibt extern |
| MAJOR · Review | Keine tatsächlich gestarteten privaten/Claude-/lokalen Reviewer; zentrale Aufnahme lehnt die Startversuche ab | Keine erfundene unabhängige Abnahme |
| HIGH · Adoption125/129 | Statische Prüfung BLOCKED_UNVERIFIED; Persistenzmuster im Serviceworker-Testkontext | Nicht übernommen/ausgeführt; exakte Kontext-/Ownerprüfung bleibt erforderlich |
| Gehärtet · Import/Archiv | Begrenzte FIDE-TXT-Liste, atomarer Erhalt des alten Cache, striktes UTF8; Installerpfade, Links, Gerätepfade, Duplikate und Größen geprüft | Synthetische Negativfälle bestanden; Produktions-Authentizität weiter vom echten Signer abhängig |
| Gehärtet · PII/CSV | Private Fehlerreferenz statt Rohfehler; redigierte Backup-/Providerfehler; zentrale CSV-Formelneutralisierung | Regressionen bestanden; historischer Public-PII-Befund nicht aus der Git-Historie entfernt |
| Gehärtet · Nebenläufigkeit | Atomare Store-Mutationen, eingefrorener Rundenturnierplan, Queue-Epoche/Receipts, Zielspieler-Snapshot vor Feldübernahme | Backend-/SQLite- und echte Mehrfenster-/Lost-ACK-/Konfliktfälle bestanden |
| Grenze · lokale Clients | Loopbackprozesse werden als vertrauenswürdig behandelt. Die API bietet keine Isolation zwischen unterschiedlichen OS-Benutzern derselben Maschine | Bei Mehrbenutzerbetrieb gesonderte Authentisierung/Threatmodell-Abnahme erforderlich; keine unbekannten Reverseproxies davorschalten |
| Grenze · LAN | Nicht lokale API-Clients benötigen explizite Hosts, TLS und ein geschütztes Laufzeitcredential | Kein realer LAN-/TLS-/Android-Gerätetest behauptet; bisheriger anonymer HTTP-Dev-LAN-Weg ist geschlossen |
| Grenze · Host-CTL | Build33674/KB5134137 ist ein neueres bedingtes, nicht sicherheitsklassifiziertes CTL-OOB. Tatsächliche CTL-Frische ist nicht bewiesen | OS-/Truststoreentscheidung extern; kein Update oder Neustart ausgeführt |

Beim ersten portablen SDK-Erstaufruf erschien ein Hinweis auf eine Entwickler-HTTPS-
Zertifikateinrichtung. Eine tatsächliche Zertifikatstore-Differenz wurde vorher nicht
inventarisiert; bestehende Zertifikate wurden nicht entfernt, exportiert oder vertraut.
Weitere Aufrufe unterdrücken die automatische Einrichtung ausdrücklich. Dies wird
nicht als nachgewiesene unveränderte Zertifikatumgebung ausgegeben.

## Reproduzierbare Prüfungen

Vor Restore/Installation: Quellen, genaue Pins, Locks und Build-/Lifecycle-Deltas
statisch prüfen. Danach im vorhandenen Gateablauf `dotnet restore --locked-mode`,
`dotnet build`, `dotnet test`, Frontendtests/TypeScript/Vite, npm-Audit und
`npm audit signatures` sowie die bestehenden Dependency-/Repository-/Instruction-/
Prompt-Gates ausführen. Aktuelle Herstelleradvisories sind zeitgebunden und erneut
zu prüfen. Kein zweiter Scheduler und kein automatisches audit-fix--force wurden eingerichtet.

## Offizielle Quellen (abgerufen2026-10-28)

- [.NET10-Releasemetadaten](https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/10.0/releases.json), [.NET-OOB-Sicherheitsupdate](https://devblogs.microsoft.com/dotnet/dotnet-october-2026-oob-security-updates/).
- [Node-Oktober-Sicherheitsrelease](https://nodejs.org/en/blog/vulnerability/october-2026-security-releases), [Node-Supportplan](https://github.com/nodejs/Release).
- [Vite-Releases/Support](https://vite.dev/releases), [Vite-Advisories](https://github.com/vitejs/vite/security/advisories), [React-Advisories](https://github.com/facebook/react/security/advisories).
- [TypeScript7: fehlende stabile programmatische API und Koexistenz mit6](https://devblogs.microsoft.com/typescript/announcing-typescript-7-0/).
- [SQLite3.54.1](https://www.sqlite.org/releaselog/3_54_1.html), [SQLitePCLRaw-Bundleabhängigkeit](https://github.com/ericsink/SQLitePCL.raw/releases), [SQLite-Copyright](https://www.sqlite.org/copyright.html).
- [Git-for-Windows2.56.0(4)](https://github.com/git-for-windows/git/releases/tag/v2.56.0.windows.4), [PowerShell7.6.9](https://github.com/PowerShell/PowerShell/releases/tag/v7.6.9).
- [Firefox159-Sicherheitskorrekturen](https://www.mozilla.org/en-US/security/advisories/mfsa2026-118/), [Mozilla-Herstellerhashes](https://archive.mozilla.org/pub/firefox/releases/159.0/SHA512SUMS).
- [Windows-Sicherheitsbuild33650](https://support.microsoft.com/en-au/servicing/os/windows-server/2026/10/kb5126646-windows-server-2025-security-update), [bedingtes CTL-OOB33674](https://support.microsoft.com/en-au/servicing/os/windows-server/2026/10/kb5134137-windows-server-2025-update).
- [Kestrel-Sicherheitsgrenzen](https://learn.microsoft.com/aspnet/core/fundamentals/servers/kestrel/security-considerations), [NuGet-Signaturprüfung](https://learn.microsoft.com/en-us/nuget/consume-packages/installing-signed-packages).

Ergänzende aktuelle Primärprüfung:33 React-/Vite-Herstelleradvisories gegen48 externe npm-Lockpakete (49 Einträge mit Projektwurzel), kein betroffenes oder nicht auswertbares Range. Kritische React-Server-Component-Pakete sind im Lock nicht vorhanden.30 vorhandene Lizenz-/Noticetexte mit Hashes vorbereitet; vollständige Distributions-/Rechteabnahme bleibt offen, siehe [Lizenzvorbereitung](LICENSE_READINESS_2026-10-28.md).

## Fortschreibung 2026-10-29

Offizielle NuGet-Abfrage über acht Projekte und npm-Audit erneut ausgeführt: keine gemeldeten betroffenen Pakete. Das ist kein semantischer Securityreview. Node24.22.2 stammt aus dem [offiziellen Windows-Archiv](https://nodejs.org/dist/v24.22.2/node-v24.22.2-win-x64.zip), gebunden an [Herstellerprüfsummen](https://nodejs.org/dist/v24.22.2/SHASUMS256.txt) und gültige OpenJS-Authenticode-Signatur. Archiv-SHA-256: `CA1BFF5D8EAD13C9F2EA404A176DB46BD430704D5B5113734049FA365E7799E2`. [Releasehinweise](https://github.com/nodejs/node/releases/tag/v24.22.2) geprüft; kein pauschaler Majorwechsel und keine systemweite Installation. Der CI-Pfad liest jetzt die tatsächlich vorhandene Root-Datei `.node-version`; ein Kontrakttest bindet deren Existenz und Manifest-/Lock-Mindeststand. Produktversion bleibt0.54.1.

## Testwerkzeuge 2026-10-29

Offizielle [Adapterhinweise4.0.0](https://xunit.net/releases/visualstudio/4.0.0), [4.0.1](https://xunit.net/releases/visualstudio/4.0.1) und [Analyzerhinweise2.2.0](https://xunit.net/releases/analyzers/2.2.0) geprüft. Testadapter4.0.1 und Analyzer2.2.0 sind exakt gepinnt. Beide signierten Herstellerpakete wurden vor Restore statisch gelesen, danach mit den restaurierten Cachebytes und den kanonischen NuGet-Inhaltshashes verglichen. Die acht Locks ändern ausschließlich zwei Paketversionen in vier Testprojekten; keine neue Runtimeabhängigkeit. Alle1024 .NET-Tests bestanden, Build ohne Warnungen oder Fehler. Neue Analyzerhinweise wurden durch sinnvolle Audit-/Golden-Assertions und die passende Single-Überladung behoben, nicht unterdrückt.

[xUnit2.9.3](https://xunit.net/docs/nuget-packages-v2) bleibt laut Hersteller in Wartung für kritische Korrekturen. Ein Testframeworkwechsel zu v3 wird nicht aus einer Featureversionsnummer abgeleitet. Die Abstraktions-Alt-Lizenz und die Root-Lizenz bleiben offen.36 aktive App-Lockpakete, zwei ausgelieferte Frameworkpacks, ein nicht ausgeliefertes Frameworkpack und fünf historische Cacheversionen ergeben44 geprüfte Cacheversionen. Die heutige NuGet-Abfrage meldet nach dem Update keine betroffenen Pakete.
