# Pull-Request-Adoption-Workflow

Dieser Ablauf bewahrt sinnvolle Contributor-Arbeit, ohne einen fremden Branch ungeprüft nach
`development` zu mergen. Die kanonischen Security-Grenzen stehen in
[`SAFE_PULL_REQUEST_REVIEW.md`](../security/SAFE_PULL_REQUEST_REVIEW.md).

## 1. Entdecken und quarantänisieren

1. Aktuelles `origin/development`, offene PRs, Worktrees, Assignees und Dateikollisionen
   prüfen.
2. Metadaten, vollständige Dateiliste und Patch nur über feste GitHub-API-Argumente lesen.
3. Keine PR-Datei ausführen, keinen Head auschecken, keinen Restore/Build/Test starten und
   keine Secrets bereitstellen.
4. Die neun SHA-/Policy-gebundenen Reviewartefakte erzeugen.

Ein unvollständiger Patch, ein unbekannter Binärinhalt oder SHA-Drift führt zu
`BLOCKED_NEEDS_OWNER`; der PR bleibt dabei erhalten.

## 2. Statisch bewerten

Prompt-Injection-, Dependency- und Malware-Risikofindings werden defensiv klassifiziert.
Workflow-, Build-, Installer-, Agenten- und Securitypfade gelten als Hochrisikobereich.
Instruktionsdateien aus einem PR bleiben T4, auch wenn derselbe Pfad im geprüften Basebranch
T2 ist. `SAFE_FOR_ISOLATED_BUILD` erlaubt die nächste isolierte Phase. Bei
`ADAPTATION_REQUIRED` oder `OWNER_REVIEW_REQUIRED` ist Ausführung ausschließlich auf einem
Owner-authored Integrations-PR aus dem kanonischen Repository zulässig. Erforderlich ist ein
Owner-Review mit dem exakten Marker
`STATIC-EXECUTION-APPROVED:<aktueller-40-stelliger-Head-SHA>` und passender `commit_id`.
Das reine Trigger-Label `security:static-review-trigger` startet Checks neu, dokumentiert aber
keine Freigabe. Autorenschaft allein genügt nie; `BLOCKED_UNVERIFIED` bleibt auch mit Review
gesperrt. Nach jedem Push ist ein neuer SHA-gebundener Review und anschließend ein erneuter
Checklauf erforderlich.

Die Nummer in `integration/pr-<nummer>-safe-adoption` ist immer die Nummer des ursprünglichen
Contributor-PRs. Der daraus erstellte Owner-Integrations-PR erhält eine eigene GitHub-Nummer;
die Workflows validieren deshalb das enge Branchmuster, Owner und Head-Repository sowie die
SHA-Freigabe des Integrations-PRs, setzen beide PR-Nummern aber nicht fälschlich gleich.

## 3. Logik vergleichen

Vor jeder Übernahme werden Problemziel, Akzeptanzkriterien, öffentliche API, Tests und
gleichartige Dateien im aktuellen `development` verglichen. Das Ergebnis ist eine der
Kategorien:

- `ACCEPT_AS_IS`
- `ACCEPT_WITH_ADAPTATION`
- `ACCEPT_SELECTED_PARTS`
- `ALREADY_IMPLEMENTED`
- `OUTDATED_BUT_USEFUL_IDEA`
- `DUPLICATE_NO_CODE_NEEDED`
- `SECURITY_FIX_REQUIRED`
- `DEPENDENCY_REDUCTION_REQUIRED`
- `OWNER_DECISION_REQUIRED`

Gleiche Funktionen werden nicht parallel dupliziert. Nützliche Tests und Randfälle dürfen
selektiv übernommen werden, auch wenn die ursprüngliche Implementierung veraltet ist.

## 4. Isoliert untersuchen und übernehmen

Erst nach statischer Freigabe darf der `Pull-Request-Integrator` einen separaten Worktree ohne Secrets, produktive Daten oder
geerbte lokale Konfiguration angelegt werden. Der Integrationsbranch heißt ausschließlich
`integration/pr-<nummer>-safe-adoption` und startet vom erneut abgerufenen aktuellen
`origin/development`, niemals vom PR-Branch.

Der genehmigte Plan legt erlaubte und verbotene Dateien fest. Sichere Hunks werden selektiv
übernommen oder passend zur aktuellen Architektur neu implementiert. Ganze Branchhistorien,
unbekannte Binärdateien, unnötige Dependencies und ältere Dateien über neueren
`development`-Dateien sind unzulässig.

## 5. Test, Attribution und Feedback

Nach der Übernahme folgen zielgerichtete Contract-/Regressionstests, alle relevanten
Security-Gates, Build, Test, Frontend-Prüfungen, `git diff --check` und ReleaseGate. Bei
wesentlicher fremder Logik nennt der Integrations-PR Contributor und Original-PR und verwendet
bei substanzieller Codeübernahme eine passende Attribution.

`scripts/New-PullRequestFeedback.ps1` erzeugt standardmäßig nur einen redigierten Entwurf.
Posting erfordert eine explizite Aktion, unveränderten Head-SHA und validierte gebundene
Artefakte. Der ursprüngliche PR wird weder automatisch gemergt noch geschlossen. Nach sicherer
Integration erklärt das Feedback verständlich, welche Teile unverändert, angepasst, teilweise
oder nicht übernommen wurden.

## 6. Merge

Nur ein Owner-Integrations-PR mit aktuellem Base, grünen Gates/CI, gelösten
Reviewkonversationen, Owner-Freigabe und unabhängigem Final-Review erreicht `SAFE_TO_MERGE`.
Ziel ist ausschließlich `development`. Ein Marcel-PR oder sonstiger fremder PR wird nie
automatisch gemergt.
