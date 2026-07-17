using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

/// <summary>
/// Golden-Turnier A: 8 Spieler, 5 Runden, in jeder Partie gewinnt Weiß.
///
/// Die erwarteten Paarungen sind NICHT aus der Implementierung übernommen, sondern von Hand aus
/// dem FIDE-Regeltext hergeleitet (Fassung gültig ab 01.02.2026, siehe
/// <c>docs/FIDE_DUTCH_REFERENCE.md</c>). Jede Runde dokumentiert ihre Herleitung mit
/// Artikelnummern. Damit prüft dieser Test die REGEL und nicht den Code — ein Golden-Test, dessen
/// Erwartungswerte aus dem eigenen Output stammen, würde nur einfrieren, was der Code zufällig tut.
///
/// Startnummern (TPN) = StartingRank 1..8, absteigende Spielstärke (C.04.2 Art. 2.2).
/// initial-colour = Weiß (C.04.3 Art. 5.1; im Projekt <c>TournamentSettings.SwissInitialColour</c>).
///
/// GEGENPROBE (2026-07-16): Die Handherleitung für Runde 3 wurde unabhängig gegen
/// <c>bbpPairings 6.0.0</c> geprüft (erschienen 2026-02-01, dem Inkrafttreten der neuen Fassung;
/// Engine hinter dem FIDE-endorsed SwissSys). Ergebnis: alle vier Paare und alle acht Farben
/// identisch. C.04.2 Art. 1.4 verlangt ausdrücklich, dass zugelassene Programme zu identischen
/// Paarungen kommen — der Abgleich ist damit der von der Regel selbst definierte Maßstab.
/// Bestätigt wurden dabei insbesondere die zwei Punkte mit dem höchsten Irrtumsrisiko:
/// die Absteigerwahl nach [C7] und die Sortierung der Transpositionen nach Art. 4.2.
/// Reproduzierbar über <c>tmp/build-dutch-trf.ps1</c> + <c>tmp/GEGENTEST-ANLEITUNG.md</c>
/// (nicht versioniert, tmp/ ist gitignored).
/// </summary>
public sealed class FideDutchGoldenTournamentATests
{
    // ---------------------------------------------------------------------------------------
    // RUNDE 1
    //
    // Alle 8 Spieler haben 0 Punkte -> eine einzige Punktgruppe, homogenes Bracket,
    // M0 = 0 (C.04.3 Art. 3.1), MaxPairs = 4.
    // Art. 3.2: S1 = die ersten MaxPairs Spieler nach TPN = {1,2,3,4}; S2 = Rest = {5,6,7,8}.
    // Art. 3.3.1: erster aus S1 gegen ersten aus S2 usw. -> 1-5, 2-6, 3-7, 4-8.
    // Art. 3.4: keine Rematches ([C1]), keine Byes ([C2]); in Runde 1 hat niemand Farbhistorie,
    //           also hat niemand eine Farbpräferenz (Art. 1.7.3 setzt eine Vorpartie voraus)
    //           -> [C12]/[C13] sind trivial erfüllt. Kandidat ist perfekt, sofort angenommen.
    //
    // Farben (Art. 5.2): 5.2.1-5.2.4 greifen mangels Präferenzen nicht. Es entscheidet 5.2.5:
    //   Hat der höher gesetzte Spieler eine UNGERADE TPN, erhält er die initial-colour (Weiß),
    //   sonst die Gegenfarbe (Schwarz).
    //   Brett 1-5: höher gesetzt = TPN 1 (ungerade) -> 1 Weiß.
    //   Brett 2-6: höher gesetzt = TPN 2 (gerade)   -> 2 Schwarz, also 6 Weiß.
    //   Brett 3-7: TPN 3 ungerade -> 3 Weiß.
    //   Brett 4-8: TPN 4 gerade   -> 4 Schwarz, also 8 Weiß.
    //
    // Brettreihenfolge (C.04.2 Art. 3.6): alle Punktzahlen gleich -> nach niedrigster TPN.
    // ---------------------------------------------------------------------------------------
    [Fact]
    public void RoundOne_EightPlayers_MatchesHandDerivedFidePairing()
    {
        var tournament = CreateTournament();

        var round = CreateStrategy().GenerateNextRound(tournament);

        AssertPairings(round,
            (1, 5),
            (6, 2),
            (3, 7),
            (8, 4));
    }

