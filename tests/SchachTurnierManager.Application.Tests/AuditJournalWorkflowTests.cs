using SchachTurnierManager.Domain.Models;
using Xunit;

namespace SchachTurnierManager.Application.Tests;

public sealed class AuditJournalWorkflowTests
{
    [Fact]
    public void AuditJournal_TracksCoreTournamentWorkflow()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Audit Test", new TournamentSettings { Format = TournamentFormat.Swiss });
        var alice = service.AddPlayer(tournament.Id, new Player { Name = "Alice", Rating = new RatingProfile { ManualTwz = 2100 } });
        var bob = service.AddPlayer(tournament.Id, new Player { Name = "Bob", Rating = new RatingProfile { ManualTwz = 2000 } });
        service.AddPlayer(tournament.Id, new Player { Name = "Carla", Rating = new RatingProfile { ManualTwz = 1900 } });
        service.AddPlayer(tournament.Id, new Player { Name = "David", Rating = new RatingProfile { ManualTwz = 1800 } });

        service.UpdatePlayer(tournament.Id, bob.Id, bob with { Club = "Ilmenauer SV" });
        service.SetPlayerStatus(tournament.Id, alice.Id, PlayerStatus.Paused);
        service.SetPlayerStatus(tournament.Id, alice.Id, PlayerStatus.Active);
        var round = service.GenerateNextRound(tournament.Id);
        service.RecordResult(tournament.Id, round.RoundNumber, 1, GameResultKind.WhiteWin);

        var journal = service.GetAuditJournal(tournament.Id);

        Assert.Contains(journal, entry => entry.Action == AuditJournalAction.TournamentCreated);
        Assert.Contains(journal, entry => entry.Action == AuditJournalAction.PlayerAdded && entry.PlayerName == "Alice");
        Assert.Contains(journal, entry => entry.Action == AuditJournalAction.PlayerUpdated && entry.PlayerId == bob.Id);
        Assert.Contains(journal, entry => entry.Action == AuditJournalAction.PlayerStatusChanged && entry.PlayerId == alice.Id);
        Assert.Contains(journal, entry => entry.Action == AuditJournalAction.RoundGenerated && entry.RoundNumber == round.RoundNumber);
        Assert.Contains(journal, entry => entry.Action == AuditJournalAction.ResultRecorded && entry.RoundNumber == round.RoundNumber && entry.BoardNumber == 1);
        Assert.All(journal, entry => Assert.NotEqual(default, entry.CreatedAt));
        Assert.All(journal, entry => Assert.False(string.IsNullOrWhiteSpace(entry.Summary)));
    }

    [Fact]
    public void AuditJournal_TracksManualCorrectionsAndRoundReview()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Correction Audit", new TournamentSettings { Format = TournamentFormat.Swiss });
        AddPlayers(service, tournament.Id, 4);
        var round = service.GenerateNextRound(tournament.Id);
        var board = Assert.Single(round.Pairings, pairing => pairing.BoardNumber == 1);

        service.OverridePairing(tournament.Id, round.RoundNumber, 1, board.WhitePlayerId, board.BlackPlayerId, "Korrektur durch Turnierleitung");
        foreach (var pairing in service.RequireTournament(tournament.Id).Rounds.Single().Pairings.Where(pairing => !pairing.IsBye))
        {
            service.RecordResult(tournament.Id, round.RoundNumber, pairing.BoardNumber, GameResultKind.Draw);
        }

        service.SetRoundLock(tournament.Id, round.RoundNumber, true);
        service.SetRoundLock(tournament.Id, round.RoundNumber, false);
        service.SetRoundVerified(tournament.Id, round.RoundNumber, true);

        var journal = service.GetAuditJournal(tournament.Id);

        Assert.Contains(journal, entry => entry.Action == AuditJournalAction.PairingOverridden && entry.Severity == AuditJournalSeverity.Warning);
        Assert.Contains(journal, entry => entry.Action == AuditJournalAction.RoundLocked);
        Assert.Contains(journal, entry => entry.Action == AuditJournalAction.RoundUnlocked);
        Assert.Contains(journal, entry => entry.Action == AuditJournalAction.RoundVerified);
        Assert.Contains(journal, entry => entry.Details is not null && entry.Details.Contains("Korrektur", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public void AuditJournal_IsPartOfTournamentStateSnapshot()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Snapshot Audit", new TournamentSettings { Format = TournamentFormat.Swiss });
        service.AddPlayer(tournament.Id, new Player { Name = "Snapshot Spieler" });

        var snapshot = service.RequireTournament(tournament.Id);

        Assert.NotEmpty(snapshot.AuditJournal);
        Assert.Contains(snapshot.AuditJournal, entry => entry.Action == AuditJournalAction.TournamentCreated);
        Assert.Contains(snapshot.AuditJournal, entry => entry.Action == AuditJournalAction.PlayerAdded);
    }

    private static void AddPlayers(TournamentService service, Guid tournamentId, int count)
    {
        for (var i = 1; i <= count; i++)
        {
            service.AddPlayer(tournamentId, new Player
            {
                Name = $"Audit Spieler {i}",
                Rating = new RatingProfile { ManualTwz = 2200 - i * 25 }
            });
        }
    }
}
