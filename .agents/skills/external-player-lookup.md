# Skill: Externe Spielerdaten-Anbindung

## Ziel

Spielerinformationen aus externen Schachquellen in den SchachTurnierManager übernehmen.

## Quellen

- FIDE: FIDE-ID-Direktabruf und später Namenssuche/Downloadcache.
- DSB/DeWIS/DWZ: bevorzugt offizielle API/Wertungsportal, danach Download/Spielersuche.
- ThSB: zunächst über DSB-Verband-/Vereinsfilter abbilden, keine eigene API annehmen, solange nicht belegt.

## Regeln

- Keine Zugangsdaten oder Tokens committen.
- Live-Webzugriffe in Tests vermeiden; statische Fixtures verwenden.
- Treffer immer als Vorschau anzeigen, nicht automatisch lokale Spieler überschreiben.
- Mehrdeutige Namen müssen mehrere Kandidaten liefern.
- Jeder importierte Wert braucht Quellangabe und Abrufzeitpunkt.
- Bei fragilen HTML-Quellen Adapter kapseln und Fehler weich behandeln.

## Akzeptanzkriterien für die erste Implementierung

- Suche nach FIDE-ID liefert einen Kandidaten oder eine klare Fehlermeldung.
- Namenssuche ist providerübergreifend vorbereitet.
- UI kann Suchergebnis in das Teilnehmerformular übernehmen.
- Tests prüfen Mapping und Fehlerfälle ohne Internet.

## Stand 0.10.0

- FIDE-ID-Lookup ist technisch aktiv (`/api/external-players/search?source=0&query=<FIDE-ID>`).
- Treffer können im Dashboard in das Teilnehmerformular übernommen werden.
- DSB/DeWIS und ThSB sind als Provider registriert und liefern bewusst eine Unsupported-Antwort, bis der offizielle API-/Registrierungsweg geklärt ist.
- Keine inoffiziellen Scraper für DSB/ThSB ohne erneute Prüfung und explizite Entscheidung.
