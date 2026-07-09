# Prompt: RUN-50 DPAPI-Pfadtrim-Hotfix

Kontext: Der ReleaseCandidateReadiness-Lauf ist bis auf SecretSafety gruen. SecretSafety scheitert beim `Get-LocalSecret.ps1`-Readback mit `Cannot convert value "\\" to type "System.Char"`.

Aufgabe:

1. `Get-LocalSecret.ps1` so korrigieren, dass relative Anzeigenpfade plattformrobust getrimmt werden.
2. Keine fachliche Turnierlogik aendern.
3. Guard-/Unit-Test gegen die fehlerhafte `[char]'\\'`-Variante ergaenzen.
4. Version, Changelog, PLANS und Prompt-Log aktualisieren.
5. Erwartung: `Invoke-ReleaseCandidateReadiness.ps1 -BuildInstaller -AllowMissingInnoSetup` erreicht `secret-safety OK` und erzeugt ein nicht-leeres `UPLOAD_ZIP=...`.
