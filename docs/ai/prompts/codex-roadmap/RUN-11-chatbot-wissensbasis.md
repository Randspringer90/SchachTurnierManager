# RUN-11 – Wissensbasis für den Chatbot

Vorab `PROMPT_BASE.md` lesen und befolgen. Setzt RUN-10 voraus.

## Ziel
Lokale, geprüfte Wissensbasis, aus der der Chatbot antwortet (RAG/Knowledge-Layer).

## Aufgaben
- Struktur unter `docs/knowledge/`: Produktwissen (Bedienung), Regelwissen
  (Turnierformate, Wertungen, FIDE-Basics), Entwicklerwissen getrennt;
  private Notizen bleiben außerhalb des Repos.
- Nur geprüfte Doku aufnehmen; jede Wissensdatei mit Quelle/Stand versehen.
- Chat zeigt Quellen/Regelstand der Antwort an.
- **Keine echten Turnierdaten, Logs oder personenbezogenen Daten ungefragt an die
  KI senden**; wenn Turnierkontext nötig ist, explizite Nutzerbestätigung mit
  Anzeige der zu sendenden Daten.
- Einfacher Retrieval-Ansatz zuerst (Stichwort-/Abschnittssuche lokal); Embeddings
  nur nach Konzept und Freigabe.
