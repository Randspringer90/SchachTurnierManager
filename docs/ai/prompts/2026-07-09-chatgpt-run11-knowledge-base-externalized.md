# RUN-11 Knowledge Base externalized

Ziel: Lokale Chat-Hilfe weiter ausbauen, aber sicher und wartbar halten.

Umgesetzt:

- Wissensartikel aus `main.tsx` nach `src/knowledge/localKnowledgeBase.json` ausgelagert.
- README fuer Pflege- und Datenschutzregeln ergaenzt.
- UI importiert JSON-Wissensbasis und zeigt Version/Stand an.
- Readiness-Skript prueft JSON-Struktur, Provider-Modus `local-only`, Quellen, Privacy-Hinweis und Build.

Keine externe KI, keine API-Keys, keine echten Turnierdaten.
