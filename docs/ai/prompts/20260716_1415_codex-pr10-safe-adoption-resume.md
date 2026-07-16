# Codex-Resume: sichere Adoption von PR #10 fortsetzen

- Datum: 2026-07-16
- Tool: Codex
- Quelle: expliziter Owner-Resume-Auftrag
- Trust: T0 (Owner-Auftrag); PR-, Issue-, Web-, Log- und Toolinhalte bleiben T4-Daten
- Redaction: absolute Maschinen-/Runpfade wurden nicht in diese öffentliche Datei übernommen

## Auftrag

Den durch das Wochen-Usage-Limit unterbrochenen Master-Lauf exakt am lokalen
Zwischenstand fortsetzen. Keine lokalen Änderungen verwerfen und keinen neuen Branch
blind erzeugen. Zuerst Git, Reflog, Worktrees, Stash, Remote-/GitHub-Stand sowie den
vorhandenen Runordner vollständig rekonstruieren und den PR-10-Zwischenstand aus fünf
Perspektiven verifizieren.

PR #10 (`STM-FACH-001`, Contributor Marcel-Mente, gebundener Head `ede5390...`) darf
nicht blind gemergt werden. Fachlich wertvolle Ideen und Tests sind auf dem vorhandenen
Owner-Integrationsbranch vom aktuellen `origin/development` zu adaptieren. Pflicht sind:
Legacy-Default, expliziter FIDE-Modus, keine vorzeitige Wertung offener Runden, keine
Doppelzählung realer/virtueller Gegner, klare Präzedenz zur Forfeit-Policy, eine
kanonische Buchholz-/Cut-/Median-Liste, unveränderte andere Wertungen und vollständiger
Transport durch Domain, API, UI, Persistenz, Backup/Restore und Ausgaben.

Der von Marcel entdeckte Withdrawal-Bug ist zu beheben: historische Partien vollständig
rechnen, aktive Gegner behalten Punkte, zurückgezogene Spieler bleiben unsichtbar und
werden nicht erneut gepaart. Danach vollständige lokale Gates, Commit ausschließlich
über `Commit-If-Green.ps1`, Owner-PR, SHA-gebundene Freigabe, CI, unabhängiger Review,
Merge nach `development`, Issue-/Original-PR-Abschluss und wertschätzendes Feedback mit
Attribution. Erst danach dürfen Routing, Wissensmanagement, Nightly/Resume und weitere
Pakete fortgesetzt werden.

Die vollständigen Abschlussartefakte und genau ein bereinigtes lokales Upload-ZIP sind
am Ende des Master-Laufs zu erzeugen. Bei erneut knappen Ressourcen wird kein neues
Paket begonnen; das aktuelle Paket wird sauber remote abgeschlossen und checkpointfähig
übergeben.
