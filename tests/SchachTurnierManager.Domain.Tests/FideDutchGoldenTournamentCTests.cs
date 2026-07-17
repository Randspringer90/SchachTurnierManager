using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

/// <summary>
/// Golden-Turnier C: 8 Spieler, 5 Runden, Schwerpunkt kampflose Ergebnisse.
///
/// Bewusst als KONTRAST zu Golden-Turnier A gebaut: Runde 1 und 2 haben exakt dieselben Paarungen
/// und danach exakt dieselben Punktzahlen. Der einzige Unterschied ist, dass Brett 1 der zweiten
/// Runde kampflos gewertet wird (Spieler 1 erscheint nicht, 6 gewinnt kampflos). Ab Runde 3 laufen
/// die Turniere auseinander — allein deswegen.
///
/// Damit lassen sich drei Regeln isoliert prüfen, die sonst nie sichtbar werden:
///   C.04.2 Art. 3.4  Ungespielte Runden zählen NICHT für die Farbfolge; die Historie wird
///                    behandelt, als hätte die Runde nicht stattgefunden.
///   C.04.2 Art. 3.5  Zwei Teilnehmer, die nicht gegeneinander GESPIELT haben, dürfen später noch
///                    gepaart werden — die kampflose Begegnung sperrt [C1] also nicht.
///   [C2] Art. 2.1.2  Wer ohne zu spielen die volle Siegpunktzahl bekommt, erhält kein Freilos.
///                    (Das ist die "Integration mit kampflosen Ergebnissen" aus Issue #22.)
///
/// Erwartungswerte von Hand hergeleitet, jede Runde einzeln gegen bbpPairings 6.0.0 gegengeprüft.
/// Siehe docs/FIDE_DUTCH_REFERENCE.md. Ergänzt STM-FACH-001 (Forfeit-Verhalten), das nicht
/// regressieren darf.
/// </summary>
public sealed class FideDutchGoldenTournamentCTests
{
    private const int PlayerCount = 8;

    // ---------------------------------------------------------------------------------------
    // RUNDE 3 — der Kern dieses Turniers.
    //
    // Punkte nach R2 sind identisch zu Turnier A: 6,8 = 2.0 | 1,2,3,4 = 1.0 | 5,7 = 0.
    // Die Farbhistorie ist es NICHT:
    //   Turnier A: 6 = W,W -> Differenz +2 -> ABSOLUT Schwarz.
    //   Turnier C: 6 = W,(kampflos) -> die zweite Runde zählt nach Art. 3.4 nicht ->
    //              nur EINE Weißpartie -> Differenz +1 -> nur STARK Schwarz.
    //
    // Folge: In Turnier A war die Spitzengruppe {6,8} durch [C3] gesperrt (beide absolut Schwarz)
    // und musste komplett abfloaten. Hier ist 8 absolut Schwarz, 6 aber nur stark — [C3] verlangt
    // dieselbe ABSOLUTE Präferenz auf beiden Seiten und greift daher nicht. 6-8 wird gepaart.
    // Gleiche Punkte, gleiche Startnummern, andere Paarung — allein wegen des kampflosen Ergebnisses.
    //
    // Zusätzlich gilt Art. 3.5: 6 und 1 haben in R2 nicht GESPIELT, gelten also als noch nicht
    // begegnet und dürften erneut gepaart werden. [C1] sperrt sie nicht.
    //
    // Farben 6-8: beide wollen Schwarz -> Art. 5.2.2 gibt der stärkeren Präferenz recht ->
    //             8 (absolut) bekommt Schwarz, 6 Weiß.
    //
    // Die 0-Gruppe {5,7} ist wie in Turnier A durch [C3] blockiert (beide absolut Weiß), daher
    // muss die 1.0-Gruppe wieder zwei Spieler abfloaten lassen ([C4] schlägt [C6]).
    // ---------------------------------------------------------------------------------------
    [Fact]
    public void RoundThree_ForfeitedRoundIsExcludedFromColourSequence_SoTopBracketCanPair_PerArticle34()
    {
        var tournament = CreateTournament();
        var strategy = CreateStrategy();
        PlayRound(tournament, strategy);
        PlayRoundWithForfeitOnBoardOne(tournament, strategy);

        var round = strategy.GenerateNextRound(tournament);

        AssertPairings(round,
            (6, 8),
            (3, 1),
            (7, 2),
            (5, 4));
    }

