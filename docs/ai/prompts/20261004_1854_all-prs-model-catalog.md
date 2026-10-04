# Auftrag: bestehende PRs integrieren und Modellpflege zentralisieren

Quelle: Owner-Auftrag vom 2026-10-04, einschliesslich nachfolgender Klarstellungen.

- Alle beim Live-Start offenen PRs gegen `development` statisch pruefen, sicher integrieren oder mit belegtem Ersatz beziehungsweise echtem Blocker klassifizieren. Keine kuenstlichen Schliessungen.
- Lokalen und Remote-Stand nach realen Builds, Tests und Security-Gates synchronisieren. Keine neuen PRs, Releases, Tags, Deployments, externen Artefakt-Uploads, Force-Pushes oder Aenderungen an `main`. Bestehende Branches erhalten.
- Veraltete Modellvorgaben ersetzen. Konkrete Modellvarianten nur an einer Stelle pflegen; alle Instruktionen verwenden logische Profile und einen Hinweis auf die neueste offiziell verifizierte stabile Generation. Historische Lauftexte versionsneutral halten, ohne damalige Ausfuehrungen als aktuelle Modellnutzung darzustellen.
- Architektur darf fuer diese Ziele verbessert werden. Keine Rueckfragen fuer sicher entscheidbare technische Schritte. Qualitaet und Sicherheitsgrenzen bleiben verbindlich; keine stillen Fallbacks oder automatischen kostenpflichtigen API-Wechsel.
- Die nachtraegliche Freigabe aktueller Modelle ersetzt die urspruengliche Bindung an ein altes Ausfuehrungsmodell.

## Umsetzungsplan fuer die Modellpflege

1. Offline-Vertragstests fuer Katalog-Aufloesung, Provider-Grenzen, sichere Pfade und Vermeidung verteilter Versionspins schreiben und den Ausgangsfehler messen.
2. `config/model-catalog.json` als einzige Quelle konkreter Modell-IDs einfuehren; die Runtime-Policy referenziert stabile Katalogschluessel. Loader validiert Schema und Semantik fail-closed.
3. Modellrouting-Dokumentation und Agentenhinweise auf den Katalog ausrichten; historische Modellangaben versionsneutral redigieren. Backlog bleibt die kanonische Aufgabenquelle.
4. Offline- und Security-Gates sowie erforderliche Build-/Testpfade ausfuehren, Aenderungen unabhaengig reviewen und getrennt von Fach-PRs integrieren.
5. Infrastruktur-PRs zuerst behandeln; nach jeder Integration alle weiteren PRs gegen den neuen Base-Stand bewerten. Externe Laufdiagnosen bleiben ausserhalb Git.

Offizielle Modellquellen: [OpenAI](https://developers.openai.com/api/docs/models),
[Anthropic](https://platform.claude.com/docs/en/models/overview), abgerufen 2026-10-04.
