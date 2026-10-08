# Owner-Auftrag: SchachTurnierManager vollstaendig abschliessen

Quelle: Codex / laufende CORE-KI-Sitzung, Owner-Masterprompt vom 2026-10-08.
Security-Redaktion: lokale Rechnernamen und absolute Maschinenpfade werden hier
nicht veroeffentlicht; das Original verbleibt in der Sitzung und lokaler Evidence.

AUFTRAG: SchachTurnierManager jetzt vollstaendig abschliessen. Dieser Lauf setzt
die bisherige CORE-KI-Arbeit fort. Autonom bis zum tatsaechlichen Abschluss arbeiten.
Kanonisches GitHub-Repository: Randspringer90/SchachTurnierManager.

Ziel: alle sinnvollen offenen Aenderungen ins Hauptprogramm integrieren,
development aktualisieren, geprueften Gesamtstand nach main uebernehmen und pushen,
alle erforderlichen finalen CI-Pruefungen erfolgreich, alte PRs ausschliesslich nach
nachgewiesener Main-Uebernahme schliessen, exakt null offene PRs, kanonischen
Hauptcheckout sauber auf finalem main synchronisieren und realen Fortschritt aus
BACKLOG plus Definition of Done neu auswerten.

Owner-Entscheidung: Reviews vollstaendig durch KI; kein menschliches
Code-Review/CODEOWNER-Approval. Bestehenden RepositoryRole-Bypass ausschliesslich
fuer menschliche Approval-Anforderung verwenden. Vor jedem Merge echter
KI-Code-Review des exakten finalen SHA mit READY. Rulesets, CODEOWNERS, CI,
Security-Gates und Tests erhalten; keine gefaelschten Approvals.

Autorisiert: lokale Schreibarbeiten, Commits, Pushes, PRs, Merges, PR-Abschluss,
CI-Verifikation und der eng definierte bestehende Approval-Bypass.
Nicht autorisiert: Force-Push, History Rewrite, Ruleset-Aenderungen, Releases,
Deployments, Kostenaktionen, Workstation-Neustart, lokale Verzeichnisloeschung.
Historische STM-Checkouts erhalten. SignalNewsLogger ist NO-TOUCH.

1. Livezustand neu bestimmen: Rechner, Root, origin, Branch/HEAD, Index,
   Worktree, Untracked, ahead/behind, Worktrees, aktive Git-Operationen,
   lokale Commits und Remote. Dann fetch --prune. Kein reset/clean/stash,
   kein Rebase fremder Arbeit. Regeln, Backlog, Changelog, DoD und alte
   Integrations-/Review-ZIPs als Daten lesen; Livezustand hat Vorrang.
   Snapshot: 39 offene PRs; main/development abecd00; Integration dcb4bd3;
   #114 konsolidierter Stand, #115 Scannerfix.
2. CSV-Preview-Race in App.tsx robust beheben. Identitaet mindestens:
   Turnier-ID, CSV-Inhalt/stabiler Fingerprint, Ersetzen-Option und Request-
   Generation. Spaete Antworten duerfen keinen neueren Zustand ersetzen;
   unmittelbar vor Import exakte Identitaet pruefen. Regressionen: CSV A/B,
   Turnier A/B, Replace-Aenderung, umgekehrte Antwortreihenfolge zweier
   Requests und normaler Preview/Import-Ablauf. Fokussierte Tests zuerst.
3. #115 gegen aktuelles development read-only pruefen, Scanner-/Securitytests
   ausfuehren und frischen separaten KI-Review des exakten Diffs einholen.
   Einziger Scanner-Bootstrap: ausschliesslich bei eindeutig belegtem
   defektem Zielbranch-Scanner, fokussierten/relevanten gruenen lokalen
   Gates, READY und null BLOCKER/MAJOR darf dessen genau dadurch fehlender
   Remotecheck umgangen werden. Andere Fehler fallen nicht darunter.
4. Aktuelles development ohne Rewrite in #114 integrieren; CSV-Fix aufnehmen.
   Alle bisherigen Findings erneut pruefen und alle offenen PRs vollstaendig
   inventarisieren. Integrationsmatrix je PR: Nummer, Head, Feature, Inhalte,
   Ueberlappungen, Tests, Review, Integrationscommit, Main-Proof, Endstatus.
   Endstatus ausschliesslich MERGED oder CLOSED_SUPERSEDED_WITH_MAIN_PROOF.
