# Report 2026-07-09 – Build-Fix Legacy-obj/bin nach Pull auf 0.42.0

## TL;DR

Der erste Patch stellt die rote Build-Basis wieder her, bevor neue Features umgesetzt werden.
Der Fehler `Doppeltes Attribut ... AssemblyInfo` entsteht plausibel dadurch, dass in einem
bestehenden Worktree alte `src/**/obj`-Dateien aus früheren Builds noch vorhanden sind und nach
der Umleitung der aktiven MSBuild-Ausgaben nach `tmp/dotnet-*` wieder von SDK-Compile-Globs
erfasst werden können.

## Änderungen

- `Directory.Build.props`
  - `**/bin/**` und `**/obj/**` explizit in `DefaultItemExcludes` aufgenommen.
  - Zusätzlich `DefaultItemExcludesInProjectFolder` gesetzt.
  - Kommentar zur Ursache ergänzt.
- `scripts/Clean-Generated.ps1`
  - entfernt weiterhin `dist`, `node_modules`, `logs`, `output`, `tmp`.
  - entfernt jetzt zusätzlich alte `bin`/`obj`-Ordner unter `src/` und `tests/`.
  - schreibt eine kurze Abschlusszusammenfassung.
- Version auf `0.42.1` erhöht:
  - `src/SchachTurnierManager.WebApi/Program.cs`
  - `src/SchachTurnierManager.WebApp/package.json`
  - `src/SchachTurnierManager.WebApp/package-lock.json`
- Projektlog gepflegt:
  - `PLANS.md`
  - `CHANGELOG.md`
  - `docs/ai/PROMPTS.md`
  - dieser Report und zugehöriger Prompt.

## Verifikation

In dieser Chat-Umgebung konnte das .NET-10-Release-Gate nicht vollständig ausgeführt werden.
Der Patch ist deshalb als lokaler Workstation-Patch gedacht. Erwarteter Prüfablauf:

1. Patch-Dateien einspielen.
2. `scripts/Clean-Generated.ps1` ausführen.
3. `Invoke-ReleaseGate.ps1 -SkipPack` ausführen.
4. Bei grünem Gate erst danach mit RUN-05 oder RUN-02 weitermachen.

## Risiken

- Der Patch behebt bewusst nur die rote Build-Basis und implementiert noch kein neues Feature.
- Falls nach dem Ausschluss alter `obj`/`bin`-Ordner weitere Fehler auftreten, sind diese echte
  Folgefehler im aktuellen 0.42.0-Stand und separat zu behandeln.

## Nächster Schritt

Nach grünem Gate: RUN-05 Installer-EXE lokal testen oder RUN-02 Release-Reife des MVP prüfen.
