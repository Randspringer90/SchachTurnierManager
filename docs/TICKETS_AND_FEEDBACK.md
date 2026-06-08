# Tickets und Feedback für Nutzer

## Ziel

Nutzer der veröffentlichten Version sollen Bugs melden und neue Features vorschlagen können, ohne direkt im Code arbeiten zu müssen. Für die öffentliche Version ist GitHub Issues der erste saubere Kanal.

## Workflow für v1.0

1. Nutzer öffnet die GitHub-Issues-Seite des Projekts.
2. Nutzer wählt entweder Bugreport oder Feature-Wunsch.
3. Das Formular fragt die wichtigsten Informationen strukturiert ab.
4. Der Maintainer triagiert mit Labels wie `bug`, `feature`, `needs-info`, `pairing`, `import-export`, `external-lookup`.
5. Für bestätigte Bugs oder Features wird ein Meilenstein gesetzt.

## Spätere In-App-Unterstützung

Für eine spätere Version sollte die Anwendung einen Button `Problem melden` anbieten. Dieser Button sollte keine Daten automatisch hochladen, sondern lokal ein Diagnosepaket vorbereiten und einen GitHub-Issue-Link öffnen.

Das Diagnosepaket sollte enthalten:

- App-Version
- Betriebssystem
- Datenbankpfad ohne private Dateiinhalte
- Backend-Healthcheck
- letzte Fehlermeldung im UI
- optional anonymisierte Turnierstruktur
- keine personenbezogenen Teilnehmerdaten ohne aktive Bestätigung

## Datenschutz

Bei öffentlichen Issues dürfen keine privaten Teilnehmerlisten, Telefonnummern, E-Mail-Adressen oder internen Vereinsdaten automatisch veröffentlicht werden. Nutzer müssen sensible Inhalte selbst prüfen und ggf. anonymisieren.
