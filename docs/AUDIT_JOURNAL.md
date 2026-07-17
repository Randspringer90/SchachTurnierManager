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

> **Grenze (TODO):** Seit v0.41.0 paart die Optimal-V2-Engine global optimal
> (Minimum-Penalty-Matching, siehe `docs/SWISS_PAIRING_ENGINE.md`) und erzeugt Rematches nur noch,
> wenn sie unvermeidbar sind. Die Forensik protokolliert weiterhin den **gewählten**
> Entscheidungsstand samt Warnungen/Blockern, jedoch keine bewerteten **Alternativ-Paarungen**
> („warum diese und nicht jene").

## FIDE-Dutch-Audit (STM-FACH-002)

Wählt das Turnier `SwissPairingStrategyKind.FideDutch`, protokolliert die Auslosung zusätzlich
nach der Struktur des Regelwerks. Grundlage: `docs/FIDE_DUTCH_REFERENCE.md` (C.04.3 in der ab
**01.02.2026** gültigen Fassung).

- `algorithm` = `Swiss-FIDE-Dutch-C0403`, `rulesetVersion` = `FIDE-C.04.3-2026-02-01`.
  Die Fassung steht bewusst im Audit: C.04.3 wurde zum 01.02.2026 neu gefasst, und eine Auslosung
  ist nur gegen die Fassung prüfbar, nach der sie erstellt wurde.
- **`scoreGroups`**: jede Punktgruppe mit Startnummern (Art. 1.3.1); die Auslosung läuft von der
  obersten abwärts (Art. 1.9.2).
- **`floaters`**: je Absteiger die Punktzahl und ob das Bracket homogen oder heterogen war
  (Art. 1.4.1). Damit ist nachvollziehbar, wer warum die Punktgruppe verlassen hat.
- **`colorNotes`** und `Pairing.Notes`: je Brett die **angewandte Regelstufe** aus Art. 5.2 samt
  Klartextbegründung, z. B. *„Stärkere Präferenz erfüllt: #8 (B) vor #2 (b). Weiß: #2, Schwarz: #8.
  [C.04.3 Art. 5.2.2]"*.
- **Freilos**: `Pairing.Notes` nennt Empfänger, Punktzahl und die Fundstelle [C5] (Art. 2.3.1).
- **Setzlisten-Warnung**: Ist die Startliste nicht nach Spielstärke sortiert (C.04.2 Art. 2.2–2.3),
  erscheint eine Warnung in `messages`. Die Strategie nummeriert **nicht** selbst um — eine intern
  abweichende Nummerierung würde C.04.1 Art. 9 verletzen, weil das Audit dann Nummern nennte, die
  in der Oberfläche nirgends stehen.
- **Keine regelkonforme Paarung möglich**: Die Strategie liefert dann keine Auslosung, sondern gibt
  den Fall mit Fundstelle an den Turnierleiter ab (Art. 1.9.3 — „der Schiedsrichter entscheidet").
  Sie paart in diesem Fall bewusst **nicht** regelwidrig weiter.

> **Offen:** Auch hier werden die **verworfenen Alternativkandidaten** nicht mit ihrer Bewertung
> protokolliert. Das Audit sagt, welche Regel die gewählte Paarung trägt, aber nicht, welcher
> Kandidat an welchem Kriterium gescheitert ist. Für eine Beschwerde beim Schiedsrichter wäre das
> die nächste Ausbaustufe.

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
