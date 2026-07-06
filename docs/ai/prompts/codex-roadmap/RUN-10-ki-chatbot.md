# RUN-10 – KI-Chatbot / Turnierassistent (BYOK)

Vorab `PROMPT_BASE.md` lesen und befolgen.

## Ziel
Integrierter Chat in der App, der bei Bedienung, Turnierformaten, Regeln, Wertungen,
Exporten und Fehlermeldungen hilft.

## Architekturvorgaben
- Anbieter-Adapter-Interface (Claude, OpenAI, später weitere) im Backend;
  WebApp spricht nur die eigene API.
- **BYOK:** Nutzer trägt eigenen API-Key lokal ein; Speicherung verschlüsselt
  (Windows DPAPI) unter `%LocalAppData%\SchachTurnierManager`, nie im Repo,
  nie im Klartext-Log, nie im Backup-Export.
- Chatbot darf erklären und vorschlagen, aber **keine destruktiven Aktionen
  automatisch ausführen** (kein Lösch-/Schreibzugriff ohne explizite UI-Bestätigung).
- Ohne Key: Feature sauber deaktiviert, App voll funktionsfähig.
- Aktuelle Modell-/API-Doku der Anbieter zum Umsetzungszeitpunkt recherchieren,
  nichts aus dem Gedächtnis hartcodieren.

## Schritte
1. Konzept + API-Design in `docs/architecture/CHATBOT.md`.
2. Backend-Adapter + Key-Verwaltung + Tests (Fixtures, keine Live-Calls in Tests).
3. Chat-UI-Panel mit klarer Kennzeichnung „KI-Antwort, ohne Gewähr".
