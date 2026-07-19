using System.Text.Json;
using SchachTurnierManager.Application;
using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Application.Tests;

public sealed class TournamentServiceTests
{
    [Fact]
    public void CreateAddGenerateRecord_CalculatesStandings()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Vereinsturnier", new TournamentSettings { Format = TournamentFormat.RoundRobin });
        var a = service.AddPlayer(tournament.Id, new Player { Name = "Alice", Rating = new RatingProfile { ManualTwz = 1900 } });
        service.AddPlayer(tournament.Id, new Player { Name = "Bob", Rating = new RatingProfile { ManualTwz = 1800 } });

        var round = service.GenerateNextRound(tournament.Id);
        service.RecordResult(tournament.Id, round.RoundNumber, 1, round.Pairings[0].WhitePlayerId == a.Id ? GameResultKind.WhiteWin : GameResultKind.BlackWin);

        var standings = service.GetStandings(tournament.Id);

        Assert.Equal("Alice", standings[0].Name);
        Assert.Equal(1m, standings[0].Points);
    }

    [Fact]
    public void RecordResult_WithStaleExpectedPreviousResult_RejectsOverwrite()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Concurrent Result Test", new TournamentSettings { Format = TournamentFormat.RoundRobin });
        service.AddPlayer(tournament.Id, new Player { Name = "Synthetic Player 01" });
        service.AddPlayer(tournament.Id, new Player { Name = "Synthetic Player 02" });
        var round = service.GenerateNextRound(tournament.Id);

        service.RecordResult(
            tournament.Id,
            round.RoundNumber,
            boardNumber: 1,
            GameResultKind.WhiteWin,
            expectedPreviousResult: GameResultKind.NotPlayed);

        var exception = Assert.Throws<InvalidOperationException>(() => service.RecordResult(
            tournament.Id,
            round.RoundNumber,
            boardNumber: 1,
            GameResultKind.Draw,
            expectedPreviousResult: GameResultKind.NotPlayed));

        Assert.Contains("zwischenzeitlich geändert", exception.Message, StringComparison.OrdinalIgnoreCase);
        var stored = service.RequireTournament(tournament.Id).Rounds.Single().Pairings.Single();
        Assert.Equal(GameResultKind.WhiteWin, stored.Result.Kind);
    }

    [Fact]
    public async Task RecordResult_ConcurrentSameExpectedValue_AllowsExactlyOneWriter()
    {
        var store = new CoordinatedTournamentStore();
        var setup = new TournamentService(store);
        var tournament = setup.CreateTournament("Concurrent Result Test", new TournamentSettings { Format = TournamentFormat.RoundRobin });
        setup.AddPlayer(tournament.Id, new Player { Name = "Synthetic Player 01" });
        setup.AddPlayer(tournament.Id, new Player { Name = "Synthetic Player 02" });
        var round = setup.GenerateNextRound(tournament.Id);
        var boardNumber = round.Pairings.Single().BoardNumber;
        store.CoordinateNextTwoNonAtomicSaves();

        using var start = new ManualResetEventSlim(false);
        async Task<bool> TryWriteAsync(GameResultKind result)
        {
            return await Task.Run(() =>
            {
                var service = new TournamentService(store);
                start.Wait();
                try
                {
                    service.RecordResult(tournament.Id, round.RoundNumber, boardNumber, result, GameResultKind.NotPlayed);
                    return true;
                }
                catch (InvalidOperationException)
                {
                    return false;
                }
            });
        }

        var whiteWrite = TryWriteAsync(GameResultKind.WhiteWin);
        var blackWrite = TryWriteAsync(GameResultKind.BlackWin);
        start.Set();
        var outcomes = await Task.WhenAll(whiteWrite, blackWrite);

        Assert.Single(outcomes, success => success);
    }

    [Fact]
    public void ResetTournament_RemovesRoundsAndRoundAuditButKeepsPlayersAndSettings()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Reset Test", new TournamentSettings { Format = TournamentFormat.Swiss, PlannedRounds = 3 });
        AddPlayers(service, tournament.Id, 4, "Reset Spieler");
        var round = service.GenerateNextRound(tournament.Id);
        service.RollChess960StartPositions(tournament.Id, round.RoundNumber, overwriteExisting: false, seed: 100);
        service.RecordResult(tournament.Id, round.RoundNumber, 1, GameResultKind.WhiteWin);

        var reset = service.ResetTournament(tournament.Id);

        Assert.Empty(reset.Rounds);
        Assert.Equal(4, reset.Players.Count);
        Assert.Equal(3, reset.Settings.PlannedRounds);
        Assert.Contains(reset.AuditJournal, entry => entry.Action == AuditJournalAction.TournamentReset);
        Assert.DoesNotContain(reset.AuditJournal, entry => entry.Action == AuditJournalAction.RoundGenerated);
        Assert.DoesNotContain(reset.AuditJournal, entry => entry.Action == AuditJournalAction.ResultRecorded);
        Assert.DoesNotContain(reset.AuditJournal, entry => entry.Action == AuditJournalAction.Chess960StartPositionsRolled);
    }

    [Fact]
    public void DeleteTournament_RemovesTournamentFromStore()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Delete Test");

        Assert.True(service.DeleteTournament(tournament.Id));
        Assert.False(service.DeleteTournament(tournament.Id));
        Assert.DoesNotContain(service.ListTournaments(), item => item.Id == tournament.Id);
    }

    [Fact]
    public void GenerateNextRound_StopsAtPlannedRounds()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Round Limit Test", new TournamentSettings { Format = TournamentFormat.Swiss, PlannedRounds = 1 });
        AddPlayers(service, tournament.Id, 4, "Limit Spieler");
        var round = service.GenerateNextRound(tournament.Id);
        foreach (var pairing in round.Pairings)
        {
            service.RecordResult(tournament.Id, round.RoundNumber, pairing.BoardNumber, GameResultKind.Draw);
        }

        var ex = Assert.Throws<InvalidOperationException>(() => service.GenerateNextRound(tournament.Id));

        Assert.Contains("maximale Rundenzahl", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void RollChess960StartPositions_PersistsPerBoardAndDoesNotOverwriteResults()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Chess960 Test", new TournamentSettings { Format = TournamentFormat.Swiss });
        AddPlayers(service, tournament.Id, 4, "Chess960 Spieler");
        var round = service.GenerateNextRound(tournament.Id);
        service.RecordResult(tournament.Id, round.RoundNumber, 1, GameResultKind.WhiteWin);

        var updated = service.RollChess960StartPositions(tournament.Id, round.RoundNumber, overwriteExisting: false, seed: 123);
        var reloaded = service.RequireTournament(tournament.Id).Rounds.Single();

        Assert.Equal(GameResultKind.WhiteWin, reloaded.Pairings.Single(pairing => pairing.BoardNumber == 1).Result.Kind);
        Assert.All(updated.Pairings.Where(pairing => !pairing.IsBye), pairing =>
        {
            Assert.NotNull(pairing.Chess960StartPosition);
            Assert.InRange(pairing.Chess960StartPosition!.PositionNumber, 0, 959);
        });
        Assert.Throws<InvalidOperationException>(() => service.RollChess960StartPositions(tournament.Id, round.RoundNumber, overwriteExisting: false, seed: 123));
        Assert.Contains(service.GetAuditJournal(tournament.Id), entry => entry.Action == AuditJournalAction.Chess960StartPositionsRolled);
    }

    [Fact]
    public void RollChess960StartPositionForBoard_OnlyTargetBoardChangesAndPersists()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Chess960 Single", new TournamentSettings { Format = TournamentFormat.Swiss });
        AddPlayers(service, tournament.Id, 4, "Chess960 Spieler");
        var round = service.GenerateNextRound(tournament.Id);

        // Erst alle Bretter würfeln, dann gezielt nur Brett 1 neu setzen.
        service.RollChess960StartPositions(tournament.Id, round.RoundNumber, overwriteExisting: false, seed: 555);
        var before = service.RequireTournament(tournament.Id).Rounds.Single();
        var board1Before = before.Pairings.Single(pairing => pairing.BoardNumber == 1).Chess960StartPosition!;
        var otherBoardsBefore = before.Pairings
            .Where(pairing => pairing.BoardNumber != 1 && !pairing.IsBye)
            .ToDictionary(pairing => pairing.BoardNumber, pairing => pairing.Chess960StartPosition!.PositionNumber);

        var updated = service.RollChess960StartPositionForBoard(tournament.Id, round.RoundNumber, 1, overwriteExisting: true, positionNumber: 701);
        var board1After = updated.Pairings.Single(pairing => pairing.BoardNumber == 1).Chess960StartPosition!;

        Assert.Equal(701, board1After.PositionNumber);
        Assert.True(new Chess960PositionService().ValidatePosition(board1After.WhiteBackRank));

        // Andere Bretter unverändert (Persistenz geprüft über erneutes Laden).
        var reloaded = service.RequireTournament(tournament.Id).Rounds.Single();
        Assert.Equal(701, reloaded.Pairings.Single(pairing => pairing.BoardNumber == 1).Chess960StartPosition!.PositionNumber);
        foreach (var (boardNumber, positionNumber) in otherBoardsBefore)
        {
            Assert.Equal(positionNumber, reloaded.Pairings.Single(pairing => pairing.BoardNumber == boardNumber).Chess960StartPosition!.PositionNumber);
        }
    }

    [Fact]
    public void RollChess960StartPositionForBoard_ThrowsOnExistingWithoutOverwrite()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Chess960 Single Guard", new TournamentSettings { Format = TournamentFormat.Swiss });
        AddPlayers(service, tournament.Id, 4, "Chess960 Spieler");
        var round = service.GenerateNextRound(tournament.Id);

        var first = service.RollChess960StartPositionForBoard(tournament.Id, round.RoundNumber, 1, overwriteExisting: false, seed: 42);
        Assert.NotNull(first.Pairings.Single(pairing => pairing.BoardNumber == 1).Chess960StartPosition);

        Assert.Throws<InvalidOperationException>(() =>
            service.RollChess960StartPositionForBoard(tournament.Id, round.RoundNumber, 1, overwriteExisting: false, seed: 42));
    }

    [Fact]
    public void ExportTrf16_ProducesSafeDownloadNameAndTextContentType()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("TRF Export: <Test>/Verein 2026", new TournamentSettings { Format = TournamentFormat.Swiss });
        AddPlayers(service, tournament.Id, 2, "TRF Spieler");

        var document = service.ExportTrf16(tournament.Id);

        Assert.Equal("text/plain; charset=utf-8", document.ContentType);
        Assert.EndsWith("_TRF16.txt", document.FileName);
        foreach (var invalidChar in Path.GetInvalidFileNameChars())
        {
            Assert.DoesNotContain(invalidChar, document.FileName);
        }
        Assert.StartsWith("012 ", document.Content);
    }

    [Fact]
    public void ExportTrf16_IncludesWithdrawnPlayerEvenThoughVisibleStandingsHideThem()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("TRF Withdrawal Test", new TournamentSettings { Format = TournamentFormat.Swiss });
        AddPlayers(service, tournament.Id, 3, "TRF Withdraw");
        var withdrawn = service.RequireTournament(tournament.Id).Players[1];
        service.SetPlayerStatus(tournament.Id, withdrawn.Id, PlayerStatus.Withdrawn);

        var visibleStandings = service.GetStandings(tournament.Id);
        Assert.DoesNotContain(visibleStandings, row => row.PlayerId == withdrawn.Id);

        var document = service.ExportTrf16(tournament.Id);
        var lines = document.Content.Split('\r').Where(l => l.Length > 0).ToArray();
        var declaredCount = int.Parse(lines[1][4..].Trim());
        var playerLineCount = lines.Skip(4).Count();

        Assert.Equal(3, declaredCount);
        Assert.Equal(3, playerLineCount);
    }

    private sealed class CoordinatedTournamentStore : ITournamentStore
    {
        private readonly object _sync = new();
        private readonly Dictionary<Guid, TournamentState> _tournaments = new();
        private CountdownEvent? _saveBarrier;

        public IReadOnlyList<TournamentState> List()
        {
            lock (_sync)
            {
                return _tournaments.Values.Select(Clone).ToList();
            }
        }

        public TournamentState? Get(Guid id)
        {
            lock (_sync)
            {
                return _tournaments.TryGetValue(id, out var tournament) ? Clone(tournament) : null;
            }
        }

        public void Save(TournamentState tournament)
        {
            var barrier = _saveBarrier;
            if (barrier is not null)
            {
                barrier.Signal();
                if (!barrier.Wait(TimeSpan.FromSeconds(5)))
                {
                    throw new TimeoutException("The concurrency test save barrier timed out.");
                }
            }

            lock (_sync)
            {
                _tournaments[tournament.Id] = Clone(tournament);
            }
        }

        public TResult UpdateAtomically<TResult>(Guid id, Func<TournamentState, TResult> update)
        {
            lock (_sync)
            {
                if (!_tournaments.TryGetValue(id, out var stored))
                {
                    throw new InvalidOperationException($"Turnier {id} wurde nicht gefunden.");
                }

                var workingCopy = Clone(stored);
                var result = update(workingCopy);
                _tournaments[id] = workingCopy;
                return result;
            }
        }

        public bool Delete(Guid id)
        {
            lock (_sync)
            {
                return _tournaments.Remove(id);
            }
        }

        public void CoordinateNextTwoNonAtomicSaves() => _saveBarrier = new CountdownEvent(2);

        private static TournamentState Clone(TournamentState tournament)
        {
            var json = JsonSerializer.Serialize(tournament);
            return JsonSerializer.Deserialize<TournamentState>(json)!;
        }
    }

    private static void AddPlayers(TournamentService service, Guid tournamentId, int count, string prefix)
    {
        for (var i = 1; i <= count; i++)
        {
            service.AddPlayer(tournamentId, new Player
            {
                Name = $"{prefix} {i}",
                Rating = new RatingProfile { ManualTwz = 2000 - i * 10 }
            });
        }
    }
}
