using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

/// <summary>
/// Golden-Turnier B: 7 Spieler (ungerade), 5 Runden, in jeder Partie gewinnt Weiß.
/// Schwerpunkt: Freilos-Regeln. Jede Runde vergibt ein pairing-allocated bye (PAB).
///
/// Erwartungswerte von Hand aus C.04.3 (Fassung ab 01.02.2026) hergeleitet, jede Runde
/// unabhängig gegen bbpPairings 6.0.0 gegengeprüft. Siehe docs/FIDE_DUTCH_REFERENCE.md.
///
/// Freilos-Verlauf: R1→7, R2→6, R3→4, R4→3, R5→5. Kein Spieler bekommt zwei
/// (C.04.1 Art. 4 / [C2], Art. 2.1.2); 1 und 2 bekommen als Einzige nie eins.
/// </summary>
public sealed class FideDutchGoldenTournamentBTests
{
    private const int PlayerCount = 7;

    // ---------------------------------------------------------------------------------------
    // RUNDE 1 — 7 Spieler, alle 0 Punkte, ein homogenes Bracket, MaxPairs = 3.
    // Art. 3.2: S1 = {1,2,3}, S2 = {4,5,6,7}. Art. 3.3.1 -> 1-4, 2-5, 3-6.
    // Spieler 7 bleibt ungepaart, floatet ab und erhält das Freilos (Art. 1.9.1: höchstens einer
    // floatet aus dem letzten Bracket ab und bekommt das PAB). [C5] greift nicht — alle 0 Punkte.
    // Farben über Art. 5.2.5 (in R1 gibt es keine Präferenzen): ungerade Startnummer des höher
    // Gesetzten -> Anfangsfarbe Weiß, sonst Gegenfarbe.
    // ---------------------------------------------------------------------------------------
    [Fact]
    public void RoundOne_OddField_LowestPlayerOfBottomHalfGetsBye()
    {
        var tournament = CreateTournament();

        var round = CreateStrategy().GenerateNextRound(tournament);

        AssertPairings(round,
            Game(1, 4),
            Game(5, 2),
            Game(3, 6),
            Bye(7));
    }

    // ---------------------------------------------------------------------------------------
    // RUNDE 2 — Punkte: 1,3,5,7 = 1.0 (7 durch das Freilos!) | 2,4,6 = 0.
    //
    // Das Freilos zählt voll (C.04.1 Art. 3: "so viele Punkte wie für einen Sieg"), gibt aber
    // KEINE Farbe. Spieler 7 hat daher 1.0 Punkte und trotzdem keine Farbhistorie -> überhaupt
    // keine Farbpräferenz (Art. 1.7.3 setzt eine Vorpartie voraus).
    //
    // Bracket 1 (1.0): {1,3,5,7} -> S1 = {1,3}, S2 = {5,7} -> 1-5, 3-7, beide rematchfrei.
    //   1-5: beide stark Schwarz -> Art. 5.2.4, der höher Gesetzte (1) bekommt Schwarz.
    //   3-7: 3 stark Schwarz, 7 ohne Präferenz -> Art. 5.2.1 erfüllt "beide": 3 Schwarz, 7 Weiß.
    // Bracket 2 (0): {2,4,6}, MaxPairs = 1 -> S1 = {2}, S2 = {4,6} -> 2-4; 6 floatet ab -> Freilos.
    //   [C2]: 6 hatte noch kein Freilos. Spieler 7 ist ab jetzt gesperrt.
    // ---------------------------------------------------------------------------------------
    [Fact]
    public void RoundTwo_ByePlayerHasPointsButNoColourHistory_AndCannotGetSecondBye()
    {
        var tournament = CreateTournament();
        PlayRound(tournament, CreateStrategy());

        var round = CreateStrategy().GenerateNextRound(tournament);

        AssertPairings(round,
            Game(5, 1),
            Game(7, 3),
            Game(2, 4),
            Bye(6));
    }

