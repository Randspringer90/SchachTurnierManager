using SchachTurnierManager.Domain.Models;
using Xunit;

namespace SchachTurnierManager.Application.Tests;

/// <summary>ADR-0006: every stored change advances the revision; idempotent retries do not.</summary>
public sealed class TournamentRevisionTests
{
    [Fact]
    public void Revision_AdvancesWithEveryStoredChange()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Revision", new TournamentSettings { Format = TournamentFormat.Swiss });
        var created = service.RequireTournament(tournament.Id).Revision;

        service.AddPlayer(tournament.Id, new Player { Name = "Synthetisch 1" });
        var afterFirstPlayer = service.RequireTournament(tournament.Id).Revision;
        service.AddPlayer(tournament.Id, new Player { Name = "Synthetisch 2" });
        var afterSecondPlayer = service.RequireTournament(tournament.Id).Revision;

        Assert.True(created >= 1);
        Assert.True(afterFirstPlayer > created);
        Assert.True(afterSecondPlayer > afterFirstPlayer);
    }

    [Fact]
    public void IdempotentRetryOfAQueuedResult_DoesNotAdvanceTheRevision()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Revision", new TournamentSettings { Format = TournamentFormat.Swiss });
        for (var index = 0; index < 4; index++)
            service.AddPlayer(tournament.Id, new Player { Name = $"Synthetisch {index + 1}", Rating = new RatingProfile { ManualTwz = 2000 - index * 50 } });
        service.GenerateNextRound(tournament.Id);
        var state = service.RequireTournament(tournament.Id);
        var board = state.Rounds[0].Pairings.Single(p => p.BoardNumber == 1);
        var mutation = new QueuedResultMutation(Guid.NewGuid(), state.ResultQueueEpoch, 1, 1, GameResultKind.WhiteWin,
            GameResultKind.NotPlayed, board.WhitePlayerId!.Value, board.BlackPlayerId!.Value, board.LastChangedAt);

        service.RecordQueuedResult(tournament.Id, mutation);
        var afterFirst = service.RequireTournament(tournament.Id).Revision;
        service.RecordQueuedResult(tournament.Id, mutation);

        Assert.True(afterFirst > state.Revision);
        Assert.Equal(afterFirst, service.RequireTournament(tournament.Id).Revision);
    }

    [Fact]
    public void Summaries_CarryNoParticipantData_AndReflectTheStoredState()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Liste", new TournamentSettings { Format = TournamentFormat.RoundRobin });
        service.AddPlayer(tournament.Id, new Player { Name = "Synthetisch 1" });
        service.AddPlayer(tournament.Id, new Player { Name = "Synthetisch 2" });

        var summary = Assert.Single(service.ListTournamentSummaries());

        Assert.Equal((tournament.Id, "Liste", TournamentFormat.RoundRobin, 2, 0),
            (summary.Id, summary.Name, summary.Format, summary.PlayerCount, summary.RoundCount));
        Assert.Equal(service.RequireTournament(tournament.Id).Revision, summary.Revision);
        Assert.DoesNotContain(typeof(TournamentSummary).GetProperties(), property =>
            property.PropertyType == typeof(Player) || property.Name.Contains("Player", StringComparison.Ordinal) && property.PropertyType != typeof(int));
    }
}
