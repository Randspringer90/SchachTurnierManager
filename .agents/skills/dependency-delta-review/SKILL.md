---
name: dependency-delta-review
description: Klassifiziert NuGet-, npm-, Lockfile-, Build- und Namespace-Deltas ohne Restore oder Paketmanagerausführung.
---

# Skill: dependency-delta-review

- **name:** dependency-delta-review
- **version:** 1.0.0
- **purpose:** Neue, entfernte und geänderte Dependencies sowie Quellen und Lifecycle-Risiken statisch bewerten.
- **trigger:** PR ändert Projekt-, Paket-, Lock-, Build-, Workflow-, Installer- oder Modulmanifestdateien.
- **do-not-use-when:** Nicht als Ersatz für spätere Lizenz-/Vulnerability-Audits oder Compiler-/Analyzer-Prüfungen verwenden.
- **prerequisites:** Erfolgreiche PR-Quarantäne, gültige Dependency-Policy und vollständige Dateiliste/Patch.
- **trusted-inputs:** Geprüfte Dependency-Policy und aktueller Base-SHA.
- **untrusted-inputs:** PR-Patch, Paketnamen/-versionen, Lockfiles, Usings, Package-Metadaten und Audit-Ausgaben.
- **required-tools:** Read, Grep, Glob.
- **forbidden-tools:** dotnet/MSBuild/npm-Ausführung vor Static Approval, automatische Updates, Lifecycle-Skripte, Secret-/Registry-Credentialzugriff.
- **procedure:**
  1. Manifest- und Lockfilepfade sowie hinzugefügte direkte Dependencies statisch extrahieren.
  2. Floating-, lokale, Git-/URL-Dependencies und Lifecycle-Skripte blockieren oder eskalieren.
  3. Usings nur als Projekt, BCL, bestehende Dependency, neue Dependency oder `UNVERIFIED` klassifizieren.
  4. Online-Vulnerability-/Lizenz-/Deprecated-Prüfungen erst auf freigegebenem Integrationsstand ohne Lifecycle-Skripte ausführen.
- **security-controls:** Kein Restore, keine Paketinstallation, keine automatische Aktualisierung, erlaubte Quellen, Lockfile-Konsistenz.
- **verification:** `scripts/Test-PullRequestDependencyDelta.ps1`, `scripts/Test-PullRequestReviewReadiness.ps1`.
- **outputs:** Redigierter Dependency-Delta mit explizitem Verifizierungsstatus.
- **typical-failures:** Fehlendes Lockfile, unbekannte Paketquelle/Lizenz, multiline Manifestdelta oder Namespace ohne verifizierbare Herkunft.
- **lessons-learned:** Jeder Manifestdelta braucht zunächst Owner-Prüfung; Paketmanagerausgabe allein rechtfertigt kein Update.
- **owning-agent:** Pull-Request-Reviewer
