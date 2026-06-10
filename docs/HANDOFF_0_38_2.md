# Handoff v0.38.2 - Open-Source-Safety-Fix

## Ziel

Aktuellen Arbeitsstand fuer ein spaeteres oeffentliches Clean-Snapshot-Repository vorbereiten.

## Inhalt

- package-lock.json wird mit public npm Registry neu erzeugt.
- Interne Registry-URLs wie tfs.fwdev/eckdservice/_packaging/ITM_KFM werden blockiert.
- Dependency-Versionen im Lockfile werden nicht mehr durch App-Versionierung ueberschrieben.
- Commit-If-Green enthaelt Safety-Checks vor und nach dem Staging.
- README ist auf aktuellen Stand gebracht.

## Wichtig

Dieses private Entwicklungsrepo darf nicht automatisch oeffentlich geschaltet werden, solange die alte Git-Historie interne URLs enthaelt. Fuer Open Source wird ein Clean-Snapshot-Repo ohne alte Historie empfohlen.
