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
        Assert.Contains("Rang;Name;TWZ;Punkte;Siege;Schwarzsiege;Direktvergleich;Buchholz;Buchholz Cut-1;Buchholz Cut-2;Median Buchholz;Sonneborn-Berger;Koya;Progressiv;Gegnerschnitt;TPR;Heldenwert", document.Content);
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

    [Fact]
    public void ExportNextRoundPreviewCsv_ContainsQualityFields()
    {
        var tournament = CreateTournament();
        var preview = CreatePreview(tournament);
        var document = new TournamentExportFormatter().ExportNextRoundPreviewCsv(tournament, preview);

        Assert.EndsWith("_Vorschau_Runde_02.csv", document.FileName);
        Assert.Contains("Runde;Brett;Weiß;Schwarz;Weiß Punkte vorher;Schwarz Punkte vorher;Score-Differenz", document.Content);
        Assert.Contains("Alpha", document.Content);
        Assert.Contains("Beta", document.Content);
        Assert.Contains("Scoregruppen-Test", document.Content);
    }

    [Fact]
    public void ExportPrintableNextRoundPreviewHtml_ContainsAuditAndEscapesContent()
    {
        var tournament = CreateTournament();
        tournament.Name = "Vorschau <Finale>";
        var preview = CreatePreview(tournament);
        var document = new TournamentExportFormatter().ExportPrintableNextRoundPreviewHtml(tournament, preview);

        Assert.Equal("text/html; charset=utf-8", document.ContentType);
        Assert.Contains("Vorschau &lt;Finale&gt;", document.Content);
        Assert.Contains("Auslosungsvorschau Runde 2", document.Content);
        Assert.Contains("Scoregruppen-Test", document.Content);
        Assert.Contains("Algorithmus", document.Content);
    }

    [Fact]
    public void ExportPrintableTournamentHtml_ParticipantListContainsFideIdBirthYearAndApproxAge()
    {
        var tournament = new TournamentState
        {
            Name = "Druck Turnier",
            Settings = new TournamentSettings { Format = TournamentFormat.Swiss },
            Players =
            {
                new Player
                {
                    Name = "Synth Spieler",
                    StartingRank = 1,
                    FideId = "99999999",
                    BirthYear = 1990,
                    Rating = new RatingProfile { ManualTwz = 1800 }
                }
            }
        };
        var standings = new StandingsCalculator().Calculate(tournament);
        var diagnostics = new RoundDiagnosticsCalculator().Calculate(tournament);
        var document = new TournamentExportFormatter().ExportPrintableTournamentHtml(tournament, standings, diagnostics);

        Assert.Contains("<th>FIDE-ID</th>", document.Content);
        Assert.Contains("<th>Jg.</th>", document.Content);
        Assert.Contains("<th>Alter</th>", document.Content);
        Assert.Contains("99999999", document.Content);
        Assert.Contains("1990", document.Content);
        Assert.Contains($"ca. {System.DateTime.Now.Year - 1990}", document.Content);
        Assert.Contains("Gedruckt am", document.Content);
    }

    [Fact]
    public void ExportPrintableRoundHtml_ShowsPrintDateAndWritableResultForOpenBoard()
    {
        var tournament = CreateTournament();
        var openRound = new TournamentRound
        {
            RoundNumber = 2,
            Pairings = new[]
            {
                Pairing.Game(1, tournament.Players[0].Id, tournament.Players[1].Id)
            }
        };
        tournament.Rounds.Add(openRound);
        var diagnostics = new RoundDiagnosticsCalculator().Calculate(tournament)
            .First(d => d.RoundNumber == 2);
        var document = new TournamentExportFormatter().ExportPrintableRoundHtml(tournament, openRound, diagnostics);

        Assert.Contains("Gedruckt am", document.Content);
        Assert.Contains("class=\"result-cell\"", document.Content);
        Assert.DoesNotContain(">offen<", document.Content);
    }

    private static NextRoundPreview CreatePreview(TournamentState tournament)
    {
        var alpha = tournament.Players[0];
        var beta = tournament.Players[1];
        var round = new TournamentRound
        {
            RoundNumber = 2,
            Pairings = new[]
            {
                Pairing.Game(1, beta.Id, alpha.Id)
            },
            Audit = new PairingAudit
            {
                Algorithm = "Test",
                RulesetVersion = "Test-1",
                Messages = new[] { "Audit-Test" },
                ScoreGroups = new[] { "Scoregruppen-Test" },
                Floaters = Array.Empty<string>(),
                ColorNotes = new[] { "Farb-Test" }
            }
        };

        return new NextRoundPreview
        {
            RoundNumber = 2,
            BoardCount = 1,
            IsSavable = true,
            Summary = "Testvorschau",
            Round = round,
            PairingQuality = new PairingQualityReport
            {
                RoundNumber = 2,
                BoardCount = 1,
                GameCount = 1,
                QualityScore = 88,
                Severity = PairingQualitySeverity.Notice,
                Findings = new[] { "Scoregruppen-Test" },
                Boards = new[]
                {
                    new PairingQualityBoard
                    {
                        BoardNumber = 1,
                        WhitePlayerId = beta.Id,
                        BlackPlayerId = alpha.Id,
                        WhiteName = beta.Name,
                        BlackName = alpha.Name,
                        WhiteScoreBeforeRound = 0,
                        BlackScoreBeforeRound = 1,
                        ScoreDifference = 1,
                        IsCrossScoreGroupPairing = true,
                        Findings = new[] { "Scoregruppen-Test" }
                    }
                }
            },
            Messages = new[] { "Audit-Test" }
        };
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
