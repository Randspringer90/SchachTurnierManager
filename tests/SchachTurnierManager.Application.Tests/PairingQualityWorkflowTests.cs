using SchachTurnierManager.Domain.Models;
using Xunit;

namespace SchachTurnierManager.Application.Tests;

public sealed class PairingQualityWorkflowTests
{
    [Fact]
    public void GetPairingQuality_ReturnsReportForGeneratedRound()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Pairing Quality", new TournamentSettings { Format = TournamentFormat.Swiss });
        AddPlayers(service, tournament.Id, 4);

        var round = service.GenerateNextRound(tournament.Id);
        var report = service.GetPairingQuality(tournament.Id, round.RoundNumber);

        Assert.Equal(round.RoundNumber, report.RoundNumber);
        Assert.Equal(round.Pairings.Count, report.BoardCount);
        Assert.Equal(100, report.QualityScore);
        Assert.Equal(PairingQualitySeverity.Good, report.Severity);
        Assert.NotEmpty(report.Findings);
        Assert.All(report.Boards, board => Assert.Equal(0, board.ScoreDifference));
    }

    [Fact]
    public void GetPairingQuality_RejectsUnknownRound()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Pairing Quality Missing Round", new TournamentSettings { Format = TournamentFormat.Swiss });
        AddPlayers(service, tournament.Id, 4);

        var ex = Assert.Throws<InvalidOperationException>(() => service.GetPairingQuality(tournament.Id, 99));

        Assert.Contains("Runde 99", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    private static void AddPlayers(TournamentService service, Guid tournamentId, int count)
    {
        for (var i = 1; i <= count; i++)
        {
            service.AddPlayer(tournamentId, new Player
            {
                Name = $"Spieler {i}",
                Rating = new RatingProfile { ManualTwz = 2100 - i * 10 }
            });
        }
    }
}