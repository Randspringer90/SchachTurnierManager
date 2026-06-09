using SchachTurnierManager.Domain.Models;
using Xunit;

namespace SchachTurnierManager.Application.Tests;

public sealed class SwissRegressionScenarioTests
{
    [Fact]
    public void OddSwissTournament_PreviewSecondRoundKeepsByeAndPairingsConsistent()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Swiss Odd Regression", new TournamentSettings { Format = TournamentFormat.Swiss });
        AddPlayers(service, tournament.Id, 5);

        var firstRound = service.GenerateNextRound(tournament.Id);
        Assert.Equal(3, firstRound.Pairings.Count);
        Assert.Single(firstRound.Pairings, pairing => pairing.IsBye);

        RecordAllNonByeResults(service, tournament.Id, firstRound, GameResultKind.WhiteWin);

        var preview = service.PreviewNextRound(tournament.Id);
        var persisted = service.RequireTournament(tournament.Id);

        Assert.Equal(2, preview.RoundNumber);
        Assert.Single(persisted.Rounds);
        Assert.Single(preview.Round.Pairings, pairing => pairing.IsBye);
        Assert.Equal(0, preview.PairingQuality.RematchCount);
        Assert.True(preview.IsSavable);
        AssertAllActivePlayersAppearAtMostOnce(preview.Round);
    }

    [Fact]
    public void ForfeitResult_CompletesRoundAndDiagnosticsExplainTiebreakImpact()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Forfeit Regression", new TournamentSettings { Format = TournamentFormat.Swiss });
        AddPlayers(service, tournament.Id, 4);
        var round = service.GenerateNextRound(tournament.Id);

        service.RecordResult(tournament.Id, round.RoundNumber, 1, GameResultKind.WhiteForfeitWin);
        service.RecordResult(tournament.Id, round.RoundNumber, 2, GameResultKind.Draw);

        var diagnostics = service.GetRoundDiagnostics(tournament.Id, round.RoundNumber);
        var forfeitBoard = Assert.Single(diagnostics.Boards.Where(board => board.IsForfeit));

        Assert.True(diagnostics.IsComplete);
        Assert.Equal(RoundResultStatus.Complete, service.RequireTournament(tournament.Id).Rounds.Single().ResultStatus);
        Assert.Equal(0, diagnostics.OpenBoards);
        Assert.Equal(1, diagnostics.ForfeitBoards);
        Assert.False(forfeitBoard.CountsForPerformance);
        Assert.Contains(diagnostics.Warnings, warning => warning.Contains("kampflos", StringComparison.OrdinalIgnoreCase));

        var preview = service.PreviewNextRound(tournament.Id);
        Assert.Equal(2, preview.RoundNumber);
    }

    [Fact]
    public void WithdrawnPlayer_AfterCompletedRound_IsNotPairedInNextPreview()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Withdrawal Regression", new TournamentSettings { Format = TournamentFormat.Swiss });
        AddPlayers(service, tournament.Id, 6);
        var firstRound = service.GenerateNextRound(tournament.Id);
        RecordAllNonByeResults(service, tournament.Id, firstRound, GameResultKind.Draw);

        var withdrawnPlayerId = firstRound.Pairings.First(pairing => !pairing.IsBye).WhitePlayerId!.Value;
        var withdrawn = service.RemovePlayer(tournament.Id, withdrawnPlayerId);

        var preview = service.PreviewNextRound(tournament.Id);

        Assert.Equal(PlayerStatus.Withdrawn, withdrawn.Status);
        Assert.DoesNotContain(preview.Round.Pairings, pairing => pairing.WhitePlayerId == withdrawnPlayerId || pairing.BlackPlayerId == withdrawnPlayerId);
        Assert.Single(preview.Round.Pairings, pairing => pairing.IsBye);
        AssertAllActivePlayersAppearAtMostOnce(preview.Round);
    }

    private static void AddPlayers(TournamentService service, Guid tournamentId, int count)
    {
        for (var i = 1; i <= count; i++)
        {
            service.AddPlayer(tournamentId, new Player
            {
                Id = Guid.Parse($"00000000-0000-0000-0000-{i:000000000000}"),
                Name = $"Regression Spieler {i}",
                StartingRank = i,
                Rating = new RatingProfile { ManualTwz = 2200 - i * 20 }
            });
        }
    }

    private static void RecordAllNonByeResults(TournamentService service, Guid tournamentId, TournamentRound round, GameResultKind result)
    {
        foreach (var pairing in round.Pairings.Where(pairing => !pairing.IsBye))
        {
            service.RecordResult(tournamentId, round.RoundNumber, pairing.BoardNumber, result);
        }
    }

    private static void AssertAllActivePlayersAppearAtMostOnce(TournamentRound round)
    {
        var playerIds = round.Pairings
            .SelectMany(pairing => new[] { pairing.WhitePlayerId, pairing.BlackPlayerId })
            .Where(playerId => playerId is not null)
            .Select(playerId => playerId!.Value)
            .ToList();

        Assert.Equal(playerIds.Count, playerIds.Distinct().Count());
    }
}
