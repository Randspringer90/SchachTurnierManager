using System.Text.Json;
using SchachTurnierManager.Domain.Models;
using Xunit;

namespace SchachTurnierManager.Application.Tests;

public sealed class RoundRobinPlanPersistenceTests
{
    [Theory]
    [InlineData(4)]
    [InlineData(5)]
    public void RatingNameAndTwzPreferenceChanges_DoNotRescheduleAfterFirstRound(int count)
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = NewTournament(service, count);
        Complete(service, tournament.Id, service.GenerateNextRound(tournament.Id));
        var first = JsonSerializer.Serialize(service.RequireTournament(tournament.Id).Rounds);
        var changed = service.RequireTournament(tournament.Id).Players[1];
        service.UpdatePlayer(tournament.Id, changed.Id, changed with
        {
            Name = "Synthetic renamed", Rating = new RatingProfile { ManualTwz = 3000, Elo = 3100 }
        });
        service.UpdateSettings(tournament.Id, tournament.Settings with { TwzSource = TwzSource.ManualThenEloThenDwz });
        for (var round = 1; round < (count % 2 == 0 ? count - 1 : count); round++)
            Complete(service, tournament.Id, service.GenerateNextRound(tournament.Id));
        var saved = service.RequireTournament(tournament.Id);
        var games = saved.Rounds.SelectMany(round => round.Pairings).Where(pair => !pair.IsBye).ToList();
        Assert.Equal(count * (count - 1) / 2, games.Select(PairKey).Distinct().Count());
        Assert.Equal(first, JsonSerializer.Serialize(saved.Rounds.Take(1).ToList()));
        using var json = JsonDocument.Parse(JsonSerializer.Serialize(saved));
        Assert.True(json.RootElement.TryGetProperty("RoundRobinPlan", out var plan));
        Assert.Equal(JsonValueKind.Object, plan.ValueKind);
        Assert.Equal("RoundRobin-Berger-v2", plan.GetProperty("AlgorithmVersion").GetString());
    }

    [Theory]
    [InlineData(4)]
    [InlineData(5)]
    public void JsonBackupRoundtrip_PreservesPlanAndNextRoundAfterMutableRatingEdits(int count)
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = NewTournament(service, count);
        Complete(service, tournament.Id, service.GenerateNextRound(tournament.Id));
        var expected = PairingSignature(service.PreviewNextRound(tournament.Id).Round);
        var copy = JsonSerializer.Deserialize<TournamentState>(JsonSerializer.Serialize(service.RequireTournament(tournament.Id)))!;
        var restored = new TournamentService(new InMemoryTournamentStore());
        restored.SaveImportedTournament(copy, overwriteExisting: false);
        var player = copy.Players[1];
        restored.UpdatePlayer(copy.Id, player.Id, player with { Name = "Synthetic changed", Rating = new RatingProfile { ManualTwz = 4000 } });
        Assert.Equal(expected, PairingSignature(restored.GenerateNextRound(copy.Id)));
    }

    [Fact]
    public void LegacyReconstruction_ValidatesEveryStoredRoundBeforeContinuingOriginalVersion()
    {
        var (service, tournament) = Legacy();
        var before = JsonSerializer.Serialize(tournament.Rounds);
        var player = tournament.Players[1];
        service.UpdatePlayer(tournament.Id, player.Id, player with { Rating = new RatingProfile { ManualTwz = 4000 } });
        var next = service.GenerateNextRound(tournament.Id);
        var ids = tournament.Players.Select(player => player.Id).ToArray();
        Assert.Equal($"1:{ids[1]}/{ids[0]}|2:{ids[2]}/{ids[3]}", PairingSignature(next));
        Assert.Equal("RoundRobin-CircleMethod", next.Audit.Algorithm);
        Assert.Equal(before, JsonSerializer.Serialize(service.RequireTournament(tournament.Id).Rounds.Take(2).ToList()));
    }

    [Theory]
    [InlineData("later-round")]
    [InlineData("manual-first-round")]
    [InlineData("unknown-algorithm")]
    public void AmbiguousOrInconsistentLegacyHistory_IsVisibleAndNeverRewritten(string corruption)
    {
        var (_, tournament) = Legacy();
        if (corruption == "later-round")
        {
            var round = tournament.Rounds[1];
            var boards = round.Pairings.ToArray();
            boards[0] = boards[0] with { WhitePlayerId = boards[0].BlackPlayerId, BlackPlayerId = boards[0].WhitePlayerId };
            tournament.Rounds[1] = round with { Pairings = boards };
        }
        else if (corruption == "manual-first-round")
        {
            var round = tournament.Rounds[0];
            tournament.Rounds[0] = round with { Pairings = round.Pairings.Select(pair => pair with { IsManualOverride = true }).ToArray() };
        }
        else tournament.Rounds[0] = tournament.Rounds[0] with { Audit = new PairingAudit { Algorithm = "Unknown" } };
        var store = new InMemoryTournamentStore();
        store.Save(tournament);
        var service = new TournamentService(store);
        var before = JsonSerializer.Serialize(tournament.Rounds);
        var error = Assert.Throws<InvalidOperationException>(() => service.GenerateNextRound(tournament.Id));
        Assert.Contains("Spielplan", error.Message, StringComparison.OrdinalIgnoreCase);
        Assert.Equal(before, JsonSerializer.Serialize(service.RequireTournament(tournament.Id).Rounds));
    }

    [Fact]
    public void PreviewDoesNotFreezeTheRoster_AndExplicitResetClearsTheOldPlan()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = NewTournament(service, 4);
        service.PreviewNextRound(tournament.Id);
        service.AddPlayer(tournament.Id, new Player { Name = "Synthetic late before start" });
        service.GenerateNextRound(tournament.Id);
        var reset = service.ResetTournament(tournament.Id);
        using var json = JsonDocument.Parse(JsonSerializer.Serialize(reset));
        Assert.True(json.RootElement.TryGetProperty("RoundRobinPlan", out var plan));
        Assert.Equal(JsonValueKind.Null, plan.ValueKind);
        Assert.Empty(reset.Rounds);
        Assert.Equal(5, reset.Players.Count);
    }

    [Fact]
    public void LegacyOddField_RecoversByePlacementWithoutReorderingHistoricalResults()
    {
        var store = new InMemoryTournamentStore();
        var service = new TournamentService(store);
        var tournament = NewTournament(service, 5);
        var p = tournament.Players.Select(player => player.Id).ToArray();
        tournament.Rounds.Add(new TournamentRound { RoundNumber = 1, Audit = new PairingAudit { Algorithm = "RoundRobin-CircleMethod" },
            Pairings = new[] { Pairing.Bye(1, p[0]), Pairing.Game(2, p[1], p[4]) with { Result = GameResult.Draw }, Pairing.Game(3, p[3], p[2]) with { Result = GameResult.Draw } } });
        tournament.Rounds.Add(new TournamentRound { RoundNumber = 2, Audit = new PairingAudit { Algorithm = "RoundRobin-CircleMethod" },
            Pairings = new[] { Pairing.Game(1, p[0], p[4]) with { Result = GameResult.Draw }, Pairing.Bye(2, p[3]), Pairing.Game(3, p[1], p[2]) with { Result = GameResult.Draw } } });
        store.Save(tournament);
        var before = JsonSerializer.Serialize(tournament.Rounds);
        var player = tournament.Players[1];
        service.UpdatePlayer(tournament.Id, player.Id, player with { Rating = new RatingProfile { ManualTwz = 4000 } });
        var next = service.GenerateNextRound(tournament.Id);
        Assert.Equal($"1:{p[3]}/{p[0]}|2:{p[4]}/{p[2]}|3:{p[1]}/", PairingSignature(next));
        Assert.Equal(before, JsonSerializer.Serialize(service.RequireTournament(tournament.Id).Rounds.Take(2).ToList()));
        Assert.Equal(GameResultKind.Bye, next.Pairings[2].Result.Kind);
    }

    [Theory]
    [InlineData("version")]
    [InlineData("duplicate")]
    [InlineData("history")]
    public void InvalidPlanInBackup_IsRejectedBeforeSavingOrChangingTheInput(string problem)
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = NewTournament(service, 4);
        Complete(service, tournament.Id, service.GenerateNextRound(tournament.Id));
        var copy = service.RequireTournament(tournament.Id);
        Assert.NotNull(copy.RoundRobinPlan);
        if (problem == "version") copy.RoundRobinPlan = copy.RoundRobinPlan with { AlgorithmVersion = "unknown" };
        else if (problem == "duplicate") copy.RoundRobinPlan = copy.RoundRobinPlan with { ParticipantOrder = Enumerable.Repeat(copy.Players[0].Id, 4).ToArray() };
        else copy.RoundRobinPlan = copy.RoundRobinPlan with { ParticipantOrder = copy.RoundRobinPlan.ParticipantOrder.Reverse().ToArray() };
        var before = JsonSerializer.Serialize(copy);
        var target = new TournamentService(new InMemoryTournamentStore());
        Assert.Throws<InvalidOperationException>(() => target.SaveImportedTournament(copy, overwriteExisting: false));
        Assert.Empty(target.ListTournaments());
        Assert.Equal(before, JsonSerializer.Serialize(copy));
    }

    private static TournamentState NewTournament(TournamentService service, int count)
    {
        var tournament = service.CreateTournament("Synthetic round robin", new TournamentSettings { Format = TournamentFormat.RoundRobin, PlannedRounds = count });
        for (var rank = 1; rank <= count; rank++)
            service.AddPlayer(tournament.Id, new Player { Name = $"Synthetic {rank:00}", StartingRank = rank, Rating = new RatingProfile { ManualTwz = 2000 - rank } });
        return service.RequireTournament(tournament.Id);
    }

    [Fact]
    public void LegacyMissingAuditFailsVisiblyWithoutChangingPersistedRounds()
    {
        var (_, tournament) = Legacy();
        tournament.Rounds[0] = tournament.Rounds[0] with { Audit = null! };
        var store = new InMemoryTournamentStore(); store.Save(tournament);
        var service = new TournamentService(store);
        var before = JsonSerializer.Serialize(new { tournament.Rounds, tournament.Players, tournament.RoundRobinPlan });
        var priorAuditCount = tournament.AuditJournal.Count;
        Assert.Throws<InvalidOperationException>(() => service.PreviewNextRound(tournament.Id));
        var after = service.RequireTournament(tournament.Id);
        Assert.Equal(before, JsonSerializer.Serialize(new { after.Rounds, after.Players, after.RoundRobinPlan }));
        Assert.Equal(priorAuditCount + 1, after.AuditJournal.Count);
        Assert.Equal(AuditJournalAction.PairingGenerationBlocked, after.AuditJournal[^1].Action);
    }

    [Fact]
    public void DuplicateLegacyFirstRoundExplainsAmbiguityAndPreservesHistory()
    {
        var (_, tournament) = Legacy();
        tournament.Rounds[1] = tournament.Rounds[1] with { RoundNumber = 1 };
        var store = new InMemoryTournamentStore(); store.Save(tournament);
        var service = new TournamentService(store);
        var before = System.Text.Json.JsonSerializer.Serialize(new { tournament.Rounds, tournament.Players, tournament.RoundRobinPlan });
        var error = Assert.Throws<InvalidOperationException>(() => service.PreviewNextRound(tournament.Id));
        Assert.Contains("mehrdeutig", error.Message, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("keine automatische Neuplanung", error.Message, StringComparison.OrdinalIgnoreCase);
        var after = service.RequireTournament(tournament.Id);
        Assert.Equal(before, System.Text.Json.JsonSerializer.Serialize(new { after.Rounds, after.Players, after.RoundRobinPlan }));
        Assert.Equal(AuditJournalAction.PairingGenerationBlocked, after.AuditJournal[^1].Action);
    }
    private static (TournamentService Service, TournamentState Tournament) Legacy()
    {
        var store = new InMemoryTournamentStore();
        var service = new TournamentService(store);
        var tournament = NewTournament(service, 4);
        var p = tournament.Players.Select(player => player.Id).ToArray();
        tournament.Rounds.Add(new TournamentRound { RoundNumber = 1, Audit = new PairingAudit { Algorithm = "RoundRobin-CircleMethod" },
            Pairings = new[] { Pairing.Game(1, p[3], p[0]) with { Result = GameResult.Draw }, Pairing.Game(2, p[1], p[2]) with { Result = GameResult.Draw } } });
        tournament.Rounds.Add(new TournamentRound { RoundNumber = 2, Audit = new PairingAudit { Algorithm = "RoundRobin-CircleMethod" },
            Pairings = new[] { Pairing.Game(1, p[0], p[2]) with { Result = GameResult.Draw }, Pairing.Game(2, p[1], p[3]) with { Result = GameResult.Draw } } });
        store.Save(tournament);
        return (service, tournament);
    }

    private static string PairKey(Pairing pair) => string.Join('/', new[] { pair.WhitePlayerId, pair.BlackPlayerId }.OrderBy(id => id));
    private static string PairingSignature(TournamentRound round) => string.Join('|', round.Pairings.Select(pair => $"{pair.BoardNumber}:{pair.WhitePlayerId}/{pair.BlackPlayerId}"));
    private static void Complete(TournamentService service, Guid id, TournamentRound round)
    {
        foreach (var pair in round.Pairings.Where(pair => !pair.IsBye))
            service.RecordResult(id, round.RoundNumber, pair.BoardNumber, GameResultKind.Draw);
    }
}
