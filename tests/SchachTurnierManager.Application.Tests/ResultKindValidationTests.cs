using System.Text.Json;
using SchachTurnierManager.Domain.Models;
using Xunit;

namespace SchachTurnierManager.Application.Tests;

public sealed class ResultKindValidationTests
{
    [Theory]
    [InlineData(-1, 0)]
    [InlineData(9999, 0)]
    [InlineData(1, -1)]
    [InlineData(1, 9999)]
    public void UndefinedResultOrPrecondition_IsRejectedWithoutMutation(int result, int previous)
    {
        var sink = new CapturingSink();
        var service = new TournamentService(new InMemoryTournamentStore(), sink);
        var tournament = service.CreateTournament("Synthetic", new TournamentSettings { Format = TournamentFormat.RoundRobin });
        service.AddPlayer(tournament.Id, new Player { Name = "Synthetic One" });
        service.AddPlayer(tournament.Id, new Player { Name = "Synthetic Two" });
        var round = service.GenerateNextRound(tournament.Id);
        var before = JsonSerializer.Serialize(service.RequireTournament(tournament.Id));
        var writes = sink.Writes;

        var exception = Assert.Throws<InvalidOperationException>(() => service.RecordResult(
            tournament.Id, round.RoundNumber, round.Pairings[0].BoardNumber,
            (GameResultKind)result, (GameResultKind)previous));

        Assert.Contains("Ergebniswert", exception.Message);
        Assert.Equal(before, JsonSerializer.Serialize(service.RequireTournament(tournament.Id)));
        Assert.Equal(writes, sink.Writes);
    }

    private sealed class CapturingSink : IAuditJournalSink
    {
        public int Writes { get; private set; }
        public void Append(Guid tournamentId, string tournamentName, AuditJournalEntry entry) => Writes++;
    }
}
