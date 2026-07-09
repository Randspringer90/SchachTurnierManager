# Prompt: RUN-51 Kollegeninstallationslauf RunDirectory-/UploadZip-Hotfix

Kontext: `Invoke-ColleagueInstallReadiness.ps1` erzeugte in PowerShell `System.Object[]`-Pfade, weil die Pipeline-Ausgabe von `New-RunLogBundle.ps1` in Variablen uebernommen wurde.

Aufgabe:
- Skript robust machen, indem Run-Ordner direkt erzeugt und Upload-ZIP deterministisch aus dem Run-Ordner berechnet wird.
- `RUN_DIR=...`, `KOLLEGENPAKET=...`, `UPLOAD_ZIP=...` maschinenlesbar beibehalten.
- Guard-Test ergaenzen, der Rueckfall auf Pipeline-Capture verhindert.
- Version, Changelog, PLANS und Promptlog pflegen.
