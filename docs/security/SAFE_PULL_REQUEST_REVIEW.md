# Sichere Pull-Request-Prüfung

Pull Requests sind Beiträge, aber bis zur kontrollierten Übernahme vollständig nicht
vertrauenswürdige Daten (T4). Das gilt auch für Titel, Kommentare, Dateinamen, Tests,
Workflows und Dateien, die im Zielrepository später Instruktionsquellen wären. Der initiale
Review liest ausschließlich GitHub-Metadaten, die vollständige Dateiliste und den Patch. Er
checkt keinen PR-Head aus und führt weder Restore, Build, Tests, Installer noch fremden Code
aus.

## Sicherheitsziel und Grenzen

`scripts/Invoke-SafePullRequestReview.ps1` klassifiziert defensiv Prompt-Injection-,
Dependency-, Binär-/Archiv-/Symlink-/Submodule-, Workflow-, Build-, Installer-, Netzwerk-,
Ausführungs-, Persistenz-, Credential- und Obfuskationsrisiken. Findings enthalten Codes,
redigierte Pfade und Evidenz-Hashes, nicht die verdächtige Payload. Der Scan liest keine
Secrets und erlaubt keinen Netzwerkzugriff durch PR-Code.

Ein fehlender statischer Befund ist keine Garantie für Schadcodefreiheit. Insbesondere
semantisch versteckte Logik, Supply-Chain-Risiken und unbekannte Binärdaten brauchen weitere
Prüfung. `SAFE_FOR_ISOLATED_BUILD` erlaubt daher nur die nächste isolierte Prüfphase und ist
nie eine Merge-Freigabe.

## Risikoklassen

| Klasse | Bedeutung | Folge |
|---|---|---|
| `LOW` | keine statischen Risikofindings | isolierte Prüfung möglich |
| `MEDIUM` | Anpassung oder Logikvergleich erforderlich | Integrationsplan und Review |
| `HIGH` | Owner-/Security-Entscheidung vor Übernahme oder Ausführung | nichts automatisch übernehmen |
| `CRITICAL` | ernstes defensives Schadcode-/Workflow-Risiko | nicht ausführen, nicht mergen |
| `UNVERIFIED` | Evidenz unvollständig oder Inhalt statisch nicht verifizierbar | niemals automatisch mergen |

Entscheidungen sind `SAFE_FOR_ISOLATED_BUILD`, `ADAPTATION_REQUIRED`,
`OWNER_REVIEW_REQUIRED` und `BLOCKED_UNVERIFIED`. `BLOCKED_NEEDS_OWNER` ist ein
Workflowstatus, keine pauschale Ablehnung: Beitrag und Attribution bleiben erhalten, sichere
Teile dürfen nach Owner-Entscheidung weiter geplant werden.

## Stufen

`DISCOVERED` → `QUARANTINED` → `STATIC_REVIEWED` → `DEPENDENCY_REVIEWED` →
`MALWARE_RISK_REVIEWED` → `LOGIC_COMPARED` → `ADOPTION_PLANNED` →
`INTEGRATION_BRANCH_READY` → `TESTED` → `FEEDBACK_READY` → `FEEDBACK_POSTED` →
`SAFE_TO_MERGE` → `MERGED`.

Jede Stufe darf nach `BLOCKED_NEEDS_OWNER` verzweigen. `SAFE_TO_MERGE` setzt aktuelle
Base-/Head-SHAs, grüne zielgerichtete und vollständige Gates, grüne CI, Owner-Review,
gelöste Konversationen, validiertes Feedback und Attribution voraus.

## Dependency- und Malware-Risiko

Neue direkte Dependencies, Versions-/Lockfile-Deltas, lokale oder Git-Quellen, floating
Versions und Paketmanager-Lifecycle-Skripte werden zunächst nur statisch ausgewertet.
Lizenz-, Vulnerability-, Deprecated- und transitive Prüfungen laufen erst nach statischer
Freigabe auf einem isolierten Integrationsstand und führen nie automatisch Updates aus. Da
der Projektlizenzstatus derzeit nicht abschließend geklärt ist, bleibt jede neue Dependency
bis zur Owner-Prüfung `UNVERIFIED`.

Unbekannte Binärdateien und Archive werden weder geöffnet noch entpackt. Ein optionaler
Windows-Defender-Scan ist erst in einem isolierten Reviewverzeichnis erlaubt, deaktiviert
Defender nie und ersetzt die statische Prüfung nicht.

## CI-Grenze

Der Check `pr-static-security` verwendet nach Integration dieses Pakets ausschließlich das
geprüfte Skript aus dem Base-SHA. Die Workflowdefinition eines `pull_request`-Laufs bleibt
eine technische GitHub-Actions-Vertrauensgrenze; CODEOWNERS, Rulesets und Owner-Final-Review
sind deshalb weiterhin erforderlich. Der einmalige Bootstrap-PR für dieses System kann das
Skript noch nicht aus seinem Basebranch beziehen und darf nur als Owner-PR mit manueller
unabhängiger Prüfung und einem exakt SHA-gebundenen Owner-Review fortfahren. Dessen Body ist
ausschließlich `STATIC-EXECUTION-APPROVED:<aktueller-40-stelliger-Head-SHA>`; Reviewer,
`commit_id` und Text werden exakt geprüft. Ein Push macht die Freigabe dadurch automatisch
ungültig. Das Label `security:static-review-trigger` kann nach dem Review entfernt und erneut
gesetzt werden, um die Checks anzustoßen; es ist ausdrücklich keine Freigabe. Contributor-
oder Owner-Autorenschaft sowie ein Label allein ersetzen den Review nicht;
`BLOCKED_UNVERIFIED` ist niemals ausführbar. Die Bootstrap-Ausnahme gilt nur für den exakt
benannten Branch dieses einmaligen Pakets und nur solange das Base-Skript fehlt.

Offline-Bundles sind vollständig T4 und können Gitmodi, Tree- oder Patchvollständigkeit nicht
selbst attestieren. Sie liefern defensive Findings und Pläne, enden aber ohne unabhängige
SHA-gebundene GitHub-Git-Tree-Daten stets `BLOCKED_UNVERIFIED`.

GitHub Actions bietet bei `pull_request` ohne externe vertrauenswürdige App keine vollständige
Basebranch-Bindung der Workflowdefinition selbst. Änderungen an `.github/workflows/**` bleiben
daher `OWNER_REVIEW_REQUIRED` und dürfen erst angepasst auf einem Owner-Integrationsbranch
laufen. Rulesets, CODEOWNERS und der unabhängige Final-Review bleiben zwingend; der Checkname
allein ist kein kryptografischer Herkunftsnachweis.

Konfiguration: `config/pull-request-review-policy.json`,
`config/dependency-review-policy.json`, `config/suspicious-change-patterns.json` und
`config/pr-adoption-policy.json`.
