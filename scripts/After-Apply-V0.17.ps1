$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root

function Invoke-Step {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][scriptblock]$Script
    )

    Write-Host "[v0.17.0] $Name..."
    & $Script
    if ($LASTEXITCODE -ne 0) {
        throw "Schritt fehlgeschlagen: $Name (ExitCode=$LASTEXITCODE)"
    }
}

function Set-TextFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )
    [System.IO.File]::WriteAllText((Join-Path $Root $Path), $Content, [System.Text.UTF8Encoding]::new($false))
}

function Update-TextFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][scriptblock]$Updater
    )

    $fullPath = Join-Path $Root $Path
    $text = [System.IO.File]::ReadAllText($fullPath)
    $updated = & $Updater $text
    if ($updated -eq $text) {
        Write-Host "[v0.17.0] Keine Änderung in ${Path}."
    }
    [System.IO.File]::WriteAllText($fullPath, $updated, [System.Text.UTF8Encoding]::new($false))
}

$pairingQualityReport = @'
using System;
using System.Collections.Generic;
using System.Linq;

namespace SchachTurnierManager.Domain.Models;

public enum PairingQualitySeverity
{
    Good = 0,
    Notice = 1,
    Warning = 2,
    Critical = 3
}

public sealed record PairingQualityReport
{
    public int RoundNumber { get; init; }
    public int BoardCount { get; init; }
    public int GameCount { get; init; }
    public int ByeCount { get; init; }
    public int RematchCount { get; init; }
    public int CrossScoreGroupPairingCount { get; init; }
    public int ThirdSameColorRiskCount { get; init; }
    public decimal MaxScoreDifference { get; init; }
    public decimal AverageScoreDifference { get; init; }
    public int QualityScore { get; init; }
    public PairingQualitySeverity Severity { get; init; } = PairingQualitySeverity.Good;
    public IReadOnlyList<string> Findings { get; init; } = Array.Empty<string>();
    public IReadOnlyList<PairingQualityBoard> Boards { get; init; } = Array.Empty<PairingQualityBoard>();

    public bool HasCriticalIssues => Severity == PairingQualitySeverity.Critical;
    public bool HasWarnings => Severity >= PairingQualitySeverity.Warning;
    public int FindingCount => Findings.Count;
}

public sealed record PairingQualityBoard
{
    public int BoardNumber { get; init; }
    public Guid? WhitePlayerId { get; init; }
    public Guid? BlackPlayerId { get; init; }
    public string WhiteName { get; init; } = string.Empty;
    public string BlackName { get; init; } = string.Empty;
    public decimal WhiteScoreBeforeRound { get; init; }
    public decimal BlackScoreBeforeRound { get; init; }
    public decimal ScoreDifference { get; init; }
    public bool IsBye { get; init; }
    public bool IsRematch { get; init; }
    public bool IsCrossScoreGroupPairing { get; init; }
    public bool WouldGiveWhiteThirdSameColor { get; init; }
    public bool WouldGiveBlackThirdSameColor { get; init; }
    public IReadOnlyList<string> Findings { get; init; } = Array.Empty<string>();
}
'@

$pairingQualityAnalyzer = @'
using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Domain.Services;