    // ---------------------------------------------------------------------------------------
    // RUNDE 2
    //
    // Ergebnisse R1 (Weiß gewinnt): 1>5, 6>2, 3>7, 8>4.
    // Punkte: 1,3,6,8 = 1.0 | 2,4,5,7 = 0.
    // Farbdifferenz: 1,3,6,8 = +1 (starke Präferenz Schwarz, Art. 1.7.2);
    //                2,4,5,7 = -1 (starke Präferenz Weiß).
    //
    // Bracket 1 (1.0): {1,3,6,8}, homogen, MaxPairs = 2.
    //   Art. 3.2: S1 = {1,3}, S2 = {6,8}. Art. 3.3.1 -> 1-6, 3-8. Keine Rematches ([C1]).
    //   Alle vier wollen Schwarz -> in jedem Paar bekommt einer seine Präferenz nicht.
    //   [C12]/[C13] = 2 ist das erreichbare Minimum; die Transposition S2 = (8,6) ergibt
    //   denselben Wert. Bei Gleichstand gewinnt der ZUERST erzeugte Kandidat (Art. 3.8)
    //   -> 1-6, 3-8.
    //   Farben (Art. 5.2): 5.2.1 unmöglich (beide wollen Schwarz); 5.2.2 beide gleich stark;
    //     5.2.3 greift nicht (beide hatten in R1 Weiß, nie unterschiedliche Farben);
    //     5.2.4 entscheidet: der höher gesetzte Spieler bekommt seine Präferenz.
    //     1-6 -> TPN 1 höher -> 1 Schwarz, 6 Weiß.  3-8 -> TPN 3 höher -> 3 Schwarz, 8 Weiß.
    //
    // Bracket 2 (0): {2,4,5,7}, homogen, MaxPairs = 2.
    //   S1 = {2,4}, S2 = {5,7} -> 2-5, 4-7. Keine Rematches ([C1]: 2 spielte 6, 5 spielte 1,
    //   4 spielte 8, 7 spielte 3).
    //   Alle vier wollen Weiß -> Art. 5.2.4: höher gesetzter bekommt Weiß.
    //     2-5 -> 2 Weiß.  4-7 -> 4 Weiß.
    //
    // Brettreihenfolge (C.04.2 Art. 3.6): erst die 1.0-Paare (nach niedrigster TPN), dann die 0-Paare.
    // ---------------------------------------------------------------------------------------
    [Fact]
    public void RoundTwo_AfterWhiteWinsEverywhere_MatchesHandDerivedFidePairing()
    {
        var tournament = CreateTournament();
        PlayRound(tournament, CreateStrategy());

        var round = CreateStrategy().GenerateNextRound(tournament);

        AssertPairings(round,
            (6, 1),
            (8, 3),
            (2, 5),
            (4, 7));
    }

