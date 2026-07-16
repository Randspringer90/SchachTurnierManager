# IMPORT_EXPORT_ROADMAP.md

Spezifikation und Stufenplan für Import/Export im Swiss-Chess-Ökosystem.
Stand: 2026-06-16 (Basis 0.38.5). Status: Analyse/Spezifikation, noch kein produktiver Adapter.

## Ziel und Leitplanken
- Austauschformate für Teilnehmer, Paarungen, Ergebnisse und Tabellen.
- Public Repo Safety: keine privaten Turnierdaten, keine echten Web-Scrapes,
  keine externen Downloads im Test. Tests nur mit synthetischen Fixtures.
- Keine großen Umbauten; erst Format-Spike und Schnittstellen, dann Parser.

## Format-Stufen (Priorität)
1. **CSV/Excel (pragmatisch, zuerst)** — vorhandene CSV-Export-Grundlage erweitern.
   - Teilnehmerliste, Tabelle, Paarungen. Klar definierte Spaltenköpfe, UTF-8.
2. **TRF (FIDE Tournament Report Format)** — Standard für Ergebnisweitergabe/Auswertung.
   - Spätere Stufe; eignet sich als verlustarmes FIDE-Ergebnisformat.
   - **Umgesetzt (STM-IE-001):** `TournamentExportFormatter.ExportTrf16` exportiert
     read-only ins FIDE-TRF16-Format (Spaltenpositionen exakt nach C.04 Annex 2,
     https://www.fide.com/FIDE/handbook/C04Annex2_TRF16.pdf). Endpoint
     `GET /api/tournaments/{id}/standings/export.trf16`, WebApp-Button
     "TRF16 (FIDE-Turnierbericht)" im Export-Center.
   - **Bewusste Scope-Grenzen (dokumentiert statt erfunden):**
     - Nur aktive Spieler (wie in den Standings enthalten). Zurückgezogene Spieler
       fehlen im TRF noch komplett — analog zum in STM-FACH-001 gefundenen
       Withdrawal-Scoring-Bug ein eigenständiger Folgeschritt.
     - Geburtsdatum (Position 70-79) bleibt aus PII-Minimierungsgründen leer.
     - Turnier-Kopfzeilen ohne Datengrundlage in unserem Domainmodell (Ort 022,
       Föderation 032, Start-/Enddatum 042/052, Schiedsrichter 102, Rundendaten 132)
       werden ausgelassen statt mit Platzhaltern erfunden — `TournamentState` hat
       aktuell keine entsprechenden Felder.
     - Name wird unverändert aus `Player.Name` übernommen; ohne strukturierte
       Vorname/Nachname-Trennung im Domainmodell ist eine korrekte
       "Nachname, Vorname"-Umformatierung nicht zuverlässig automatisierbar.
     - Zeilenenden sind LF (nicht das historische "CR" aus der FIDE-Doku von 2006),
       passend zu heutiger Praxis.
3. **Swiss-Manager / Chess-Results** — weit verbreitetes Ökosystem.
   - Chess-Results stellt Tabellen, Paarungen und Swiss-Manager-Dateien bereit.
   - Zunächst nur Format-Analyse; kein Live-Scrape, kein Reverse-Engineering binärer Formate ohne Quelle.
4. **PGN (optional)** — ausschließlich Partien/Züge, nicht für Tabellen/Wertungen.

Quellen werden als Notiz/Link referenziert; kein langer Fremdtext wird kopiert.

## Technische Schnittstellen (Skizze, noch nicht angelegt)
Vorgeschlagene, format-neutrale Datenträgertypen in Application/Domain. Bewusst
schlank gehalten; produktive Parser-Komplexität folgt erst mit Fixtures + Tests.

```csharp
// Ergebnis eines Importvorgangs, inkl. toleranter Fehlersammlung.
public sealed record ImportResult(
    IReadOnlyList<PlayerImportRecord> Players,
    IReadOnlyList<PairingImportRecord> Pairings,
    IReadOnlyList<ResultImportRecord> Results,
    IReadOnlyList<string> Warnings,
    IReadOnlyList<string> Errors)
{
    public bool Success => Errors.Count == 0;
}

public sealed record PlayerImportRecord(
    int? StartingRank, string Name, string? FideId, string? Federation,
    int? FideElo, int? Dwz, char? Sex, string? BirthDate, string? Club);

public sealed record PairingImportRecord(
    int Round, int Board, int? WhiteStartingRank, int? BlackStartingRank, bool IsBye);

public sealed record ResultImportRecord(
    int Round, int Board, string RawResultToken); // z.B. "1-0", "½-½", "+/-", "bye"

// Profil für den Export (Format + Umfang).
public sealed record ExportProfile(
    ExportFormat Format, bool IncludePlayers, bool IncludePairings,
    bool IncludeStandings, bool IncludeGames);

public enum ExportFormat { Csv, Excel, Trf, Pgn }
```

## Architektur-Anbindung (geplant)
- Import/Export liegt in `Application` (Orchestrierung) mit reinen Codecs in `Domain`.
- Vorhandene Bausteine als Referenz: `PlayerCsvCodec`, `TournamentExportFormatter`.
- Adapter-Schnittstellen z.B. `ITournamentImporter` / `ITournamentExporter` je Format.

## Teststrategie
- Synthetische Fixture-Dateien (kleine, frei erfundene Turniere) im Testprojekt.
- Round-Trip-Tests (Export → Import → Vergleich) je Format.
- Keine Netzwerkzugriffe im CI-/Gate-Pfad.

## Nächste konkrete Schritte
1. CSV-Teilnehmerimport-Spaltenschema festlegen und Fixture anlegen.
2. `ImportResult`/`*ImportRecord` als minimale Typen in Application anlegen (mit Tests).
3. TRF-Feldanalyse als separate Notiz; Mapping zu den obigen Records dokumentieren.
