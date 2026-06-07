using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Application.Tests;

public sealed class RoundWorkflowTests
{
    [Fact]
    public void LockedRound_RejectsResultChanges()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Lock Test", new TournamentSettings { Format = TournamentFormat.Swiss });
        AddPlayers(service, tournament.Id, 4);
        var round = service.GenerateNextRound(tournament.Id);

        service.SetRoundLock(tournament.Id, round.RoundNumber, true);

        var ex = Assert.Throws<InvalidOperationException>(() =>
            service.RecordResult(tournament.Id, round.RoundNumber, 1, GameResultKind.WhiteWin));
        Assert.Contains("gesperrt", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void ManualPairingOverride_IsAuditedAndMarked()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Override Test", new TournamentSettings { Format = TournamentFormat.Swiss });
        AddPlayers(service, tournament.Id, 4);
        var round = service.GenerateNextRound(tournament.Id);
        var boardBefore = Assert.Single(round.Pairings.Where(pairing => pairing.BoardNumber == 1));
        var white = boardBefore.WhitePlayerId;
        var black = boardBefore.BlackPlayerId;

        var updated = service.OverridePairing(tournament.Id, round.RoundNumber, 1, white, black, "Test-Override");
        var board = Assert.Single(updated.Pairings.Where(pairing => pairing.BoardNumber == 1));

        Assert.True(board.IsManualOverride);
        Assert.Equal(white, board.WhitePlayerId);
        Assert.Equal(black, board.BlackPlayerId);
        Assert.Contains(updated.Audit.Messages, message => message.Contains("Manuelle Paarungsänderung", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public void NextRound_RequiresPreviousRoundComplete()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Round Complete Test", new TournamentSettings { Format = TournamentFormat.Swiss });
        AddPlayers(service, tournament.Id, 4);
        service.GenerateNextRound(tournament.Id);

        var ex = Assert.Throws<InvalidOperationException>(() => service.GenerateNextRound(tournament.Id));
        Assert.Contains("offene Ergebnisse", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void VerifiedRound_IsLockedAndCannotBeChanged()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Verify Test", new TournamentSettings { Format = TournamentFormat.Swiss });
        AddPlayers(service, tournament.Id, 4);
        var round = service.GenerateNextRound(tournament.Id);
        foreach (var pairing in round.Pairings.Where(pairing => !pairing.IsBye))
        {
            service.RecordResult(tournament.Id, round.RoundNumber, pairing.BoardNumber, GameResultKind.Draw);
        }

        var verified = service.SetRoundVerified(tournament.Id, round.RoundNumber, true);

        Assert.True(verified.IsVerified);
        Assert.True(verified.IsLocked);
        Assert.Equal(RoundResultStatus.Verified, verified.ResultStatus);
        Assert.Throws<InvalidOperationException>(() => service.RecordResult(tournament.Id, round.RoundNumber, 1, GameResultKind.WhiteWin));
    }

    private static void AddPlayers(TournamentService service, Guid tournamentId, int count)
    {
        for (var i = 1; i <= count; i++)
        {
            service.AddPlayer(tournamentId, new Player
            {
                Name = $"Spieler {i}",
                Rating = new RatingProfile { ManualTwz = 2000 - i * 10 }
            });
        }
    }
}
