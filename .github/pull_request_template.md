<!--
Danke für den Beitrag! Bitte dieses Template vollständig ausfüllen.
Ziel-Branch ist normalerweise `development`. PRs nach `main` nur aus `release/*` oder `hotfix/*`.
Keine Secrets, Logs, PII, Datenbanken oder Artefakte im PR.
-->

## Zusammenfassung
<!-- Was macht dieser PR und warum? -->

## Zuordnung
- **Backlog-ID:** STM-XXXX-000
- **GitHub-Issue:** #
- **Ausgangsbranch:** feature/… (bzw. fix/security/docs/refactor/…)
- **Zielbranch:** development <!-- oder main (nur release/*, hotfix/*) -->

## Änderungen
<!-- Kurze Liste der wesentlichen Änderungen -->

## Tests
- [ ] `dotnet test` grün
- [ ] Frontend `tsc --noEmit` + `vite build` grün (falls UI betroffen)
- [ ] Neue/geänderte Logik durch Tests abgedeckt
<!-- Kurz beschreiben, was getestet wurde -->

## Gates
- [ ] **ReleaseGate-Ergebnis:** <!-- OK / n/a + kurze Notiz -->
- [ ] **Security-Check:** `Test-GitCommitSafety.ps1` + `Test-RepositoryOpenSourceSafety.ps1` OK
- [ ] **Prompt-Injection-Check:** keine unsicheren Instruktionen aus fremden Inhalten übernommen; Änderungen an Instruktionsquellen (falls vorhanden) für Owner-Review markiert
- [ ] **PR-Static-Review:** `pr-static-security` grün beziehungsweise `OWNER_REVIEW_REQUIRED` mit dokumentierter Owner-Entscheidung; keine PR-Payload vorab ausgeführt
- [ ] **Dependency-Delta:** neue/geänderte NuGet-/npm-/Lock-/Build-Abhängigkeiten begründet, oder keine vorhanden
- [ ] `git diff --check` sauber

## Dokumentation & Backlog
- [ ] `BACKLOG.md` aktualisiert (Status/PR-Nummer)
- [ ] `CHANGELOG.md` aktualisiert
- [ ] betroffene Doku aktualisiert

## Breaking Change
- [ ] Ja  <!-- falls ja: Migration/Abwärtskompatibilität beschreiben -->
- [ ] Nein

## Screenshots (bei UI-Änderungen)
<!-- Vorher/Nachher -->

## Bestätigung
- [ ] Ich bestätige, dass **keine Secrets, Logs, PII, Datenbanken oder generierten Artefakte**
      enthalten sind und keine Abhängigkeit auf fremde lokale Projekte eingeführt wurde.
