using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

public sealed class TournamentExportFormatterTests
{
    [Fact]
    public void ExportStandingsCsv_ContainsStableHeaderAndPlayerRows()
    {
        var tournament = CreateTournament();
        var standings = new StandingsCalculator().Calculate(tournament);
        var document = new TournamentExportFormatter().ExportStandingsCsv(tournament, standings);

        Assert.EndsWith("_Tabelle.csv", document.FileName);
        Assert.Contains("Rang;Name;TWZ;Punkte;Siege;Schwarzsiege;Direktvergleich;Buchholz;Buchholz Cut-1;Buchholz Cut-2;Median-Buchholz;Sonneborn-Berger;Progressiv;Koya;Gegnerschnitt;TPR;Heldenwert", document.Content);
        Assert.Contains("Alpha", document.Content);
        Assert.Contains("Beta", document.Content);
    }

    [Fact]
    public void ExportPairingsCsv_CanExportSingleRound()
    {
        var tournament = CreateTournament();
        var document = new TournamentExportFormatter().ExportPairingsCsv(tournament, roundNumber: 1);

        Assert.EndsWith("_Runde_01.csv", document.FileName);
        Assert.Contains("Runde;Brett;Weiß;Schwarz;Ergebnis", document.Content);
        Assert.Contains("Alpha", document.Content);
        Assert.Contains("1-0", document.Content);
    }

    [Fact]
    public void ExportPrintableTournamentHtml_EncodesTournamentName()
    {
        var tournament = CreateTournament();
        tournament.Name = "Verein <Finale>";
        var standings = new StandingsCalculator().Calculate(tournament);
        var diagnostics = new RoundDiagnosticsCalculator().Calculate(tournament);
        var document = new TournamentExportFormatter().ExportPrintableTournamentHtml(tournament, standings, diagnostics);

        Assert.Equal("text/html; charset=utf-8", document.ContentType);
        Assert.Contains("Verein &lt;Finale&gt;", document.Content);
        Assert.Contains("Teilnehmerliste", document.Content);
        Assert.Contains("Rundenprüfung", document.Content);
    }

    private static TournamentState CreateTournament()
    {
        var alpha = new Player
        {
            Id = Guid.Parse("00000000-0000-0000-0000-000000000001"),
            Name = "Alpha",
            StartingRank = 1,
            Rating = new RatingProfile { ManualTwz = 1800 }
        };
        var beta = new Player
        {
            Id = Guid.Parse("00000000-0000-0000-0000-000000000002"),
            Name = "Beta",
            StartingRank = 2,
            Rating = new RatingProfile { ManualTwz = 1700 }
        };

        return new TournamentState
        {
            Name = "Test Turnier",
            Settings = new TournamentSettings { Format = TournamentFormat.Swiss },
            Players = { alpha, beta },
            Rounds =
            {
                new TournamentRound
                {
                    RoundNumber = 1,
                    Pairings = new[]
                    {
                        Pairing.Game(1, alpha.Id, beta.Id) with { Result = new GameResult(GameResultKind.WhiteWin) }
                    }
                }
            }
        };
    }
}
