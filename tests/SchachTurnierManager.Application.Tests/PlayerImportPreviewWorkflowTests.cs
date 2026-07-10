using SchachTurnierManager.Domain.Models;
using Xunit;

namespace SchachTurnierManager.Application.Tests;

public sealed class PlayerImportPreviewWorkflowTests
{
    [Fact]
    public void PreviewPlayersCsv_FindsExistingFideDuplicate()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Vereinsturnier");
        service.AddPlayer(tournament.Id, new Player
        {
            Name = "Lina Weißbach",
            BirthYear = 1990,
            FideId = "99900123"
        });

        var preview = service.PreviewPlayersCsv(tournament.Id, SyntheticCsv(), replaceExisting: false);

        var row = Assert.Single(preview.Rows);
        Assert.Equal(PlayerImportPreviewRowStatus.Warning, row.Status);
        Assert.True(row.DuplicateCheck.HasLikelyDuplicate);
        Assert.Equal(1, preview.LikelyDuplicateRows);
        Assert.Contains(row.DuplicateCheck.Matches, match => match.Kind == ExternalPlayerDuplicateKind.FideId);
    }

    [Fact]
    public void PreviewPlayersCsv_FindsDuplicatesInsideImportFile()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Vereinsturnier");

        var preview = service.PreviewPlayersCsv(tournament.Id, Header() + """
Weissbach, Lina;Beispiel SV;1990;männlich;;;1968;;99900123;;;;
Weißbach, Lina;Beispiel SV;1990;männlich;;;1968;;99900123;;;;
""", replaceExisting: false);

        Assert.Equal(2, preview.Rows.Count);
        Assert.Equal(PlayerImportPreviewRowStatus.Ready, preview.Rows[0].Status);
        Assert.Equal(PlayerImportPreviewRowStatus.Warning, preview.Rows[1].Status);
        Assert.Contains(preview.Rows[1].Warnings, warning => warning.Contains("FIDE-ID", StringComparison.OrdinalIgnoreCase));
        Assert.Contains(preview.Rows[1].Warnings, warning => warning.Contains("Name + Geburtsjahr", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public void PreviewPlayersCsv_BlocksReplaceExistingAfterRounds()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Vereinsturnier");
        service.AddPlayer(tournament.Id, new Player { Name = "Spieler A" });
        service.AddPlayer(tournament.Id, new Player { Name = "Spieler B" });
        service.GenerateNextRound(tournament.Id);

        var preview = service.PreviewPlayersCsv(tournament.Id, SyntheticCsv(), replaceExisting: true);

        Assert.True(preview.HasBlockingIssues);
        Assert.Single(preview.Rows);
        Assert.Equal(PlayerImportPreviewRowStatus.Blocked, preview.Rows[0].Status);
        Assert.Contains(preview.Rows[0].BlockingIssues, issue => issue.Contains("nicht erlaubt", StringComparison.OrdinalIgnoreCase));
    }

    private static string Header() => "Name;Verein;Geburtsjahr;Geschlecht;DWZ;DWZIndex;Elo;TWZ;FIDE-ID;DSB-ID;Titel;Status;Notizen\n";

    private static string SyntheticCsv() => Header() + "Weissbach, Lina;Beispiel SV;1990;männlich;;;1968;;99900123;;IA;;Importtest\n";
}
