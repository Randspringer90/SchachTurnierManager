using System.Text.Json;
using SchachTurnierManager.Domain.Models;
using Xunit;

namespace SchachTurnierManager.Application.Tests;

public sealed class QueuedResultMutationTests
{
    [Fact]
    public void RetryAfterLostReply_IsIdempotent_AndDoesNotDuplicateAudit()
    {
        var (service, id, mutation) = Fixture();
        service.RecordQueuedResult(id, mutation);
        var before = JsonSerializer.Serialize(service.RequireTournament(id));
        service.RecordQueuedResult(id, mutation);
        Assert.Equal(before, JsonSerializer.Serialize(service.RequireTournament(id)));
    }

    [Fact]
    public void RetryDoesNotOverwriteALaterCorrection()
    {
        var (service, id, mutation) = Fixture();
        service.RecordQueuedResult(id, mutation);
        service.RecordResult(id, 1, 1, GameResultKind.BlackWin);
        var before = JsonSerializer.Serialize(service.RequireTournament(id));
        service.RecordQueuedResult(id, mutation);
        Assert.Equal(before, JsonSerializer.Serialize(service.RequireTournament(id)));
    }

    [Theory]
    [InlineData("result")]
    [InlineData("players")]
    [InlineData("timestamp")]
    [InlineData("epoch")]
    public void StalePreconditions_NeverChangeState(string problem)
    {
        var (service, id, mutation) = Fixture();
        mutation = problem switch
        {
            "result" => mutation with { ExpectedPreviousResult = GameResultKind.BlackWin },
            "players" => mutation with { WhitePlayerId = Guid.NewGuid() },
            "timestamp" => mutation with { ExpectedLastChangedAt = DateTimeOffset.UnixEpoch },
            _ => mutation with { Epoch = Guid.NewGuid() }
        };
        var before = JsonSerializer.Serialize(service.RequireTournament(id));
        Assert.Throws<QueuedResultConflictException>(() => service.RecordQueuedResult(id, mutation));
        Assert.Equal(before, JsonSerializer.Serialize(service.RequireTournament(id)));
    }

    [Fact]
    public void ResultChangedAndChangedBack_IsStillAConflict()
    {
        var (service, id, mutation) = Fixture();
        service.RecordResult(id, 1, 1, GameResultKind.BlackWin);
        service.RecordResult(id, 1, 1, GameResultKind.NotPlayed);
        Assert.Throws<QueuedResultConflictException>(() => service.RecordQueuedResult(id, mutation));
    }

    [Fact]
    public void MutationIdCannotBeReusedForDifferentPayload()
    {
        var (service, id, mutation) = Fixture();
        service.RecordQueuedResult(id, mutation);
        Assert.Throws<QueuedResultConflictException>(() => service.RecordQueuedResult(id, mutation with { Result = GameResultKind.Draw }));
    }

    [Fact]
    public void ResetAndRecreateTheSamePairing_InvalidatesUnsentMutation()
    {
        var (service, id, mutation) = Fixture();
        service.ResetTournament(id);
        service.GenerateNextRound(id);
        Assert.Throws<QueuedResultConflictException>(() => service.RecordQueuedResult(id, mutation));
    }

    [Fact]
    public void BackupRoundtrip_PreservesReceipts_ButInvalidatesUnsentRequests()
    {
        var (service, id, mutation) = Fixture();
        service.RecordQueuedResult(id, mutation);
        var backup = JsonSerializer.Deserialize<TournamentState>(JsonSerializer.Serialize(service.RequireTournament(id)))!;
        var target = new TournamentService(new InMemoryTournamentStore());
        target.SaveImportedTournament(backup, overwriteExisting: false);
        var before = JsonSerializer.Serialize(target.RequireTournament(id));
        target.RecordQueuedResult(id, mutation);
        Assert.Equal(before, JsonSerializer.Serialize(target.RequireTournament(id)));
        Assert.Throws<QueuedResultConflictException>(() => target.RecordQueuedResult(id, mutation with { MutationId = Guid.NewGuid() }));
    }

    [Fact]
    public void ParallelReplayOfOneMutation_CommitsOnlyOnce()
    {
        var (service, id, mutation) = Fixture();
        Parallel.For(0, 8, _ => service.RecordQueuedResult(id, mutation));
        Assert.Single(service.RequireTournament(id).ResultMutationReceipts);
        Assert.Single(service.RequireTournament(id).AuditJournal, entry => entry.Action == AuditJournalAction.ResultRecorded);
    }

    private static (TournamentService Service, Guid Id, QueuedResultMutation Mutation) Fixture()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var t = service.CreateTournament("Synthetic queued results", new TournamentSettings { Format = TournamentFormat.RoundRobin });
        service.AddPlayer(t.Id, new Player { Name = "Synthetic A" });
        service.AddPlayer(t.Id, new Player { Name = "Synthetic B" });
        var pair = service.GenerateNextRound(t.Id).Pairings.Single();
        var state = service.RequireTournament(t.Id);
        return (service, t.Id, new QueuedResultMutation(Guid.NewGuid(), state.ResultQueueEpoch, 1, 1,
            GameResultKind.WhiteWin, pair.Result.Kind, pair.WhitePlayerId!.Value, pair.BlackPlayerId!.Value, pair.LastChangedAt));
    }

    [Theory]
    [InlineData(0)]
    [InlineData(14)]
    [InlineData(-14)]
    public void ExhaustedLegacyTimestampIsReportedAsControlledValidationWithoutMutation(int offsetHours)
    {
        var store = new InMemoryTournamentStore();
        var source = new TournamentService(store);
        var tournament = source.CreateTournament("Synthetic maximum timestamp", new TournamentSettings { Format = TournamentFormat.RoundRobin });
        source.AddPlayer(tournament.Id, new Player { Name = "Synthetic Timestamp A" });
        source.AddPlayer(tournament.Id, new Player { Name = "Synthetic Timestamp B" });
        source.GenerateNextRound(tournament.Id);
        var state = source.RequireTournament(tournament.Id);
        var exhausted = new DateTimeOffset(offsetHours < 0 ? DateTime.MaxValue.AddHours(offsetHours) : DateTime.MaxValue, TimeSpan.FromHours(offsetHours));
        state.Rounds[0] = state.Rounds[0] with { Pairings = state.Rounds[0].Pairings.Select(pair => pair with { LastChangedAt = exhausted }).ToArray() };
        store.Save(state);
        var before = JsonSerializer.Serialize(source.RequireTournament(tournament.Id));
        Assert.Throws<InvalidOperationException>(() => source.RecordResult(tournament.Id, 1, 1, GameResultKind.Draw));
        Assert.Equal(before, JsonSerializer.Serialize(source.RequireTournament(tournament.Id)));
    }
}
