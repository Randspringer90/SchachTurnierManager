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

    public static IEnumerable<object[]> ContradictoryResults()
    {
        yield return new object[] { true, GameResultKind.Bye };
        foreach (var kind in Enum.GetValues<GameResultKind>().Where(kind => kind != GameResultKind.Bye))
        {
            yield return new object[] { false, kind };
        }
    }

    [Theory]
    [MemberData(nameof(ContradictoryResults))]
    public void ResultMustMatchBoardParticipants_WithoutMutationOrAudit(bool hasOpponent, GameResultKind result)
    {
        var sink = new CapturingSink();
        var service = new TournamentService(new InMemoryTournamentStore(), sink);
        var tournament = CreateTournamentWithBye(service);
        var pairing = tournament.Rounds[0].Pairings.Single(pairing => pairing.BlackPlayerId.HasValue == hasOpponent);
        var before = JsonSerializer.Serialize(tournament);
        var writes = sink.Writes;

        var exception = Assert.Throws<InvalidOperationException>(() => service.RecordResult(
            tournament.Id, 1, pairing.BoardNumber, result));

        Assert.Contains("Bye", exception.Message);
        Assert.Equal(before, JsonSerializer.Serialize(service.RequireTournament(tournament.Id)));
        Assert.Equal(writes, sink.Writes);
    }

    [Theory]
    [MemberData(nameof(ContradictoryResults))]
    public void ImportedResultMustMatchBoardParticipants_BeforeChangingEitherSnapshotOrAudit(bool hasOpponent, GameResultKind result)
    {
        var sink = new CapturingSink();
        var service = new TournamentService(new InMemoryTournamentStore(), sink);
        var existing = CreateTournamentWithBye(service);
        var before = JsonSerializer.Serialize(existing);
        var incoming = service.RequireTournament(existing.Id);
        incoming.Name = "  Synthetic replacement  ";
        var round = incoming.Rounds[0];
        incoming.Rounds[0] = round with
        {
            Pairings = round.Pairings.Select(pairing => pairing.BlackPlayerId.HasValue == hasOpponent
                ? pairing with { Result = new GameResult(result) }
                : pairing).ToList()
        };
        var incomingBefore = JsonSerializer.Serialize(incoming);
        var writes = sink.Writes;

        var exception = Assert.Throws<InvalidOperationException>(() => service.SaveImportedTournament(incoming, overwriteExisting: true));

        Assert.Contains("Bye", exception.Message);
        Assert.Equal(before, JsonSerializer.Serialize(service.RequireTournament(existing.Id)));
        Assert.Equal(incomingBefore, JsonSerializer.Serialize(incoming));
        Assert.Equal(writes, sink.Writes);
    }

    [Fact]
    public void RealBye_CanBeRecordedAndImported()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = CreateTournamentWithBye(service);
        var bye = tournament.Rounds[0].Pairings.Single(pairing => pairing.BlackPlayerId is null);

        service.RecordResult(tournament.Id, 1, bye.BoardNumber, GameResultKind.Bye);
        service.SaveImportedTournament(service.RequireTournament(tournament.Id), overwriteExisting: true);

        var saved = service.RequireTournament(tournament.Id).Rounds[0].Pairings.Single(pairing => pairing.BoardNumber == bye.BoardNumber);
        Assert.Null(saved.BlackPlayerId);
        Assert.Equal(GameResultKind.Bye, saved.Result.Kind);
        Assert.Equal(1m, service.GetStandings(tournament.Id).Single(row => row.PlayerId == bye.WhitePlayerId).Points);
    }

    private static TournamentState CreateTournamentWithBye(TournamentService service)
    {
        var tournament = service.CreateTournament("Synthetic result validation", new TournamentSettings { PlannedRounds = 3 });
        for (var index = 1; index <= 3; index++)
        {
            service.AddPlayer(tournament.Id, new Player { Name = $"Synthetic {index}" });
        }
        service.GenerateNextRound(tournament.Id);
        return service.RequireTournament(tournament.Id);
    }

    private sealed class CapturingSink : IAuditJournalSink
    {
        public int Writes { get; private set; }
        public void Append(Guid tournamentId, string tournamentName, AuditJournalEntry entry) => Writes++;
    }
}
