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
    public void SaveImportedTournament_RejectsDuplicateExternalIds()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var imported = new TournamentState
        {
            Id = Guid.NewGuid(),
            Name = "Import Guard",
            Settings = new TournamentSettings { Format = TournamentFormat.Swiss, PlannedRounds = 3 },
            Players =
            {
                new Player { Id = Guid.NewGuid(), Name = "Spieler A", FideId = "4610563" },
                new Player { Id = Guid.NewGuid(), Name = "Spieler B", FideId = "4610563" }
            }
        };

        var ex = Assert.Throws<InvalidOperationException>(() => service.SaveImportedTournament(imported, overwriteExisting: true));

        Assert.Contains("FIDE-ID", ex.Message);
        Assert.Empty(service.ListTournaments());
    }

    [Fact]
    public void SaveImportedTournament_RejectsPairingWithUnknownPlayer()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var knownPlayerId = Guid.NewGuid();
        var unknownPlayerId = Guid.NewGuid();
        var imported = new TournamentState
        {
            Id = Guid.NewGuid(),
            Name = "Restore Guard",
            Settings = new TournamentSettings { Format = TournamentFormat.Swiss, PlannedRounds = 3 },
            Players =
            {
                new Player { Id = knownPlayerId, Name = "Spieler A" }
            },
            Rounds =
            {
                new TournamentRound
                {
                    RoundNumber = 1,
                    Pairings = new[] { Pairing.Game(1, knownPlayerId, unknownPlayerId) }
                }
            }
        };

        var ex = Assert.Throws<InvalidOperationException>(() => service.SaveImportedTournament(imported, overwriteExisting: true));

        Assert.Contains("nicht in der Teilnehmerliste", ex.Message);
        Assert.Empty(service.ListTournaments());
    }

    [Fact]
    public void SaveImportedTournament_NormalizesSettingsAndRecordsAudit()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var imported = new TournamentState
        {
            Id = Guid.NewGuid(),
            Name = "  Restore ok  ",
            Settings = new TournamentSettings
            {
                Format = TournamentFormat.Swiss,
                PlannedRounds = 0,
                HeroCupMinimumRatedGames = 0,
                Tiebreaks = Array.Empty<TiebreakType>()
            },
            Players =
            {
                new Player { Id = Guid.NewGuid(), Name = "Spieler A" },
                new Player { Id = Guid.NewGuid(), Name = "Spieler B" }
            }
        };

        var saved = service.SaveImportedTournament(imported, overwriteExisting: true);

        Assert.Equal("Restore ok", saved.Name);
        Assert.Equal(1, saved.Settings.PlannedRounds);
        Assert.Equal(1, saved.Settings.HeroCupMinimumRatedGames);
        Assert.Contains(TiebreakType.StartingRank, saved.Settings.Tiebreaks);
        Assert.Contains(saved.AuditJournal, entry => entry.Action == AuditJournalAction.TournamentImported);
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
