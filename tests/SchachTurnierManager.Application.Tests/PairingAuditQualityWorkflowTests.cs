using SchachTurnierManager.Domain.Models;
using Xunit;

namespace SchachTurnierManager.Application.Tests;

public sealed class PairingAuditQualityWorkflowTests
{
    [Fact]
    public void GenerateNextRound_AppendsPairingQualitySummaryToAudit()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Audit Quality", new TournamentSettings { Format = TournamentFormat.Swiss });
        AddPlayers(service, tournament.Id, 4);

        var round = service.GenerateNextRound(tournament.Id);

        Assert.Contains(round.Audit.Messages, message => message.Contains("Paarungsqualität", StringComparison.OrdinalIgnoreCase));
        Assert.Contains(round.Audit.Messages, message => message.Contains("Qualitätsprüfung", StringComparison.OrdinalIgnoreCase));
        Assert.Equal("Swiss-ScoreGroup-Optimal-V2", round.Audit.Algorithm);
    }

    [Fact]
    public void SecondSwissRound_AvoidsRematchesAndKeepsQualityAuditReadable()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Swiss Golden", new TournamentSettings { Format = TournamentFormat.Swiss });
        AddPlayers(service, tournament.Id, 6);

        var firstRound = service.GenerateNextRound(tournament.Id);
        foreach (var pairing in firstRound.Pairings.Where(pairing => !pairing.IsBye))
        {
            service.RecordResult(tournament.Id, firstRound.RoundNumber, pairing.BoardNumber, GameResultKind.WhiteWin);
        }

        var secondRound = service.GenerateNextRound(tournament.Id);
        var quality = service.GetPairingQuality(tournament.Id, secondRound.RoundNumber);

        Assert.Equal(0, quality.RematchCount);
        Assert.False(quality.HasCriticalIssues);
        Assert.Contains(secondRound.Audit.Messages, message => message.Contains("Paarungsqualität", StringComparison.OrdinalIgnoreCase));
        foreach (var firstRoundPairing in firstRound.Pairings.Where(pairing => !pairing.IsBye))
        {
            Assert.DoesNotContain(secondRound.Pairings, pairing => IsPair(pairing, firstRoundPairing.WhitePlayerId!.Value, firstRoundPairing.BlackPlayerId!.Value));
        }
    }

    private static void AddPlayers(TournamentService service, Guid tournamentId, int count)
    {
        for (var i = 1; i <= count; i++)
        {
            service.AddPlayer(tournamentId, new Player
            {
                Id = Guid.Parse($"00000000-0000-0000-0000-{i:000000000000}"),
                Name = $"Spieler {i}",
                Rating = new RatingProfile { ManualTwz = 2200 - i * 25 },
                StartingRank = i
            });
        }
    }

    private static bool IsPair(Pairing pairing, Guid a, Guid b)
    {
        return (pairing.WhitePlayerId == a && pairing.BlackPlayerId == b) ||
               (pairing.WhitePlayerId == b && pairing.BlackPlayerId == a);
    }
}