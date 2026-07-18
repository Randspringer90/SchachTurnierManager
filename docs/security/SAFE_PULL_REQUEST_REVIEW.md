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

## Eng attestierte Android-Buildartefakte

STM-INFRA-008 führt keine allgemeine Binary-Allowlist ein. Das Gate darf ausschließlich
Git-Blobs lesen, die in `config/pull-request-artifact-attestations.json` einzeln und
vollständig gebunden sind. Eine Attestation enthält mindestens:

- Pull-Request-Nummer und exakten 40-stelligen Head-SHA,
- exakten Repositorypfad ohne Wildcards,
- Git-Blob-SHA, SHA-256, MIME-Typ und Dateigröße,
- offizielle Source-Repository-, Tag-, Commit-, Pfad- und Git-Blob-Provenienz,
- Generator und Generatorversion,
- dateitypspezifische Invarianten sowie die ausdrückliche Owner-Review-Pflicht.

Der vertrauenswürdige Base-Scanner lädt nur diese bereits größenbegrenzten Blobs über die
GitHub-Git-Blob-API. Er schreibt sie nicht auf die Platte, entpackt keinen JAR und führt
weder Wrapper noch PR-Code aus. Jede Pfad-, Head-, Blob-, Größen- oder Hashabweichung endet
weiterhin in `BLOCKED_UNVERIFIED`. Eine erfolgreich verifizierte Datei erzeugt dagegen ein
`HIGH`-Finding und höchstens `OWNER_REVIEW_REQUIRED`; sie ist nie automatisch ausführbar
oder mergefähig.

Für `android-png` prüft der Scanner zusätzlich PNG-Signatur, jede Chunk-CRC, exakte
Chunkfolge, Abmessungen, attestierte Textmetadaten, `IEND` und fehlende Nachlaufdaten. Für
`gradle-wrapper.jar` gelten exakter offizieller Wrapper-Hash, JAR-Signatur, Gradle-Version
und Distribution-Checksum. `gradle-wrapper.properties` muss HTTPS, die offizielle
`distributionSha256Sum` und `validateDistributionUrl=true` enthalten. `gradlew` und
`gradlew.bat` werden als Drittanbieter-Buildwrapper klassifiziert; Downloadwerkzeuge,
zusätzliche Shell-Nachladung, Bidi-/Steuerzeichen und unerwartete Zeilenenden blockieren.
Die normale Prozessausführungs-Klassifikation bleibt zusätzlich erhalten.

Die für STM-MOB-001 geprüfte Provenienz stammt aus dem offiziellen Capacitor-Tag `7.4.3`
(Commit `e12818ac2254583fb11c3ea96853d01cb4978438`). Der Gradle-Wrapper `8.11.1` besitzt den
offiziellen SHA-256
`2db75c40782f5e8ba1fc278a5574bab070adccb2d21ca5a6e5ed840888448046`; die vollständige
8.11.1-Distribution den SHA-256
`89d4e70e4e84e2d2dfbb63e4daa53e21b25017cc70c37e4eea31ee51fb15098a`.
Primärquellen, geprüft am 2026-07-18:
[Capacitor 7.4.3](https://github.com/ionic-team/capacitor/tree/7.4.3/android-template),
[Gradle-Prüfsummen](https://gradle.org/release-checksums/) und
[Gradle-Distributionen](https://services.gradle.org/distributions/).

Eine optional aktive, repositoryübergreifende BAT-Fleet darf die exakt attestierte
`gradlew.bat` ebenfalls als `third-party-build-wrapper` einstufen. Sie darf dafür keine
Endnutzer-Launcher-Evidence verlangen und keine pauschale `.bat`-Ausnahme schaffen. Diese
externe Klassifizierung ist kein Repository-Gate und keine Pflichtabhängigkeit des Projekts.

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
`config/pull-request-artifact-attestations.json`,
`config/dependency-review-policy.json`, `config/suspicious-change-patterns.json` und
`config/pr-adoption-policy.json`.
