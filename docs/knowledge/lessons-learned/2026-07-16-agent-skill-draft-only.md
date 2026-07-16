# Lernsignale bleiben bis zur getrennten Freigabe Daten

- source: STM-AI-002 Implementierung und synthetische AgentSkillProposal-Matrix
- date: 2026-07-16
- trust: T2 für geprüfte Repository-Mechanismen; synthetische Beobachtungen blieben T3-Daten
- review: Owner-PR, Prompt-Injection-Review und Remote-CI vor Integration vorgesehen

## Beobachtung

Ein wiederholter Befund kann fachlich nützlich sein und zugleich aus einem Kanal
stammen, der Verhalten nicht steuern darf. Eine automatische Übernahme in Agenten
oder Skills würde diese beiden Eigenschaften unzulässig vermischen.

## Konsequenz

Der vorbereitende Mechanismus erzeugt nur einen lokalen DRAFT. Er hält Quelle,
Trust-Zone, kurze Evidenz, Ziel, Pflichtreviews und Gates fest. Erst ein separater
geprüfter Diff kann die kanonische Agenten- oder Skill-Struktur verändern.

## Wiederverwendung

Sichere Improvement-Prozesse benötigen immer Negativfälle für Secrets, PII,
lokale Pfade, Injection, Befehlsmuster, Code-Fences, T5 und Traversal. Zusätzlich
müssen die Hashes aller Instruktionsquellen vor und nach dem Generator identisch sein.