    /// <summary>
    /// Direkter Nachweis des Unterschieds: dieselbe Ausgangslage, nur einmal mit gespieltem und
    /// einmal mit kampflosem Brett 1 in Runde 2 — und die Spitzenpaarung kippt.
    /// Turnier A (gespielt): 6 und 8 beide absolut Schwarz -> [C3] sperrt -> beide floaten ab.
    /// Turnier C (kampflos): 6 nur stark Schwarz -> 6-8 erlaubt.
    /// </summary>
    [Fact]
    public void RoundThree_ComparedToPlayedGame_ForfeitChangesTheTopBoardPairing()
    {
        var played = CreateTournament();
        var forfeited = CreateTournament();
        var strategy = CreateStrategy();

        PlayRound(played, strategy);
        PlayRound(played, strategy);
        PlayRound(forfeited, strategy);
        PlayRoundWithForfeitOnBoardOne(forfeited, strategy);

        var playedRound = strategy.GenerateNextRound(played);
        var forfeitedRound = strategy.GenerateNextRound(forfeited);

        // Bei gespieltem Brett 1 treffen 6 und 8 NICHT aufeinander, bei kampflosem schon.
        Assert.False(ContainsPair(playedRound, 6, 8));
        Assert.True(ContainsPair(forfeitedRound, 6, 8));
    }

    // ---------------------------------------------------------------------------------------
    // RUNDE 4 — Punkte: 6 = 3.0 | 3,8 = 2.0 | 1,2,4,5,7 = 1.0.
    //
    // Bracket 1 (3.0): {6} allein -> floatet ab.
    // Bracket 2 (2.0 + MDP 6): {6 | 3,8}. 6 kann nicht gegen 8 (Rematch R3) -> 6-3; 8 floatet ab.
    // Bracket 3 (1.0 + MDP 8): {8 | 1,2,4,5,7}.
    //   Art. 4.2 liefert zuerst 8-1. Es gewinnt aber 8-2 wegen [C13]:
    //   Bei 8-1 bliebe der Rest {2,4,5,7} — alle vier wollen Weiß, zwei gehen leer aus, und beide
    //   haben eine STARKE Präferenz ([C13] = 2). Bei 8-2 ist der Rest {1,4,5,7}; dort geht Spieler 1
    //   leer aus, dessen Präferenz nur MILD ist ([C13] = 1). [C12] ist in beiden Fällen 2 und
    //   entscheidet nicht — erst [C13] tut es.
    //   -> 8-2, Rest 1-4 (erzwungen: 4 kann nur noch gegen 1) und 5-7.
    // ---------------------------------------------------------------------------------------
    [Fact]
    public void RoundFour_StrongPreferenceCountsMoreThanMild_PerC13()
    {
        var tournament = CreateTournament();
        var strategy = CreateStrategy();
        PlayRound(tournament, strategy);
        PlayRoundWithForfeitOnBoardOne(tournament, strategy);
        PlayRound(tournament, strategy);

        var round = strategy.GenerateNextRound(tournament);

        AssertPairings(round,
            (3, 6),
            (2, 8),
            (4, 1),
            (5, 7));
    }