    // ---------------------------------------------------------------------------------------
    // RUNDE 3  —  der fachlich interessanteste Fall dieses Turniers
    //
    // Ergebnisse R2 (Weiß gewinnt): 6>1, 8>3, 2>5, 4>7.
    // Punkte: 6,8 = 2.0 | 1,2,3,4 = 1.0 | 5,7 = 0.
    // Farbhistorie: 6,8 = W,W -> Differenz +2 UND zweimal gleiche Farbe -> ABSOLUTE Präferenz
    //               Schwarz (Art. 1.7.1). 5,7 = B,B -> ABSOLUTE Präferenz Weiß.
    //               1,3 = W,B -> Differenz 0, zuletzt Schwarz -> milde Präferenz Weiß (Art. 1.7.3).
    //               2,4 = B,W -> Differenz 0, zuletzt Weiß -> milde Präferenz Schwarz.
    // Bisherige Gegner: 1:{5,6} 2:{6,5} 3:{7,8} 4:{8,7} 5:{1,2} 6:{2,1} 7:{3,4} 8:{4,3}.
    //
    // Bracket 1 (2.0): {6,8}. Die einzige mögliche Paarung wäre 6-8 — aber beide sind
    //   Nicht-Topscorer (Art. 1.8 greift erst in der Schlussrunde) mit derselben ABSOLUTEN
    //   Farbpräferenz (Schwarz). [C3] (Art. 2.1.3) verbietet das ausdrücklich.
    //   -> MaxPairs = 0, beide floaten ab.
    //
    // Bracket 2 (1.0 + MDPs 6,8): {6,8 | 1,2,3,4}, HETEROGEN, M0 = 2.
    //   Naiv wären 3 Paare möglich. Das ist aber verboten: Bliebe Bracket 3 = {5,7}, so müssten
    //   5 und 7 gegeneinander — beide ABSOLUT Weiß, also wieder [C3]. Dann gäbe es für die
    //   restlichen Spieler überhaupt keine regelkonforme Paarung mehr, was das
    //   COMPLETION-Kriterium [C4] (Art. 2.2.1) verletzt. [C4] ist absolut und schlägt [C6]
    //   ("Zahl der Downfloater minimieren"). Bracket 2 MUSS also zwei Spieler abfloaten lassen.
    //   [C7] (Art. 2.4.2): Downfloater mit möglichst NIEDRIGER Punktzahl -> es floaten zwei
    //   Residents (1.0), nicht die MDPs (2.0). Beide MDPs werden gepaart (M1 = 2).
    //
    //   BSN-Vergabe (Art. 4.1, Reihenfolge nach Art. 1.2): 6->1, 8->2, 1->3, 2->4, 3->5, 4->6.
    //   S1 = {6,8}, S2 = {1,2,3,4}. Transpositionen von S2 werden nach dem lexikografischen
    //   Wert der ersten N1 = 2 BSNs sortiert (Art. 4.2):
    //     (3,4) 6-1 ✗[C1]   (3,5) 6-1 ✗   (3,6) 6-1 ✗
    //     (4,3) 6-2 ✗[C1]   (4,5) 6-2 ✗   (4,6) 6-2 ✗
    //     (5,3) 6-3, 8-1 ✓  <- erster gültiger Kandidat
    //   Rest = {2,4} -> beide Downfloater (siehe [C4] oben).
    //   [C8] (Art. 2.4.3) ist erfüllt: Bracket 3 = {5,7,2,4} ist paarbar (siehe unten).
    //
    //   Farben: 6-3 -> 6 absolut Schwarz, 3 mild Weiß -> Art. 5.2.1 erfüllt BEIDE: 3 Weiß, 6 Schwarz.
    //           8-1 -> 8 absolut Schwarz, 1 mild Weiß -> beide erfüllt: 1 Weiß, 8 Schwarz.
    //
    // Bracket 3 (0 + MDPs 2,4): {2,4 | 5,7}, heterogen, M0 = 2, MaxPairs = 2.
    //   BSN: 2->1, 4->2, 5->3, 7->4. S1 = {2,4}, S2 = {5,7}.
    //   Art. 3.3.1 -> 2-5 ✗[C1] (R2: 2 schlug 5). Transposition (4,3) -> 2-7, 4-5:
    //     2 spielte {6,5} ✓, 4 spielte {8,7} ✓, 7 spielte {3,4} ✓, 5 spielte {1,2} ✓. Gültig.
    //   [C3] unkritisch: 2 und 4 haben nur MILDE Präferenzen.
    //   Farben: 2-7 -> 2 mild Schwarz, 7 absolut Weiß -> Art. 5.2.1 erfüllt beide: 7 Weiß, 2 Schwarz.
    //           4-5 -> 4 mild Schwarz, 5 absolut Weiß -> beide erfüllt: 5 Weiß, 4 Schwarz.
    //
    // Brettreihenfolge (C.04.2 Art. 3.6): höchste Punktzahl im Paar, dann Punktsumme, dann
    //   niedrigste TPN. Paare (1,8) und (3,6) haben je Höchstwert 2.0 und Summe 3.0
    //   -> niedrigste TPN entscheidet: (1,8) vor (3,6). Danach (2,7) vor (4,5).
    // ---------------------------------------------------------------------------------------
    [Fact]
    public void RoundThree_AbsoluteColourPreferenceBlocksTopBracket_ForcesDoubleFloatPerC4()
    {
        var tournament = CreateTournament();
        var strategy = CreateStrategy();
        PlayRound(tournament, strategy);
        PlayRound(tournament, strategy);

        var round = strategy.GenerateNextRound(tournament);

        AssertPairings(round,
            (1, 8),
            (3, 6),
            (7, 2),
            (5, 4));
    }

