# STM-INFRA-007 - Owner-Paketbranches

Issue #62 / PR #63. Ergaenzt die kanonische `BRANCHING_STRATEGY.md` (Abschnitt "Owner-Paketbranches").

Eigenstaendige Owner-Pakete nutzen `owner/STM-<BEREICH>-<NNN>-<slug>`, zum Beispiel `owner/STM-INFRA-007-branch-policy`. Bereich: Grossbuchstaben; Nummer: drei Ziffern; Slug: Kleinbuchstaben/Ziffern mit einzelnen Bindestrichen. Ziel ist ausschliesslich development.

Nur `owner/` ist ein Owner-Paketpfad. `feature/`, `fix/`, `security/`, `docs/` und `refactor/` bleiben der normale, nicht privilegierte Feature-Branch-Weg und erhalten auch mit STM-ID **keinen** Owner-Ausfuehrungspfad. Der unabhaengige Review von PR #63 hat eine dauerhafte Bestandsausnahme fuer diese Praefixe verworfen, weil sie die Ausfuehrungsfreigabe breiter geoeffnet haette als noetig. Bestehende Owner-PRs mit solchen Namen werden ueber einen Integrationsbranch uebernommen statt ueber einen Sonderpfad.

Der Owner-Ausfuehrungspfad verlangt weiterhin OWNER-Autor und Head im kanonischen Repository. Contributors und Forks erhalten dadurch keine Sonderrechte. `integration/pr-<nr>-safe-adoption` bleibt fuer statisch gepruefte Adoptionen reserviert.

Ein zulaessiger Branchname ist KEINE Ausfuehrungsfreigabe. Die drei Gate-Workflows verlangen weiterhin den exakten Head-SHA, den Repository-Owner und dessen passenden Review. BLOCKED_UNVERIFIED bleibt immer gesperrt; Base-SHA-Checkout und read-only Permissions bleiben erhalten. Keine automatische Review-Erzeugung, kein Auto-Merge.

Tests: `node --test tests/scripts/owner-branch-policy.test.mjs` (33 Faelle):

- 24 echte Bash-Fixtures der Branch-Policy;
- je Gate-Workflow ein Mustervertrag (nur `owner/STM-...`, keine anderen Praefixe);
- je Gate-Workflow die **ausgefuehrten** PowerShell-Funktionen `Test-ShaBoundOwnerReview` und `Assert-OwnerExecutionApproval` mit 18 Positiv-/Negativfaellen (Owner, Repository, Head-SHA, Marker, Review-Status, gh-Fehler, ungueltige Antwort; `gh` ist ein lokales Fixture ohne Netzwerk);
- statische Haertungsvertraege (Base-SHA-Checkout, keine Write-Permissions, kein `pull_request_target`).

Workflowdateien werden zeilenendenunabhaengig (LF/CRLF) gelesen. Lokal unter Windows muss `bash` (z. B. Git Bash) im PATH liegen.

Vor Merge bleiben Owner-/CODEOWNERS-Review und alle Projekt-Gates erforderlich.
