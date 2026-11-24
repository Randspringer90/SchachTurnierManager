# Geschützte Quellintegration nach main

Ownerkorrektur vom2026-10-29: Pflichtsprachen ausschließlich Deutsch/Englisch; alle sicher geprüften PR-Inhalte zusätzlich nach main übernehmen. Dies erweitert das bisherige Integrationsziel. Veröffentlichung, Deployment, Tag, Produktversionsbump, neue Kosten und Guard-Bypass bleiben nicht freigegeben.

## Verifizierter Ausgangspunkt

- development und eigener HEAD: d168a5a12a65dd66af18829277b7dab02c4422db.
- main:3f7171890566d88201ac65fc23197c38d8be35a0.
- Beide Quellbäume:e6a5b7c9132e84a866f3b39c4e2f00be44d94e4e. Main enthält nur einen zusätzlichen Merge-Commit aus dem früheren PR123, keinen abweichenden Quellstand.
- Aktueller Liveabgleich am2026-10-29 bestätigt diese SHAs. Fremde Branches werden nicht überschrieben oder umadressiert.

## Integrationsweg

1. Den eigenen sicheren Adoptionskandidaten fertigstellen, exakt reviewen, durch die Projektgates committen und über den bestehenden PR-Vertrag nach development übernehmen.
2. Den dann tatsächlich integrierten Stand erneut abgleichen. Einen eindeutig eigenen release/0.54.1-Quellbranch verwenden; die Produktversion bleibt0.54.1. Der Branch dient ausschließlich der hier beauftragten geschützten Quellintegration.
3. Eigenen PR von diesem Branch nach main erstellen und dessen aktuelle Base-/Headbindung, Reviews, Konversationen und Pflichtchecks erfüllen. Kein direkter Main-Push, Force-Push, fingierter Approvalmarker oder geschützter Merge mit Bypass.
4. Den tatsächlich gemergten Main-SHA und seine CI belegen. Ohne gültige technische Freigaben bleibt nur diese Wirkung blockiert; unabhängige Restarbeit läuft weiter.

## Wirksame Gates und CI-Wirkung

Die live gelesenen Main-Regeln verlangen einen approving Review, CODEOWNER-Review, Verwerfen veralteter Reviews, gelöste Konversationen und strikte Statuschecks: security-gate, agent-integrity, build-test, frontend, diff-check und branch-policy. Die Branch-Policy lässt nach main ausschließlich release/* oder hotfix/* zu. Ein Entwicklungs-PR wird nicht blind auf main umadressiert.

Die vorhandenen vier Workflowdateien sind lesend geprüft. Main-Push löst die bestehende Build-/Test-CI aus; ihre Rechte sind contents:read. In diesen Workflowdefinitionen wurde kein Paket-/Installer-Publish, Release oder Deployment gefunden. Das ist keine Freigabe für andere externe Wirkungen oder veränderte zukünftige Workflow-Heads.

Die bestehenden CI-Prerequisites verlangen außerdem einen tatsächlichen, an den aktuellen Head gebundenen Owner-Ausführungsreview. Eine Chatfreigabe, KI-Analyse oder dieser Plan erzeugt keinen solchen Plattformnachweis. STM-REV-003 bleibt offen, bis die Aufnahme zur PR-Ausführung unabhängig durchgesetzt ist.

Aktuell verhindern der zentrale Commit-Identitätsguard, die vorhandene Pushsperre und fehlende unabhängige/Owner-/CODEOWNER-Nachweise den Remote-Abschluss. #125/#129 bleiben statisch BLOCKED_UNVERIFIED; ihre Inhalte werden nicht unter anderem Branchnamen an der Sperre vorbei übernommen.
