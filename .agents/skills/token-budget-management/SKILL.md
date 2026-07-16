---
name: token-budget-management
description: Plant und ueberwacht Tokenbudgets fuer delegierte Teilaufgaben; Budgetueberschreitung fuehrt zu Checkpoint statt Qualitaetsverlust.
---

# Skill: token-budget-management

- **name:** token-budget-management
- **version:** 1.0.0
- **purpose:** Tokensparen ohne Qualitaetsverlust bei Routed Execution.
- **trigger:** Zerlegung oder Ausfuehrung eines Taskgraphen mit Budgetentscheidungen.
- **do-not-use-when:** Budgetdruck wuerde zu Downgrade kritischer Arbeit fuehren (verboten).
- **prerequisites:** `config/task-decomposition-policy.json` (defaults), Taskgroessen bekannt.
- **trusted-inputs:** Policies, Taskgraph (T0-T2).
- **untrusted-inputs:** Child-Ausgaben (T3) – nur zur Laengenmessung.
- **required-tools:** Read.
- **forbidden-tools:** Stille Kuerzung von Anforderungen; stiller Profilwechsel.
- **procedure:**
  1. Delegieren nur, wenn das Qualitaetsgate erfuellt ist (begrenzter Scope, definiertes Format, testbares Ergebnis, bekannte Dateien, staerkerer Finalreview) – sonst selbst bearbeiten.
  2. Budget je Task konservativ setzen (Default 20000 Tokens; kleine Analysen deutlich darunter).
  3. Ausgabelaenge grob schaetzen (~4 Zeichen/Token); Ueberschreitung → `BUDGET_EXCEEDED` + Checkpoint, kein Teilergebnis-Commit.
  4. Ersparnis dokumentieren: welche Teilaufgaben liefen auf kleineren Profilen statt auf dem Orchestrator.
  5. Bei wiederholten Budgetproblemen Zerlegung verfeinern statt Qualitaet zu senken.
- **security-controls:** Kein Downgrade kritischer Kategorien; Checkpoint-Bindung.
- **verification:** `scripts/Test-RoutedExecutionReadiness.ps1` (Budget-Test).
- **outputs:** Budgetentscheidungen im Routing-Log.
- **typical-failures:** Zu knappe Budgets fuer Analysen; Budgetdruck als Begruendung fuer Regelverstoss.
- **lessons-learned:** siehe `docs/knowledge/lessons-learned/`.
- **owning-agent:** Routing-Supervisor

> Kanonisch: `.agents/skills/token-budget-management/SKILL.md`. Risiko: medium.
