# Prompt 2026-07-06 – Claude Fable 5: Installation, i18n-Start, Codex-Roadmap

Auftrag (sinngemäß zusammengefasst, Original per Chat):

- Am SchachTurnierManager weiterarbeiten; Schwerpunkt **Installation**:
  Desktop-Variante mit allem Nötigen und einer Klick-Start-Datei.
- **Mehrsprachigkeit** beginnen: Deutsch, Englisch, Spanisch und 15 weitere Sprachen.
- Code-Review, Bugfixing, Architekturprüfung; risikoarme Verbesserungen direkt umsetzen.
- Die vom Nutzer mitgebrachte 20-Punkte-Roadmap (Audit → Release Candidate) **nicht**
  in einem Lauf umsetzen, sondern als einzelne, saubere Arbeitspakete mit je einem
  eigenen Prompt vorbereiten, damit Codex (ChatGPT) die Fertigstellung übernehmen kann:
  „Codex, arbeite daran weiter, du findest die Prompts dort."
- Arbeitsweise: wie ein Senior-Entwickler/Release-Engineer – erst Regeln/Ist-Zustand/
  Tests verstehen, dann kleine überprüfbare Schritte; immer erst pullen (paralleles
  Arbeiten an mehreren Stellen); nach jedem Lauf geänderte Dateien, Tests, Ergebnis,
  Risiken und nächsten Schritt dokumentieren.

Ergebnis/Report: `docs/ai/reports/2026-07-06-fable-installation-i18n.md`
Roadmap-Prompts: `docs/ai/prompts/codex-roadmap/`