    // ---------------------------------------------------------------------------------------
    // RUNDE 4
    //
    // Ergebnisse R3: 1>8, 3>6, 7>2, 5>4.
    // Punkte: 1,3,6,8 = 2.0 | 2,4,5,7 = 1.0.
    // Farben: 1,3 = WBW und 6,8 = WWB -> Differenz +1 -> starke Präferenz Schwarz (Art. 1.7.2).
    //         2,4 = BWB und 5,7 = BBW -> Differenz -1 -> starke Präferenz Weiß.
    // Gegner: 1:{5,6,8} 2:{6,5,7} 3:{7,8,6} 4:{8,7,5} 5:{1,2,4} 6:{2,1,3} 7:{3,4,2} 8:{4,3,1}.
    //
    // Bracket 1 (2.0): {1,3,6,8}, homogen, MaxPairs = 2. S1 = {1,3}, S2 = {6,8}.
    //   Art. 3.3.1 -> 1-6 ✗[C1]. Transposition (8,6) -> 1-8 ✗[C1] (R3). Beide Transpositionen
    //   scheitern, also Exchange (Art. 4.3). Ergebnis in jedem Fall: 1-3 und 6-8 — es ist die
    //   einzige rematchfreie Aufteilung, denn 1 und 3 haben beide schon gegen 6 UND 8 gespielt.
    //   [C3] unkritisch: alle vier haben nur STARKE, keine absoluten Präferenzen.
    //   Farben: beide Paare wollen dieselbe Farbe; Art. 5.2.3 greift nicht (identische Farbfolgen),
    //   also entscheidet Art. 5.2.4 — der höher Gesetzte bekommt seine Präferenz:
    //   1 bekommt Schwarz (3 Weiß), 6 bekommt Schwarz (8 Weiß).
    //
    // Bracket 2 (1.0): {2,4,5,7}, homogen. S1 = {2,4}, S2 = {5,7}.
    //   2-5 ✗[C1] (R2), 2-7 ✗[C1] (R3) -> beide Transpositionen scheitern -> Exchange.
    //   Erster Exchange nach Art. 4.3: S1 = {2,5}, S2 = {4,7} -> 2-4 ✓, 5-7 ✓.
    //   Farben wieder über Art. 5.2.4: 2 bekommt Weiß, 5 bekommt Weiß.
    //
    // GEGENPROBE bbpPairings 6.0.0: identisch, inkl. Farben. Die Checkliste bestätigt zusätzlich
    // die Float-Buchführung aus R3 (1,3,5,7 = Upfloat, 2,4,6,8 = Downfloat).
    // ---------------------------------------------------------------------------------------
    [Fact]
    public void RoundFour_OnlyRematchFreeSplitRemains_MatchesHandDerivedFidePairing()
    {
        var tournament = CreateTournament();
        var strategy = CreateStrategy();
        PlayRound(tournament, strategy);
        PlayRound(tournament, strategy);
        PlayRound(tournament, strategy);

        var round = strategy.GenerateNextRound(tournament);

        AssertPairings(round,
            (3, 1),
            (8, 6),
            (2, 4),
            (5, 7));
    }