    // ---------------------------------------------------------------------------------------
    // RUNDE 5 — Schlussrunde. Punkte: 3,6 = 3.0 | 2,4,5,8 = 2.0 | 1,7 = 1.0.
    // Topscorer (Art. 1.8, nur in der Schlussrunde): über 2.0 -> {3, 6}.
    //
    // Spieler 7 ist der Engpass, an dem die ganze Runde hängt:
    //   7 hat gegen 3, 4, 2 und 5 gespielt -> [C1] sperrt diese vier.
    //   7 ist absolut Weiß; 1 und 8 sind es ebenfalls und sind Nicht-Topscorer -> [C3] sperrt beide.
    //   Bleibt einzig 6 — ein Topscorer, für den [C3] nicht gilt, und gegen den 7 noch nicht
    //   gespielt hat.
    // 7 kann also im gesamten Feld NUR gegen 6. Damit ist 6 gezwungen, über zwei Brackets hinweg
    // von 3.0 auf 1.0 abzufloaten. [C4] (Art. 2.2.1) erzwingt das.
    //
    // Danach ist auch 1 festgelegt: 1 hat gegen 5, 3 und 4 gespielt, gegen 7 und 8 sperrt [C3]
    // (alle drei absolut Weiß), und 6 ist für 7 reserviert -> 1 kann nur gegen 2.
    //
    // Bracket 1 (3.0): {3,6} -> 3-6 ist ein Rematch aus R4 -> beide floaten ab.
    // Bracket 2 (2.0 + MDPs 3,6): 3-4 und 5-8 werden gepaart; 6 und 2 floaten ab.
    // Bracket 3 (1.0 + MDPs 6,2): 6-7 und 2-1.
    //
    // Farben: 3-4 -> 3 absolut Schwarz, 4 mild Schwarz -> Art. 5.2.2: 3 Schwarz, 4 Weiß.
    //         5-8 -> 5 absolut Schwarz, 8 absolut Weiß -> Art. 5.2.1 erfüllt beide.
    //         6-7 -> 6 stark Schwarz, 7 absolut Weiß  -> beide erfüllt.
    //         2-1 -> 2 mild Schwarz, 1 absolut Weiß   -> beide erfüllt.
    // ---------------------------------------------------------------------------------------
    [Fact]
    public void RoundFive_FinalRound_OnlyLegalOpponentForcesTopscorerToFloatDownTwoBrackets()
    {
        var tournament = CreateTournament();
        var strategy = CreateStrategy();
        PlayRound(tournament, strategy);
        PlayRoundWithForfeitOnBoardOne(tournament, strategy);
        PlayRound(tournament, strategy);
        PlayRound(tournament, strategy);

        var round = strategy.GenerateNextRound(tournament);

        AssertPairings(round,
            (4, 3),
            (7, 6),
            (8, 5),
            (1, 2));
    }

    private static ISwissPairingStrategy CreateStrategy() => new FideDutchPairingStrategy();

    private static TournamentState CreateTournament()
    {
        var tournament = new TournamentState
        {
            Name = "FIDE Dutch Golden C",
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

    /// <summary>Spielt die nächste Runde regulär aus; Weiß gewinnt jede Partie.</summary>
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

    /// <summary>
    /// Wie <see cref="PlayRound"/>, aber Brett 1 wird kampflos für Weiß gewertet: Schwarz erscheint
    /// nicht. Weiß bekommt den vollen Punkt, gespielt wurde nichts.
    /// </summary>
    private static void PlayRoundWithForfeitOnBoardOne(TournamentState tournament, ISwissPairingStrategy strategy)
    {
        var round = strategy.GenerateNextRound(tournament);
        tournament.Rounds.Add(round with
        {
            Pairings = round.Pairings
                .Select(pairing => pairing.IsBye
                    ? pairing
                    : pairing with
                    {
                        Result = new GameResult(pairing.BoardNumber == 1
                            ? GameResultKind.WhiteForfeitWin
                            : GameResultKind.WhiteWin)
                    })
                .ToList(),
            ResultStatus = RoundResultStatus.Complete
        });
    }

    private static bool ContainsPair(TournamentRound round, int firstRank, int secondRank)
    {
        return round.Pairings.Any(pairing =>
            !pairing.IsBye &&
            ((RankOf(pairing.WhitePlayerId) == firstRank && RankOf(pairing.BlackPlayerId) == secondRank) ||
             (RankOf(pairing.WhitePlayerId) == secondRank && RankOf(pairing.BlackPlayerId) == firstRank)));
    }

    private static void AssertPairings(TournamentRound round, params (int White, int Black)[] expected)
    {
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
            : Enumerable.Range(1, PlayerCount).First(rank => PlayerId(rank) == playerId.Value);
    }
}
