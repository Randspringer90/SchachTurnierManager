using SchachTurnierManager.Application;
using SchachTurnierManager.Domain.Models;
using Xunit;

namespace SchachTurnierManager.Application.Tests;

public sealed class TournamentSettingsWorkflowTests
{
    [Fact]
    public void UpdateSettings_NormalizesTiebreaksAndPersistsChanges()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Einstellungen");

        var updated = service.UpdateSettings(tournament.Id, tournament.Settings with
        {
            ScoringSystem = ScoringSystem.ThreeOneZero,
            PlannedRounds = 0,
            UnplayedRoundBuchholzMode = UnplayedRoundBuchholzMode.FideVirtualOpponent,
            Tiebreaks = new[] { TiebreakType.Buchholz }
        });

        Assert.Equal(ScoringSystem.ThreeOneZero, updated.Settings.ScoringSystem);
        Assert.Equal(1, updated.Settings.PlannedRounds);
        Assert.Equal(UnplayedRoundBuchholzMode.FideVirtualOpponent, updated.Settings.UnplayedRoundBuchholzMode);
        Assert.Equal(new[] { TiebreakType.Buchholz, TiebreakType.StartingRank }, updated.Settings.Tiebreaks);
        var audit = Assert.Single(updated.AuditJournal, entry => entry.Action == AuditJournalAction.SettingsUpdated);
        Assert.Contains(nameof(UnplayedRoundBuchholzMode.FideVirtualOpponent), audit.Details);
    }

    [Fact]
    public void UpdateSettings_DoesNotAllowFormatChangeAfterPairingsExist()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Formatwechsel", new TournamentSettings { Format = TournamentFormat.Swiss });
        service.AddPlayer(tournament.Id, new Player { Name = "Alice" });
        service.AddPlayer(tournament.Id, new Player { Name = "Bob" });
        service.GenerateNextRound(tournament.Id);

        var ex = Assert.Throws<InvalidOperationException>(() => service.UpdateSettings(tournament.Id, tournament.Settings with { Format = TournamentFormat.RoundRobin }));

        Assert.Contains("Turnierformat", ex.Message);
    }

    [Fact]
    public void UpdateSettings_InvalidUnplayedRoundModeFallsBackToLegacyDefault()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Legacy-Fallback");

        var updated = service.UpdateSettings(tournament.Id, tournament.Settings with
        {
            UnplayedRoundBuchholzMode = (UnplayedRoundBuchholzMode)999
        });

        Assert.Equal(UnplayedRoundBuchholzMode.IgnoreUnplayedRounds, updated.Settings.UnplayedRoundBuchholzMode);
    }
}
