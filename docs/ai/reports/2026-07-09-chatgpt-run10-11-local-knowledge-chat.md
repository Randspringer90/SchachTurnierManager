# Report: RUN-10/11 lokale Chat-Hilfe und Wissensbasis

## Ergebnis

- Lokale Chat-Hilfe im Reiter **Assistent** ergaenzt.
- Wissensbasis mit Themen Turnierstart, Pairing, Tie-Breaks, Backup, QR/Handy, Import/Export und KI-Datenschutz angelegt.
- Antworten nutzen den aktuellen Turnierkontext und die Assistenten-Empfehlung.
- Schnellfragen und Chat-Export ergaenzt.
- Keine externe KI/API, keine Secrets, keine Datenuebertragung.

## Grenzen

- Noch kein Claude/OpenAI-Provider.
- Wissensbasis ist noch im Frontend-Code eingebettet; spaeter nach Markdown/JSON auslagern.
- Keine Tool-Aktionen aus dem Chat heraus.

## Verifikation

- `scripts/Invoke-KnowledgeChatReadiness.ps1` fuehrt ReleaseGate `-SkipPack`, Frontend-Build und Quelltext-Pruefungen aus.
