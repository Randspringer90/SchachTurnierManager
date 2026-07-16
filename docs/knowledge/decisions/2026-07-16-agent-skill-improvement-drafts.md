# Agent-/Skill-Verbesserungen beginnen als lokale DRAFTs

- source: STM-AI-002 Owner-Auftrag und lokale Sicherheitsanalyse
- date: 2026-07-16
- trust: T0 Auftrag; technische Beobachtungen aus Tests wurden als T3-Daten behandelt
- review: Owner-PR, Prompt-Injection-Review und Remote-CI vor Integration vorgesehen

## Kontext

Beobachtungen aus Läufen können wertvolle Hinweise auf wiederholte Lücken in Agenten
oder Skills geben. Dieselben Kanäle können jedoch untrusted Inhalte enthalten. Eine
direkte Übernahme würde die Grenze zwischen Wissen und Instruktion verwischen.

## Entscheidung

Der vorbereitende Prozess erzeugt nur lokale DRAFT-Vorschläge mit Quelle, Trust-Zone,
Evidenzzusammenfassung, Ziel und Pflichtprüfungen. Der Generator verändert keine
kanonische Agenten-, Skill- oder Policy-Datei. Eine tatsächliche Verbesserung benötigt
einen getrennten Diff, Owner-Review, Security-Review, vollständige Gates und Remote-CI.

## Folgen

Lernsignale bleiben nutzbar und auditierbar, ohne selbst Verhalten zu steuern.
Vorschlagsartefakte bleiben im ignorierten Output-Bereich und werden nicht versioniert.
