# Dependency-, Lizenz- und Supply-Chain-Baseline

STM-SEC-002 / Issue #60 / PR #61. Dies ist ein struktureller Offline-Check, keine vollstaendige Supply-Chain- oder Lizenzfreigabe.

## Gepruefter Scope

`scripts/Test-DependencySupplyChainSafety.ps1` liest `Directory.Packages.props`, die csproj-Dateien unter `src/` und `tests/` (ohne generierte bin/obj/node_modules) sowie package.json und package-lock.json der WebApp. XML wird ohne DTD und ohne externen Resolver gelesen. Fehlende optionale XML-Attribute oder JSON-Abschnitte werden StrictMode-sicher behandelt.

Geprueft werden zentrale NuGet-Versionen und CPM-Zuordnung, Attribut-/Element-VersionOverride, feste direkte npm-Versionen einschliesslich optionalDependencies/peerDependencies, Root-Identitaet, installierte Direktversionen, Lockfile-Pfade, Typen, Lizenzmetadaten und Lifecycle-Skripte (inklusive des Root-Ereignisses `dependencies`, das npm nach jeder Aenderung an node_modules ausfuehrt). npm-shrinkwrap.json wird abgewiesen, da es sonst package-lock.json uebersteuern wuerde.

NuGet: Nur `[x.y.z]` bindet genau eine Version; ein nacktes `x.y.z` ist eine inklusive Mindestversion. Der Check akzeptiert beide Einzelversionsformen, meldet aber `DEPENDENCY_NUGET_PINNING=EXACT` oder `MINIMUM_ONLY; COUNT=n`; mit `-RequireExactNuGetPins` ist `MINIMUM_ONLY` ein Fehler. Sieben der acht zentralen Pakete sind exakt gebunden (Restore-Vergleich: identischer aufgeloester Graph). `System.Text.Encoding.CodePages` bleibt bewusst eine Mindestversion: .NET 10 liefert es mit und kuerzt das Paket (NU1510); eine exakte Range beendet dieses Kuerzen und fuegt das Paket sieben weiteren Projekten hinzu.

Registry-URLs werden als URI geprueft: HTTPS, tatsaechlicher Host registry.npmjs.org, Standardport, kein Userinfo/Query/Fragment, und der Tarball-Pfad muss exakt zu Paketname (bzw. Alias-`name`) und Version des Lockfile-Eintrags passen. Vorhandene Integrity-Werte muessen kanonische SHA-512-SRI-Werte mit einem 64-Byte-Digest sein. Jede transitive `dependencies`-Kante muss nach Nodes Suchreihenfolge auf einen Lockfile-Eintrag aufloesen (`optionalDependencies` duerfen fehlen); Versionsbereiche selbst wertet erst `npm ci` aus. Dies validiert Metadaten; heruntergeladene Pakete werden NICHT gehasht oder ausgefuehrt.

Reihenfolge: In CI laeuft der Check nach der statischen PR-Freigabe und vor `dotnet restore` (Job build-test) bzw. vor `npm ci` (Job frontend). Das ReleaseGate ruft ihn vor `dotnet restore` auf, installiert die WebApp mit `npm ci` statt `npm install`, bricht bei jeder Aenderung von package-lock.json ab und nennt PARTIAL/MINIMUM_ONLY ausdruecklich in seiner Abschlussmeldung.

## Vollstaendigkeit wird nicht erfunden

Die bestehende Lockdatei enthaelt auch Eintraege ohne resolved UND integrity. Der bisherige PR uebersprang diese still. Jetzt zaehlt der Check diese explizit und meldet `DEPENDENCY_PROVENANCE=PARTIAL`. `DEPENDENCY_STRUCTURE=PASS` bedeutet nur, dass die vorhandenen Strukturen den hier dokumentierten Regeln entsprechen.

Mit `-RequireCompleteProvenance` fuehrt jeder solche Eintrag zu einem Fehler. Einzelne fehlende Felder (nur resolved oder nur integrity) sind immer ein Fehler. Es werden keine Registry-Metadaten erfunden oder Lockfiles automatisch repariert. Der bestehende ReleaseGate-Aufruf bleibt strukturell; er erteilt keine vollstaendige Release-Herkunftsfreigabe.

## Lifecycle-Baseline

Der bereits vorhandene Fall fsevents@2.3.3 ist an Version, exakte Registry-URL, vorhandenen SHA-512-Digest, MIT-Metadatum, optional=true und ausschliesslich macOS gebunden. Das ist eine eng begrenzte, Owner-reviewpflichtige Baseline-Ausnahme und KEIN Nachweis einer unabhaengigen Pruefung des Paketcodes.

Akzeptierte Lizenz-Bezeichner sind 0BSD, Apache-2.0, BSD-3-Clause, ISC, MIT und MPL-2.0. Diese Liste ist keine juristische Freigabe und deckt weder NuGet-Lizenztexte noch Attribution/Weitergabepflichten ab.

## Tests und Grenzen

`Test-DependencySupplyChainReadiness.ps1` fuehrt 43 synthetische Positiv-/Negativfaelle gegen den echten Gate-Prozess aus (u. a. NuGet-Mindestversion sichtbar/strikt, Root-Ereignis `dependencies`, fremde Paket-/Versions-URL, unaufloesbare transitive Kante, verschachtelte/scoped/optionale Kanten). Die Fixtures werden vorher/nachher gehasht; keine Paketinstallation und kein Netzwerk. Zwei xUnit-Tests binden den synthetischen Lauf (anzahlunabhaengig) und einen Lauf gegen den echten Checkout in das Application-Testprojekt ein.

Lokal am 2026-10-01 ausgefuehrt: 43/43 synthetische Faelle PASS; echter Checkout `DEPENDENCY_STRUCTURE=PASS`, `DEPENDENCY_PROVENANCE=PARTIAL` (16 Lockfile-Eintraege ohne resolved/integrity), `DEPENDENCY_NUGET_PINNING=MINIMUM_ONLY; COUNT=1` (CodePages, siehe oben).

Lizenz-Hinweis fuer das Android-Paket (PR #49/#55): Dessen Capacitor-CLI bringt Pakete unter BlueOak-1.0.0 (glob, lru-cache, minimatch, minipass, package-json-from-dist, path-scurry, rimraf) und Unlicense (big-integer) mit. Diese Bezeichner sind nicht in der Liste oben; der Check meldet dann `UNKNOWN_LICENSE`. Ob sie zugelassen werden, ist eine Owner-Lizenzentscheidung und wird hier bewusst nicht vorweggenommen.

Weiter offen: aktuelle Advisory-Pruefung, NuGet-Lizenzinventar, vollstaendige Registry-/Integrity-Metadaten sowie MSBuild-Auswertung importierter/nachgelagerter props/targets. Diese strukturelle Pruefung behauptet keine vollstaendige MSBuild-Sandbox.

Primaerreferenz fuer Lockfile-Felder: https://docs.npmjs.com/files/package-lock.json/ (geprueft 2026-10-01).
