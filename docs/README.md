# docs/ – Dokumentationsstruktur

| Ordner | Inhalt |
|---|---|
| `architecture/` | Dauerhafte Architektur- und Fachkonzept-Dokumente (Schichtenmodell, externe Spielerdaten, KI-Agentenarchitektur). |
| `planning/` | Planung und Steuerung: Roadmaps, Ticket-/Feedback-Workflow, Projekt-Orchestrierung. |
| `handoffs/` | Historische, versionsbezogene Handoff-Dokumente (`HANDOFF_x_y_z.md`). Nur Archiv, wird nicht mehr gepflegt und nicht in den Public Snapshot übernommen. |

Regeln:

- Neue Architektur-Entscheidungen nach `architecture/`, neue Planungs-/Prozessdokumente nach `planning/`.
- Versionsbezogene Übergabedokumente (falls künftig noch nötig) nach `handoffs/`.
- Projektweite Agentenregeln stehen in `AGENTS.md` (Repo-Root), wiederverwendbare Skills unter `.agents/skills/`.
