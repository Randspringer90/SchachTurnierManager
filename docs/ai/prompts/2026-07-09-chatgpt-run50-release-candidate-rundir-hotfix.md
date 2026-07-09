# Prompt: RUN-50 Hotfix ReleaseCandidateReadiness RunDirectory

Aufgabe: Behebe den Fehler in `scripts/Invoke-ReleaseCandidateReadiness.ps1`, bei dem `$runDirectory` innerhalb des Skripts null bleibt, obwohl `New-RunLogBundle.ps1 -CreateOnly` den Pfad in der Konsole ausgibt.

Anforderungen:

- Keine Fachlogik aendern.
- Run-Verzeichnis im Skript robust selbst erzeugen.
- `RUN_DIR=...` ausgeben.
- Bei Fehlern `FAILED.txt`, Artefaktmanifest und `UPLOAD_ZIP=...` erzeugen.
- Unit-/Guard-Test ergaenzen, damit die fehlerhafte Capture-Variante nicht zurueckkehrt.
- Version auf 0.50.1 setzen und CHANGELOG/PLANS/README aktualisieren.
