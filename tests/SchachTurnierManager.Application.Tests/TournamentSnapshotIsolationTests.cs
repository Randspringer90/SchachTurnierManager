using System.Text.Json;
using SchachTurnierManager.Domain.Models;
using Xunit;

namespace SchachTurnierManager.Application.Tests;

public sealed class TournamentSnapshotIsolationTests
{
    [Fact]
    public void StoredSnapshots_DoNotShareMutableStateWithCallers()
    {
        var store = new InMemoryTournamentStore();
        var original = new TournamentState { Name = "Synthetic" };
        store.Save(original);
        original.Name = "caller";
        store.Get(original.Id)!.Name = "reader";
        store.List().Single().Name = "list";
        var updated = store.UpdateAtomically(original.Id, state => { state.Name = "committed"; return state; });
        updated.Name = "returned callback object";
        Assert.Equal("committed", store.Get(original.Id)!.Name);
    }

    [Fact]
    public void DeletedTournament_CannotBeResurrectedByAnExistingTournamentMutation()
    {
        var store = new InMemoryTournamentStore();
        var service = new TournamentService(store);
        var tournament = service.CreateTournament("Synthetic");
        Assert.True(service.DeleteTournament(tournament.Id));
        Assert.Throws<InvalidOperationException>(() => service.UpdateSettings(tournament.Id, new TournamentSettings()));
        Assert.Null(store.Get(tournament.Id));
    }

    [Fact]
    public void ResultSavedBetweenReadAndLock_IsPreserved()
    {
        var store = new InterleavingStore();
        var service = new TournamentService(store);
        var tournament = service.CreateTournament("Synthetic", new TournamentSettings { Format = TournamentFormat.RoundRobin });
        service.AddPlayer(tournament.Id, new Player { Name = "Synthetic 1" });
        service.AddPlayer(tournament.Id, new Player { Name = "Synthetic 2" });
        var round = service.GenerateNextRound(tournament.Id);
        // For the old Get/Save path, inject after its stale read. For the atomic path,
        // inject before the transaction reads, precisely modelling an earlier writer.
        store.BeforeMutation = () => service.RecordResult(tournament.Id, round.RoundNumber, 1, GameResultKind.WhiteWin);
        service.SetRoundLock(tournament.Id, round.RoundNumber, true);
        var saved = store.Get(tournament.Id)!;
        Assert.Equal(GameResultKind.WhiteWin, saved.Rounds.Single().Pairings.Single().Result.Kind);
        Assert.True(saved.Rounds.Single().IsLocked);
        Assert.Contains(saved.AuditJournal, entry => entry.Action == AuditJournalAction.ResultRecorded);
        Assert.Contains(saved.AuditJournal, entry => entry.Action == AuditJournalAction.RoundLocked);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(1)]
    public void ImportWithNullRound_IsControlledAndPreservesStoredAndIncomingState(int nullPosition)
    {
        var store = new InMemoryTournamentStore();
        var service = new TournamentService(store);
        var tournament = service.CreateTournament("Synthetic existing", new TournamentSettings
        {
            Format = TournamentFormat.RoundRobin,
            PlannedRounds = 2
        });
        service.AddPlayer(tournament.Id, new Player { Name = "Synthetic 1" });
        service.AddPlayer(tournament.Id, new Player { Name = "Synthetic 2" });
        var round = service.GenerateNextRound(tournament.Id);
        service.RecordResult(tournament.Id, round.RoundNumber, 1, GameResultKind.WhiteWin);
        var storedBefore = JsonSerializer.Serialize(service.RequireTournament(tournament.Id));
        var incoming = JsonSerializer.Deserialize<TournamentState>(storedBefore)!;
        incoming.Name = "  Incoming replacement  ";
        incoming.Rounds.Insert(nullPosition, null!);
        var incomingAuditCount = incoming.AuditJournal.Count;

        var error = Assert.Throws<InvalidOperationException>(() =>
            service.SaveImportedTournament(incoming, overwriteExisting: true));

        Assert.Contains($"Importierte Runde {nullPosition + 1} ist leer.", error.Message);
        Assert.Equal(storedBefore, JsonSerializer.Serialize(service.RequireTournament(tournament.Id)));
        Assert.Equal("  Incoming replacement  ", incoming.Name);
        Assert.Equal(incomingAuditCount, incoming.AuditJournal.Count);
        Assert.Null(incoming.Rounds[nullPosition]);
    }

    private sealed class InterleavingStore : ITournamentStore
    {
        private readonly InMemoryTournamentStore inner = new();
        public Action? BeforeMutation { get; set; }
        private void Inject() { var action = BeforeMutation; BeforeMutation = null; action?.Invoke(); }
        public IReadOnlyList<TournamentState> List() => inner.List();
        public TournamentState? Get(Guid id) { var stale = inner.Get(id); Inject(); return stale; }
        public void Save(TournamentState state, bool overwriteExisting = true) => inner.Save(state, overwriteExisting);
        public TResult UpdateAtomically<TResult>(Guid id, Func<TournamentState, TResult> change) { Inject(); return inner.UpdateAtomically(id, change); }
        public bool Delete(Guid id, Action<TournamentState>? beforeDelete = null) => inner.Delete(id, beforeDelete);
    }
}
