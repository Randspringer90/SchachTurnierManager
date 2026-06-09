using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

public sealed class SwissPairingGoldenScenarioTests
{
    [Fact]
    public void SwissPairing_TwoRoundSixPlayerScenario_HasNoRematchesAndReadableQualityReport()
    {
        var tournament = CreateTournament(6);
        var engine = new SwissPairingEngine();
        var qualityAnalyzer = new PairingQualityAnalyzer();

        var firstRound = engine.GenerateNextRound(tournament);
        tournament.Rounds.Add(firstRound with
        {
            Pairings = firstRound.Pairings
                .Select(pairing => pairing.IsBye ? pairing : pairing with { Result = new GameResult(GameResultKind.WhiteWin) })
                .ToList()
        });

        var secondRound = engine.GenerateNextRound(tournament);
        var quality = qualityAnalyzer.Analyze(tournament, secondRound);

        Assert.Equal(0, quality.RematchCount);
        Assert.False(quality.HasCriticalIssues);
        Assert.InRange(quality.QualityScore, 1, 100);
        Assert.NotEmpty(secondRound.Audit.ScoreGroups);
        Assert.NotEmpty(secondRound.Audit.ColorNotes);
    }

    [Fact]
    public void SwissPairing_OddPlayerScenario_GivesSingleByeAndAuditsIt()
    {
        var tournament = CreateTournament(5);
        var round = new SwissPairingEngine().GenerateNextRound(tournament);
        var quality = new PairingQualityAnalyzer().Analyze(tournament, round);

        Assert.Single(round.Pairings, pairing => pairing.IsBye);
        Assert.Equal(1, quality.ByeCount);
        Assert.Contains(round.Audit.Messages, message => message.Contains("Bye vergeben", StringComparison.OrdinalIgnoreCase));
    }

    private static TournamentState CreateTournament(int playerCount)
    {
        var tournament = new TournamentState
        {
            Name = "Swiss Golden Scenario",
            Settings = new TournamentSettings { Format = TournamentFormat.Swiss }
        };

        for (var i = 1; i <= playerCount; i++)
        {
            tournament.Players.Add(new Player
            {
                Id = Guid.Parse($"00000000-0000-0000-0000-{i:000000000000}"),
                Name = $"Spieler {i}",
                StartingRank = i,
                Rating = new RatingProfile { ManualTwz = 2300 - i * 30 }
            });
        }

        return tournament;
    }
}