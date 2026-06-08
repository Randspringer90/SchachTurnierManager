using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

public sealed class PairingQualityAnalyzerTests
{
    [Fact]
    public void Analyze_CleanFirstRound_ReturnsGoodQuality()
    {
        var players = CreatePlayers(4);
        var tournament = CreateTournament(players);
        var round = new TournamentRound
        {
            RoundNumber = 1,
            Pairings = new[]
            {
                Pairing.Game(1, players[0].Id, players[3].Id),
                Pairing.Game(2, players[1].Id, players[2].Id)
            }
        };

        var report = new PairingQualityAnalyzer().Analyze(tournament, round);

        Assert.Equal(PairingQualitySeverity.Good, report.Severity);
        Assert.Equal(100, report.QualityScore);
        Assert.Equal(0, report.RematchCount);
        Assert.Equal(0, report.CrossScoreGroupPairingCount);
        Assert.Contains(report.Findings, finding => finding.Contains("Keine Wiederholung", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public void Analyze_FlagsRematchesAndCrossScoreGroups()
    {
        var players = CreatePlayers(4);
        var tournament = CreateTournament(players);
        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 1,
            Pairings = new[]
            {
                Pairing.Game(1, players[0].Id, players[1].Id) with { Result = new GameResult(GameResultKind.WhiteWin) },
                Pairing.Game(2, players[2].Id, players[3].Id) with { Result = new GameResult(GameResultKind.Draw) }
            }
        });

        var round = new TournamentRound
        {
            RoundNumber = 2,
            Pairings = new[]
            {
                Pairing.Game(1, players[0].Id, players[1].Id),
                Pairing.Game(2, players[2].Id, players[3].Id)
            }
        };

        var report = new PairingQualityAnalyzer().Analyze(tournament, round);

        Assert.Equal(PairingQualitySeverity.Critical, report.Severity);
        Assert.Equal(2, report.RematchCount);
        Assert.True(report.CrossScoreGroupPairingCount >= 1);
        Assert.True(report.QualityScore < 100);
        Assert.Contains(report.Boards, board => board.IsRematch && board.WhitePlayerId == players[0].Id && board.BlackPlayerId == players[1].Id);
    }

    [Fact]
    public void Analyze_FlagsThirdSameColorRisk()
    {
        var players = CreatePlayers(4);
        var tournament = CreateTournament(players);
        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 1,
            Pairings = new[]
            {
                Pairing.Game(1, players[0].Id, players[1].Id) with { Result = new GameResult(GameResultKind.Draw) },
                Pairing.Game(2, players[2].Id, players[3].Id) with { Result = new GameResult(GameResultKind.Draw) }
            }
        });
        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 2,
            Pairings = new[]
            {
                Pairing.Game(1, players[0].Id, players[2].Id) with { Result = new GameResult(GameResultKind.Draw) },
                Pairing.Game(2, players[1].Id, players[3].Id) with { Result = new GameResult(GameResultKind.Draw) }
            }
        });

        var round = new TournamentRound
        {
            RoundNumber = 3,
            Pairings = new[]
            {
                Pairing.Game(1, players[0].Id, players[3].Id),
                Pairing.Game(2, players[1].Id, players[2].Id)
            }
        };

        var report = new PairingQualityAnalyzer().Analyze(tournament, round);

        Assert.Equal(PairingQualitySeverity.Warning, report.Severity);
        Assert.Equal(1, report.ThirdSameColorRiskCount);
        Assert.Contains(report.Boards, board => board.WhitePlayerId == players[0].Id && board.WouldGiveWhiteThirdSameColor);
        Assert.Contains(report.Findings, finding => finding.Contains("Farbfolge", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public void Analyze_ReportsByeSeparately()
    {
        var players = CreatePlayers(5);
        var tournament = CreateTournament(players);
        var round = new TournamentRound
        {
            RoundNumber = 1,
            Pairings = new[]
            {
                Pairing.Game(1, players[0].Id, players[4].Id),
                Pairing.Game(2, players[1].Id, players[3].Id),
                Pairing.Bye(3, players[2].Id)
            }
        };

        var report = new PairingQualityAnalyzer().Analyze(tournament, round);

        Assert.Equal(1, report.ByeCount);
        Assert.Equal(2, report.GameCount);
        Assert.Contains(report.Boards, board => board.IsBye && board.WhitePlayerId == players[2].Id);
        Assert.Equal(PairingQualitySeverity.Notice, report.Severity);
    }

    private static TournamentState CreateTournament(IReadOnlyList<Player> players)
    {
        var tournament = new TournamentState
        {
            Name = "Pairing Quality",
            Settings = new TournamentSettings { Format = TournamentFormat.Swiss }
        };
        tournament.Players.AddRange(players);
        return tournament;
    }

    private static List<Player> CreatePlayers(int count)
    {
        return Enumerable.Range(1, count)
            .Select(index => new Player
            {
                Id = Guid.Parse($"00000000-0000-0000-0000-{index:000000000000}"),
                Name = $"Spieler {index}",
                StartingRank = index,
                Rating = new RatingProfile { ManualTwz = 2200 - index * 25 }
            })
            .ToList();
    }
}