    // ---------------------------------------------------------------------------------------
    // RUNDE 5 — Schlussrunde. Entscheidet sich an der Float-Historie ([C20]).
    //
    // Ergebnisse R4: 3>1, 8>6, 2>4, 5>7.
    // Punkte: 3,8 = 3.0 | 1,2,5,6 = 2.0 | 4,7 = 1.0.
    // Farben: 3 = WBWW und 8 = WWBW -> Differenz +2 -> ABSOLUT Schwarz.
    //         5 = BBWW -> zweimal Weiß zuletzt -> ABSOLUT Schwarz.
    //         6 = WWBB -> zweimal Schwarz zuletzt -> ABSOLUT Weiß (obwohl Differenz 0!).
    //         4 = BWBB und 7 = BBWB -> Differenz -2 -> ABSOLUT Weiß.
    //         1 = WBWB -> mild Weiß. 2 = BWBW -> mild Schwarz.
    //
    // ERSTMALS greift Art. 1.8: Topscorer sind Spieler mit über 50 % der maximal möglichen
    // Punktzahl BEI DER AUSLOSUNG DER SCHLUSSRUNDE, hier also über 2.0 -> {3, 8}. Für sie gilt
    // [C3] nicht. In den Runden 1-4 gab es keine Topscorer.
    //
    // Bracket 1 (3.0): {3,8}. [C3] wäre hier kein Hindernis (beide sind Topscorer), aber 3 und 8
    //   haben in R2 bereits gegeneinander gespielt -> [C1]. MaxPairs = 0, beide floaten ab.
    //
    // Bracket 2 (2.0 + MDPs 3,8): {3,8 | 1,2,5,6}, heterogen.
    //   3 spielte {7,8,6,1}, 8 spielte {4,3,1,6} -> BEIDE können nur gegen 2 oder 5.
    //   Residents untereinander paarbar: nur 1-2 und 5-6 (1-5, 1-6, 2-5, 2-6 alles Rematches).
    //
    //   M1 = 2 (beide MDPs gepaart) scheidet aus: dann bliebe Rest {1,6}, nicht paarbar (R2), also
    //   floaten 1 und 6 ab -> Bracket 3 = {1,6,4,7}. Dort haben 6, 4 und 7 ALLE absolut Weiß und
    //   sind Nicht-Topscorer, 6 könnte also gegen niemanden -> keine regelkonforme Restpaarung,
    //   [C4] (Art. 2.2.1) verletzt. Also wird nur EIN MDP gepaart, der andere geht ins Limbo
    //   (Art. 3.2.4) und floatet ab.
    //
    //   Welcher? Beide Varianten sind bis [C17] EXAKT gleichauf: gleiche Paarzahl [C6], gleiche
    //   Downfloater-Punkte [C7] (3.0, 2.0), gleiches [C12]/[C13] (je 2 unerfüllte Präferenzen),
    //   keine Floats in R4 also [C14]/[C15] = 0.
    //
    //   Es entscheidet [C20] (Art. 2.4.15) — die Float-Historie:
    //     8 ist in R3 bereits ABGESTIEGEN, 3 ist AUFGESTIEGEN.
    //   Ließe man 8 erneut abfloaten, wäre das der zweite Abstieg binnen drei Runden. Genau das
    //   sollen [C18]-[C21] verhindern ("kein doppelter Absteiger"). Also wird 8 gepaart und 3
    //   floatet ab.
    //     -> MDP-Paarung 8-2, Rest {1,5,6} -> nur 5-6 paarbar, 1 floatet ab. Limbo {3} floatet ab.
    //
    // Bracket 3 (1.0 + MDPs 3,1): {3,1 | 4,7}.
    //   3 spielte 7 in R1 -> 3 muss gegen 4. Bleibt 1-7 ✓.
    //   [C3]: 3 ist Topscorer -> ausgenommen. 1 hat nur MILDE Präferenz -> kein Konflikt mit 7.
    //
    // Farben: 8-2 -> beide wollen Schwarz; Art. 5.2.2 gibt der STÄRKEREN Präferenz recht
    //           (8 absolut vs. 2 mild) -> 8 Schwarz, 2 Weiß.
    //         5-6 -> 5 absolut Schwarz, 6 absolut Weiß -> Art. 5.2.1 erfüllt beide: 6 Weiß, 5 Schwarz.
    //         3-4 -> 3 absolut Schwarz, 4 absolut Weiß -> beide erfüllt: 4 Weiß, 3 Schwarz.
    //         1-7 -> beide wollen Weiß; Art. 5.2.2 -> 7 (absolut) Weiß, 1 Schwarz.
    //
    // WARNUNG AN KÜNFTIGE BEARBEITER: Die erste Handherleitung dieser Runde war FALSCH (sie ergab
    // 2-3, 7-8, 6-5, 4-1). Der Fehler: [C18]-[C21] wurden als vage Feinjustierung abgetan und
    // übersprungen. Sie entscheiden diese Runde vollständig. Aufgefallen ist es nur durch die
    // Gegenprobe gegen bbpPairings 6.0.0 — eine Implementierung ohne [C18]-[C21] paart hier falsch.
    // ---------------------------------------------------------------------------------------
    [Fact]
    public void RoundFive_FinalRound_FloatHistoryDecidesWhichMdpIsPaired_PerC20()
    {
        var tournament = CreateTournament();
        var strategy = CreateStrategy();
        PlayRound(tournament, strategy);
        PlayRound(tournament, strategy);
        PlayRound(tournament, strategy);
        PlayRound(tournament, strategy);

        var round = strategy.GenerateNextRound(tournament);

        AssertPairings(round,
            (2, 8),
            (4, 3),
            (6, 5),
            (7, 1));
    }

