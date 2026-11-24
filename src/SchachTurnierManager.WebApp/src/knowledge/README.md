# Lokale Wissensbasis

Diese Dateien versorgen die lokale Chat-Hilfe im Reiter **Assistent**. Der Inhalt ist bewusst statisch, lokal und quellennah gepflegt.

Regeln:

- Keine echten Turnierdaten, Logs, API-Keys, Tokens oder privaten Notizen eintragen.
- Jeder Artikel enthält kurze `sources`, damit Antworten nachvollziehbar bleiben.
- Externe KI/Provider dürfen diese Daten später nur nach ausdrücklicher BYOK-/Datenschutzentscheidung verwenden.
- `/api/*` und echte Turnierdaten bleiben getrennt von dieser Wissensbasis.

Aktive Datei: `localKnowledgeBase.json`.

DE/EN werden getrennt in `localKnowledgeBase.json` und `localKnowledgeBase.en.json`
gepflegt. Themen-IDs und Quellenreferenzen bleiben gleich; deutsch und englisch
formulierte Fragen sind auch nach einem Sprachwechsel zuordenbar. Noch nicht
übersetzte Vorschau-Sprachen verwenden den englischen Wissensfallback. Antworten,
Quellenversion und Datenschutztext werden lokal ausgewählt; es gibt keinen
Provideraufruf. Bisherige Chatantworten und noch nicht gesendete Eingaben werden bei
Sprachwechsel nicht umgeschrieben.

Stand 2026-10-29: Hinweise zur tatsächlich aktiven Ergebnisqueue (maximal 200 Einträge,
Serverbestätigung und manuelle Konfliktprüfung) sowie zu blockiertem Standard-LAN
und nötiger TLS-/Geräteabnahme sind mit dem Implementierungsstand abgeglichen.
Ein Wissensdaten-Versionswechsel ist kein Produktversionsbump.
