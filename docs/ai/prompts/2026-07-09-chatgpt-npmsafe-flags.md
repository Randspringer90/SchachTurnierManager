# Prompt 2026-07-09 – ChatGPT: NpmSafe-Flags statt dash-beginnender Argumentwerte

Auftrag:

- Terminalausgabe aus dem 0.42.5-Verifikationslauf auswerten.
- Fehler beheben: `Invoke-NpmSafe.ps1: A parameter cannot be found that matches parameter name '-fund=false'`.
- Run-Log-Bundle-Workflow beibehalten.
- Keine fachliche Turnierlogik aendern.
- Logging/Dokumentation/Version sauber fortschreiben.

Vorgehen:

- npm-Flags nicht mehr als dash-beginnende Werte an `-NpmArguments` uebergeben.
- Stattdessen explizite Schalter `-NoAudit` und `-NoFund` in `Invoke-NpmSafe.ps1` ergaenzen.
- ReleaseGate, Portable- und Desktop-Publish auf diese Schalter umstellen.
