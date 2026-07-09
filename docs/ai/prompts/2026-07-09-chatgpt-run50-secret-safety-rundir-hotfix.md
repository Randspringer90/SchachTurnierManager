# Prompt: RUN-50 SecretSafety/UploadZip-Hotfix

Ziel: Den Release-/Betriebsunterbau stabilisieren, nachdem der ReleaseCandidate-Orchestrator zwar ReleaseGate/Desktop/Portable/InstallerReadiness/GitSafety ausfuehrte, aber der verschachtelte SecretSafety-Lauf seinen Run-Ordner nicht korrekt in eine Variable uebernahm und `UPLOAD_ZIP=` leer ausgab.

Umsetzung:

- `Invoke-SecretSafetyReadiness.ps1` darf nicht von `New-RunLogBundle.ps1 -CreateOnly` als Host-Ausgabe abhaengen.
- `New-RunLogBundle.ps1` soll Run-/ZIP-Pfade maschinenlesbar ueber die Pipeline ausgeben.
- `Invoke-ReleaseCandidateReadiness.ps1` soll das erzeugte ZIP validieren und nie ein leeres `UPLOAD_ZIP=` schreiben.
- Unit-/Guard-Tests fuer diese Regressionspunkte ergaenzen.
- Keine fachliche Turnierlogik veraendern.
