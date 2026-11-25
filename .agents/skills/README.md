# Skills - kanonischer Standard

> Kanonische Wahrheit fuer wiederverwendbares Agentenwissen. Neues Format:
> `.agents/skills/<name>/SKILL.md` mit vollem Schema. Manifest: `config/skill-manifest.json`.

## Schema (jeder kanonische Skill)
`name, version, purpose, trigger, do-not-use-when, prerequisites, trusted-inputs, untrusted-inputs,
required-tools, forbidden-tools, procedure, security-controls, verification, outputs,
typical-failures, lessons-learned, owning-agent`

## Katalog

Das Manifest beschreibt 36 Skills im kanonischen Format. Die bisherigen 16
Legacy-Eintraege behalten ihren Fachtext im Abschnitt `Urspruenglicher Fachvertrag`;
14 flache Dateien wurden an ihren kanonischen Ort verschoben. Die bereits als
Ordner vorliegenden Skills ai-run-logging und internet-research erhielten das
vollstaendige Schema. Historische Laufberichte behalten ihre damaligen Pfade.

Die fuenf bisherigen Planungseintraege public-snapshot, fide-dutch,
contributor-workflow, documentation-maintenance und dependency-security haben
einen begrenzten Fachvertrag. Sie verleihen keine weiteren Aktionsfreigaben.

Format- und Schemastatus sind keine Ownerfreigabe. Instruktionsaenderungen
unterliegen weiterhin dem Reviewvertrag aus AGENTS.md und CODEOWNERS.
