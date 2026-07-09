# Prompt: RUN-50 Release Operations, Logging und Secrets

Ziel: Den SchachTurnierManager für Kollegeninstallation, Release-Prüfung, Logging, Secret-Sicherheit und KI-Agentenarbeit stabilisieren.

Vorgaben:

- keine externen Downloads, keine Cloud-/Kostenaktionen, kein Push
- Projekt bleibt eigenständig
- lokale Secrets innerhalb `.secrets/local/`, DPAPI-verschlüsselt, gitignored
- ruhige Terminalausgabe und ein Upload-ZIP pro Run
- Unit-/Contract-Tests für neue Betriebsregeln
