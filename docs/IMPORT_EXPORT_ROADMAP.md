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
   - **Alle Turnierteilnehmer:** Der Export berechnet die Standings mit
     `includeInactive: true`. Zurückgezogene und pausierte Spieler bleiben damit im
     TRF erhalten, obwohl sie nach der STM-FACH-001-Withdrawal-Logik aus der
     sichtbaren Rangliste gefiltert werden — die FIDE-Spezifikation erwartet den
     vollständigen Teilnehmerkreis. Die Kopfzeilen 062/072 zählen konsistent die
     tatsächlich exportierten Spielerzeilen.
   - **Bewusste Scope-Grenzen (dokumentiert statt erfunden):**
     - Geburtsdatum (Position 70-79) bleibt aus PII-Minimierungsgründen leer
       (Spezifikation: nur "warning if wrong", nicht Pflichtfeld).
     - Turnier-Kopfzeilen ohne Datengrundlage in unserem Domainmodell (Ort 022,
       Föderation 032, Start-/Enddatum 042/052, Schiedsrichter 102, Rundendaten 132)
       werden ausgelassen statt mit Platzhaltern erfunden — `TournamentState` hat
       aktuell keine entsprechenden Felder. Sobald das Domainmodell belastbare Felder
       dafür besitzt, werden diese Zeilen ergänzt.
     - Name wird unverändert aus `Player.Name` übernommen; ohne strukturierte
       Vorname/Nachname-Trennung im Domainmodell ist eine korrekte
       "Nachname, Vorname"-Umformatierung nicht zuverlässig automatisierbar.
     - Eine FIDE-ID wird nur übernommen, wenn sie rein numerisch und höchstens 11
       Stellen lang ist; andernfalls bleibt das Feld leer, statt eine durch Kürzung
       verfälschte Kennung zu exportieren.
   - **Format-Härtung:** Zeilenenden sind CR gemäß Remark 1 der Spezifikation.
     Feldwerte werden positionssicher über einen Line-Builder geschrieben, der bei
     Feldüberlängen wirft, statt nachfolgende Spalten stillschweigend zu verschieben.
     Steuerzeichen aus Turnier- und Spielernamen werden vor dem Schreiben entfernt.
3. **Swiss-Manager / Chess-Results** — weit verbreitetes Ökosystem.
   - Chess-Results stellt Tabellen, Paarungen und Swiss-Manager-Dateien bereit.
   - Zunächst nur Format-Analyse; kein Live-Scrape, kein Reverse-Engineering binärer Formate ohne Quelle.
   - **Umgesetzt (STM-IE-002):** `SwissManagerCsvCodec` (Domain) exportiert/importiert
     das offizielle Swiss-Manager-CSV-Layout aus dem User's Guide, Anhang C:
     Header `No;Name;Title;FIDE-No;ID no;Rating nat;Rating int;Birth;Fed;Sex;Club`,
     komma-separiert. Zusätzlich importiert `TournamentExportFormatter.ImportTrf16Players`
     jetzt auch TRF16-Stammdatenzeilen zurück (Ergänzung zum reinen Export aus
     STM-IE-001) — das deckt den Chess-Results-Austausch ab, da Chess-Results TRF16
     liest/schreibt; ein gesondertes Chess-Results-Format wurde nicht zusätzlich gebaut.
     Endpoints: `GET/POST .../players/export-swissmanager.csv`,
     `POST .../players/import-swissmanager.csv`, `POST .../players/import-trf16`.
     WebApp-Bereich "Swiss-Manager / TRF16 (Spieler-Stammdaten)" im Import/Export-Card.
   - **Namensfeld:** Swiss-Manager unterstützt sowohl eine kombinierte `Name`-Spalte
     als auch getrennte Vor-/Nachname-Spalten; der Import akzeptiert beide Varianten
     und übernimmt damit den bereits bei TRF16 etablierten Grundsatz, keine eigene
     Vor-/Nachname-Split-Logik zu erfinden.
   - **Encoding-Toleranz:** `ImportTextDecoder` (Domain) versucht zuerst striktes
     UTF-8 (inkl. BOM-Erkennung) und fällt bei ungültigen Bytes auf Windows-1252
     zurück (`System.Text.Encoding.CodePages`), da ältere Swiss-Manager-Exporte
     Windows-1252-kodiert sein können. Live über die echte HTTP-API verifiziert
     (rohe Windows-1252-Bytes → korrekt dekodierter Umlautname in der API-Antwort).
   - **Fehlertoleranz:** Import sammelt Format-Fehler pro Zeile (`PlayerImportOutcome`)
     statt beim ersten Fehler abzubrechen; gültige Zeilen werden trotzdem übernommen.
   - **Bewusste Scope-Grenzen (dokumentiert statt erfunden):**
     - Nur Spieler-Stammdaten (Name, Rating, Föderation, FIDE-ID, Geburtsjahr, Verein,
       Titel, Geschlecht) — keine Paarungen/Ergebnisse (Issue-Anforderung).
     - `Birth` wird beim Export nur als Jahr geschrieben (PII-Minimierung, konsistent
       mit der TRF16-Entscheidung aus STM-IE-001); ein voller Tag/Monat wird beim
       Import toleriert, aber nicht persistiert, da `Player.BirthYear` nur ein Jahr kennt.
     - Swiss-Manager-Felder ohne Entsprechung im Domainmodell (`Type`, `Gr`, `Clubno`,
       `Team`) werden beim Export ausgelassen statt mit Platzhaltern erfunden.
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
