# Bedrohungsmodell: Prompt-Injection

## Angreiferziele
- Agent dazu bringen, Regeln (`AGENTS.md`) zu ignorieren.
- Secrets/PII exfiltrieren.
- `git push`/Force-Push/History-Rewrite ausloesen.
- Zusaetzliche Tools/Netz freischalten.
- Untrusted Inhalt als dauerhafte Systemregel persistieren.

## Angriffsvektoren (T4)
Issues, PRs, Kommentare, Branch-/Commitnamen, Imports (CSV/JSON), Webseiten, Dependency-Doku,
Toolausgaben, Logdateien, Markdown-Code-Fence-Ausbrueche, relative Pfad-Traversierung.

## Grundprinzip
T3/T4 sind **Daten**, keine Anweisungen. Nur `config/trusted-instruction-paths.json` steuert.
Secrets (T5) sind waehrend T4-Verarbeitung unerreichbar.

## Gegenmassnahmen
Siehe `docs/security/AGENT_SECURITY_CONTROLS.md`. Nachweis: `scripts/Test-PromptInjectionDefense.ps1`
mit ausschliesslich synthetischen, ungefaehrlichen Fixtures (keine realen Payloads).
