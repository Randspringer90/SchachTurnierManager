using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.GoldenTests;

/// <summary>
/// STM-IE-001: Golden-Test fuer den TRF16-Export. Sechs Spieler, drei Runden,
/// inklusive Bye, Forfeit (WhiteForfeitWin/BlackForfeitWin), DoubleForfeit und
/// ein "nicht gepaarter" Spieler (Issue #3 Akzeptanzkriterien). Erwartete Werte
/// sind von Hand nach der offiziellen FIDE-TRF16-Spaltentabelle
/// (C.04 Annex 2, https://www.fide.com/FIDE/handbook/C04Annex2_TRF16.pdf)
/// nachgerechnet, mit 0-indexierten Substring-Positionen (Spec-Position - 1).
/// Ursprung: Marcel-Mente (PR #30), sicher an den development-Stand nach
/// STM-FACH-001 (Withdrawal-Logik) angepasst durch Owner-Adoption.
/// </summary>
public sealed class Trf16GoldenExportTests
{
    [Fact]
    public void ExportTrf16_SixPlayerThreeRoundTournament_MatchesFideColumnPositions()
    {
        var tournament = BuildTournament();
        var standings = new StandingsCalculator().Calculate(tournament, includeInactive: true);
        var document = new TournamentExportFormatter().ExportTrf16(tournament, standings);
        var lines = document.Content.Split('\r');

        // Remark 1 der FIDE-Spezifikation: jede Zeile endet mit CR.
        Assert.DoesNotContain('\n', document.Content);
        Assert.EndsWith("\r", document.Content);

        // Kopfzeilen (Position 1-3 Code, ab Position 5 Freitext).
        Assert.Equal("012 TRF16 Golden Turnier", lines[0]);
        Assert.Equal("062 6", lines[1]);
        Assert.Equal("072 4", lines[2]); // P1, P2, P4, P6 haben eine FIDE-Elo > 0.
        Assert.Equal("092 Individual: Swiss System", lines[3]);

        var playerLines = lines.Skip(4).Where(l => l.Length > 0).ToArray();
        Assert.Equal(6, playerLines.Length);

        var p1 = FindPlayerLine(playerLines, startingRank: 1);
        AssertField(p1, position: 1, length: 3, expected: "001");
        AssertField(p1, position: 5, length: 4, expected: "   1"); // Startrang 1, rechtsbuendig.
        AssertField(p1, position: 10, length: 1, expected: "m"); // Geschlecht maennlich.
        AssertField(p1, position: 11, length: 3, expected: "FM "); // Titel, linksbuendig.
        AssertField(p1, position: 15, length: 33, expected: "Mustermann, Max".PadRight(33));
        AssertField(p1, position: 49, length: 4, expected: "2100");
        AssertField(p1, position: 54, length: 3, expected: "GER");
        AssertField(p1, position: 58, length: 11, expected: "    1234567");
        AssertField(p1, position: 70, length: 10, expected: new string(' ', 10)); // Geburtsdatum bewusst leer (PII).
        AssertField(p1, position: 81, length: 4, expected: " 2.5"); // Endpunktzahl.
        AssertField(p1, position: 86, length: 4, expected: "   1"); // Rang 1 (bester Spieler).
        // Runde 1: Sieg gegen Startrang 2 mit Weiss.
        AssertField(p1, position: 92, length: 4, expected: "   2");
        AssertField(p1, position: 97, length: 1, expected: "w");
        AssertField(p1, position: 99, length: 1, expected: "1");
        // Runde 2: Forfeit-Sieg gegen Startrang 3 mit Weiss.
        AssertField(p1, position: 102, length: 4, expected: "   3");
        AssertField(p1, position: 107, length: 1, expected: "w");
        AssertField(p1, position: 109, length: 1, expected: "+");
        // Runde 3: Remis gegen Startrang 4 mit Weiss.
        AssertField(p1, position: 112, length: 4, expected: "   4");
        AssertField(p1, position: 117, length: 1, expected: "w");
        AssertField(p1, position: 119, length: 1, expected: "=");

        var p2 = FindPlayerLine(playerLines, startingRank: 2);
        AssertField(p2, position: 11, length: 3, expected: "   "); // kein Titel.
        AssertField(p2, position: 58, length: 11, expected: new string(' ', 11)); // keine FIDE-ID.
        AssertField(p2, position: 81, length: 4, expected: " 1.0");
        // Runde 3: kampflose Niederlage gegen Startrang 6 (Schwarz gewinnt Forfeit).
        AssertField(p2, position: 112, length: 4, expected: "   6");
        AssertField(p2, position: 117, length: 1, expected: "w");
        AssertField(p2, position: 119, length: 1, expected: "-");

        var p3 = FindPlayerLine(playerLines, startingRank: 3);
        AssertField(p3, position: 49, length: 4, expected: "    "); // unrated -> keine Elo.
        // Runde 3: DoubleForfeit gegen Startrang 5.
        AssertField(p3, position: 112, length: 4, expected: "   5");
        AssertField(p3, position: 117, length: 1, expected: "w");
        AssertField(p3, position: 119, length: 1, expected: "-");

        var p4 = FindPlayerLine(playerLines, startingRank: 4);
        // Runde 2: Freilos -> 'U', kein Gegner, keine Farbe.
        AssertField(p4, position: 102, length: 4, expected: new string(' ', 4));
        AssertField(p4, position: 107, length: 1, expected: " ");
        AssertField(p4, position: 109, length: 1, expected: "U");

        var p5 = FindPlayerLine(playerLines, startingRank: 5);
        AssertField(p5, position: 81, length: 4, expected: " 0.0");
        AssertField(p5, position: 86, length: 4, expected: "   6"); // letzter Rang.
        // Runde 2: Niederlage als Schwarz gegen Startrang 2.
        AssertField(p5, position: 102, length: 4, expected: "   2");
        AssertField(p5, position: 107, length: 1, expected: "b");
        AssertField(p5, position: 109, length: 1, expected: "0");

        var p6 = FindPlayerLine(playerLines, startingRank: 6);
        AssertField(p6, position: 81, length: 4, expected: " 2.0");
        AssertField(p6, position: 86, length: 4, expected: "   2"); // Rang 2 (mehr Siege als P4 bei Punktgleichstand).
        // Runde 2: nicht gepaart -> alles leer (nicht zu verwechseln mit Bye/'U').
        AssertField(p6, position: 102, length: 4, expected: new string(' ', 4));
        AssertField(p6, position: 107, length: 1, expected: " ");
        AssertField(p6, position: 109, length: 1, expected: " ");
        // Runde 3: kampfloser Sieg als Schwarz gegen Startrang 2.
        AssertField(p6, position: 112, length: 4, expected: "   2");
        AssertField(p6, position: 117, length: 1, expected: "b");
        AssertField(p6, position: 119, length: 1, expected: "+");
    }

