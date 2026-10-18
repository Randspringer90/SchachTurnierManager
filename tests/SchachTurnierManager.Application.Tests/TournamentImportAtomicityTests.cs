using System.Text.Json;
using SchachTurnierManager.Domain.Models;
using Xunit;

namespace SchachTurnierManager.Application.Tests;

public sealed class TournamentImportAtomicityTests
{
    [Fact]
    public void DuplicateWithoutOverwrite_LeavesBothSnapshotsAndMirrorUntouched()
    {
        var store = new InMemoryTournamentStore();
        var existing = new TournamentState { Name = "Synthetic existing" };
        store.Save(existing);
        var incoming = Incoming(existing.Id);
        var incomingBefore = JsonSerializer.Serialize(incoming);
        var storedBefore = JsonSerializer.Serialize(store.Get(existing.Id));
        var sink = new CallbackSink((_, _) => { });
        var service = new TournamentService(store, sink);

        Assert.Throws<InvalidOperationException>(() => service.SaveImportedTournament(incoming, overwriteExisting: false));

        Assert.Equal(0, sink.Calls);
        Assert.Equal(incomingBefore, JsonSerializer.Serialize(incoming));
        Assert.Equal(storedBefore, JsonSerializer.Serialize(store.Get(existing.Id)));
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public void SaveFailure_DoesNotChangeInputOrEmitAnImportEvent(bool overwriteExisting)
    {
        var store = new FaultingStore();
        var existing = new TournamentState { Name = "Synthetic existing" };
        store.Inner.Save(existing);
        var incoming = Incoming(overwriteExisting ? existing.Id : Guid.NewGuid());
        var incomingBefore = JsonSerializer.Serialize(incoming);
        var storedBefore = JsonSerializer.Serialize(store.List());
        var sink = new CallbackSink((_, _) => { });
        var service = new TournamentService(store, sink);
        store.FailSave = true;

        Assert.Throws<IOException>(() => service.SaveImportedTournament(incoming, overwriteExisting));

        Assert.Equal(0, sink.Calls);
        Assert.Equal(incomingBefore, JsonSerializer.Serialize(incoming));
        Assert.Equal(storedBefore, JsonSerializer.Serialize(store.List()));
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public void SuccessfulImport_NormalizesACopyAndSavesItsAuditBeforeMirroring(bool overwriteExisting)
    {
        var store = new InMemoryTournamentStore();
        var incoming = Incoming(Guid.NewGuid());
        if (overwriteExisting)
        {
            store.Save(new TournamentState { Id = incoming.Id, Name = "Synthetic old version" });
        }
        var incomingBefore = JsonSerializer.Serialize(incoming);
        var importWasSavedBeforeMirror = false;
        var sink = new CallbackSink((id, entry) =>
        {
            importWasSavedBeforeMirror = store.Get(id)?.AuditJournal.Any(saved => saved.Id == entry.Id) == true;
        });
        var service = new TournamentService(store, sink);

        var saved = service.SaveImportedTournament(incoming, overwriteExisting);

        Assert.True(importWasSavedBeforeMirror);
        Assert.Equal(1, sink.Calls);
        Assert.Equal(incomingBefore, JsonSerializer.Serialize(incoming));
        Assert.NotSame(incoming, saved);
        Assert.Equal("Synthetic import", saved.Name);
        Assert.Equal(1, saved.Settings.PlannedRounds);
        Assert.Equal(1, saved.Settings.HeroCupMinimumRatedGames);
        Assert.Equal(new[] { TiebreakType.StartingRank }, saved.Settings.Tiebreaks);
        Assert.Single(saved.AuditJournal, entry => entry.Action == AuditJournalAction.TournamentImported);
        Assert.Equal(JsonSerializer.Serialize(saved), JsonSerializer.Serialize(store.Get(incoming.Id)));
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public void MirrorFailure_AppendsWarningAtomicallyWithoutOverwritingLaterChanges(bool replaceDuringMirror)
    {
        var store = new InMemoryTournamentStore();
        var incoming = Incoming(Guid.NewGuid());
        var incomingBefore = JsonSerializer.Serialize(incoming);
        var sink = new CallbackSink((id, _) =>
        {
            if (replaceDuringMirror)
            {
                store.Save(new TournamentState { Id = id, Name = "Concurrent replacement" });
            }
            else
            {
                store.UpdateAtomically(id, current =>
                {
                    current.Name = "Concurrent edit";
                    current.Players.Add(new Player { Name = "Concurrent participant" });
                    return true;
                });
            }
            throw new IOException("Synthetic mirror failure");
        });
        var service = new TournamentService(store, sink);

        var returned = service.SaveImportedTournament(incoming, overwriteExisting: false);
        var stored = store.Get(incoming.Id)!;

        Assert.Equal(1, sink.Calls);
        Assert.Equal(incomingBefore, JsonSerializer.Serialize(incoming));
        Assert.Equal(replaceDuringMirror ? "Concurrent replacement" : "Concurrent edit", stored.Name);
        Assert.Equal(JsonSerializer.Serialize(stored), JsonSerializer.Serialize(returned));
        if (replaceDuringMirror)
        {
            Assert.Empty(stored.AuditJournal);
        }
        else
        {
            Assert.Single(stored.Players, player => player.Name == "Concurrent participant");
            Assert.Single(stored.AuditJournal, entry => entry.Action == AuditJournalAction.TournamentImported);
            var warning = Assert.Single(stored.AuditJournal, entry => entry.Action == AuditJournalAction.AuditJournalMirrorFailed);
            Assert.Equal(AuditJournalSeverity.Warning, warning.Severity);
        }
    }

    [Fact]
    public void MirrorAndWarningWriteFailure_ReturnsSavedImportWithAnExplicitTransientWarning()
    {
        var store = new FaultingStore { FailUpdates = true };
        var incoming = Incoming(Guid.NewGuid());
        var incomingBefore = JsonSerializer.Serialize(incoming);
        var sink = new CallbackSink((_, _) => throw new IOException("Synthetic mirror failure"));
        var service = new TournamentService(store, sink);

        var returned = service.SaveImportedTournament(incoming, overwriteExisting: false);
        var persisted = store.Get(incoming.Id)!;

        Assert.Equal(1, sink.Calls);
        Assert.Equal(incomingBefore, JsonSerializer.Serialize(incoming));
        Assert.Single(persisted.AuditJournal, entry => entry.Action == AuditJournalAction.TournamentImported);
        Assert.DoesNotContain(persisted.AuditJournal, entry => entry.Action == AuditJournalAction.AuditJournalMirrorFailed);
        var warning = Assert.Single(returned.AuditJournal, entry => entry.Action == AuditJournalAction.AuditJournalMirrorFailed);
        Assert.Contains("nicht gespeichert", warning.Summary);
    }

    private static TournamentState Incoming(Guid id) => new()
    {
        Id = id,
        Name = "  Synthetic import  ",
        Settings = new TournamentSettings { PlannedRounds = 0, HeroCupMinimumRatedGames = 0, Tiebreaks = null! }
    };

    private sealed class CallbackSink(Action<Guid, AuditJournalEntry> append) : IAuditJournalSink
    {
        public int Calls { get; private set; }
        public void Append(Guid tournamentId, string tournamentName, AuditJournalEntry entry)
        {
            Calls++;
            append(tournamentId, entry);
        }
    }

    private sealed class FaultingStore : ITournamentStore
    {
        public InMemoryTournamentStore Inner { get; } = new();
        public bool FailSave { get; set; }
        public bool FailUpdates { get; set; }
        public IReadOnlyList<TournamentState> List() => Inner.List();
        public TournamentState? Get(Guid id) => Inner.Get(id);
        public void Save(TournamentState tournament, bool overwriteExisting = true)
        {
            if (FailSave) throw new IOException("Synthetic store failure");
            Inner.Save(tournament, overwriteExisting);
        }
        public TResult UpdateAtomically<TResult>(Guid id, Func<TournamentState, TResult> update)
        {
            if (FailUpdates) throw new IOException("Synthetic warning persistence failure");
            return Inner.UpdateAtomically(id, update);
        }
        public bool Delete(Guid id, Action<TournamentState>? beforeDelete = null) => Inner.Delete(id, beforeDelete);
    }
}
