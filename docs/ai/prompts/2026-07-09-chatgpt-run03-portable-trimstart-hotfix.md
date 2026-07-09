# Prompt: RUN-03 Portable-Manifest TrimStart-Hotfix

Kontext: RUN-03 baut ReleaseGate und Portable-Paket erfolgreich, bricht danach aber in
`scripts/Invoke-PortableFreshFolderTest.ps1` bei der Manifest-Auflistung ab:
`Cannot convert argument trimChars ... for TrimStart to type System.Char`.

Aufgabe:
- Korrigiere nur die PowerShell-Pfadlogik im Portable-Fresh-Folder-Test.
- Verwende robuste `char[]`-Trimmzeichen und Pfadsegment-Zaehlung.
- Keine fachliche Turnier-, Pairing-, Persistenz- oder UI-Logik aendern.
- Version/Doku/Prompt-/Report-Log sauber pflegen.
- Terminalausgabe bleibt ruhig; Details ins Run-ZIP.
