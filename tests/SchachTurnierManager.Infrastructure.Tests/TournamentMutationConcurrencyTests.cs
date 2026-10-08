using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using SchachTurnierManager.Application;
using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Infrastructure.Persistence;
using Xunit;

namespace SchachTurnierManager.Infrastructure.Tests;

public sealed class TournamentMutationConcurrencyTests
{
    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public void IndependentConnections_PreserveResultOrRespectAnEarlierDeletion(bool delete)
    {
        var directory = Path.Combine(Path.GetTempPath(), $"stm-atomic-{Guid.NewGuid():N}");
        Directory.CreateDirectory(directory);
        try
        {
            var connection = new SqliteConnectionStringBuilder { DataSource = Path.Combine(directory, "synthetic.sqlite"), Pooling = false }.ToString();
            var options = new DbContextOptionsBuilder<TournamentDbContext>().UseSqlite(connection).Options;
            using var first = new TournamentDbContext(options);
            using var second = new TournamentDbContext(options);
            first.Database.EnsureCreated();
            var interleaving = new InterleavingStore(new SqliteTournamentStore(first));
            var service = new TournamentService(interleaving);
            var concurrent = new TournamentService(new SqliteTournamentStore(second));
            var tournament = service.CreateTournament("Synthetic", new TournamentSettings { Format = TournamentFormat.RoundRobin });
            service.AddPlayer(tournament.Id, new Player { Name = "Synthetic 1" });
            service.AddPlayer(tournament.Id, new Player { Name = "Synthetic 2" });
            var round = service.GenerateNextRound(tournament.Id);
            if (delete)
            {
                interleaving.BeforeMutation = () => concurrent.DeleteTournament(tournament.Id);
                Assert.Throws<InvalidOperationException>(() => service.SetRoundLock(tournament.Id, round.RoundNumber, true));
                Assert.Null(concurrent.ListTournaments().SingleOrDefault(t => t.Id == tournament.Id));
            }
            else
            {
                interleaving.BeforeMutation = () => concurrent.RecordResult(tournament.Id, round.RoundNumber, 1, GameResultKind.WhiteWin);
                service.SetRoundLock(tournament.Id, round.RoundNumber, true);
                var saved = concurrent.RequireTournament(tournament.Id);
                Assert.Equal(GameResultKind.WhiteWin, saved.Rounds.Single().Pairings.Single().Result.Kind);
                Assert.True(saved.Rounds.Single().IsLocked);
                Assert.Contains(saved.AuditJournal, entry => entry.Action == AuditJournalAction.ResultRecorded);
                Assert.Contains(saved.AuditJournal, entry => entry.Action == AuditJournalAction.RoundLocked);
            }
        }
        finally
        {
            Directory.Delete(directory, recursive: true);
        }
    }

    private sealed class InterleavingStore(ITournamentStore inner) : ITournamentStore
    {
        public Action? BeforeMutation { get; set; }
        private void Inject() { var action = BeforeMutation; BeforeMutation = null; action?.Invoke(); }
        public IReadOnlyList<TournamentState> List() => inner.List();
        public TournamentState? Get(Guid id) { var stale = inner.Get(id); Inject(); return stale; }
        public void Save(TournamentState state, bool overwriteExisting = true) => inner.Save(state, overwriteExisting);
        public TResult UpdateAtomically<TResult>(Guid id, Func<TournamentState, TResult> change) { Inject(); return inner.UpdateAtomically(id, change); }
        public bool Delete(Guid id, Action<TournamentState>? beforeDelete = null) => inner.Delete(id, beforeDelete);
    }
}