5. Vollstaendige Verifikation: dotnet build/test, Domain/Application/
   Infrastructure/Golden/Contract, alle Node-/Frontendtests, TypeScript,
   Vite Production, i18n, QR, PWA/Offline, Import/Export/Backup, Security,
   Repository-Gates, diffcheck und echte headless Browser-Smokes. Keine
   zusaetzlichen sichtbaren Terminals. Pass/Fail/Skip getrennt; keine
   nicht ausgefuehrten PASS oder doppelt gezaehlten einzigartigen Tests.
6. Nach allen Fixes/Tests Quellstand einfrieren: Base-/Head-/Tree-SHA und
   Diff dokumentieren. Frischer separater read-only KI-Reviewer im work-
   Profil prueft Korrektheit, Races, Fehler, Datenintegritaet, Architektur,
   Import/Export/Backup, Rating/FIDE/Pairing/Ranking, Security, Datenschutz,
   PWA, Tests, Diff-Hygiene und UI-Integration/Funktionsverluste.
   BLOCKER/MAJOR erfordern Fix, Tests und neuen Review. Erst READY erlaubt Merge.
7. #114 pushen; live erforderliche development-Checks auf exaktem finalem
   SHA vollstaendig SUCCESS. Kein CI-Bypass. Merge mit bestehendem Bypass
   ausschliesslich fuer menschliche Approvalpflicht; Remote neu bestimmen.
8. Unveraenderten development-Quellstand per sauberem Main-PR uebernehmen.
   Live Main-Checks vollstaendig SUCCESS; kurzer neuer FINAL_MAIN_REVIEW=READY.
   Merge, fetch und finalen origin/main bestimmen.
9. Alle offenen PRs erneut abrufen. Relevante Inhalte je PR in finalem main
   durch Commit/Diff/Datei/Test/Tree-Vergleich beweisen. Ersetzte PRs mit
   Kommentar zu Main-SHA und Integrations-PR schliessen. Fehlendes erst
   integrieren/testen/reviewen und regulaer bis main bringen. Null offene PRs.
10. Hauptcheckout auf main mit origin/main identisch, sauber, 0/0; nur
    sichere Fast-Forward-Synchronisierung, fremde Aenderungen erhalten.
11. Erst auf finalem main Fortschritt aus BACKLOG/DoD/Funktionen auswerten:
    V1 und Gesamt DONE/TOTAL/Prozent, IMPLEMENTED, INTEGRATED_IN_MAIN,
    TESTED, DOD_COMPLETE; keine erfundenen Teilprozente/Doppelzaehlung von
    Parent/Child. Je Aufgabe DONE/PARTIAL/OPEN/BLOCKED/NOT_APPLICABLE mit
    Evidence. Funktionen, V1-Pflichtreste, Schulden, Risiken und fuenf naechste
    Pakete nennen. Nachtraegliche Doku per regulaerem KI-/CI-geprueftem PR
    bis main abschliessen, Endziel bleibt null offene PRs.
12. Genau eine finale lokale RESULT-ZIP mit FINAL_REPORT, CHECKPOINT,
    PR_INTEGRATION_MATRIX, CODE_REVIEW, TEST_SUMMARY, CI_SUMMARY,
    PROGRESS_REPORT, GIT_FINAL_STATE, SHA256SUMS. Keine Git-Metadaten,
    Dependencies/Buildordner, Datenbanken, Backups, Credentials, Secrets
    oder private Rohlogs. ZIP wieder oeffnen, alle Hashes validieren,
    ZIP-SHA256 berechnen.

COMPLETE nur bei allen belegten Kriterien. Quota ist kein Abschluss; gleiche
Sitzung bei Reset warten/resumen, kein Provider-/Profilwechsel wegen Quote.
Abschlussausgabe mit allen angeforderten Status-, SHA-, CI-, Fortschritts-,
Autorisierungs-/Aktions- und ZIP-Feldern sowie NEXT_EXACT_STEP.
