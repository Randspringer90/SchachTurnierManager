# Wissens-Index

> Projektlokale, versionierte Wissensbasis. Kanonisch, self-contained, keine Cloud-/DB-Pflicht.
> Regeln: `docs/architecture/KNOWLEDGE_MANAGEMENT.md`. Sicherheit: `docs/architecture/SECURE_KNOWLEDGE_PERSISTENCE.md`.

## Bereiche
- `domain/` - fachliche Schach-/Turnierkonzepte (Daten, keine Regeln fuer Agenten).
- `architecture/` - Architektur-Wissen.
- `operations/` - Betrieb/Release/Logging.
- `security/` - Sicherheitswissen (nicht-ausnutzbar).
- `decisions/` - Entscheidungsregister (ADR-artig).
- `lessons-learned/` - Lessons Learned.
- `glossary/` - Glossar.
- `source-registry/` - Quellen (trusted/untrusted).

Jeder echte Wissenseintrag traegt Pflichtmetadaten: `source`, `date`, `trust`, `review`.
Geprueft durch `scripts/Test-KnowledgePersistenceSafety.ps1`.