public sealed class PairingQualityAnalyzer
{
    public PairingQualityReport Analyze(TournamentState tournament, TournamentRound round)
    {
        ArgumentNullException.ThrowIfNull(tournament);
        ArgumentNullException.ThrowIfNull(round);

        var players = tournament.Players.ToDictionary(player => player.Id);
        var priorRounds = tournament.Rounds
            .Where(existingRound => existingRound.RoundNumber < round.RoundNumber)
            .OrderBy(existingRound => existingRound.RoundNumber)
            .ToList();

        var priorTournament = new TournamentState
        {
            Id = tournament.Id,
            Name = tournament.Name,
            CreatedOn = tournament.CreatedOn,
            Settings = tournament.Settings
        };
        priorTournament.Players.AddRange(tournament.Players);
        priorTournament.Rounds.AddRange(priorRounds);

        var pointsBeforeRound = new StandingsCalculator()
            .Calculate(priorTournament)
            .ToDictionary(row => row.PlayerId, row => row.Points);

        var history = BuildHistory(tournament.Players, priorRounds);
        var boardReports = new List<PairingQualityBoard>();

        foreach (var pairing in round.Pairings.OrderBy(pairing => pairing.BoardNumber))
        {
            boardReports.Add(AnalyzeBoard(pairing, players, pointsBeforeRound, history));
        }

        var gameBoards = boardReports.Where(board => !board.IsBye).ToList();
        var findings = BuildFindings(boardReports);
        var averageScoreDifference = gameBoards.Count == 0 ? 0m : gameBoards.Average(board => board.ScoreDifference);
        var maxScoreDifference = gameBoards.Count == 0 ? 0m : gameBoards.Max(board => board.ScoreDifference);
        var rematches = boardReports.Count(board => board.IsRematch);
        var crossScoreGroupPairings = boardReports.Count(board => board.IsCrossScoreGroupPairing);
        var thirdSameColorRisks = boardReports.Count(board => board.WouldGiveWhiteThirdSameColor || board.WouldGiveBlackThirdSameColor);
        var byeCount = boardReports.Count(board => board.IsBye);
        var qualityScore = CalculateQualityScore(rematches, crossScoreGroupPairings, thirdSameColorRisks, maxScoreDifference);

        return new PairingQualityReport
        {
            RoundNumber = round.RoundNumber,
            BoardCount = boardReports.Count,
            GameCount = gameBoards.Count,
            ByeCount = byeCount,
            RematchCount = rematches,
            CrossScoreGroupPairingCount = crossScoreGroupPairings,
            ThirdSameColorRiskCount = thirdSameColorRisks,
            MaxScoreDifference = maxScoreDifference,
            AverageScoreDifference = decimal.Round(averageScoreDifference, 2),
            QualityScore = qualityScore,
            Severity = DetermineSeverity(rematches, crossScoreGroupPairings, thirdSameColorRisks, byeCount),
            Findings = findings,
            Boards = boardReports
        };
    }

    private static PairingQualityBoard AnalyzeBoard(
        Pairing pairing,
        IReadOnlyDictionary<Guid, Player> players,
        IReadOnlyDictionary<Guid, decimal> pointsBeforeRound,
        IReadOnlyDictionary<Guid, PairingQualityPlayerHistory> history)
    {
        var findings = new List<string>();
        var whiteName = PlayerName(players, pairing.WhitePlayerId);
        var blackName = pairing.IsBye ? "spielfrei" : PlayerName(players, pairing.BlackPlayerId);

        if (pairing.IsBye || pairing.WhitePlayerId is null || pairing.BlackPlayerId is null)
        {
            findings.Add($"Brett {pairing.BoardNumber}: Bye/Spielfrei für {whiteName}.");
            return new PairingQualityBoard
            {
                BoardNumber = pairing.BoardNumber,
                WhitePlayerId = pairing.WhitePlayerId,
                BlackPlayerId = pairing.BlackPlayerId,
                WhiteName = whiteName,
                BlackName = blackName,
                IsBye = true,
                Findings = findings
            };
        }

        var whiteScore = pointsBeforeRound.GetValueOrDefault(pairing.WhitePlayerId.Value);
        var blackScore = pointsBeforeRound.GetValueOrDefault(pairing.BlackPlayerId.Value);
        var scoreDifference = Math.Abs(whiteScore - blackScore);
        var whiteHistory = history[pairing.WhitePlayerId.Value];
        var blackHistory = history[pairing.BlackPlayerId.Value];
        var isRematch = whiteHistory.OpponentIds.Contains(pairing.BlackPlayerId.Value);
        var whiteThirdSameColor = WouldCreateThirdSameColor(whiteHistory.Colors, ChessColor.White);
        var blackThirdSameColor = WouldCreateThirdSameColor(blackHistory.Colors, ChessColor.Black);

        if (isRematch)
        {
            findings.Add($"Brett {pairing.BoardNumber}: Rematch {whiteName} gegen {blackName}.");
        }

        if (scoreDifference > 0)
        {
            findings.Add($"Brett {pairing.BoardNumber}: unterschiedliche Scoregruppen ({whiteScore} : {blackScore}).");
        }

        if (whiteThirdSameColor)
        {
            findings.Add($"Brett {pairing.BoardNumber}: {whiteName} bekäme zum dritten Mal in Folge Weiß.");
        }

        if (blackThirdSameColor)
        {
            findings.Add($"Brett {pairing.BoardNumber}: {blackName} bekäme zum dritten Mal in Folge Schwarz.");
        }

        return new PairingQualityBoard
        {
            BoardNumber = pairing.BoardNumber,
            WhitePlayerId = pairing.WhitePlayerId,
            BlackPlayerId = pairing.BlackPlayerId,
            WhiteName = whiteName,
            BlackName = blackName,
            WhiteScoreBeforeRound = whiteScore,
            BlackScoreBeforeRound = blackScore,
            ScoreDifference = scoreDifference,
            IsRematch = isRematch,
            IsCrossScoreGroupPairing = scoreDifference > 0,
            WouldGiveWhiteThirdSameColor = whiteThirdSameColor,
            WouldGiveBlackThirdSameColor = blackThirdSameColor,
            Findings = findings
        };
    }

