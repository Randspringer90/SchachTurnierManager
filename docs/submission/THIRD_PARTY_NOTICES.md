# Third-party inventory and notice status

This is an evidence-oriented inventory, not a replacement for the upstream license texts and not
legal advice. Versions are taken from the committed manifests and lockfile. A final transitive
license/vulnerability review is required against the frozen candidate.

## Direct runtime/build dependencies on `development`

| Component | Version | Declared license evidence |
|---|---:|---|
| System.Text.Encoding.CodePages | 10.0.0 | MIT in cached NuGet metadata |
| Microsoft.EntityFrameworkCore | 10.0.9 | MIT in cached NuGet metadata |
| Microsoft.EntityFrameworkCore.Sqlite | 10.0.9 | MIT in cached NuGet metadata |
| SQLitePCLRaw.bundle_e_sqlite3 | 3.0.3 | Apache-2.0 in cached NuGet metadata; bundled native SQLite obligations need final package review |
| React | 19.2.7 | MIT in `package-lock.json` |
| React DOM | 19.2.7 | MIT in `package-lock.json` |
| TypeScript | 6.0.3 | Apache-2.0 in `package-lock.json` |
| Vite | 8.0.16 | MIT in `package-lock.json` |
| @vitejs/plugin-react | 6.0.2 | MIT in `package-lock.json` |
| @types/react | 19.2.17 | MIT in `package-lock.json` |
| @types/react-dom | 19.2.3 | MIT in `package-lock.json` |

## Test-only direct dependencies

- Microsoft.NET.Test.Sdk 18.0.0 — MIT in cached NuGet metadata.
- xunit 2.9.3 — Apache-2.0 in cached NuGet metadata.
- xunit.runner.visualstudio 3.1.5 — Apache-2.0 in cached NuGet metadata.
- coverlet.collector 6.0.4 — MIT in cached NuGet metadata.

## Android candidate

Android/Capacitor dependencies are not listed as final here because PR #49 is still T4,
unmerged, and behind `development`. They must be extracted statically from the exact PR head,
reviewed without running lifecycle scripts, and then regenerated after any head update. Gradle,
Capacitor, AndroidX, wrapper, icon/splash provenance, native artifacts, and transitive licenses
must be included in the final candidate notice set.

## Repository license

The repository itself currently has no root license and GitHub reports `licenseInfo = null`.
Dependency licenses do not grant a license to this project's original or contributed code. See
`LICENSE_DECISION.md`.
