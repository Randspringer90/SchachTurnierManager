using SchachTurnierManager.Domain.Models;
using Xunit;

namespace SchachTurnierManager.Application.Tests;

public sealed class ExternalPlayerApplyWorkflowTests
{
    [Fact]
    public void CheckExternalPlayerDuplicates_FindsFideIdMatch()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Vereinsturnier");
        var existing = service.AddPlayer(tournament.Id, new Player
        {
            Name = "Marco Geißhirt",
            BirthYear = 1990,
            FideId = "4610563"
        });

        var duplicateCheck = service.CheckExternalPlayerDuplicates(tournament.Id, MarcoFideProfile());

        var match = Assert.Single(duplicateCheck.Matches);
        Assert.True(duplicateCheck.HasLikelyDuplicate);
        Assert.Equal(existing.Id, match.PlayerId);
        Assert.Equal(ExternalPlayerDuplicateKind.FideId, match.Kind);
        Assert.Equal(100, match.Score);
    }

    [Fact]
    public void CheckExternalPlayerDuplicates_FindsNameAndBirthYearMatch()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Vereinsturnier");
        var existing = service.AddPlayer(tournament.Id, new Player
        {
            Name = "Marco Geisshirt",
            BirthYear = 1990
        });

        var duplicateCheck = service.CheckExternalPlayerDuplicates(tournament.Id, MarcoFideProfile());

        var match = Assert.Single(duplicateCheck.Matches);
        Assert.True(duplicateCheck.HasLikelyDuplicate);
        Assert.Equal(existing.Id, match.PlayerId);
        Assert.Equal(ExternalPlayerDuplicateKind.NameAndBirthYear, match.Kind);
        Assert.Equal(85, match.Score);
    }

    [Fact]
    public void CheckExternalPlayerDuplicates_ReportsConflictsForLikelyDuplicate()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Vereinsturnier");
        var existing = service.AddPlayer(tournament.Id, new Player
        {
            Name = "Marco Geißhirt",
            BirthYear = 1989,
            FideId = "4610563",
            Rating = new RatingProfile { Elo = 1900 }
        });

        var duplicateCheck = service.CheckExternalPlayerDuplicates(tournament.Id, MarcoFideProfile());

        Assert.True(duplicateCheck.HasLikelyDuplicate);
        Assert.True(duplicateCheck.HasCriticalConflict);
        Assert.Contains(duplicateCheck.Conflicts, conflict =>
            conflict.PlayerId == existing.Id
            && conflict.FieldName == "Geburtsjahr"
            && conflict.LocalValue == "1989"
            && conflict.ExternalValue == "1990"
            && conflict.Severity == ExternalPlayerConflictSeverity.Critical
            && !conflict.WillOverwrite);
        Assert.Contains(duplicateCheck.Conflicts, conflict =>
            conflict.FieldName == "Elo"
            && conflict.LocalValue == "1900"
            && conflict.ExternalValue == "1968"
            && conflict.Severity == ExternalPlayerConflictSeverity.Warning);
    }

    [Fact]
    public void ApplyExternalPlayer_CreatesNewPlayerAndReturnsDuplicateWarning()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Vereinsturnier");
        service.AddPlayer(tournament.Id, new Player
        {
            Name = "Marco Geißhirt",
            BirthYear = 1990,
            FideId = "4610563"
        });

        var result = service.ApplyExternalPlayer(tournament.Id, MarcoFideProfile(), targetPlayerId: null, createIfNoTarget: true, overwriteExistingValues: false);
        var updated = service.RequireTournament(tournament.Id);

        Assert.True(result.Created);
        Assert.False(result.Updated);
        Assert.True(result.DuplicateCheck.HasLikelyDuplicate);
        Assert.Equal(2, updated.Players.Count);
        Assert.Equal("4610563", result.Player.FideId);
        Assert.Contains("FIDE-ID", result.ChangedFields);
    }

    [Fact]
    public void ApplyExternalPlayer_UpdatesExistingPlayerAndPreservesLocalValuesByDefault()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Vereinsturnier");
        var existing = service.AddPlayer(tournament.Id, new Player
        {
            Name = "Marco Geißhirt",
            Club = "Ilmenauer SV",
            BirthYear = 1990,
            Rating = new RatingProfile { ManualTwz = 2000, Elo = 1900 }
        });

        var result = service.ApplyExternalPlayer(tournament.Id, MarcoFideProfile(), existing.Id, createIfNoTarget: false, overwriteExistingValues: false);

        Assert.True(result.Updated);
        Assert.False(result.Created);
        Assert.Equal(existing.Id, result.Player.Id);
        Assert.Equal(existing.StartingRank, result.Player.StartingRank);
        Assert.Equal("Ilmenauer SV", result.Player.Club);
        Assert.Equal(1900, result.Player.Rating.Elo);
        Assert.Equal(2000, result.Player.Rating.ManualTwz);
        Assert.Equal("4610563", result.Player.FideId);
        Assert.Contains("FIDE-ID", result.ChangedFields);
        Assert.DoesNotContain("Elo", result.ChangedFields);
        Assert.Contains("Externe Spielerdaten übernommen", result.Player.Notes);
    }

    [Fact]
    public void ApplyExternalPlayer_ReturnsConflictsWhenPreservingLocalValues()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Vereinsturnier");
        var existing = service.AddPlayer(tournament.Id, new Player
        {
            Name = "Marco Geißhirt",
            BirthYear = 1990,
            Rating = new RatingProfile { Elo = 1900 }
        });

        var result = service.ApplyExternalPlayer(tournament.Id, MarcoFideProfile(), existing.Id, createIfNoTarget: false, overwriteExistingValues: false);

        Assert.Equal(1900, result.Player.Rating.Elo);
        Assert.Contains(result.Conflicts, conflict =>
            conflict.FieldName == "Elo"
            && conflict.LocalValue == "1900"
            && conflict.ExternalValue == "1968"
            && !conflict.WillOverwrite);
    }

    [Fact]
    public void ApplyExternalPlayer_OverwritesExistingValuesWhenRequested()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Vereinsturnier");
        var existing = service.AddPlayer(tournament.Id, new Player
        {
            Name = "Marco Geißhirt",
            Rating = new RatingProfile { Elo = 1900 }
        });

        var result = service.ApplyExternalPlayer(tournament.Id, MarcoFideProfile(), existing.Id, createIfNoTarget: false, overwriteExistingValues: true);

        Assert.Equal(1968, result.Player.Rating.Elo);
        Assert.Contains("Elo", result.ChangedFields);
        Assert.Contains(result.Conflicts, conflict => conflict.FieldName == "Elo" && conflict.WillOverwrite);
        Assert.Equal(GenderCategory.Male, result.Player.Gender);
        Assert.Equal(1990, result.Player.BirthYear);
    }

    private static ExternalPlayerProfile MarcoFideProfile() => new()
    {
        Source = ExternalPlayerSource.Fide,
        ExternalId = "4610563",
        Name = "Geisshirt, Marco",
        Federation = "Germany",
        Country = "Germany",
        BirthYear = 1990,
        Gender = GenderCategory.Male,
        FideId = "4610563",
        Elo = 1968,
        RapidElo = 1800,
        BlitzElo = 1750,
        ProfileUrl = "https://ratings.fide.com/profile/4610563",
        Notes = "Aus FIDE-Ratings-Profil importiert."
    };
}
