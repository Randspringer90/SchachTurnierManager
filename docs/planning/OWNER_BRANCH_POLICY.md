# STM-INFRA-007 - Owner-Paketbranches

Issue #62. Vorgeschlagene Ergaenzung der kanonischen BRANCHING_STRATEGY.md; wirksam erst nach freigegebener Integration.

Eigenstaendige Owner-Pakete nutzen `owner/STM-<BEREICH>-<NNN>-<slug>`, zum Beispiel `owner/STM-INFRA-007-branch-policy`. Bereich: Grossbuchstaben; Nummer: drei Ziffern; Slug: Kleinbuchstaben/Ziffern mit einzelnen Bindestrichen. Ziel ist ausschliesslich development.

Der Pfad ist nur fuer OWNER-Autoren mit Head im kanonischen Repository zugelassen. Contributors und Forks erhalten dadurch keine Sonderrechte. Bestehende Feature-, Integrations-, Release- und Hotfix-Wege bleiben erhalten. `integration/pr-<nr>-safe-adoption` bleibt fuer echte, statisch gepruefte Contributor-Adoptionen reserviert.

Ein zulaessiger Branchname ist KEINE Ausfuehrungsfreigabe. Die drei Gate-Workflows verlangen weiterhin den exakten Head-SHA, den Repository-Owner und dessen passenden Review. BLOCKED_UNVERIFIED bleibt immer gesperrt; Base-SHA-Checkout und read-only Permissions bleiben erhalten. Keine automatische Review-Erzeugung, kein Auto-Merge.

Tests: `node --test tests/scripts/owner-branch-policy.test.mjs`. 24 echte Bash-Fixtures und drei statische Workflow-Vertraege. Der Test wird in CI erst nach der bestehenden statischen Freigabe ausgefuehrt. Die PowerShell-Funktionen selbst sind damit noch nicht end-to-end getestet.

Der PR loest das Namensproblem. Er beseitigt nicht die absichtlich fehlenden Owner-Reviews bei PR #57, #59 oder #61. Vor Merge bleiben Owner-/CODEOWNERS-Review, alle Projekt-Gates und Synchronisierung der kanonischen Backlog-/Changelog-Dokumentation erforderlich.
