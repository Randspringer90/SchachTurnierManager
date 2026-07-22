using SchachTurnierManager.Application;
using SchachTurnierManager.Domain.Models;
using Xunit;

namespace SchachTurnierManager.Application.Tests;

/// <summary>
/// Vertrag des Ablaufs "Turnier anlegen" (STM-STAB-001).
///
/// Der Ablauf war im echten Browser zeitweise defekt, ohne dass ein Test das
/// sehen konnte: die vorhandenen Tests decken Auslosung und Wertung ab, aber
/// nicht die Zusagen, auf die sich das Anlageformular verlaesst - Trimmen des
/// Namens, Ablehnung leerer Namen, exakte Uebernahme der Formularoptionen und
/// die Fehlerform, aus der die Oberflaeche ihren Text bildet.
/// </summary>
public sealed class TournamentCreationWorkflowTests
{
    [Fact]
    public void CreateTournament_WithValidName_IsImmediatelyListable()
    {
        var service = new TournamentService(new InMemoryTournamentStore());

        var created = service.CreateTournament("Vereinsturnier 2026");

        var listed = service.ListTournaments();
        Assert.Single(listed);
        Assert.Equal(created.Id, listed[0].Id);
        Assert.Equal("Vereinsturnier 2026", listed[0].Name);
        Assert.NotEqual(Guid.Empty, created.Id);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("\t")]
    [InlineData("\r\n")]
    public void CreateTournament_WithBlankName_IsRejectedWithAnActionableMessage(string name)
    {
        var service = new TournamentService(new InMemoryTournamentStore());

        var exception = Assert.Throws<ArgumentException>(() => service.CreateTournament(name));

        // Die Oberflaeche zeigt genau diesen Text an, wenn das Backend ablehnt.
        // Er muss also fuer einen Turnierleiter lesbar sein, nicht nur fuer den
        // Entwickler.
        Assert.Contains("Turniername", exception.Message);
        Assert.Empty(service.ListTournaments());
    }

    [Fact]
    public void CreateTournament_TrimsSurroundingWhitespace()
    {
        var service = new TournamentService(new InMemoryTournamentStore());

        var created = service.CreateTournament("  Bergfest  ");

        Assert.Equal("Bergfest", created.Name);
    }

    [Fact]
    public void CreateTournament_WithTheSameNameTwice_YieldsTwoDistinctTournaments()
    {
        // Bewusstes Verhalten: an einem Turniertag entstehen durchaus zwei
        // Turniere mit gleichem Namen (z. B. zwei Gruppen). Die Oberflaeche
        // unterscheidet ueber die Id, nicht ueber den Namen - und der
        // Doppelklickschutz im Formular haengt genau daran, dass das Backend
        // hier nicht selbst dedupliziert.
        var service = new TournamentService(new InMemoryTournamentStore());

        var first = service.CreateTournament("Blitz");
        var second = service.CreateTournament("Blitz");

        Assert.NotEqual(first.Id, second.Id);
        Assert.Equal(2, service.ListTournaments().Count);
    }

    [Fact]
    public void CreateTournament_TakesTheFormOptionsOverUnchanged()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var settings = new TournamentSettings
        {
            Format = TournamentFormat.Swiss,
            PairingStrategy = SwissPairingStrategyKind.FideDutch,
            SwissInitialColour = ChessColor.Black,
            PlannedRounds = 7
        };

        var created = service.CreateTournament("Dutch Test", settings);

        var stored = service.RequireTournament(created.Id);
        Assert.Equal(TournamentFormat.Swiss, stored.Settings.Format);
        Assert.Equal(SwissPairingStrategyKind.FideDutch, stored.Settings.PairingStrategy);
        Assert.Equal(ChessColor.Black, stored.Settings.SwissInitialColour);
        Assert.Equal(7, stored.Settings.PlannedRounds);
    }

    [Fact]
    public void CreateTournament_WithoutSettings_UsesTheDocumentedDefaults()
    {
        var service = new TournamentService(new InMemoryTournamentStore());

        var created = service.CreateTournament("Standard");

        Assert.Equal(TournamentFormat.Swiss, created.Settings.Format);
        Assert.Equal(SwissPairingStrategyKind.OptimalMatchingV2, created.Settings.PairingStrategy);
        Assert.NotEmpty(created.Settings.Tiebreaks);
    }

    [Fact]
    public void CreateTournament_StartsAnEmptyTournamentWithAnAuditTrail()
    {
        var service = new TournamentService(new InMemoryTournamentStore());

        var created = service.CreateTournament("Auditiert");

        Assert.Empty(created.Players);
        Assert.Empty(created.Rounds);
        Assert.Contains(created.AuditJournal, entry => entry.Action == AuditJournalAction.TournamentCreated);
    }

    [Fact]
    public void RequireTournament_ForAnUnknownId_FailsInsteadOfReturningAnEmptyTournament()
    {
        // Nach dem Loeschen darf eine veraltete Id niemals still ein leeres
        // Turnier liefern - sonst zeigt die Oberflaeche eine Geisterauswahl.
        var service = new TournamentService(new InMemoryTournamentStore());

        Assert.Throws<InvalidOperationException>(() => service.RequireTournament(Guid.NewGuid()));
    }

    [Fact]
    public void WebApi_CreateEndpoint_ReturnsTheErrorShapeTheFrontendParses()
    {
        // requestJson liest bei einem Fehlerstatus `body.error`. Faellt dieses
        // Feld weg, zeigt die Oberflaeche wieder nur "HTTP 400" statt der
        // fachlichen Begruendung.
        var program = File.ReadAllText(FindRepositoryFile("src", "SchachTurnierManager.WebApi", "Program.cs"));

        Assert.Contains("app.MapPost(\"/api/tournaments\"", program);
        Assert.Contains("service.CreateTournament(request.Name, request.Settings)", program);
        Assert.Contains("Results.BadRequest(new { error = ex.Message })", program);
    }

    [Fact]
    public void WebApi_NoErrorResponseShipsAnUntypedBody()
    {
        // Jede BadRequest-/NotFound-Antwort muss das error-Feld tragen. Eine
        // Antwort ohne dieses Feld erreicht den Bediener als nackter Statuscode.
        var program = File.ReadAllText(FindRepositoryFile("src", "SchachTurnierManager.WebApi", "Program.cs"));

        var offenders = program
            .Split('\n')
            .Select((line, index) => (Line: line.Trim(), Number: index + 1))
            .Where(entry => entry.Line.Contains("Results.BadRequest(") || entry.Line.Contains("Results.NotFound("))
            .Where(entry => !entry.Line.Contains("error ="))
            .Select(entry => $"Program.cs:{entry.Number}: {entry.Line}")
            .ToList();

        Assert.Empty(offenders);
    }

    private static string FindRepositoryFile(params string[] relativeParts)
    {
        var current = new DirectoryInfo(AppContext.BaseDirectory);
        while (current is not null)
        {
            var candidate = Path.Combine(new[] { current.FullName }.Concat(relativeParts).ToArray());
            if (File.Exists(candidate))
            {
                return candidate;
            }

            current = current.Parent;
        }

        throw new FileNotFoundException(
            $"Repository file not found: {Path.Combine(relativeParts)}",
            Path.Combine(relativeParts));
    }
}
