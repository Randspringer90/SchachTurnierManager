using SchachTurnierManager.Domain.Models;
using Xunit;

namespace SchachTurnierManager.Application.Tests;

public sealed class NextRoundPreviewWorkflowTests
{
    [Fact]
    public void PreviewNextRound_DoesNotPersistRound()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Preview Test", new TournamentSettings { Format = TournamentFormat.Swiss });
        AddPlayers(service, tournament.Id, 6);

        var preview = service.PreviewNextRound(tournament.Id);
        var afterPreview = service.RequireTournament(tournament.Id);

        Assert.Equal(1, preview.RoundNumber);
        Assert.Equal(3, preview.BoardCount);
        Assert.Equal(3, preview.Round.Pairings.Count);
        Assert.True(preview.IsSavable);
        Assert.NotEmpty(preview.Messages);
        Assert.Contains("nicht gespeichert", string.Join(" ", preview.Messages), StringComparison.OrdinalIgnoreCase);
        Assert.Empty(afterPreview.Rounds);
    }

    [Fact]
    public void PreviewNextRound_RequiresCompletedPreviousRound()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Open Round Preview Test", new TournamentSettings { Format = TournamentFormat.Swiss });
        AddPlayers(service, tournament.Id, 4);
        service.GenerateNextRound(tournament.Id);

        var ex = Assert.Throws<InvalidOperationException>(() => service.PreviewNextRound(tournament.Id));

        Assert.Contains("offene Ergebnisse", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void PreviewNextRound_ProvidesPairingQualitySummary()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Quality Preview Test", new TournamentSettings { Format = TournamentFormat.Swiss });
        AddPlayers(service, tournament.Id, 5);

        var preview = service.PreviewNextRound(tournament.Id);

        Assert.InRange(preview.PairingQuality.QualityScore, 0, 100);
        Assert.Equal(preview.Round.RoundNumber, preview.PairingQuality.RoundNumber);
        Assert.Contains("Qualität", preview.Summary, StringComparison.OrdinalIgnoreCase);
        Assert.Contains(preview.Messages, message => message.Contains("Vorschau", StringComparison.OrdinalIgnoreCase));
    }

    private static void AddPlayers(TournamentService service, Guid tournamentId, int count)
    {
        for (var i = 1; i <= count; i++)
        {
            service.AddPlayer(tournamentId, new Player
            {
                Name = $"Preview Spieler {i}",
                Rating = new RatingProfile { ManualTwz = 2100 - i * 25 }
            });
        }
    }
}
