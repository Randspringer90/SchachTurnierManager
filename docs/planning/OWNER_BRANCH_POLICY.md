# STM-INFRA-007 - Owner-Paketbranches

Issue #62 / PR #63. Vorgeschlagene Ergaenzung der kanonischen BRANCHING_STRATEGY.md; wirksam erst nach freigegebener Integration.

Eigenstaendige Owner-Pakete koennen `owner/STM-<BEREICH>-<NNN>-<slug>` nutzen, zum Beispiel `owner/STM-INFRA-007-branch-policy`. Bereich: Grossbuchstaben; Nummer: drei Ziffern; Slug: Kleinbuchstaben/Ziffern mit einzelnen Bindestrichen. Ziel ist ausschliesslich development.

Rueckwaertskompatibilitaet: Bereits normgerecht benannte Owner-Pakete unter feature/, fix/, security/, docs/ und refactor/ mit demselben exakten STM-ID-/Slug-Schema duerfen ebenfalls in die Owner-Ausfuehrungspruefung gelangen. So muss etwa PR #65 nicht nur fuer einen anderen Branchnamen geschlossen und neu angelegt werden. Freie/nicht normgerechte Namen erhalten keinen Sonderpfad.

Der Owner-Ausfuehrungspfad verlangt weiterhin OWNER-Autor und Head im kanonischen Repository. Contributors und Forks erhalten dadurch keine Sonderrechte. Der normale nicht privilegierte Feature-Branch-Weg bleibt unveraendert. `integration/pr-<nr>-safe-adoption` bleibt fuer echte, statisch gepruefte Contributor-Adoptionen reserviert.

Ein zulaessiger Branchname ist KEINE Ausfuehrungsfreigabe. Die drei Gate-Workflows verlangen weiterhin den exakten Head-SHA, den Repository-Owner und dessen passenden Review. BLOCKED_UNVERIFIED bleibt immer gesperrt; Base-SHA-Checkout und read-only Permissions bleiben erhalten. Keine automatische Review-Erzeugung, kein Auto-Merge.

Fehlt das statische Skript im Base-Stand, ist ausschliesslich der exakt benannte historische Bootstrap-Branch mit passendem SHA-Review zulaessig. Owner-Paket- und Integrationsbranches duerfen diese Ausnahme nicht verwenden. Die erweiterten Tests fuehren die echten PowerShell-Approval-Funktionen mit synthetischen gh-Antworten aus; keine Netzwerk- oder Credential-Verwendung.

Tests: `node --test tests/scripts/owner-branch-policy.test.mjs tests/scripts/owner-execution-approval.test.mjs`. Lokal 78/78 PASS: 30 Bash-/Quellvertraege und 48 synthetische Pruefungen der echten PowerShell-Workflowfunktionen. Geprueft werden unter anderem Owner-/Fork-Identitaet, aktueller SHA, exakter Marker, fehlende oder abgelehnte Reviews, ungueltiges JSON, die eng begrenzte Bootstrap-Ausnahme und die unveraenderte BLOCKED_UNVERIFIED-Sperre. Die Fixtures verwenden keine Credentials oder Netzwerkaufrufe. CRLF-Normalisierung vor der Bash-Extraktion macht den Test auf Windows und Linux identisch. CI fuehrt beide Suites erst nach bestehender statischer Freigabe aus.

Der PR loest das Namensproblem. Er beseitigt nicht die absichtlich fehlenden Owner-Reviews bei PR #57, #59 oder #61. Vor Merge bleiben Owner-/CODEOWNERS-Review, alle Projekt-Gates und Synchronisierung der kanonischen Backlog-/Changelog-Dokumentation erforderlich.
