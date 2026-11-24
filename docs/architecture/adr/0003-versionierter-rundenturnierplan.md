# ADR-0003: Versionierter, dauerhaft gespeicherter Rundenturnier-Spielplan (STM-REV-002)

- Status: angenommen (2026-11-24)

## Kontext
Früher wurde der Rundenturnier-Plan aus der aktuellen Teilnehmerliste neu berechnet. Änderungen an
Namen oder Wertungszahlen konnten dadurch spätere Runden verschieben und zu wiederholten Gegnern führen.

## Entscheidung
Beim Erzeugen der ersten Runde wird ein `RoundRobinPlan` mit Algorithmusversion und fester
Teilnehmerreihenfolge gespeichert. Neue Turniere nutzen `RoundRobin-Berger-v2` (FIDE-Handbuch C.05,
Annex 1, Berger-Tabellen; bei ungerader Zahl ist der virtuelle letzte Platz spielfrei). Altturniere
(`RoundRobin-CircleMethod`) werden nur aus eindeutiger Historie rekonstruiert und gegen alle vorhandenen
Runden geprüft; sonst Fehler `ROUND_ROBIN_HISTORY_INVALID` ohne automatische Neuplanung.

## Folgen
- Spätere Änderungen an Teilnehmerdaten beeinflussen bereits geplante Runden nicht.
- Manuell geprüft 2026-11-24: Paarungen und Farben für 4 und 6 Teilnehmer entsprechen den Berger-Tabellen.
- Offen (Produktfunktion): Startnummern werden derzeit nach Wertungszahl, dann Eingabereihenfolge vergeben;
  Auslosung oder manuelle Setzliste ist als Option nachzurüsten.
