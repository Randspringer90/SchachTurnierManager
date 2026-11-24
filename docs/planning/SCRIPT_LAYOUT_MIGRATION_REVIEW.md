# Skriptmigration: konkreter Kandidat vor Aktivierung prüfen

STM-INFRA-001 ist nicht abgeschlossen. Die geltenden Projektregeln behalten aktive
Skripte zunächst flach; das Verschieben betrifft gegenseitige Aufrufe, CI,
Instruction-Manifeste, Security-Pattern-Ausnahmen, Tests und zentrale Aufrufer.
AGENTS.md fordert für Änderungen an Instruktionsquellen und Security-Skripten
Owner-Review. Der Kandidat aktiviert daher keine geänderte Vertrauenswurzel.

Die lokale Vorbereitung vom 2026-10-29 umfasst 115 Verschiebungen und 268 geänderte
Textdateien: dev3, test35, release19, git5, security26, maintenance27. `lib` und
`archive` bleiben erhalten. Repositorypfade, getrennte Pfadargumente, literale
PowerShell-Skriptwurzeln und Node-Modul-/URL-Bezüge sind im Patch angepasst.
Verzeichnispfade behalten bei URL-Auflösung ihren abschließenden Schrägstrich.

- Lokales Artefakt: `script-layout-prepared.patch` im Evidence-Laufordner.
- SHA-256: `31c828c9fa4dfe36457ad453765a4b0f662fb8eb64fe929954d783b88fe3160f`.
- `git apply --check` gegen den unveränderten Kandidaten zum Vorbereitungszeitpunkt: bestanden.
- 113 vorbereitete PowerShell-Dateien ausschließlich geparst: keine Syntaxfehler.
- Keine vorbereiteten Skripte ausgeführt; keine Aktivierung und keine funktionale
  oder semantische Vollabnahme behauptet.

Vor Anwendung: unabhängiger exakter Patchreview, Ownerreview der Instruktions-/Guard-
und CI-Pfade, Kontrolle der gleichbleibenden Erkennung und der verpackten BAT-
Startdateien sowie Prüfung der bestehenden zentralen Nightly-Aufrufer. Danach
isoliertes ReleaseGate und betroffene Verträge ausführen. Änderungen am Quellstand
entwerten die Anwendbarkeitsprüfung und erfordern Regenerierung des Kandidaten.
Keine zweite Registrierung, kein neuer Scheduler und kein fremder State-Store.
