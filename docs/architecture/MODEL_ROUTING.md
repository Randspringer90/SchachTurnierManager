# Modellrouting (qualitaetsklassenbasiert)

Kein Hardcoding schnell veraltender Modellnamen. Routing ueber **Qualitaetsklassen**
(`config/agent-routing.json`): `strongest-planning`, `strongest-implementation`,
`standard-low-risk`, `local-deterministic`, `human-required`.

Konkrete Modellwahl je Provider: `config/model-routing.json` (repo-intern, self-contained).

## Regeln
- Qualitaet vor Kosten; **kein** automatischer Downgrade bei riskanten Aufgaben.
- Security, Architektur, Pairing, Tie-Breaks, Datenmigration und Release duerfen **nicht** auf ein
  kleineres Modell herabgestuft werden, nur um Tokens zu sparen.
- `securityReviewRequired`/`humanApprovalRequired` je Taskkategorie beachten.
