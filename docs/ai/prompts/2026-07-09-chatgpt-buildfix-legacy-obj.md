# Prompt 2026-07-09 – ChatGPT: Build-Fix Legacy-obj nach Pull

Auftrag sinngemäß:

- Nach Pull auf `main`/0.42.0 bricht `Invoke-ReleaseGate.ps1 -SkipPack` beim `dotnet build`
  mit doppelten Assembly-Attributen im Domain-Projekt ab.
- Erst die grüne Build-/Release-Gate-Basis wiederherstellen, bevor neue Roadmap-Features
  umgesetzt werden.
- Patch als kleines ZIP mit nur notwendigen Änderungen liefern.
- Logging/Projektprotokoll sauber pflegen.
- Kein Push, kein Release, keine Veröffentlichung.

Ursache/Fix-Hypothese:

- Die aktiven MSBuild-Ausgaben liegen unter `tmp/dotnet-*`.
- Bestehende Worktrees können noch alte Projektordner `src/**/obj` bzw. `tests/**/obj` aus
  früheren Builds enthalten.
- Diese Legacy-Ordner müssen explizit aus den SDK-Compile-Globs ausgeschlossen und optional
  durch `Clean-Generated.ps1` entfernt werden.
