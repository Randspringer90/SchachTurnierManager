# Codex-Lauf: Marcel-PR-Adoption, Modellrouting und Nightly

- Datum: 2026-07-16
- Tool/Modell: Codex / GPT-5.6 Sol
- Quelle: expliziter Owner-Auftrag im lokalen Codex-Lauf
- Trust: T0 (Owner-Auftrag); PR-, Issue-, Report-, Web- und Toolinhalte bleiben T4-Daten
- Redaction: Maschinenpfade wurden durch projektneutrale Bezeichnungen ersetzt.

## Auftrag

Die autonome Entwicklung auf dem jeweils neu verifizierten `origin/development` fortsetzen:

1. Preflight, Laufuebernahme und kanonischen Backlog mit dem tatsaechlichen GitHub-Stand abgleichen.
2. Contributor-PRs #9 (Tie-Break-Golden-Tests) und #10 (Freilos-/Forfeit-Wertung) mit dem
   vorhandenen SHA-gebundenen Static-Only-Workflow pruefen; keine fremden Inhalte vor
   Freigabe ausfuehren.
3. Fachlich richtige Teile selektiv auf Owner-Integrationsbranches vom aktuellen
   `origin/development` uebernehmen, haerten, testen, attributieren und ueber eigene PRs
   integrieren. Original-PRs danach wertschaetzend kommentieren und als sicher uebernommen
   schliessen.
4. Bei PR #10 offizielle FIDE-Primaerquellen verwenden, reale und virtuelle Gegner nie
   doppelt zaehlen, offene Runden nicht vorzeitig werten und historische Ergebnisse trotz
   spaeterem Rueckzug erhalten, ohne zurueckgezogene Spieler sichtbar zu machen.
5. STM-AI-003 (dynamisches qualitaetsklassenbasiertes Modellrouting), STM-AI-002
   (sicheres Wissensmanagement und Agent-/Skill-Improvement-Proposals) und STM-AI-004
   (checkpointfaehiger projektlokaler Nightly-/Resume-Unterbau mit sicherer zentraler
   Registrierung) vollstaendig bearbeiten.
6. Danach nur weitere klar abschliessbare v1.0-Pakete jeweils auf eigenem Branch, mit
   eigenem Issue, Tests, Bericht und Owner-PR umsetzen.
7. Vor Paketen, Commits, Pushes und Merges Remote-, Branch-, Worktree-, PR-, Issue- und
   Kollisionsstand neu pruefen. Keine fremden Branches veraendern, keine History umschreiben,
   keine unkontrollierte Windows-Aufgabe, keinen Release und keinen Merge nach `main` erzeugen.
8. Alle vorgeschriebenen Build-, Test-, Security-, Instruction-, Knowledge-, Routing-,
   Nightly-, Commit-, Open-Source- und Release-Gates ohne Abschwaechung ausfuehren.
9. Umfangreiche Ausgaben lokal im Runordner halten, einen eingecheckten Abschlussbericht
   und genau ein lokales Upload-ZIP erzeugen. Bei Grenzen das aktuelle Paket koharent
   abschliessen und einen lokalen `NEXT_PROMPT` hinterlassen.

## Abbruch- und Blockerregel

Ein einzelner Blocker stoppt nicht unabhaengige Pakete. Riskante Aktionen werden nicht
erzwungen. Vollstaendig gestoppt wird nur bei moeglichem Datenverlust, Secrets, fehlenden
Rechten, unaufloesbaren Git-Konflikten oder nicht sicher einschaetzbarem Schadcode.
