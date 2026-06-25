# Audit-Journal & Pairing-Forensik

**Stand:** 2026-06-21 · Reaktion auf die Forensik-Lücke aus `POSTMORTEM_BERGFEST_2026.md`.

> Alle Beispiele sind synthetisch. Echte Teilnehmerdaten, lokale Turnierdatenbanken,
> Audit-Spiegel und Exporte werden **nicht** committet (`local-input/**`, `logs/`, `output/`,
> `tmp/`, `*.sqlite`, `.local-audits/` sind ignoriert).

## Warum

Das Bergfest-Postmortem hatte eine zentrale Lücke: Es gab zwar ein Audit-Journal in der
Datenbank, aber **keine gesicherte, exportierbare Forensik**. Symptome wie „falsch ausgelost"
oder „6. Runde trotz geplanter 5" waren nachträglich nicht rekonstruierbar. Diese Erweiterung
schließt die Lücke auf drei Ebenen, **ohne Auslosungs- oder Wertungslogik zu ändern**:

1. **DB-Audit-Journal** (bestand bereits): vollständiges Ereignisprotokoll je Turnier.
2. **Append-only Datei-Spiegel** (neu): jedes Ereignis zusätzlich in eine JSONL-Datei pro
   Turnier im lokalen AppData-Bereich – überlebt DB-Verlust und `Reset`.
3. **Forensisches Export-Bundle** (neu): in sich geschlossener Snapshot zum Sichern nach
   jeder Runde und am Turnierende.

## Ereignisse (`AuditJournalAction`)

Turnier angelegt/geändert/importiert/**zurückgesetzt**/**gelöscht**, externe Spielerdaten
übernommen, Spieler hinzugefügt/aktualisiert/Status geändert/entfernt/zurückgezogen,
**Runde-Vorschau erzeugt**, Runde ausgelost, Ergebnis gespeichert, Paarung manuell geändert,
Runde gesperrt/entsperrt/geprüft, Chess960-Stellungen gewürfelt, **Auslosung blockiert**
(Rundenlimit, Round-Robin-Roster-Sperre, offene Vorrunde, zu wenige Spieler),
**Audit-Bundle exportiert**, **Audit-Spiegel fehlgeschlagen**.

Jeder Eintrag (`AuditJournalEntry`): `id`, `createdAt` (UTC), `action`, `severity`
(Info/Warning/Critical), `actor` (Standard „Turnierleitung", System-Einträge „System"),
`summary`, `details`, `reason`, `roundNumber`, `boardNumber`, `playerId`, `playerName`.

## Pairing-Forensik (`PairingForensics`)

Bei **Vorschau** und **Auslosung** wird ein unveränderlicher Entscheidungs-Snapshot je Runde
festgehalten (`TournamentRound.Forensics`) – aus dem Stand **vor** dieser Runde, damit er auch
nach Ergebniseingaben/Statusänderungen gültig bleibt:

- `trigger` (`preview` / `generated`), `format`, `algorithm`, `plannedRounds`, `currentRound`
- aktive/inaktive Spielerzahl, offene Ergebnisse der Vorrunden (`openResultsBeforeRound`)
- Bretter-/Bye-/manuelle-Paarungen-Zahl, Rematches, Scoregruppen-Abweichungen, Farbfolgerisiken
- Qualitätswert (0–100) + Schweregrad
- `byeDecisions`, `rematchWarnings`, `scoreGroupDeviations`, `colorNotes`, `engineMessages`, `findings`
- `proposedPairings`: je Brett Weiß/Schwarz, Punkte vor der Runde, Differenz, Bye/Override/Rematch-Flags

> **Grenze (TODO):** Seit v0.41.0 paart die Swiss-Engine global optimal (Minimum-Penalty-Matching,
> siehe `docs/SWISS_PAIRING_ENGINE.md`) und erzeugt Rematches nur noch, wenn sie unvermeidbar
> sind. Die Forensik protokolliert weiterhin den **gewählten** Entscheidungsstand samt
> Warnungen/Blockern, jedoch keine bewerteten **Alternativ-Paarungen** („warum diese und nicht
> jene") und keine FIDE-Dutch-Bracket-Reihenfolge. Ein vollständiges FIDE-Dutch mit
> Alternativbewertung ist Folgearbeit (siehe `docs/SWISS_CHESS_PARITY_ROADMAP.md`).

## Speicherorte & Format

| Ebene | Ort | Format |
|---|---|---|
| DB-Journal | SQLite (`%LocalAppData%\SchachTurnierManager\SchachTurnierManager.sqlite`) | Teil des `TournamentState` |
| Datei-Spiegel | `%LocalAppData%\SchachTurnierManager\audit\{tournamentId}.jsonl` | append-only JSONL, 1 Ereignis/Zeile |
| Export-Bundle | manuell gewählt (Skript-Standard: `output\audit\`, ignoriert) | JSONL oder JSON |

Der Datei-Spiegel ist **fehlertolerant**: Scheitert ein Schreibvorgang, bricht der
Turnierschritt **nicht** ab; stattdessen entsteht ein `AuditJournalMirrorFailed`-Warneintrag
im DB-Journal, der in UI/API sichtbar ist.

## Export-Bundle

In sich geschlossen (Snapshot + Forensik + Ereignisse):

- **JSONL** (`…_audit.jsonl`): `manifest`-Zeile, `tournament-snapshot`-Zeile,
  je Runde eine `pairing-forensics`-Zeile, je Ereignis eine `audit-event`-Zeile (chronologisch).
- **JSON** (`…_audit.json`): strukturiertes Dokument mit `manifest`, `pairingForensics`,
  `auditJournal`, `tournamentSnapshot`.

Dateiname: `{Turniername}_round{Rundennummer}_{Zeitstempel}_audit.{jsonl|json}`.

### Bedienung

- **WebApp:** Audit-Journal-Karte → Button **„Audit-Bundle (JSONL)"** bzw. **„(JSON)"**.
- **API:** `GET /api/tournaments/{id}/audit-journal/export.jsonl` (bzw. `.json`).
- **Skript:** `pwsh -File .\scripts\Export-TournamentAudit.ps1 [-TournamentId <guid>] [-Format jsonl|json]`
  – speichert lokal nach `output\audit\` (ignoriert). Kein Upload, keine Cloud.

**Empfehlung:** Nach **jeder Runde** und nach **Turnierende** ein Bundle exportieren und
lokal sichern. Zusammen mit `scripts\Backup-BergfestTournament.ps1` ist damit jederzeit
rekonstruierbar, was wann durch wen ausgelöst wurde.
