# Report — RUN-17 Turnierassistent im UI

## Ergebnis

Version 0.46.0 ergänzt einen ersten produktiven, lokalen Turnierassistenten in der WebApp.

## Änderungen

- Neuer Hauptreiter `Assistent`.
- Lokale Empfehlungslogik für Szenario, Format, Runden, Zeitbedarf, Bretter und Punktesystem.
- Setup-Schritte, Turniertag-Checkliste, Export-/Veröffentlichungsplan und Warnungen.
- Empfehlung kann Neuanlage und Einstellungen vorbefüllen; bestehende Turniere müssen danach bewusst gespeichert werden.
- Privacy-Hinweis: keine externen KI-Requests, keine API-Keys, keine Secrets.
- Neues Readiness-Skript `scripts/Invoke-TournamentAssistantReadiness.ps1`.

## Nicht enthalten

- Kein KI-Chatbot.
- Keine Anbieter-Adapter für OpenAI/Claude.
- Keine Offline-Ergebnis-Synchronisation.
- Keine vollständige Team-/Mannschaftslogik; Team bleibt als Planungsszenario markiert.

## Verifikation

- TypeScript-Check lokal im Container mit `npx tsc --noEmit`: OK.
- Vollständiges Windows-ReleaseGate erfolgt im nächsten Nutzerlauf über `Invoke-TournamentAssistantReadiness.ps1`.

## Nächste Schritte

- 0.46.0 lokal committen, wenn Readiness grün ist.
- Danach RUN-10/11 KI-Chatbot/Wissensbasis oder RUN-14 Wertungs-/Tie-Break-Erklärungen vertiefen.
