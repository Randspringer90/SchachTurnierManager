# Prompt 2026-07-09 - RUN-08 PWA-Readiness

Ziel: Die SchachTurnierManager-WebApp als installierbare PWA vorbereiten, ohne
Turnierdaten unkontrolliert offline zu cachen.

Umgesetzt:

- Manifest, Icons und Service Worker ergaenzen.
- Service Worker darf `/api/*` nicht cachen.
- UI zeigt PWA-Status und Browser-Installationsdialog, falls verfuegbar.
- Readiness-Skript mit Run-ZIP unter `D:\Temp`.
- Version/Doku/Changelog/PLANS pflegen.

Nicht umgesetzt in diesem Lauf:

- Kein echtes Offline-Ergebnis-Syncing.
- Keine Cloud-/Kostenaktion.
- Keine nativen App-Stores.
