# STM-SEC-002 - Nachpruefung und Korrektur

Auftrag: mehrere getrennte Entwicklungspakete direkt in GitHub vorbereiten; kein Merge, Release oder Dependency-Update.

Ausgangs-Head: 8c868269ebecaf9ee76d1d1cd3ca0b45c6859789. Statische Nachpruefung fand ungeschuetzte XML-Property-Zugriffe unter StrictMode, eine unvollstaendige Versions-Blacklist und zu starke Aussagen zur Lockfile-Herkunft. Korrektur im bestehenden PR #61 statt eines doppelten PRs.

Umsetzung: sichere XML-Abfragen, positiv definierte feste Versionen, Root-/Graph-Abgleich, URI-/SRI-Pruefung, gebundene Lifecycle-Baseline und explizite PARTIAL-Provenienz. 32 echte Prozess-Testfaelle plus xUnit-Einbindung ergaenzt.

Verifikation: statischer Self-Review; PowerShell-Parser, PowerShell-Testlauf und dotnet test NOT_RUN (Runtimes in dieser Umgebung nicht vorhanden). Kein unabhaengiger Owner-Review vorgetaeuscht, kein Approval-Marker geschrieben. Direkte API-Commits ersetzen nicht Commit-If-Green oder die DoD. PR bleibt Draft; vor Merge sind alle Projekt-Gates nachzuholen.

ARTIFACT_UPDATE_AUTHORIZATION=NO
ARTIFACT_UPDATE_REQUIRED=NO
ARTIFACT_UPDATE_EXECUTED=NO