    [Fact]
    public void ExportTrf16_SameInput_ProducesByteIdenticalOutputTwice()
    {
        var tournament = BuildTournament();
        var standings = new StandingsCalculator().Calculate(tournament, includeInactive: true);
        var formatter = new TournamentExportFormatter();

        var first = formatter.ExportTrf16(tournament, standings);
        var second = formatter.ExportTrf16(tournament, standings);

        Assert.Equal(first.Content, second.Content);
        Assert.Equal(
            System.Text.Encoding.UTF8.GetBytes(first.Content),
            System.Text.Encoding.UTF8.GetBytes(second.Content));
    }

    [Fact]
    public void ExportTrf16_RunningTournamentWithOpenRound_DoesNotThrowAndLeavesOpenGameBlank()
    {
        var players = Players();
        var tournament = new TournamentState
        {
            Name = "Laufendes Turnier",
            Settings = new TournamentSettings { Format = TournamentFormat.Swiss }
        };
        tournament.Players.AddRange(players.Take(2));
        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 1,
            ResultStatus = RoundResultStatus.Open,
            Pairings = new[] { Pairing.Game(1, players[0].Id, players[1].Id) }
        });

        var standings = new StandingsCalculator().Calculate(tournament, includeInactive: true);
        var document = new TournamentExportFormatter().ExportTrf16(tournament, standings);
        var line = document.Content.Split('\r').Skip(4).First(l => l.Length > 0);

        AssertField(line, position: 92, length: 4, expected: new string(' ', 4));
        AssertField(line, position: 97, length: 1, expected: " ");
        AssertField(line, position: 99, length: 1, expected: " ");
    }

    [Fact]
    public void ExportTrf16_WithdrawnPlayer_StaysInExportButNotInVisibleStandings()
    {
        // STM-FACH-001-Regel: zurueckgezogene Spieler verschwinden aus der sichtbaren
        // Rangliste, ihre gespielten Partien bleiben aber vollstaendig erhalten. Der
        // TRF-Export braucht per FIDE-Spezifikation trotzdem ALLE Teilnehmer.
        var players = Players();
        var withdrawn = players[2] with { Status = PlayerStatus.Withdrawn };
        var tournament = new TournamentState
        {
            Name = "Turnier mit Rueckzug",
            Settings = new TournamentSettings { Format = TournamentFormat.Swiss }
        };
        tournament.Players.AddRange(new[] { players[0], players[1], withdrawn });
        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 1,
            Pairings = new[]
            {
                Pairing.Game(1, players[0].Id, withdrawn.Id) with { Result = new GameResult(GameResultKind.WhiteWin) },
                Pairing.Bye(2, players[1].Id)
            }
        });

        var visibleStandings = new StandingsCalculator().Calculate(tournament);
        Assert.DoesNotContain(visibleStandings, r => r.PlayerId == withdrawn.Id);

        var exportStandings = new StandingsCalculator().Calculate(tournament, includeInactive: true);
        var document = new TournamentExportFormatter().ExportTrf16(tournament, exportStandings);
        var lines = document.Content.Split('\r').Where(l => l.Length > 0).ToArray();

        Assert.Equal("062 3", lines[1]); // Teilnehmerzahl passt zur tatsaechlichen Exportliste.
        var playerLines = lines.Skip(4).ToArray();
        Assert.Equal(3, playerLines.Length);
        Assert.Contains(playerLines, l => l.Substring(4, 4) == "   3"); // Startrang des zurueckgezogenen Spielers bleibt exportiert.
    }

    [Fact]
    public void ExportTrf16_ParticipantCounts_MatchExportedPlayerLineCount()
    {
        var tournament = BuildTournament();
        var standings = new StandingsCalculator().Calculate(tournament, includeInactive: true);
        var document = new TournamentExportFormatter().ExportTrf16(tournament, standings);
        var lines = document.Content.Split('\r').Where(l => l.Length > 0).ToArray();
        var declaredCount = int.Parse(lines[1][4..].Trim());
        var playerLineCount = lines.Skip(4).Count();

        Assert.Equal(playerLineCount, declaredCount);
        Assert.Equal(standings.Count, declaredCount);
    }

    [Fact]
    public void ExportTrf16_UnicodeAndOverlongName_IsSanitizedAndTruncatedNotSplit()
    {
        var player = new Player
        {
            Id = Guid.NewGuid(),
            Name = "Grzegorz Brzęczyszczykiewicz-Müller ó€ 名前 the-third-very-long-surname",
            StartingRank = 1,
            Gender = GenderCategory.Male,
            Rating = new RatingProfile()
        };
        var tournament = new TournamentState
        {
            Name = "Unicode-Turnier",
            Settings = new TournamentSettings { Format = TournamentFormat.Swiss }
        };
        tournament.Players.Add(player);

        var standings = new StandingsCalculator().Calculate(tournament, includeInactive: true);
        var document = new TournamentExportFormatter().ExportTrf16(tournament, standings);
        var line = document.Content.Split('\r').Where(l => l.Length > 0).Skip(4).First();

        var nameField = line.Substring(14, 33);
        Assert.Equal(33, nameField.Length);
        Assert.Equal(player.Name[..33], nameField);
        // Der Vor-/Nachname wird bewusst nicht automatisch getrennt (Domainmodell hat
        // kein strukturiertes Feld dafuer) - der Rohname wird nur laengenbegrenzt.
    }

    [Fact]
    public void ExportTrf16_ControlCharactersInNameAndTournamentName_AreSanitized()
    {
        var player = new Player
        {
            Id = Guid.NewGuid(),
            Name = "Evil\r\nName\twithcontrol",
            StartingRank = 1,
            Rating = new RatingProfile()
        };
        var tournament = new TournamentState
        {
            Name = "Turnier\r\nmitSteuerzeichen",
            Settings = new TournamentSettings { Format = TournamentFormat.Swiss }
        };
        tournament.Players.Add(player);

        var standings = new StandingsCalculator().Calculate(tournament, includeInactive: true);
        var document = new TournamentExportFormatter().ExportTrf16(tournament, standings);

        // Genau ein CR pro Zeile (Zeilentrenner); keine eingebetteten Steuerzeichen aus
        // Turnier- oder Spielernamen duerfen zusaetzliche Zeilenumbrueche erzeugen.
        var lines = document.Content.Split('\r');
        Assert.Equal(6, lines.Length); // 4 Kopfzeilen + 1 Spielerzeile + trailing empty.
        Assert.DoesNotContain('\n', document.Content);
        Assert.DoesNotContain('\t', document.Content);
        Assert.Equal("012 Turnier  mitSteuerzeichen", lines[0]); // \r und \n werden je einzeln durch ein Leerzeichen ersetzt.
    }

    [Fact]
    public void ExportTrf16_TournamentName_ProducesFileSystemSafeFileName()
    {
        var tournament = new TournamentState
        {
            Name = "Turnier: <Test>/\\?*|\"2026",
            Settings = new TournamentSettings { Format = TournamentFormat.Swiss }
        };

        var standings = new StandingsCalculator().Calculate(tournament, includeInactive: true);
        var document = new TournamentExportFormatter().ExportTrf16(tournament, standings);

        foreach (var invalidChar in System.IO.Path.GetInvalidFileNameChars())
        {
            Assert.DoesNotContain(invalidChar, document.FileName);
        }
        Assert.EndsWith("_TRF16.txt", document.FileName);
    }

    [Fact]
    public void ExportTrf16_EmptyTournament_ProducesHeaderOnlyDocument()
    {
        var tournament = new TournamentState
        {
            Name = "Leeres Turnier",
            Settings = new TournamentSettings { Format = TournamentFormat.Swiss }
        };

        var standings = new StandingsCalculator().Calculate(tournament, includeInactive: true);
        var document = new TournamentExportFormatter().ExportTrf16(tournament, standings);
        var lines = document.Content.Split('\r').Where(l => l.Length > 0).ToArray();

        Assert.Equal(4, lines.Length);
        Assert.Equal("062 0", lines[1]);
        Assert.Equal("072 0", lines[2]);
    }

    [Fact]
    public void ExportTrf16_ManyRounds_WritesEachRoundAtCorrectOffsetWithoutOverlap()
    {
        const int roundCount = 12; // > 9 Runden, damit zweistellige Rundennummern getestet sind.
        var players = new List<Player>
        {
            new() { Id = Guid.NewGuid(), Name = "Spieler A", StartingRank = 1, Rating = new RatingProfile() },
            new() { Id = Guid.NewGuid(), Name = "Spieler B", StartingRank = 2, Rating = new RatingProfile() }
        };
        var tournament = new TournamentState
        {
            Name = "Marathon-Turnier",
            Settings = new TournamentSettings { Format = TournamentFormat.Swiss, PlannedRounds = roundCount }
        };
        tournament.Players.AddRange(players);
        for (var round = 1; round <= roundCount; round++)
        {
            var whiteIsA = round % 2 == 1;
            tournament.Rounds.Add(new TournamentRound
            {
                RoundNumber = round,
                Pairings = new[]
                {
                    Pairing.Game(1, whiteIsA ? players[0].Id : players[1].Id, whiteIsA ? players[1].Id : players[0].Id)
                        with { Result = new GameResult(GameResultKind.Draw) }
                }
            });
        }

        var standings = new StandingsCalculator().Calculate(tournament, includeInactive: true);
        var document = new TournamentExportFormatter().ExportTrf16(tournament, standings);
        var line = document.Content.Split('\r').Where(l => l.Length > 0).Skip(4).First(l => l.Substring(4, 4) == "   1");

        for (var round = 1; round <= roundCount; round++)
        {
            var basePosition = 92 + (round - 1) * 10;
            AssertField(line, position: basePosition + 7, length: 1, expected: "=");
        }

        // Letzte Runde (12) liegt bei Position 202-209 und darf nicht durch fruehere Runden ueberschrieben sein.
        AssertField(line, position: 92 + (roundCount - 1) * 10, length: 4, expected: "   2");
    }

    private static string FindPlayerLine(IReadOnlyList<string> playerLines, int startingRank)
    {
        var marker = startingRank.ToString().PadLeft(4);
        return Assert.Single(playerLines, line => line.Substring(4, 4) == marker);
    }

    private static void AssertField(string line, int position, int length, string expected)
    {
        Assert.Equal(expected, line.Substring(position - 1, length));
    }

    private static TournamentState BuildTournament()
    {
        var players = Players();
        var tournament = new TournamentState
        {
            Name = "TRF16 Golden Turnier",
            Settings = new TournamentSettings { Format = TournamentFormat.Swiss }
        };
        tournament.Players.AddRange(players);
        var (p1, p2, p3, p4, p5, p6) = (players[0], players[1], players[2], players[3], players[4], players[5]);

        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 1,
            Pairings = new[]
            {
                Pairing.Game(1, p1.Id, p2.Id) with { Result = new GameResult(GameResultKind.WhiteWin) },
                Pairing.Game(2, p3.Id, p4.Id) with { Result = new GameResult(GameResultKind.Draw) },
                Pairing.Game(3, p5.Id, p6.Id) with { Result = new GameResult(GameResultKind.BlackWin) }
            }
        });
        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 2,
            Pairings = new[]
            {
                Pairing.Game(1, p1.Id, p3.Id) with { Result = new GameResult(GameResultKind.WhiteForfeitWin) },
                Pairing.Game(2, p2.Id, p5.Id) with { Result = new GameResult(GameResultKind.WhiteWin) },
                Pairing.Bye(3, p4.Id)
                // P6 bewusst nicht gepaart in dieser Runde (testet den "nicht gepaart"-Fall).
            }
        });
        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 3,
            Pairings = new[]
            {
                Pairing.Game(1, p1.Id, p4.Id) with { Result = new GameResult(GameResultKind.Draw) },
                Pairing.Game(2, p2.Id, p6.Id) with { Result = new GameResult(GameResultKind.BlackForfeitWin) },
                Pairing.Game(3, p3.Id, p5.Id) with { Result = new GameResult(GameResultKind.DoubleForfeit) }
            }
        });

        return tournament;
    }

    private static List<Player> Players() => new()
    {
        new Player
        {
            Id = Guid.Parse("00000000-0000-0000-0000-000000000001"),
            Name = "Mustermann, Max",
            StartingRank = 1,
            Gender = GenderCategory.Male,
            Title = "FM",
            FideId = "1234567",
            Federation = "GER",
            Rating = new RatingProfile { Elo = 2100 }
        },
        new Player
        {
            Id = Guid.Parse("00000000-0000-0000-0000-000000000002"),
            Name = "Musterfrau, Erika",
            StartingRank = 2,
            Gender = GenderCategory.Female,
            Federation = "GER",
            Rating = new RatingProfile { Elo = 1950 }
        },
        new Player
        {
            Id = Guid.Parse("00000000-0000-0000-0000-000000000003"),
            Name = "Schmidt, Anna",
            StartingRank = 3,
            Gender = GenderCategory.Female,
            Rating = new RatingProfile()
        },
        new Player
        {
            Id = Guid.Parse("00000000-0000-0000-0000-000000000004"),
            Name = "Weber, Tom",
            StartingRank = 4,
            Gender = GenderCategory.Male,
            FideId = "7654321",
            Federation = "AUT",
            Rating = new RatingProfile { Elo = 1800 }
        },
        new Player
        {
            Id = Guid.Parse("00000000-0000-0000-0000-000000000005"),
            Name = "Klein, Lisa",
            StartingRank = 5,
            Gender = GenderCategory.Unknown,
            Rating = new RatingProfile()
        },
        new Player
        {
            Id = Guid.Parse("00000000-0000-0000-0000-000000000006"),
            Name = "Fischer, Jan",
            StartingRank = 6,
            Gender = GenderCategory.Male,
            Rating = new RatingProfile { Elo = 1700 }
        }
    };
}
