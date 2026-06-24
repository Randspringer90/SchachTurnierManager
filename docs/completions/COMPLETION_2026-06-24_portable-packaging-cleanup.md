# Completion – Portable-Packaging-Härtung & Dirty-State-Bereinigung (2026-06-24)

## TL;DR
Der einzige unsaubere Arbeitsbaum der Fleet (`SchachTurnierManager`, Public-Sonderfall)
ist bereinigt. Der Dirty-State war ein **zusammenhängendes, fast fertiges Portable-Packaging-
Härtungspaket** plus generierte Test-Artefakte. Das Härtungspaket wurde fertiggestellt, durch
Tests, Portable-Gate und Safety-Scan validiert und **lokal committet** (`e1d9838`). Die
generierten `.trx`-Artefakte wurden per `.gitignore` aus dem Arbeitsbaum gehalten (nicht
gelöscht). **Kein Push, kein Release, kein PR.**

## Ausgangsstatus
- Branch `main`, remote-synchron mit `origin/main` bei `a6e7381` (letzter Fleet-Sync).
- Remote: `https://github.com/Randspringer90/SchachTurnierManager.git` (Public-Sonderfall).
- Dirty mit ~10 Einträgen:
  - Geändert: `CHANGELOG.md`, `Directory.AfterMicrosoftNETSdk.targets`,
    `scripts/Invoke-ReleaseGate.ps1`, `scripts/Pack-Portable.ps1`, `scripts/Start-Portable.bat`
  - Untracked (Quelle): `scripts/Test-PortablePackageGate.ps1`
  - Untracked (generiert): 4× `tests/**/TestResults/status-safety-tests.trx`

## Analyse der Änderungen
**Echte Quell-/Doku-Änderungen (zusammengehörig, in CHANGELOG/PLANS als 0.41.1 dokumentiert):**
- `Pack-Portable.ps1` – Standard jetzt framework-dependent (kein Runtime-Identifier,
  `--no-restore`, `UseAppHost=false`); `-Runtime win-x64` weiterhin für EXE/Self-contained.
  Native Schritte mit Timeout, UTF-8-Logs, seriellem Publish (`-m:1`), Retry-Löschung und
  Zeitstempel-Fallback-ZIP bei gesperrtem ZIP. Ausgabe-/Log-Pfade werden auf `output/`|`tmp/`
  begrenzt (Sicherheits-Guard).
- `Start-Portable.bat` – startet EXE **oder** DLL via `dotnet`, setzt Arbeitsordner auf `app\`
  (damit `wwwroot` gefunden wird), entfernt interaktives `pause`, Health-Timeout 45→60 s.
- `Directory.AfterMicrosoftNETSdk.targets` – deaktiviert nur das inkrementelle
  Publish-Clean-Bookkeeping, wenn `STMDisableIncrementalPublishClean=true`.
- `Invoke-ReleaseGate.ps1` – nutzt vorhandene `node_modules` (npm ci/install nur bei
  sauberem Checkout).
- `Test-PortablePackageGate.ps1` (neu) – baut ein Paket in gitignored `tmp/`, prüft Startdatei,
  DLL, eingebettetes Dashboard, leeres Datenverzeichnis, keine verbotenen/staged Privatdateien,
  räumt anschließend auf. Referenziert real existierende Skripte (`Pack-Portable.ps1`,
  `Test-GitCommitSafety.ps1`).
- `CHANGELOG.md` – dokumentiert genau diese Änderungen.

**Generierte Artefakte (NICHT committet):**
- `tests/**/TestResults/status-safety-tests.trx` – Test-Runner-Outputs vom 2026-06-23,
  enthalten lokale Maschinen-/Benutzernamen im Klartext. Waren nicht gitignored → das war
  die Lücke, die den Dirty-State mitverursacht hat.

## Ursache des Dirty-States
Ein vorheriger Codex-/Claude-Zwischenlauf hatte die Portable-Packaging-Härtung weitgehend
implementiert und in CHANGELOG/PLANS (0.41.1) dokumentiert, aber **nicht committet**. Parallel
hinterließ ein Testlauf `.trx`-Outputs, die mangels `.gitignore`-Eintrag als untracked
auftauchten. Es handelte sich also nicht um defekte oder halbfertige Arbeit, sondern um einen
abschlussreifen, nicht festgeschriebenen Zwischenstand.

## Was abgeschlossen wurde
1. `.gitignore` um `TestResults/` / `**/TestResults/` ergänzt (generierte `.trx` raus, Dateien
   auf Platte belassen – nichts gelöscht).
2. Das kohärente Härtungspaket + Gate-Skript + `.gitignore` staged und lokal committet.
3. Keine fremde Arbeit verworfen oder überschrieben.

## Tests / Checks (real ausgeführt)
| Check | Ergebnis |
|-------|----------|
| `dotnet test SchachTurnierManager.sln` | **175 bestanden, 0 Fehler** (Domain 76, Application 81, Infrastructure 17, Golden 1) |
| `Test-PortablePackageGate.ps1` (npm build + dotnet publish in tmp/) | **OK** – Paket baubar, Dashboard eingebettet, data leer, keine verbotenen Dateien, tmp aufgeräumt |
| `Test-GitCommitSafety.ps1 -Staged` | **OK** – keine verbotenen Pfade, internen Referenzen oder Credential-Muster |
| `git diff --cached --check` | **OK** – keine Whitespace-Fehler |

## Finaler Git-Status
```
## main...origin/main [ahead 1]
e1d9838 Harden portable packaging and add package gate
```
Arbeitsbaum clean (nur gitignored `.trx`/`bin`/`obj`/`output` verbleiben auf Platte).

## Lokaler Commit
Ja – `e1d9838` „Harden portable packaging and add package gate“, 7 Dateien
(+410/−26). Gemäß `AGENTS.md` („Lokale Commits sind erwünscht, wenn Build und Tests sauber
sind“) und ausdrücklichem Task-Auftrag. Commit auf `main` (kein Branch), da der Public-
Sonderfall eine lineare lokale Historie hält und der Task einen lokalen Commit ohne Push wollte.

## Warum kein Push / Release / PR
Der Task untersagt für diesen Public-/Schach-Sonderfall ausdrücklich automatisches Pushen,
Releases, PRs und Tags ohne Freigabe; zudem verlangt `PLANS.md` vor jeglicher Veröffentlichung
eine vollständige History-/Snapshot-Sicherheitsprüfung (Clean-Snapshot-Strategie). Der Stand
ist damit clean mit lokalem Commit, bereit zur Übergabe – aber bewusst **nicht** veröffentlicht.