    private static IReadOnlyDictionary<Guid, PairingQualityPlayerHistory> BuildHistory(
        IEnumerable<Player> players,
        IEnumerable<TournamentRound> priorRounds)
    {
        var histories = players.ToDictionary(player => player.Id, _ => new PairingQualityPlayerHistory());

        foreach (var round in priorRounds.OrderBy(round => round.RoundNumber))
        {
            foreach (var pairing in round.Pairings.OrderBy(pairing => pairing.BoardNumber))
            {
                if (pairing.WhitePlayerId is null)
                {
                    continue;
                }

                if (pairing.IsBye || pairing.BlackPlayerId is null)
                {
                    if (histories.TryGetValue(pairing.WhitePlayerId.Value, out var byeHistory))
                    {
                        byeHistory.HadBye = true;
                    }

                    continue;
                }

                if (histories.TryGetValue(pairing.WhitePlayerId.Value, out var whiteHistory))
                {
                    whiteHistory.Colors.Add(ChessColor.White);
                    whiteHistory.OpponentIds.Add(pairing.BlackPlayerId.Value);
                }

                if (histories.TryGetValue(pairing.BlackPlayerId.Value, out var blackHistory))
                {
                    blackHistory.Colors.Add(ChessColor.Black);
                    blackHistory.OpponentIds.Add(pairing.WhitePlayerId.Value);
                }
            }
        }

        return histories;
    }

    private static IReadOnlyList<string> BuildFindings(IReadOnlyList<PairingQualityBoard> boards)
    {
        var findings = new List<string>();
        var rematches = boards.Where(board => board.IsRematch).ToList();
        var crossScoreGroups = boards.Where(board => board.IsCrossScoreGroupPairing).ToList();
        var colorRisks = boards.Where(board => board.WouldGiveWhiteThirdSameColor || board.WouldGiveBlackThirdSameColor).ToList();
        var byes = boards.Where(board => board.IsBye).ToList();

        if (rematches.Count == 0)
        {
            findings.Add("Keine Wiederholungspaarung erkannt.");
        }
        else
        {
            findings.Add($"{rematches.Count} Wiederholungspaarung(en) erkannt.");
        }

        if (crossScoreGroups.Count == 0)
        {
            findings.Add("Alle regulären Bretter liegen innerhalb gleicher Scoregruppen.");
        }
        else
        {
            findings.Add($"{crossScoreGroups.Count} Paarung(en) zwischen unterschiedlichen Scoregruppen erkannt.");
        }

        if (colorRisks.Count == 0)
        {
            findings.Add("Keine dritte gleiche Farbe in Folge erkannt.");
        }
        else
        {
            findings.Add($"{colorRisks.Count} Farbfolge-Risiko/Risiken erkannt.");
        }

        if (byes.Count > 0)
        {
            findings.Add($"{byes.Count} Bye/Spielfrei in dieser Runde.");
        }

        return findings;
    }

    private static PairingQualitySeverity DetermineSeverity(int rematches, int crossScoreGroupPairings, int thirdSameColorRisks, int byeCount)
    {
        if (rematches > 0)
        {
            return PairingQualitySeverity.Critical;
        }

        if (thirdSameColorRisks > 0)
        {
            return PairingQualitySeverity.Warning;
        }

        if (crossScoreGroupPairings > 0 || byeCount > 0)
        {
            return PairingQualitySeverity.Notice;
        }

        return PairingQualitySeverity.Good;
    }

    private static int CalculateQualityScore(int rematches, int crossScoreGroupPairings, int thirdSameColorRisks, decimal maxScoreDifference)
    {
        var score = 100
            - rematches * 35
            - crossScoreGroupPairings * 8
            - thirdSameColorRisks * 20
            - (int)Math.Round(maxScoreDifference * 8m, MidpointRounding.AwayFromZero);

        return Math.Max(0, Math.Min(100, score));
    }

