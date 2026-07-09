# Report 2026-07-09 - RUN-08 PWA-Readiness

## Ergebnis

PWA-/Handy-Basis vorbereitet. Die WebApp erhaelt Manifest, SVG-Icons, Service Worker
und einen sichtbaren PWA-Status im Header.

## Sicherheitsentscheidung

Der Service Worker cached bewusst keine `/api/*`-Aufrufe. Damit werden Turnierdaten,
personenbezogene Teilnehmerdaten und lokale SQLite-Inhalte nicht unkontrolliert in den
Browser-Cache gespiegelt.

## Neue Pruefung

`scripts/Invoke-PwaReadiness.ps1` fuehrt ReleaseGate `-SkipPack`, Frontend-Build und
PWA-Artefaktpruefung aus. Das Ergebnis landet als Run-ZIP unter `D:\Temp`.

## Offene Punkte

- Echte Offline-Ergebnisaufnahme braucht ein Sync-/Konfliktkonzept.
- Manifest/Icons sollten spaeter optional durch finale Vereins-/Produktgrafiken ersetzt
  werden.
- Browserinstallationsdialog ist browserabhaengig und erscheint nicht in jedem Kontext.
