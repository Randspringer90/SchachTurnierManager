# Prompt: RUN-50 DPAPI-Blob-Trim-Hotfix

Behebe den Fehler aus dem ReleaseCandidateReadiness-Lauf: `Get-LocalSecret.ps1` scheitert bei `ConvertTo-SecureString`, weil der gespeicherte DPAPI-Blob mit Whitespace/Zeilenumbruch gelesen wird.

Anforderungen:
- `Get-LocalSecret.ps1` muss serialisierte DPAPI-Dateien robust trimmen und bei leerer Datei klar abbrechen.
- `Set-LocalSecret.ps1` soll den DPAPI-Blob ohne abschliessende neue Zeile schreiben.
- `Invoke-SecretSafetyReadiness.ps1` soll leere DPAPI-Dateien frueh erkennen.
- Guard-/Unit-Tests fuer diese Schutzregeln ergaenzen.
- Version/Doku/Changelog/PROMPTS pflegen.
- Keine fachliche Turnierlogik aendern.
