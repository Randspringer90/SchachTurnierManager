# Externe Spielerdaten-Anbindung

Ziel: Spielerinformationen direkt aus FIDE, DSB/DWZ und Thüringen/ThSB-Kontext übernehmen, ohne Turnierleiter zu manueller Doppeleingabe zu zwingen.

## Quellenstrategie

### FIDE

- Primärer Einzelabruf über FIDE-ID, z. B. `https://ratings.fide.com/profile/{fideId}`.
- FIDE-Profilseiten enthalten Name, Standard/Rapid/Blitz-Rating, FIDE-ID, Federation, Geburtsjahr, Geschlecht und Titel.
- Für Namenssuche ist zuerst zu prüfen, ob FIDE eine stabile öffentliche Schnittstelle oder ein erlaubtes Downloadformat anbietet. FIDE bietet auf der Ratings-Seite Suche und Downloadbereiche an; automatisiertes Scraping muss zurückhaltend und cache-freundlich bleiben.

### DSB / DeWIS / DWZ

- DSB beschreibt die DWZ-Datenbank als Echtzeitabfrage gegen DeWIS mit Cache auf dem DSB-Server.
- Offizielle Suchpfade: Spieler, Verein, Verband und Turnier.
- Zusätzlich sind eine API sowie eine Registrierung für den Zugriff auf die DWZ-Schnittstelle verlinkt. Für echte Produktivnutzung soll bevorzugt die offizielle API bzw. das Wertungsportal verwendet werden.

### ThSB

- Der Thüringer Schachbund hat nach aktueller Recherche keine separat erkennbare öffentliche Spieler-API.
- ThSB-Spielerdaten sollten daher zuerst über DSB/DeWIS mit Verbands-/Vereinsfilter Thüringen abgebildet werden.
- Später können zusätzliche ThSB-spezifische Links oder Downloads ergänzt werden, falls der Verband eine stabile Quelle anbietet.

## Zielmodell im SchachTurnierManager

Geplant ist ein neutraler `PlayerLookupResult`, der in einen lokalen `Player` übernommen werden kann:

- Quelle: FIDE, DSB, ThSB/DSB
- Name
- Verein/Club
- Verband/Federation
- Land
- Geburtsjahr
- Geschlecht
- FIDE-ID
- Nationale ID / DSB-ID
- Elo Standard/Rapid/Blitz
- DWZ und DWZ-Index
- Titel
- Quell-URL
- Abrufzeitpunkt
- Warnungen/Unsicherheiten

## Datenschutz und Qualität

- Nur öffentlich abrufbare bzw. autorisierte Schnittstellen nutzen.
- Ergebnisse nicht automatisch blind übernehmen; immer Vorschau und Bestätigung im UI.
- Mehrdeutige Namenssuche muss mehrere Treffer zeigen.
- Lokal gecachte Daten mit Abrufzeitpunkt anzeigen.
- Kein Token, API-Key oder Zugangsdaten im Repository speichern.

## Umsetzungsschritte

1. Domain-Modelle für Suchanfragen und Suchergebnisse.
2. Provider-Interface `IPlayerLookupProvider`.
3. FIDE-ID-Direktabruf als erster realer Provider.
4. DSB/DWZ-Provider über offizielle Schnittstelle bzw. konfigurierbare API-Basis.
5. ThSB als DSB-Verband-/Vereinsfilter, solange keine eigene API vorhanden ist.
6. Dashboard-Suche mit Ergebnisvorschau und Button "als Teilnehmer übernehmen".
7. Tests mit statischen HTML-/JSON-Fixtures statt Live-Netzwerk.
