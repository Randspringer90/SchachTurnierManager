# Dependency-, Lizenz- und Supply-Chain-Baseline

Diese Datei dokumentiert die reproduzierbare Offline-Prüfung für **STM-SEC-002**.

## Ziel

`scripts/Test-DependencySupplyChainSafety.ps1` prüft ausschließlich den bereits eingecheckten Dependency-Stand. Der Check verändert keine Paketversion, führt kein Restore durch und greift nicht auf Paketregistries oder Advisory-Dienste zu.

Geprüft werden:

- zentrale, exakt gepinnte NuGet-Versionen in `Directory.Packages.props`;
- vollständige Central-Package-Management-Abdeckung aller `PackageReference`-Einträge unter `src/**` und `tests/**`;
- exakt gepinnte direkte npm-Abhängigkeiten;
- Konsistenz zwischen `package.json` und dem Root-Eintrag der `package-lock.json`;
- npm-Lockfile-Quellen ausschließlich unter `https://registry.npmjs.org/`;
- vorhandene SHA-512-Integrity-Metadaten für Registry-Tarballs;
- bekannte Lizenzwerte im Lockfile;
- Lifecycle-Skripte nur bei explizit reviewten, versionsgebundenen Baseline-Paketen.

## Aktuelle Baseline

Beim Start von STM-SEC-002 enthält der eingecheckte Stand:

- 8 zentrale NuGet-Paketversionen;
- 7 direkte npm-Abhängigkeiten;
- npm-Lizenzen aus der Menge `MIT`, `Apache-2.0`, `MPL-2.0`, `ISC`, `BSD-3-Clause`, `0BSD`;
- genau ein Lockfile-Paket mit `hasInstallScript=true`: das optionale macOS-Paket `fsevents@2.3.3` (MIT).

Die Lifecycle-Ausnahme ist absichtlich **versionsgebunden**. Eine Versions-, Lizenz- oder Optionalitätsänderung blockiert den Gate-Lauf, bis ein neuer Owner-Review erfolgt.

## Was dieser Check nicht behauptet

Der Offline-Gate ist kein Ersatz für eine aktuelle Schwachstellen- oder Herstellerbewertung. Er behauptet insbesondere nicht, dass eine Abhängigkeit frei von CVEs, kompromittierten Maintainer-Konten oder später bekannt gewordenen Supply-Chain-Problemen ist.

Vor einem Release bleibt deshalb eine getrennte aktuelle Online-Prüfung von Advisories, Deprecations und Lizenzänderungen sinnvoll. Solche Netzwerkprüfungen werden bewusst nicht automatisch aus dem Repository-Gate gestartet.

## Fail-closed-Regeln

Der Gate-Lauf schlägt unter anderem fehl bei:

- floating/range/local/git/url-basierten direkten Dependency-Angaben;
- PackageReferences ohne zentrale Version;
- unbekannter oder fehlender npm-Lizenz;
- Registry-Tarball ohne Integrity-Wert;
- npm-Tarball außerhalb der erwarteten Registry;
- neuem oder verändertem Lifecycle-Skript ohne explizite Review-Bindung.

## Integration

`scripts/Invoke-ReleaseGate.ps1` führt den Dependency-Safety-Check vor `dotnet restore` aus. Dadurch wird ein strukturell nicht freigegebener Dependency-Stand gestoppt, bevor Restore/Build Paketcode beziehen oder ausführen können.
