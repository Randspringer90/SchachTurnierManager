# ADR-0002: Persistenz als Turnier-Aggregat-Snapshot mit atomaren Mutationen

- Status: angenommen (2026-11-24)

## Kontext
Jedes Turnier wird als JSON-Snapshot in der Tabelle `TournamentSnapshots` gespeichert. Anforderungen:
Mehrgerätebetrieb, Auditierbarkeit, große Felder (bis 200 Spieler), Sicherung/Wiederherstellung,
parallele Ergebniseingabe.

## Geprüfte Optionen
| Option | Nutzen | Aufwand/Risiko |
|---|---|---|
| A. Snapshot weiterentwickeln | einfache Sicherung (eine Zeile = ein Turnier), Roundtrip trivial | ohne Konfliktprüfung droht Lost Update |
| B. Versionierte Aggregate mit Concurrency-Kontrolle | erkennt veraltete Clients, idempotente Wiederholungen | gering, auf A aufsetzbar |
| C. Normalisiertes relationales Modell | feingranulare Abfragen, Teilsperren | hoher Migrationsaufwand, Risiko für Altturniere, Backup/Restore-Formate ändern sich |

## Entscheidung
Hybrid A+B: Der Snapshot bleibt die Einheit. Jede Mutation läuft über `ITournamentStore.UpdateAtomically`
in einer serialisierbaren Transaktion (Lesen–Ändern–Schreiben). Mobile/Offline-Ergebnisse tragen
`MutationId` (Idempotenz über Empfangsbelege), `Epoch`, `ExpectedPreviousResult` und
`ExpectedLastChangedAt` (optimistische Prüfung je Brett); Abweichungen enden in einem Konfliktfehler,
nie in stillem Überschreiben.

## Folgen
- Kein relationaler Umbau nötig; Datenformat und Backups bleiben kompatibel.
- Messung 2026-10-28: 200 Spieler, zwei Runden, Export und Neustart innerhalb der Testgrenzen.
- Neu zu prüfen, falls Turniere deutlich größer werden oder gleichzeitige Bearbeitung über das
  Ergebnis-Brett hinausgeht (z. B. paralleles Bearbeiten von Teilnehmerdaten auf mehreren Geräten).
