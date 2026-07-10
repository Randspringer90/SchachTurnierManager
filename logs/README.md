# logs/

Lokales Projekt-Logverzeichnis fuer Entwicklungslaeufe des SchachTurnierManagers.

- Die WebApi schreibt im Entwicklungsmodus hierhin, wenn `SchachTurnierManager:LogDirectory=logs` aktiv ist.
- Installierte Desktop-Versionen schreiben standardmaessig nach `%LocalAppData%\SchachTurnierManager\logs`.
- Portable Pakete schreiben nach `logs\` neben `Start-SchachTurnierManager.bat`.
- Logdateien selbst werden nicht committet (`*.log`, `logs/**` bleiben ignoriert).
- Diese README und `.gitkeep` bleiben als Ordneranker im Repo.

Keine Secrets, Tokens, `.npmrc`-Inhalte, echten Teilnehmerlisten oder privaten Datenbanken in Logs kopieren.
