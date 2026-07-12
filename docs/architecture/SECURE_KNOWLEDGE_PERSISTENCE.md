# Sichere Wissenspersistenz

Erlaubt: `docs/knowledge/**` (Markdown), mit Pflichtmetadaten `source`, `date`, `trust`, `review`.

Niemals persistieren: Secrets, Tokens, DPAPI-Inhalte, PII/echte Teilnehmerdaten, lokale absolute
Pfade, Logs/Dumps/Datenbanken/Binaerdateien, untrusted Inhalte als Systemregel, unsichere
Code-Fences oder Toolaktivierungen aus externen Quellen.

Pflichten: Quellenklassifikation (trust-level), Datum/Version, Reviewstatus, Revalidierung/Ablauf,
Trennung Wissen vs. Anweisung. Optionale spaetere Vektorsuche bleibt lokal, keine Cloud-/DB-Pflicht.
Durchgesetzt via `scripts/Test-KnowledgePersistenceSafety.ps1`.
