# ADR-0004: Lokaler Netzzugriff nur mit Schutz; Gerätekopplung ohne Dauer-Geheimnis

- Status: angenommen für den Zugriffsschutz; Gerätekopplung vorgeschlagen (2026-11-24)

## Kontext
Die API darf im Vereinsnetz nicht anonym erreichbar sein (öffentliche Hallen-WLANs). Gleichzeitig sollen
Handys Paarungen anzeigen und Ergebnisse melden. Das Backlog verlangt „keine Secrets im QR, Ablaufzeit“.

## Entscheidung
1. `LocalApiAccessGuard`: Zugriff vom eigenen Rechner (Loopback) wie bisher. Zugriff aus dem LAN nur über
   HTTPS, erlaubten Hostnamen (`SchachTurnierManager:AllowedLanHosts`) und Zugangstoken
   (`X-STM-Lan-Token`, nur als Hash im Speicher). Origin-/Fetch-Site-Prüfung gegen Cross-Site-Anfragen.
2. Vorschlag Gerätekopplung (STM-MOB-005): Der Turnierrechner zeigt einen QR-Code mit Adresse und einem
   kurzlebigen Einmalcode (z. B. 5 Minuten, einmal einlösbar). Das Gerät tauscht ihn gegen eine
   widerrufbare Sitzung mit Rolle `spectator` (nur lesen) oder `results` (Ergebnisse melden). Kein
   dauerhaftes Geheimnis im QR-Code; Widerruf und Ablauf in der Turnierleiter-Oberfläche.

## Folgen
- Standard bleibt sicher; LAN-Betrieb erfordert bewusste Einrichtung.
- Bis zur Umsetzung von Punkt 2 können Browser im LAN die API nicht ohne Konfiguration nutzen.
