# Harness-Fortentwicklung - Reviewplan

Backlog: STM-AI-008. Folgeslice zur bestehenden STM-AI-001/001b/003/005/007-Struktur.
Aktive Arbeit bleibt in BACKLOG.md; diese Datei ist ein Integrationsplan, kein
zweites Statusregister. Keine Contributor-Zuweisung oder historische Done-Zeile
wird automatisch veraendert.

1. Bestehende Task-Decomposer-/Routing-/Budgetskills konsolidieren und
   Owner-/Instruction-/Skillgates am exakten HEAD ausfuehren. Keine neuen
   parallelen Rollen/manifeste, keine private Pflichtabhaengigkeit.
2. Kleinsten zugelassenen lokalen read-only Worker ueber vorhandenen Router
   verifizieren: Runtime-/Modelldigest, echte Qualifikation, Scope, Ergebnis,
   unabhaengiger Review. Fehlendes lokales Profil bleibt HOLD.
3. Adaptive Admission im bestehenden Runtimepfad mit Worktree-/Lease-/Quota-
   Nachweisen ergaenzen. Erst dann die derzeitige Writergrenze gezielt
   migrieren; JSON-Aufheben allein ist nicht zulaessig.
4. Native TestSummary/FailureSummary und Usage-Aggregation pruefen; EMPTY,
   unbekannte Telemetrie, Profilwechsel, Scopekonflikt, Trunkierung und stale
   Review muessen als Negativkontrollen wirken.
5. Bestehende Nightly/Resume/DRAFT-Persistenz nur im ausdruecklichen Scope
   erweitern; keine Aktivierung und keine aktive Self-Modification.
6. Metriken und synthetische DB-/Kontextbenchmarks vor weiteren Optimierungen.

Vor Merge: kanonischen Backlog-/Changelogstatus fuer diesen Folgeslice
nachfuehren, vollstaendiges PR-Template, unabh. Owner-/CODEOWNERS-Review,
Source-gebundene lokale/CI-Gates. Keine historischen Ergebnisse uebertragen.
Runtime, lokale Modelle, Parallelitaetsnutzen und Produktabnahme sind durch
Instruktionen allein NOT_RUN. Kein Release-/Installer-/Modellupdate.