    private static bool WouldCreateThirdSameColor(IReadOnlyList<ChessColor> priorColors, ChessColor assignedColor)
    {
        return priorColors.Count >= 2
               && priorColors[^1] == assignedColor
               && priorColors[^2] == assignedColor;
    }

    private static string PlayerName(IReadOnlyDictionary<Guid, Player> players, Guid? playerId)
    {
        if (playerId is null)
        {
            return "—";
        }

        return players.TryGetValue(playerId.Value, out var player) ? player.Name : playerId.Value.ToString("N")[..8];
    }

    private sealed class PairingQualityPlayerHistory
    {
        public HashSet<Guid> OpponentIds { get; } = new();
        public List<ChessColor> Colors { get; } = new();
        public bool HadBye { get; set; }
    }
}
'@

$pairingQualityAnalyzerTests = @'
using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

public sealed class PairingQualityAnalyzerTests
{
    [Fact]
    public void Analyze_CleanFirstRound_ReturnsGoodQuality()
    {
        var players = CreatePlayers(4);
        var tournament = CreateTournament(players);
        var round = new TournamentRound
        {
            RoundNumber = 1,
            Pairings = new[]
            {
                Pairing.Game(1, players[0].Id, players[3].Id),
                Pairing.Game(2, players[1].Id, players[2].Id)
            }
        };

        var report = new PairingQualityAnalyzer().Analyze(tournament, round);

        Assert.Equal(PairingQualitySeverity.Good, report.Severity);
        Assert.Equal(100, report.QualityScore);
        Assert.Equal(0, report.RematchCount);
        Assert.Equal(0, report.CrossScoreGroupPairingCount);
        Assert.Contains(report.Findings, finding => finding.Contains("Keine Wiederholung", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public void Analyze_FlagsRematchesAndCrossScoreGroups()
    {
        var players = CreatePlayers(4);
        var tournament = CreateTournament(players);
        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 1,
            Pairings = new[]
            {
                Pairing.Game(1, players[0].Id, players[1].Id) with { Result = new GameResult(GameResultKind.WhiteWin) },
                Pairing.Game(2, players[2].Id, players[3].Id) with { Result = new GameResult(GameResultKind.Draw) }
            }
        });

        var round = new TournamentRound
        {
            RoundNumber = 2,
            Pairings = new[]
            {
                Pairing.Game(1, players[0].Id, players[1].Id),
                Pairing.Game(2, players[2].Id, players[3].Id)
            }
        };

        var report = new PairingQualityAnalyzer().Analyze(tournament, round);

        Assert.Equal(PairingQualitySeverity.Critical, report.Severity);
        Assert.Equal(2, report.RematchCount);
        Assert.True(report.CrossScoreGroupPairingCount >= 1);
        Assert.True(report.QualityScore < 100);
        Assert.Contains(report.Boards, board => board.IsRematch && board.WhitePlayerId == players[0].Id && board.BlackPlayerId == players[1].Id);
    }

    [Fact]
    public void Analyze_FlagsThirdSameColorRisk()
    {
        var players = CreatePlayers(4);
        var tournament = CreateTournament(players);
        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 1,
            Pairings = new[]
            {
                Pairing.Game(1, players[0].Id, players[1].Id) with { Result = new GameResult(GameResultKind.Draw) },
                Pairing.Game(2, players[2].Id, players[3].Id) with { Result = new GameResult(GameResultKind.Draw) }
            }
        });
        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 2,
            Pairings = new[]
            {
                Pairing.Game(1, players[0].Id, players[2].Id) with { Result = new GameResult(GameResultKind.Draw) },
                Pairing.Game(2, players[1].Id, players[3].Id) with { Result = new GameResult(GameResultKind.Draw) }
            }
        });

        var round = new TournamentRound
        {
            RoundNumber = 3,
            Pairings = new[]
            {
                Pairing.Game(1, players[0].Id, players[3].Id),
                Pairing.Game(2, players[1].Id, players[2].Id)
            }
        };

        var report = new PairingQualityAnalyzer().Analyze(tournament, round);

        Assert.Equal(PairingQualitySeverity.Warning, report.Severity);
        Assert.Equal(1, report.ThirdSameColorRiskCount);
        Assert.Contains(report.Boards, board => board.WhitePlayerId == players[0].Id && board.WouldGiveWhiteThirdSameColor);
        Assert.Contains(report.Findings, finding => finding.Contains("Farbfolge", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public void Analyze_ReportsByeSeparately()
    {
        var players = CreatePlayers(5);
        var tournament = CreateTournament(players);
        var round = new TournamentRound
        {
            RoundNumber = 1,
            Pairings = new[]
            {
                Pairing.Game(1, players[0].Id, players[4].Id),
                Pairing.Game(2, players[1].Id, players[3].Id),
                Pairing.Bye(3, players[2].Id)
            }
        };

        var report = new PairingQualityAnalyzer().Analyze(tournament, round);

        Assert.Equal(1, report.ByeCount);
        Assert.Equal(2, report.GameCount);
        Assert.Contains(report.Boards, board => board.IsBye && board.WhitePlayerId == players[2].Id);
        Assert.Equal(PairingQualitySeverity.Notice, report.Severity);
    }

    private static TournamentState CreateTournament(IReadOnlyList<Player> players)
    {
        var tournament = new TournamentState
        {
            Name = "Pairing Quality",
            Settings = new TournamentSettings { Format = TournamentFormat.Swiss }
        };
        tournament.Players.AddRange(players);
        return tournament;
    }

    private static List<Player> CreatePlayers(int count)
    {
        return Enumerable.Range(1, count)
            .Select(index => new Player
            {
                Id = Guid.Parse($"00000000-0000-0000-0000-{index:000000000000}"),
                Name = $"Spieler {index}",
                StartingRank = index,
                Rating = new RatingProfile { ManualTwz = 2200 - index * 25 }
            })
            .ToList();
    }
}
'@

Set-TextFile -Path 'src/SchachTurnierManager.Domain/Models/PairingQualityReport.cs' -Content $pairingQualityReport
Set-TextFile -Path 'src/SchachTurnierManager.Domain/Services/PairingQualityAnalyzer.cs' -Content $pairingQualityAnalyzer
Set-TextFile -Path 'tests/SchachTurnierManager.Domain.Tests/PairingQualityAnalyzerTests.cs' -Content $pairingQualityAnalyzerTests

Update-TextFile -Path 'src/SchachTurnierManager.WebApi/Program.cs' -Updater {
    param($text)
    $text -replace 'version = "0\.\d+\.\d+"', 'version = "0.17.0"'
}

Update-TextFile -Path 'src/SchachTurnierManager.WebApp/src/main.tsx' -Updater {
    param($text)
    $text -replace 'Lokaler Turnierleiter · v0\.\d+\.\d+', 'Lokaler Turnierleiter · v0.17.0'
}

Update-TextFile -Path 'src/SchachTurnierManager.WebApp/package.json' -Updater {
    param($text)
    $text -replace '"version": "0\.\d+\.\d+"', '"version": "0.17.0"'
}

Update-TextFile -Path 'src/SchachTurnierManager.WebApp/package-lock.json' -Updater {
    param($text)
    $text -replace '"version": "0\.\d+\.\d+"', '"version": "0.17.0"'
}

Update-TextFile -Path 'CHANGELOG.md' -Updater {
    param($text)
    if ($text -match '## 0\.17\.0') {
        return $text
    }

    $entry = @'
## 0.17.0 - Pairing-Qualitätsbericht

- Pairing-Qualitätsmodell für Schweizer-System-Runden ergänzt.
- Analyzer erkennt Rematches, Scoregruppen-Unterschiede, dritte gleiche Farbe in Folge und Bye/Spielfrei.
- Qualitätswert und Schweregrad für spätere UI-Erklärung „Warum wurde so gelost?“ ergänzt.
- Golden-nahe Tests für Pairing-Qualität ergänzt.

'@
    return $text -replace '(# Changelog\s*)', "`$1`r`n$entry"
}

Invoke-Step 'dotnet restore' { dotnet restore }
Invoke-Step 'dotnet build' { dotnet build }
Invoke-Step 'dotnet test' { dotnet test }
Invoke-Step 'npm install' { Push-Location 'src/SchachTurnierManager.WebApp'; npm install; Pop-Location }
Invoke-Step 'npm run build' { Push-Location 'src/SchachTurnierManager.WebApp'; npm run build; Pop-Location }
Invoke-Step 'Pack-Portable' { pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File '.\scripts\Pack-Portable.ps1' }

Write-Host '[v0.17.0] Nachkontrolle abgeschlossen. Bitte danach git status prüfen und committen.'
git status --short