    // ---------------------------------------------------------------------------------------
    // RUNDE 3 — Punkte: 5,7 = 2.0 | 1,2,3,6 = 1.0 | 4 = 0.
    // Bracket 1 (2.0): {5,7} -> 5-7 rematchfrei. 5 ist ABSOLUT Schwarz (WW), 7 stark Schwarz.
    //   Nicht beide absolut -> [C3] greift nicht. Art. 5.2.2 gibt der stärkeren Präferenz recht:
    //   5 bekommt Schwarz, 7 Weiß.
    // Bracket 2 (1.0): {1,2,3,6} -> S1 = {1,2}, S2 = {3,6} -> 1-3, 2-6.
    // Bracket 3 (0): {4} allein -> Freilos. [C5] ist erfüllt: 4 hat die niedrigste Punktzahl.
    // ---------------------------------------------------------------------------------------
    [Fact]
    public void RoundThree_ByeGoesToTheLowestScoringPlayer_PerC5()
    {
        var tournament = CreateTournament();
        var strategy = CreateStrategy();
        PlayRound(tournament, strategy);
        PlayRound(tournament, strategy);

        var round = strategy.GenerateNextRound(tournament);

        AssertPairings(round,
            Game(7, 5),
            Game(1, 3),
            Game(6, 2),
            Bye(4));
    }

    // ---------------------------------------------------------------------------------------
    // RUNDE 4 — der lehrreichste Fall dieses Turniers.
    //
    // Punkte: 7 = 3.0 | 1,5,6 = 2.0 | 2,3,4 = 1.0.
    // Farben: 1 = WBW (stark Schwarz) · 2 = BWB (stark Weiß) · 5 = WWB (stark Schwarz)
    //         6 = B,-,W (mild Schwarz) · 7 = -,WW (ABSOLUT Schwarz) · 4 = BB,- (ABSOLUT Weiß)
    //         3 = WBB -> Differenz nur -1, aber ZWEIMAL SCHWARZ ZULETZT -> ABSOLUT Weiß!
    //
    // Die 1.0-Gruppe {2,3,4} ist dadurch VOLLSTÄNDIG UNPAARBAR:
    //   3-4 verboten ([C3]: beide absolut Weiß, beide Nicht-Topscorer — R4 ist nicht die
    //       Schlussrunde, es gibt also nach Art. 1.8 keine Topscorer)
    //   2-4 Rematch aus R2 ([C1])
    //   2-3 ließe 4 mit dem Freilos zurück — [C2] sperrt 4, er hatte in R3 bereits eins.
    // Also muss die 2.0-Gruppe zwei Spieler abfloaten lassen, obwohl sie sich selbst vollständig
    // paaren könnte ([C4] Art. 2.2.1 schlägt [C6]).
    //
    // Bracket 2 (2.0 + MDP 7): {7 | 1,5,6}. 7 kann nur gegen 1 oder 6 (5 ist Rematch).
    //   Art. 4.2 würde 7-1 zuerst liefern. Es gewinnt aber 7-6 wegen [C13]:
    //   Bei beiden Varianten bekommt genau einer seine Präferenz nicht ([C12] = 1), aber bei 7-1
    //   wäre das Spieler 1 mit STARKER Präferenz ([C13] = 1), bei 7-6 nur Spieler 6 mit MILDER
    //   ([C13] = 0). [C13] entscheidet.
    //   -> 7-6 gepaart, 1 und 5 floaten ab.
    // Bracket 3 (1.0 + MDPs 1,5): {1,5 | 2,3,4} -> 1-2, 5-4, Freilos für 3 ([C2]: 3 ist frei).
    //
    // WARNUNG: Die erste Handherleitung dieser Runde war FALSCH (1-7, 6-5, 4-3, Freilos 2) — beide
    // Fehler oben (Einstufung von Spieler 3 und [C13]) waren die Ursache. Aufgefallen nur durch
    // die Gegenprobe gegen bbpPairings 6.0.0.
    // ---------------------------------------------------------------------------------------
    [Fact]
    public void RoundFour_AbsoluteByTwoLatestRoundsRule_MakesBottomBracketUnpairable_AndC13Decides()
    {
        var tournament = CreateTournament();
        var strategy = CreateStrategy();
        PlayRound(tournament, strategy);
        PlayRound(tournament, strategy);
        PlayRound(tournament, strategy);

        var round = strategy.GenerateNextRound(tournament);

        AssertPairings(round,
            Game(6, 7),
            Game(2, 1),
            Game(4, 5),
            Bye(3));
    }

