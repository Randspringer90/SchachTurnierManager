# Prompt 2026-07-09 – ChatGPT: lokale Secrets und npm-Auth härten

Auftrag aus dem Chat:

- Nach 0.42.1 ist das Release-Gate wieder grün, aber npm meldet eine Warnung zu `always-auth`.
- Prüfen, ob die sichere lokale Authentifizierung wie in anderen Projekten bereits eingebaut ist.
- Ein kleines ZIP-Paket mit den nächsten Anpassungen erstellen.
- Logging/Dokumentation sauber pflegen.
- Keine echten Secrets, keine Pushes, keine Releases und keine Kosten-/Cloud-Aktionen.

Umsetzungsidee:

- Bestehendes `secrets/README.md` respektieren, aber `.secrets/local/` als bevorzugten lokalen
  Secret-Ort ergänzen.
- npm-Aufrufe in Release-/Paketierungswegen gegen globale/userweite `.npmrc`-Altlasten isolieren.
- Lokale npmrc/DPAPI-npmrc nur aus gitignored Secret-Orten lesen, Werte nie loggen.
- CommitGuard/Gitignore/Doku entsprechend nachziehen.
