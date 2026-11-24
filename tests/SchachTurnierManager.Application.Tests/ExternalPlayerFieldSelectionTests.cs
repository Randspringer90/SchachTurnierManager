using System.Text.Json;
using SchachTurnierManager.Domain.Models;
using Xunit;

namespace SchachTurnierManager.Application.Tests;

public sealed class ExternalPlayerFieldSelectionTests
{
    private static ExternalPlayerProfile Profile => new()
    {
        Source = ExternalPlayerSource.Fide, ExternalId = "99900101", FideId = "99900101",
        Name = "Synthetic External Name", Federation = "GER", Country = "Germany", Title = "FM",
        Elo = 2100, RapidElo = 2000, BirthYear = 1995, Gender = GenderCategory.Female
    };

    [Fact]
    public void CreatingFromExternalProfileCannotDuplicateAnExistingExternalId()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Synthetic FIDE duplicate");
        service.AddPlayer(tournament.Id, new Player { Name = "Synthetic Existing", FideId = Profile.FideId });
        var before = JsonSerializer.Serialize(service.RequireTournament(tournament.Id));
        Assert.Throws<InvalidOperationException>(() => service.ApplyExternalPlayer(tournament.Id, Profile, null, true, false));
        Assert.Equal(before, JsonSerializer.Serialize(service.RequireTournament(tournament.Id)));
    }

    [Fact]
    public void OnlyExplicitlySelectedFieldsAreAppliedAndAudited()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Synthetic confirmed FIDE fields");
        var existing = service.AddPlayer(tournament.Id, new Player { Name = "Synthetic Kept Name", Country = "Kept Country", Federation = "USA", Title = "CM", Rating = new RatingProfile { Elo = 1500, RapidElo = 1400 } });
        var result = service.ApplyExternalPlayer(tournament.Id, Profile, existing.Id, false, true, ["elo", "federation"], existing);
        Assert.Equal(2100, result.Player.Rating.Elo);
        Assert.Equal("GER", result.Player.Federation);
        Assert.Equal(existing.Name, result.Player.Name);
        Assert.Equal(existing.Country, result.Player.Country);
        Assert.Equal(existing.Title, result.Player.Title);
        Assert.Equal(existing.Rating.RapidElo, result.Player.Rating.RapidElo);
        Assert.Null(result.Player.FideId);
        Assert.Null(result.Player.BirthYear);
        Assert.Equal(existing.Gender, result.Player.Gender);
        Assert.Contains("Elo", result.ChangedFields);
        Assert.Contains("Verband/Federation", result.ChangedFields);
        Assert.Contains(service.GetAuditJournal(tournament.Id), entry => entry.Action == AuditJournalAction.ExternalPlayerApplied);
    }

    [Theory]
    [InlineData("")]
    [InlineData("unexpected")]
    [InlineData("Elo")]
    public void InvalidFieldSelectionDoesNotChangeAnyState(string field)
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Synthetic invalid field selection");
        var existing = service.AddPlayer(tournament.Id, new Player { Name = "Synthetic Kept" });
        var before = JsonSerializer.Serialize(service.RequireTournament(tournament.Id));
        Assert.Throws<InvalidOperationException>(() => service.ApplyExternalPlayer(tournament.Id, Profile, existing.Id, false, true, [field], existing));
        Assert.Equal(before, JsonSerializer.Serialize(service.RequireTournament(tournament.Id)));
    }

    [Fact]
    public void NewPlayerRequiresExplicitNameSelectionAndDoesNotImportOtherFields()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Synthetic new selected fields");
        Assert.Throws<InvalidOperationException>(() => service.ApplyExternalPlayer(tournament.Id, Profile, null, true, true, ["elo"]));
        var result = service.ApplyExternalPlayer(tournament.Id, Profile, null, true, true, ["name", "fideId", "elo"]);
        Assert.Equal(Profile.Name, result.Player.Name);
        Assert.Equal(Profile.FideId, result.Player.FideId);
        Assert.Equal(Profile.Elo, result.Player.Rating.Elo);
        Assert.Null(result.Player.Title);
        Assert.Null(result.Player.Federation);
        Assert.Single(service.RequireTournament(tournament.Id).Players);
    }

    [Fact]
    public void AStaleOrMissingTargetSnapshotCannotOverwriteNewerLocalValues()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Synthetic FIDE stale confirmation");
        var existing = service.AddPlayer(tournament.Id, new Player { Name = "Synthetic Target", Rating = new RatingProfile { Elo = 1500 } });
        service.UpdatePlayer(tournament.Id, existing.Id, existing with { Rating = existing.Rating with { Elo = 1700 } });
        var before = JsonSerializer.Serialize(service.RequireTournament(tournament.Id));
        Assert.ThrowsAny<InvalidOperationException>(() => service.ApplyExternalPlayer(tournament.Id, Profile, existing.Id, false, true, ["elo"], existing));
        Assert.ThrowsAny<InvalidOperationException>(() => service.ApplyExternalPlayer(tournament.Id, Profile, existing.Id, false, true, ["elo"]));
        Assert.Equal(before, JsonSerializer.Serialize(service.RequireTournament(tournament.Id)));
    }
}