    // ---------------------------------------------------------------------------------------
    // RUNDE 5 — Schlussrunde. Punkte: 6,7 = 3.0 | 1,2,3,4,5 = 2.0.
    //
    // Topscorer (Art. 1.8, gilt nur in der Schlussrunde): über 50 % von 4.0, also über 2.0 -> {6,7}.
    // 6 und 7 haben in R4 gegeneinander gespielt -> [C1] verbietet die Spitzenpaarung, beide floaten ab.
    //
    // Bracket 2 (2.0 + MDPs 6,7): 7 Spieler -> 3 Partien + 1 Freilos.
    //   Spieler 1 hat bereits gegen 2, 3, 4 UND 5 gespielt — er kann NUR noch gegen 6 oder 7.
    //   [C2] lässt für das Freilos nur 1, 2 oder 5 zu (3, 4, 6, 7 hatten schon eins).
    //   Art. 4.2 liefert zuerst 6-1, 7-2 (Rest 3-4, Freilos 5) — dabei bekämen 2 und 4 ihre
    //   Präferenz nicht ([C12] = 2). Die nächste gültige Transposition 6-1, 7-4 (Rest 2-3,
    //   Freilos 5) erreicht [C12] = 0: JEDER bekommt seine Farbe. Das ist das Minimum, also gewinnt
    //   dieser Kandidat.
    //     6-1: 6 absolut Schwarz, 1 mild Weiß -> Art. 5.2.1 erfüllt beide.
    //     7-4: 7 stark Schwarz, 4 stark Weiß  -> beide erfüllt.
    //     2-3: 2 mild Schwarz, 3 absolut Weiß -> beide erfüllt.
    // ---------------------------------------------------------------------------------------
    [Fact]
    public void RoundFive_FinalRound_PicksCandidateWhereEveryPlayerGetsTheirColour_PerC12()
    {
        var tournament = CreateTournament();
        var strategy = CreateStrategy();
        PlayRound(tournament, strategy);
        PlayRound(tournament, strategy);
        PlayRound(tournament, strategy);
        PlayRound(tournament, strategy);

        var round = strategy.GenerateNextRound(tournament);

        AssertPairings(round,
            Game(1, 6),
            Game(4, 7),
            Game(3, 2),
            Bye(5));
    }

    /// <summary>
    /// [C2] (Art. 2.1.2) / C.04.1 Art. 4: Kein Spieler erhält über das ganze Turnier ein zweites
    /// Freilos. Bei 7 Spielern und 5 Runden werden fünf verschiedene Spieler bedient.
    /// </summary>
    [Fact]
    public void OverFiveRounds_NoPlayerEverReceivesASecondBye_PerC2()
    {
        var tournament = CreateTournament();
        var strategy = CreateStrategy();
        var byeRecipients = new List<int>();

        for (var round = 0; round < 5; round++)
        {
            var next = strategy.GenerateNextRound(tournament);
            byeRecipients.Add(next.Pairings
                .Where(pairing => pairing.IsBye)
                .Select(pairing => RankOf(pairing.WhitePlayerId))
                .Single());
            CompleteAndAdd(tournament, next);
        }

        Assert.Equal(byeRecipients.Count, byeRecipients.Distinct().Count());
        Assert.Equal(new[] { 7, 6, 4, 3, 5 }, byeRecipients);
    }

    private static ISwissPairingStrategy CreateStrategy() => new FideDutchPairingStrategy();

    private static TournamentState CreateTournament()
    {
        var tournament = new TournamentState
        {
            Name = "FIDE Dutch Golden B",
            Settings = new TournamentSettings
            {
                Format = TournamentFormat.Swiss,
                PairingStrategy = SwissPairingStrategyKind.FideDutch,
                SwissInitialColour = ChessColor.White,
                PlannedRounds = 5
            }
        };

        for (var index = 1; index <= PlayerCount; index++)
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

    private static void PlayRound(TournamentState tournament, ISwissPairingStrategy strategy)
        => CompleteAndAdd(tournament, strategy.GenerateNextRound(tournament));

    /// <summary>Trägt die Runde ins Turnier ein; Weiß gewinnt jede Partie, Freilose bleiben Freilose.</summary>
    private static void CompleteAndAdd(TournamentState tournament, TournamentRound round)
    {
        tournament.Rounds.Add(round with
        {
            Pairings = round.Pairings
                .Select(pairing => pairing.IsBye ? pairing : pairing with { Result = new GameResult(GameResultKind.WhiteWin) })
                .ToList(),
            ResultStatus = RoundResultStatus.Complete
        });
    }

    private static string Game(int white, int black) => $"{white} - {black}";

    private static string Bye(int player) => $"{player} - bye";

    private static void AssertPairings(TournamentRound round, params string[] expected)
    {
        Assert.Equal(
            expected.Select((text, index) => $"Brett {index + 1}: {text}").ToArray(),
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
            : Enumerable.Range(1, PlayerCount).First(rank => PlayerId(rank) == playerId.Value);
    }
}
