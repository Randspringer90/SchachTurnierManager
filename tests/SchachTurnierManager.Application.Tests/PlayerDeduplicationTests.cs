using SchachTurnierManager.Application;
using SchachTurnierManager.Domain.Models;
using Xunit;

namespace SchachTurnierManager.Application.Tests;

public sealed class PlayerDeduplicationTests
{
    [Fact]
    public void AddPlayer_WithDuplicateFideId_Throws()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Dedupe");
        service.AddPlayer(tournament.Id, new Player { Name = "Lina Weißbach", FideId = "99900123" });

        var ex = Assert.Throws<InvalidOperationException>(() =>
            service.AddPlayer(tournament.Id, new Player { Name = "Anderer Name", FideId = "99900123" }));

        Assert.Contains("FIDE-ID", ex.Message);
        Assert.Single(service.RequireTournament(tournament.Id).Players);
    }

    [Fact]
    public void AddPlayer_WithDuplicateNationalId_Throws()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Dedupe");
        service.AddPlayer(tournament.Id, new Player { Name = "Spieler A", NationalId = "12345-X" });

        var ex = Assert.Throws<InvalidOperationException>(() =>
            service.AddPlayer(tournament.Id, new Player { Name = "Spieler B", NationalId = "12345X" }));

        Assert.Contains("DSB-ID", ex.Message);
    }

    [Fact]
    public void AddPlayer_WithoutIds_AllowsDistinctNames()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Dedupe");
        service.AddPlayer(tournament.Id, new Player { Name = "Spieler A" });
        service.AddPlayer(tournament.Id, new Player { Name = "Spieler B" });

        Assert.Equal(2, service.RequireTournament(tournament.Id).Players.Count);
    }

    [Fact]
    public void ImportPlayersCsv_SkipsDuplicateFideId()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Import Dedupe");
        const string csv =
            "Name;Verein;Geburtsjahr;Geschlecht;DWZ;DWZIndex;Elo;TWZ;FIDE-ID;DSB-ID;Titel;Status;Notizen\n"
            + "Lina Weißbach;;;;;;;;99900123;;;;\n"
            + "Doppelter Eintrag;;;;;;;;99900123;;;;\n"
            + "Andere Person;;;;;;;;1111111;;;;\n";

        var added = service.ImportPlayersCsv(tournament.Id, csv, replaceExisting: false);

        Assert.Equal(2, added.Count);
        Assert.Equal(2, service.RequireTournament(tournament.Id).Players.Count);
        Assert.DoesNotContain(service.RequireTournament(tournament.Id).Players, p => p.Name == "Doppelter Eintrag");
    }
}
