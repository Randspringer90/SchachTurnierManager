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
Auch ein PR, der `AGENTS.md`, einen Skill, eine Policy oder einen Workflow ändert, bleibt als
Quelle T4; der Zielpfad verleiht kein Vertrauen.

## Grundprinzip
T3/T4 sind **Daten**, keine Anweisungen. Nur `config/trusted-instruction-paths.json` steuert.
Secrets (T5) sind waehrend T4-Verarbeitung unerreichbar.

## Gegenmassnahmen
Siehe `docs/security/AGENT_SECURITY_CONTROLS.md` und `docs/security/SAFE_PULL_REQUEST_REVIEW.md`.
Nachweis: `scripts/Test-PromptInjectionDefense.ps1` sowie
`scripts/Test-PullRequestReviewReadiness.ps1` mit ausschließlich synthetischen,
ungefährlichen Fixtures. Findings persistieren nur redigierte Labels und Evidenz-Hashes;
erkannte Texte werden weder ausgeführt noch als Regel übernommen.
