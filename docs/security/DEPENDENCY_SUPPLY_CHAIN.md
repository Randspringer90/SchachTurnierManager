# Dependency-, Lizenz- und Supply-Chain-Baseline

STM-SEC-002 / Issue #60 / PR #61. Dies ist ein struktureller Offline-Check, keine vollstaendige Supply-Chain- oder Lizenzfreigabe.

## Gepruefter Scope

`scripts/Test-DependencySupplyChainSafety.ps1` liest `Directory.Packages.props`, die csproj-Dateien unter `src/` und `tests/` (ohne generierte bin/obj/node_modules) sowie package.json und package-lock.json der WebApp. XML wird ohne DTD und ohne externen Resolver gelesen. Fehlende optionale XML-Attribute oder JSON-Abschnitte werden StrictMode-sicher behandelt.

Geprueft werden feste NuGet-Versionen und CPM-Zuordnung, Attribut-/Element-VersionOverride, feste direkte npm-Versionen einschliesslich optionalDependencies/peerDependencies, Root-Identitaet, installierte Direktversionen, Lockfile-Pfade, Typen, Lizenzmetadaten und Lifecycle-Skripte. npm-shrinkwrap.json wird abgewiesen, da es sonst package-lock.json uebersteuern wuerde.

Registry-URLs werden als URI geprueft: HTTPS, tatsaechlicher Host registry.npmjs.org, Standardport, kein Userinfo/Query/Fragment. Vorhandene Integrity-Werte muessen kanonische SHA-512-SRI-Werte mit einem 64-Byte-Digest sein. Dies validiert Metadaten; heruntergeladene Pakete werden NICHT gehasht oder ausgefuehrt.

## Vollstaendigkeit wird nicht erfunden

Die bestehende Lockdatei enthaelt auch Eintraege ohne resolved UND integrity. Der bisherige PR uebersprang diese still. Jetzt zaehlt der Check diese explizit und meldet `DEPENDENCY_PROVENANCE=PARTIAL`. `DEPENDENCY_STRUCTURE=PASS` bedeutet nur, dass die vorhandenen Strukturen den hier dokumentierten Regeln entsprechen.

Mit `-RequireCompleteProvenance` fuehrt jeder solche Eintrag zu einem Fehler. Einzelne fehlende Felder (nur resolved oder nur integrity) sind immer ein Fehler. Es werden keine Registry-Metadaten erfunden oder Lockfiles automatisch repariert. Der bestehende ReleaseGate-Aufruf bleibt strukturell; er erteilt keine vollstaendige Release-Herkunftsfreigabe.

## Lifecycle-Baseline

Der bereits vorhandene Fall fsevents@2.3.3 ist an Version, exakte Registry-URL, vorhandenen SHA-512-Digest, MIT-Metadatum, optional=true und ausschliesslich macOS gebunden. Das ist eine eng begrenzte, Owner-reviewpflichtige Baseline-Ausnahme und KEIN Nachweis einer unabhaengigen Pruefung des Paketcodes.

Akzeptierte Lizenz-Bezeichner sind 0BSD, Apache-2.0, BSD-3-Clause, ISC, MIT und MPL-2.0. Diese Liste ist keine juristische Freigabe und deckt weder NuGet-Lizenztexte noch Attribution/Weitergabepflichten ab.

## Tests und Grenzen

`Test-DependencySupplyChainReadiness.ps1` fuehrt 32 synthetische Positiv-/Negativfaelle gegen den echten Gate-Prozess aus. Die Fixtures werden vorher/nachher gehasht; keine Paketinstallation und kein Netzwerk. Ein xUnit-Test bindet den Lauf in das vorhandene Application-Testprojekt ein. Die synthetischen Testdateien werden nur im betriebssystemeigenen Tempverzeichnis erzeugt und wieder entfernt; der Gate selbst bleibt read-only.

Am 2026-10-01 wurden Quelltext und Testvertrag nachgeprueft. In der Chat-Ausfuehrungsumgebung fehlen PowerShell und .NET; deshalb sind Parser-, PowerShell- und xUnit-Ausfuehrung hier NOT_RUN, nicht PASS. PR bleibt Draft bis zur echten CI-/Owner-Verifikation.

Weiter offen: aktuelle Advisory-Pruefung, NuGet-Lizenzinventar, vollstaendige Registry-/Integrity-Metadaten sowie MSBuild-Auswertung importierter/nachgelagerter props/targets. Diese strukturelle Pruefung behauptet keine vollstaendige MSBuild-Sandbox.

Primaerreferenz fuer Lockfile-Felder: https://docs.npmjs.com/files/package-lock.json/ (geprueft 2026-10-01).
