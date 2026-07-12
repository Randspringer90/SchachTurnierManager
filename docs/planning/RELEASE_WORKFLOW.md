# Release- und Hotfix-Workflow – SchachTurnierManager

> Ergänzt [`BRANCHING_STRATEGY.md`](BRANCHING_STRATEGY.md). In diesem Bootstrap-Lauf
> wurde **kein** Release-Branch, Tag oder Release erzeugt – hier ist nur der Ablauf
> dokumentiert und über Skripte vorbereitet.

## Grundsatz

- `main` = immer der zuletzt **veröffentlichte** Release-Stand.
- `development` = laufende Entwicklung.
- Ein Release wandert `development → release/<semver> → main`, danach zurück nach `development`.

## Release-Ablauf

1. **Releasefähigkeit prüfen** – `development` ist fachlich/technisch fertig, alle Gates grün
   (`scripts/Invoke-ReleaseGate.ps1`, `scripts/Invoke-ReleaseCandidateReadiness.ps1`).
2. **Release-Branch erzeugen** – `scripts/Prepare-ReleaseBranch.ps1 -Version 1.0.0`
   (zweigt von aktuellem `development` ab). Erzeugt **noch keinen** Tag.
3. **Stabilisieren** – auf `release/1.0.0` nur:
   - Bugfixes / Release-Fixes
   - Versionsanpassungen (`package.json`, ggf. `Directory.Build.props`)
   - Dokumentation, `CHANGELOG.md` (Release-Abschnitt finalisieren)
   - **keine** neuen Features
4. **PR nach `main`** – Review durch den Owner, ReleaseGate + Security-Gate erforderlich.
5. **Merge nach `main`** – Merge-Commit.
6. **Tag setzen** – der Owner setzt bewusst `v<semver>` auf den Merge-Commit (manuell).
7. **Rückführung** – Release-Fix-Stand **zwingend** nach `development` zurückmergen, damit
   `development` alle Stabilisierungen enthält.

## Hotfix-Ablauf

1. `scripts/Prepare-HotfixBranch.ps1 -Version 1.0.1 -Name kurz-name` (von `main`).
2. Fix + Test.
3. PR nach `main`, Review, Gates.
4. Merge nach `main`, Tag `v1.0.1`.
5. **Zwingend** nach `development` zurückführen.

## Versionierung

- SemVer `MAJOR.MINOR.PATCH`.
- Der Weg zu `1.0.0` ist in [`ROADMAP_TO_1_0.md`](ROADMAP_TO_1_0.md) beschrieben.
- Definition of Done je Aufgabe: [`DEFINITION_OF_DONE.md`](DEFINITION_OF_DONE.md).

## Nicht in diesem Lauf

- Kein `release/*`-Branch erzeugt.
- Kein Tag, kein Release, kein Release Candidate veröffentlicht.
- Diese Punkte sind als Backlog-Aufgaben (Kategorie `release`) erfasst.
