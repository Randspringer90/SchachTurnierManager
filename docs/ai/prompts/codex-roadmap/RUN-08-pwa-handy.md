# RUN-08 – PWA / Handy-Ansicht

Vorab `PROMPT_BASE.md` lesen und befolgen.

## Ziel
Bessere Handy-Nutzung für Zuschauer, Ergebnisse und QR-Würfeln im lokalen WLAN/Hotspot.

## Aufgaben
- Responsive UI systematisch prüfen (Dashboard, Runden, Tabelle, MobileDicePage);
  konkrete Bruchstellen fixen.
- Web-App-Manifest + Icons ergänzen; Installierbarkeit („Zum Startbildschirm") testen.
- Zuschauer-Sicht abgrenzen: read-only Ansicht für Paarungen/Tabelle über LAN-URL.
- Offline-/Hotspot-Szenario dokumentieren (was geht ohne Internet, was braucht den
  Laptop im gleichen Netz).
- **Service Worker erst nach schriftlichem Konzept** (Cache-Invalidierung bei lokalen
  Turnierdaten ist riskant – Konzept zuerst als Doku in `docs/architecture/`).

## Nicht in diesem Lauf
- Kein Cloud-Sync, keine Push-Notifications.