    /// <summary>
    /// C.04.2 Art. 1.4: verschiedene Schiedsrichter und verschiedene zugelassene Programme müssen
    /// zu identischen Paarungen kommen. Zweiter Lauf mit identischer Eingabe = identisches Ergebnis.
    /// </summary>
    [Fact]
    public void SameInputRunTwice_ProducesIdenticalPairings_PerC0402Article14()
    {
        var first = CreateTournament();
        var second = CreateTournament();
        var strategy = CreateStrategy();
        PlayRound(first, strategy);
        PlayRound(first, strategy);
        PlayRound(second, strategy);
        PlayRound(second, strategy);

        var firstRound = strategy.GenerateNextRound(first);
        var secondRound = strategy.GenerateNextRound(second);

        Assert.Equal(Describe(firstRound), Describe(secondRound));
    }

    private static ISwissPairingStrategy CreateStrategy() => new FideDutchPairingStrategy();

    private static TournamentState CreateTournament()
    {
        var tournament = new TournamentState
        {
            Name = "FIDE Dutch Golden A",
            Settings = new TournamentSettings
            {
                Format = TournamentFormat.Swiss,
                PairingStrategy = SwissPairingStrategyKind.FideDutch,
                SwissInitialColour = ChessColor.White,
                PlannedRounds = 5
            }
        };

        for (var index = 1; index <= 8; index++)
        {
            tournament.Players.Add(new Player
            {
                Id = PlayerId(index),
                Name = $"Dutch Spieler {index}",
                StartingRank = index,
                Rating = new RatingProfile { ManualTwz = 2400 - index * 50 }
            });
        }

        return tournament;
    }

    private static Guid PlayerId(int startingRank) => Guid.Parse($"00000000-0000-0000-0000-{startingRank:000000000000}");

    /// <summary>Spielt die nächste Runde aus; Weiß gewinnt jede Partie.</summary>
    private static void PlayRound(TournamentState tournament, ISwissPairingStrategy strategy)
    {
        var round = strategy.GenerateNextRound(tournament);
        tournament.Rounds.Add(round with
        {
            Pairings = round.Pairings
                .Select(pairing => pairing.IsBye ? pairing : pairing with { Result = new GameResult(GameResultKind.WhiteWin) })
                .ToList(),
            ResultStatus = RoundResultStatus.Complete
        });
    }

    /// <summary>Prüft Bretter, Farben und Reihenfolge byte-genau anhand der Startnummern.</summary>
    private static void AssertPairings(TournamentRound round, params (int White, int Black)[] expected)
    {
        Assert.Equal(expected.Length, round.Pairings.Count);
        Assert.Equal(
            expected.Select((pair, index) => $"Brett {index + 1}: {pair.White} - {pair.Black}").ToArray(),
            Describe(round));
    }

    private static string[] Describe(TournamentRound round)
    {
        return round.Pairings
            .OrderBy(pairing => pairing.BoardNumber)
            .Select(pairing => pairing.IsBye
                ? $"Brett {pairing.BoardNumber}: {RankOf(pairing.WhitePlayerId)} - bye"
                : $"Brett {pairing.BoardNumber}: {RankOf(pairing.WhitePlayerId)} - {RankOf(pairing.BlackPlayerId)}")
            .ToArray();
    }

    private static int RankOf(Guid? playerId)
    {
        return playerId is null
            ? 0
            : Enumerable.Range(1, 8).First(rank => PlayerId(rank) == playerId.Value);
    }
}
