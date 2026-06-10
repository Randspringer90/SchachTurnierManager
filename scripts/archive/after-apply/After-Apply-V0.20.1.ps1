$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
    Write-Host "[v0.20.1] $Message"
}

function Read-Utf8([string]$Path) {
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8
}

function Write-Utf8NoBom([string]$Path, [string]$Content) {
    $encoding = [System.Text.UTF8Encoding]::new($false)
    $fullPath = if ([System.IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path (Get-Location).Path $Path }
    [System.IO.File]::WriteAllText($fullPath, $Content, $encoding)
}

function Replace-ExactNormalized([string]$Path, [string]$Old, [string]$New, [string]$Description) {
    $content = (Read-Utf8 $Path).Replace("`r`n", "`n")
    $oldNormalized = $Old.Replace("`r`n", "`n")
    $newNormalized = $New.Replace("`r`n", "`n")
    if (-not $content.Contains($oldNormalized)) {
        if ($content.Contains($newNormalized)) {
            Write-Step "$Description bereits vorhanden"
            return
        }
        throw "Erwartete Stelle nicht gefunden in ${Path}: ${Description}"
    }
    $content = $content.Replace($oldNormalized, $newNormalized)
    Write-Utf8NoBom $Path $content
    Write-Step $Description
}

$root = (Get-Location).Path
if (-not (Test-Path -LiteralPath (Join-Path $root 'src/SchachTurnierManager.Domain/Services/StandingsCalculator.cs'))) {
    throw 'Bitte im Projektwurzelverzeichnis D:\Schach\SchachTurnierManager ausführen.'
}

# Defekten Zwischenstand aus 0.20.0 nicht mitcommitten.
Remove-Item -LiteralPath 'scripts/After-Apply-V0.20.ps1' -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath 'docs/HANDOFF_0_20_0.md' -Force -ErrorAction SilentlyContinue

# Versionen
$packageJson = 'src/SchachTurnierManager.WebApp/package.json'
$packageLock = 'src/SchachTurnierManager.WebApp/package-lock.json'
$program = 'src/SchachTurnierManager.WebApi/Program.cs'
$main = 'src/SchachTurnierManager.WebApp/src/main.tsx'
$changelog = 'CHANGELOG.md'

foreach ($file in @($packageJson, $packageLock, $program, $main)) {
    $content = Read-Utf8 $file
    $content = $content -replace '0\.20\.0', '0.20.1'
    $content = $content -replace '0\.19\.0', '0.20.1'
    $content = $content -replace '0\.18\.1', '0.20.1'
    Write-Utf8NoBom $file $content
}
Write-Step 'Versionen auf 0.20.1 gesetzt'

# Enums erweitern - line-ending-insensitive, da Windows/Unix-Zeilenenden im Repo gemischt sein können.
$enumsPath = 'src/SchachTurnierManager.Domain/Models/Enums.cs'
Replace-ExactNormalized $enumsPath @'
public enum TiebreakType
{
    DirectEncounter = 0,
    NumberOfWins = 1,
    Buchholz = 2,
    BuchholzCutOne = 3,
    SonnebornBerger = 4,
    AverageOpponentRating = 5,
    TournamentPerformance = 6,
    StartingRank = 99
}
'@ @'
public enum TiebreakType
{
    DirectEncounter = 0,
    NumberOfWins = 1,
    Buchholz = 2,
    BuchholzCutOne = 3,
    SonnebornBerger = 4,
    AverageOpponentRating = 5,
    TournamentPerformance = 6,
    BuchholzCutTwo = 7,
    MedianBuchholz = 8,
    ProgressiveScore = 9,
    KoyaScore = 10,
    NumberOfBlackWins = 11,
    StartingRank = 99
}
'@ 'TiebreakType um Swiss-Chess-nahe Wertungen erweitert'

# StandingRow ersetzen
$standingRowPath = 'src/SchachTurnierManager.Domain/Models/StandingRow.cs'
@'
namespace SchachTurnierManager.Domain.Models;

public sealed record StandingRow
{
    public int Rank { get; init; }
    public Guid PlayerId { get; init; }
    public string Name { get; init; } = string.Empty;
    public int StartingRank { get; init; }
    public int Twz { get; init; }
    public decimal Points { get; init; }
    public int Wins { get; init; }
    public int BlackWins { get; init; }
    public decimal DirectEncounter { get; init; }
    public decimal Buchholz { get; init; }
    public decimal BuchholzCutOne { get; init; }
    public decimal BuchholzCutTwo { get; init; }
    public decimal MedianBuchholz { get; init; }
    public decimal SonnebornBerger { get; init; }
    public decimal KoyaScore { get; init; }
    public decimal ProgressiveScore { get; init; }
    public decimal AverageOpponentRating { get; init; }
    public int? TournamentPerformance { get; init; }
    public decimal HeroScore { get; init; }
    public IReadOnlyDictionary<string, bool> Categories { get; init; } = new Dictionary<string, bool>();
}
'@ | Set-Content -LiteralPath $standingRowPath -Encoding utf8NoBOM
Write-Step 'StandingRow um erweiterte Wertungsfelder ergänzt'

# StandingsCalculator ersetzen
$standingsCalculatorPath = 'src/SchachTurnierManager.Domain/Services/StandingsCalculator.cs'
@'
using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Domain.Services;

public sealed class StandingsCalculator
{
    public IReadOnlyList<StandingRow> Calculate(TournamentState tournament)
    {
        var referenceYear = DateTime.Today.Year;
        var rows = tournament.Players
            .Where(p => p.IsActive)
            .ToDictionary(p => p.Id, p => new MutableStanding(p, p.Twz(tournament.Settings.TwzSource)));

        foreach (var round in tournament.Rounds.OrderBy(round => round.RoundNumber))
        {
            foreach (var pairing in round.Pairings)
            {
                ApplyPairing(tournament, pairing, rows);
            }

            foreach (var row in rows.Values)
            {
                row.ProgressiveScore += row.Points;
            }
        }

        var opponentPoints = rows.ToDictionary(kv => kv.Key, kv => kv.Value.Points);
        foreach (var row in rows.Values)
        {
            var opponentScores = row.OpponentIds
                .Where(opponentPoints.ContainsKey)
                .Select(id => opponentPoints[id])
                .OrderBy(x => x)
                .ToList();
            row.Buchholz = opponentScores.Sum();
            row.BuchholzCutOne = SumAfterDropping(opponentScores, lowest: 1, highest: 0);
            row.BuchholzCutTwo = SumAfterDropping(opponentScores, lowest: 2, highest: 0);
            row.MedianBuchholz = SumAfterDropping(opponentScores, lowest: 1, highest: 1);
            row.AverageOpponentRating = row.OpponentRatings.Count == 0 ? 0m : Math.Round(row.OpponentRatings.Average(), 2);
            row.TournamentPerformance = row.PerformanceGames == 0 || row.PerformanceOpponentRatings.Count == 0
                ? null
                : RatingCalculator.ApproximatePerformanceRating((int)Math.Round(row.PerformanceOpponentRatings.Average()), (double)(row.NormalizedPerformancePoints / row.PerformanceGames));
        }

        var koyaThreshold = KoyaThreshold(tournament);
        foreach (var row in rows.Values)
        {
            foreach (var contribution in row.SonnebornContributions)
            {
                if (opponentPoints.TryGetValue(contribution.OpponentId, out var points))
                {
                    row.SonnebornBerger += points * contribution.ScoreAgainstOpponent;
                }
            }

            row.KoyaScore = row.DirectResults
                .Where(result => opponentPoints.TryGetValue(result.OpponentId, out var points) && points >= koyaThreshold)
                .Sum(result => result.ScoreAgainstOpponent);
            row.HeroScore = row.TournamentPerformance is null ? 0m : row.TournamentPerformance.Value - row.Twz;
        }

        foreach (var group in rows.Values.GroupBy(r => r.Points))
        {
            var playerIds = group.Select(g => g.Player.Id).ToHashSet();
            foreach (var row in group)
            {
                row.DirectEncounter = row.DirectResults.Where(r => playerIds.Contains(r.OpponentId)).Sum(r => r.ScoreAgainstOpponent);
            }
        }

        var ordered = rows.Values
            .OrderByDescending(r => r.Points)
            .ThenBy(r => r, new TiebreakComparer(tournament.Settings.Tiebreaks))
            .ThenBy(r => r.Player.Name, StringComparer.OrdinalIgnoreCase)
            .ToList();

        return ordered.Select((r, index) => new StandingRow
        {
            Rank = index + 1,
            PlayerId = r.Player.Id,
            Name = r.Player.Name,
            StartingRank = r.Player.StartingRank,
            Twz = r.Twz,
            Points = r.Points,
            Wins = r.Wins,
            BlackWins = r.BlackWins,
            DirectEncounter = r.DirectEncounter,
            Buchholz = r.Buchholz,
            BuchholzCutOne = r.BuchholzCutOne,
            BuchholzCutTwo = r.BuchholzCutTwo,
            MedianBuchholz = r.MedianBuchholz,
            SonnebornBerger = r.SonnebornBerger,
            KoyaScore = r.KoyaScore,
            ProgressiveScore = r.ProgressiveScore,
            AverageOpponentRating = r.AverageOpponentRating,
            TournamentPerformance = r.TournamentPerformance,
            HeroScore = r.HeroScore,
            Categories = CategoryClassifier.Classify(r.Player, tournament.Settings, referenceYear)
        }).ToList();
    }

    private static void ApplyPairing(TournamentState tournament, Pairing pairing, Dictionary<Guid, MutableStanding> rows)
    {
        if (pairing.WhitePlayerId is null)
        {
            return;
        }

        if (!rows.TryGetValue(pairing.WhitePlayerId.Value, out var white))
        {
            return;
        }

        if (pairing.IsBye || pairing.BlackPlayerId is null)
        {
            white.Points += ScoringRules.ScoreFor(pairing.Result, isWhite: true, tournament.Settings.ScoringSystem);
            if (ScoringRules.IsWinFor(pairing.Result, isWhite: true, countForfeitWins: true, countByeAsWin: tournament.Settings.CountByeAsWin))
            {
                white.Wins++;
            }
            return;
        }

        if (!rows.TryGetValue(pairing.BlackPlayerId.Value, out var black))
        {
            return;
        }

        var whiteScore = ScoringRules.ScoreFor(pairing.Result, isWhite: true, tournament.Settings.ScoringSystem);
        var blackScore = ScoringRules.ScoreFor(pairing.Result, isWhite: false, tournament.Settings.ScoringSystem);
        white.Points += whiteScore;
        black.Points += blackScore;

        if (ScoringRules.IsWinFor(pairing.Result, isWhite: true)) white.Wins++;
        if (ScoringRules.IsWinFor(pairing.Result, isWhite: false))
        {
            black.Wins++;
            black.BlackWins++;
        }

        var whiteNormalized = ScoringRules.NormalizedClassicalScore(pairing.Result.Kind, isWhite: true);
        var blackNormalized = ScoringRules.NormalizedClassicalScore(pairing.Result.Kind, isWhite: false);

        if (ResultPolicy.CountsAsOpponentForBuchholz(pairing.Result.Kind, tournament.Settings))
        {
            white.OpponentIds.Add(black.Player.Id);
            black.OpponentIds.Add(white.Player.Id);
            if (black.Twz > 0) white.OpponentRatings.Add(black.Twz);
            if (white.Twz > 0) black.OpponentRatings.Add(white.Twz);
        }

        if (ResultPolicy.CountsAsGameForDirectAndSonneborn(pairing.Result.Kind, tournament.Settings))
        {
            white.DirectResults.Add(new DirectResult(black.Player.Id, whiteNormalized));
            black.DirectResults.Add(new DirectResult(white.Player.Id, blackNormalized));
            white.SonnebornContributions.Add(new DirectResult(black.Player.Id, whiteNormalized));
            black.SonnebornContributions.Add(new DirectResult(white.Player.Id, blackNormalized));
        }

        if (ResultPolicy.CountsForPerformance(pairing.Result.Kind))
        {
            white.NormalizedPerformancePoints += whiteNormalized;
            black.NormalizedPerformancePoints += blackNormalized;
            white.PerformanceGames++;
            black.PerformanceGames++;
            if (black.Twz > 0) white.PerformanceOpponentRatings.Add(black.Twz);
            if (white.Twz > 0) black.PerformanceOpponentRatings.Add(white.Twz);
        }
    }

    private static decimal SumAfterDropping(IReadOnlyList<decimal> orderedScores, int lowest, int highest)
    {
        if (orderedScores.Count <= lowest + highest)
        {
            return orderedScores.Sum();
        }

        return orderedScores
            .Skip(lowest)
            .Take(orderedScores.Count - lowest - highest)
            .Sum();
    }

    private static decimal KoyaThreshold(TournamentState tournament)
    {
        if (tournament.Rounds.Count == 0)
        {
            return 0m;
        }

        var winScore = ScoringRules.ScoreFor(new GameResult(GameResultKind.WhiteWin), isWhite: true, tournament.Settings.ScoringSystem);
        return tournament.Rounds.Count * winScore / 2m;
    }

    private sealed class TiebreakComparer(IReadOnlyList<TiebreakType> configuredTiebreaks) : IComparer<MutableStanding>
    {
        private readonly IReadOnlyList<TiebreakType> _configuredTiebreaks = configuredTiebreaks.Count == 0
            ? new[] { TiebreakType.StartingRank }
            : configuredTiebreaks;

        public int Compare(MutableStanding? x, MutableStanding? y)
        {
            if (ReferenceEquals(x, y))
            {
                return 0;
            }

            if (x is null)
            {
                return 1;
            }

            if (y is null)
            {
                return -1;
            }

            foreach (var tiebreak in _configuredTiebreaks)
            {
                var comparison = CompareByTiebreak(x, y, tiebreak);
                if (comparison != 0)
                {
                    return comparison;
                }
            }

            return 0;
        }

        private static int CompareByTiebreak(MutableStanding x, MutableStanding y, TiebreakType tiebreak)
        {
            return tiebreak switch
            {
                TiebreakType.DirectEncounter => Desc(x.DirectEncounter, y.DirectEncounter),
                TiebreakType.NumberOfWins => Desc(x.Wins, y.Wins),
                TiebreakType.Buchholz => Desc(x.Buchholz, y.Buchholz),
                TiebreakType.BuchholzCutOne => Desc(x.BuchholzCutOne, y.BuchholzCutOne),
                TiebreakType.BuchholzCutTwo => Desc(x.BuchholzCutTwo, y.BuchholzCutTwo),
                TiebreakType.MedianBuchholz => Desc(x.MedianBuchholz, y.MedianBuchholz),
                TiebreakType.SonnebornBerger => Desc(x.SonnebornBerger, y.SonnebornBerger),
                TiebreakType.KoyaScore => Desc(x.KoyaScore, y.KoyaScore),
                TiebreakType.ProgressiveScore => Desc(x.ProgressiveScore, y.ProgressiveScore),
                TiebreakType.NumberOfBlackWins => Desc(x.BlackWins, y.BlackWins),
                TiebreakType.AverageOpponentRating => Desc(x.AverageOpponentRating, y.AverageOpponentRating),
                TiebreakType.TournamentPerformance => Desc(x.TournamentPerformance ?? int.MinValue, y.TournamentPerformance ?? int.MinValue),
                TiebreakType.StartingRank => Asc(StartingRankOrMax(x), StartingRankOrMax(y)),
                _ => 0
            };
        }

        private static int Desc<T>(T x, T y) where T : IComparable<T> => y.CompareTo(x);

        private static int Asc<T>(T x, T y) where T : IComparable<T> => x.CompareTo(y);

        private static int StartingRankOrMax(MutableStanding row) => row.Player.StartingRank <= 0 ? int.MaxValue : row.Player.StartingRank;
    }

    private sealed class MutableStanding(Player player, int twz)
    {
        public Player Player { get; } = player;
        public int Twz { get; } = twz;
        public decimal Points { get; set; }
        public int Wins { get; set; }
        public int BlackWins { get; set; }
        public decimal DirectEncounter { get; set; }
        public decimal Buchholz { get; set; }
        public decimal BuchholzCutOne { get; set; }
        public decimal BuchholzCutTwo { get; set; }
        public decimal MedianBuchholz { get; set; }
        public decimal SonnebornBerger { get; set; }
        public decimal KoyaScore { get; set; }
        public decimal ProgressiveScore { get; set; }
        public decimal AverageOpponentRating { get; set; }
        public int? TournamentPerformance { get; set; }
        public decimal HeroScore { get; set; }
        public List<Guid> OpponentIds { get; } = new();
        public List<decimal> OpponentRatings { get; } = new();
        public List<decimal> PerformanceOpponentRatings { get; } = new();
        public List<DirectResult> DirectResults { get; } = new();
        public List<DirectResult> SonnebornContributions { get; } = new();
        public decimal NormalizedPerformancePoints { get; set; }
        public int PerformanceGames { get; set; }
    }

    private sealed record DirectResult(Guid OpponentId, decimal ScoreAgainstOpponent);
}
'@ | Set-Content -LiteralPath $standingsCalculatorPath -Encoding utf8NoBOM
Write-Step 'StandingsCalculator um Cut-2, Median, Koya, Progressiv und Schwarzsiege erweitert'

# Export um neue Spalten erweitern
$exportPath = 'src/SchachTurnierManager.Domain/Services/TournamentExportFormatter.cs'
Replace-ExactNormalized $exportPath 'builder.AppendLine("Rang;Name;TWZ;Punkte;Siege;Direktvergleich;Buchholz;Buchholz Cut-1;Sonneborn-Berger;Gegnerschnitt;TPR;Heldenwert");' 'builder.AppendLine("Rang;Name;TWZ;Punkte;Siege;Schwarzsiege;Direktvergleich;Buchholz;Buchholz Cut-1;Buchholz Cut-2;Median Buchholz;Sonneborn-Berger;Koya;Progressiv;Gegnerschnitt;TPR;Heldenwert");' 'Tabellen-CSV-Header erweitert'
Replace-ExactNormalized $exportPath @'
                row.Wins.ToString(CultureInfo.InvariantCulture),
                FormatDecimal(row.DirectEncounter),
                FormatDecimal(row.Buchholz),
                FormatDecimal(row.BuchholzCutOne),
                FormatDecimal(row.SonnebornBerger),
                FormatDecimal(row.AverageOpponentRating),
'@ @'
                row.Wins.ToString(CultureInfo.InvariantCulture),
                row.BlackWins.ToString(CultureInfo.InvariantCulture),
                FormatDecimal(row.DirectEncounter),
                FormatDecimal(row.Buchholz),
                FormatDecimal(row.BuchholzCutOne),
                FormatDecimal(row.BuchholzCutTwo),
                FormatDecimal(row.MedianBuchholz),
                FormatDecimal(row.SonnebornBerger),
                FormatDecimal(row.KoyaScore),
                FormatDecimal(row.ProgressiveScore),
                FormatDecimal(row.AverageOpponentRating),
'@ 'Tabellen-CSV-Werte erweitert'
Replace-ExactNormalized $exportPath 'builder.AppendLine("<section><h2>Tabelle</h2><table><thead><tr><th>Rang</th><th>Name</th><th>Punkte</th><th>Siege</th><th>Buchholz</th><th>SB</th><th>TPR</th></tr></thead><tbody>");' 'builder.AppendLine("<section><h2>Tabelle</h2><table><thead><tr><th>Rang</th><th>Name</th><th>Punkte</th><th>Siege</th><th>Schwarzsiege</th><th>Buchholz</th><th>BH Cut-1</th><th>BH Cut-2</th><th>Median</th><th>SB</th><th>Koya</th><th>Progressiv</th><th>TPR</th></tr></thead><tbody>");' 'Druckansicht-Tabellenkopf erweitert'
Replace-ExactNormalized $exportPath 'builder.AppendLine($"<tr><td>{row.Rank}</td><td>{Html(row.Name)}</td><td>{FormatDecimal(row.Points)}</td><td>{row.Wins}</td><td>{FormatDecimal(row.Buchholz)}</td><td>{FormatDecimal(row.SonnebornBerger)}</td><td>{(row.TournamentPerformance?.ToString(CultureInfo.InvariantCulture) ?? "—")}</td></tr>");' 'builder.AppendLine($"<tr><td>{row.Rank}</td><td>{Html(row.Name)}</td><td>{FormatDecimal(row.Points)}</td><td>{row.Wins}</td><td>{row.BlackWins}</td><td>{FormatDecimal(row.Buchholz)}</td><td>{FormatDecimal(row.BuchholzCutOne)}</td><td>{FormatDecimal(row.BuchholzCutTwo)}</td><td>{FormatDecimal(row.MedianBuchholz)}</td><td>{FormatDecimal(row.SonnebornBerger)}</td><td>{FormatDecimal(row.KoyaScore)}</td><td>{FormatDecimal(row.ProgressiveScore)}</td><td>{(row.TournamentPerformance?.ToString(CultureInfo.InvariantCulture) ?? "—")}</td></tr>");' 'Druckansicht-Tabellenwerte erweitert'

# React-Typen und UI erweitern
Replace-ExactNormalized $main @'
  wins: number;
  buchholz: number;
  buchholzCutOne: number;
  sonnebornBerger: number;
  averageOpponentRating: number;
'@ @'
  wins: number;
  blackWins: number;
  buchholz: number;
  buchholzCutOne: number;
  buchholzCutTwo: number;
  medianBuchholz: number;
  sonnebornBerger: number;
  koyaScore: number;
  progressiveScore: number;
  averageOpponentRating: number;
'@ 'React StandingRow-Typ erweitert'

Replace-ExactNormalized $main @'
  { value: 5, label: 'Gegnerschnitt' },
  { value: 6, label: 'Turnierleistung' },
  { value: 99, label: 'Startnummer' }
'@ @'
  { value: 5, label: 'Gegnerschnitt' },
  { value: 6, label: 'Turnierleistung' },
  { value: 7, label: 'Buchholz Cut-2' },
  { value: 8, label: 'Median-Buchholz' },
  { value: 9, label: 'Progressiv' },
  { value: 10, label: 'Koya' },
  { value: 11, label: 'Schwarzsiege' },
  { value: 99, label: 'Startnummer' }
'@ 'React Wertungsoptionen erweitert'

Replace-ExactNormalized $main @'
                  <thead><tr><th>Rang</th><th>Name</th><th>Punkte</th><th>Siege</th><th>BH</th><th>SB</th><th>TPR</th></tr></thead>
'@ @'
                  <thead><tr><th>Rang</th><th>Name</th><th>Punkte</th><th>Siege</th><th>Schwarz</th><th>BH</th><th>BH-1</th><th>BH-2</th><th>Median</th><th>SB</th><th>Koya</th><th>Prog.</th><th>TPR</th></tr></thead>
'@ 'Live-Tabelle Kopf erweitert'

Replace-ExactNormalized $main @'
                        <td>{row.wins}</td>
                        <td>{row.buchholz}</td>
                        <td>{row.sonnebornBerger}</td>
                        <td>{row.tournamentPerformance ?? '—'}</td>
'@ @'
                        <td>{row.wins}</td>
                        <td>{row.blackWins}</td>
                        <td>{row.buchholz}</td>
                        <td>{row.buchholzCutOne}</td>
                        <td>{row.buchholzCutTwo}</td>
                        <td>{row.medianBuchholz}</td>
                        <td>{row.sonnebornBerger}</td>
                        <td>{row.koyaScore}</td>
                        <td>{row.progressiveScore}</td>
                        <td>{row.tournamentPerformance ?? '—'}</td>
'@ 'Live-Tabelle Werte erweitert'

# Tests ergänzen
$testPath = 'tests/SchachTurnierManager.Domain.Tests/ExtendedTiebreakTests.cs'
@'
using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

public sealed class ExtendedTiebreakTests
{
    [Fact]
    public void Calculate_ExposesExtendedTiebreakValues()
    {
        var players = CreatePlayers();
        var tournament = CreateTournament(players);
        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 1,
            Pairings = new[]
            {
                Pairing.Game(1, players[1].Id, players[0].Id) with { Result = new GameResult(GameResultKind.BlackWin) },
                Pairing.Game(2, players[2].Id, players[3].Id) with { Result = new GameResult(GameResultKind.WhiteWin) }
            }
        });
        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 2,
            Pairings = new[]
            {
                Pairing.Game(1, players[0].Id, players[2].Id) with { Result = new GameResult(GameResultKind.Draw) },
                Pairing.Game(2, players[1].Id, players[3].Id) with { Result = new GameResult(GameResultKind.WhiteWin) }
            }
        });

        var standings = new StandingsCalculator().Calculate(tournament);
        var playerA = Assert.Single(standings, row => row.Name == "A");

        Assert.Equal(1.5m, playerA.Points);
        Assert.Equal(1, playerA.BlackWins);
        Assert.Equal(2.5m, playerA.Buchholz);
        Assert.Equal(1.5m, playerA.BuchholzCutOne);
        Assert.Equal(2.5m, playerA.BuchholzCutTwo);
        Assert.Equal(2.5m, playerA.MedianBuchholz);
        Assert.Equal(1.5m, playerA.KoyaScore);
        Assert.Equal(2.5m, playerA.ProgressiveScore);
    }

    [Fact]
    public void Calculate_UsesBlackWinsAsConfiguredTiebreak()
    {
        var players = CreatePlayers();
        var tournament = CreateTournament(players);
        tournament.Settings = new TournamentSettings
        {
            Format = TournamentFormat.Swiss,
            Tiebreaks = new[] { TiebreakType.NumberOfBlackWins, TiebreakType.StartingRank }
        };
        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 1,
            Pairings = new[]
            {
                Pairing.Game(1, players[1].Id, players[0].Id) with { Result = new GameResult(GameResultKind.BlackWin) },
                Pairing.Game(2, players[2].Id, players[3].Id) with { Result = new GameResult(GameResultKind.WhiteWin) }
            }
        });

        var onePointGroup = new StandingsCalculator()
            .Calculate(tournament)
            .Where(row => row.Points == 1m)
            .Take(2)
            .ToList();

        Assert.Equal("A", onePointGroup[0].Name);
        Assert.Equal(1, onePointGroup[0].BlackWins);
        Assert.Equal("C", onePointGroup[1].Name);
        Assert.Equal(0, onePointGroup[1].BlackWins);
    }

    private static TournamentState CreateTournament(IReadOnlyList<Player> players)
    {
        var tournament = new TournamentState
        {
            Name = "Extended Tiebreaks",
            Settings = new TournamentSettings { Format = TournamentFormat.Swiss }
        };
        tournament.Players.AddRange(players);
        return tournament;
    }

    private static List<Player> CreatePlayers()
    {
        return new()
        {
            Player("A", 4, 2000),
            Player("B", 2, 1900),
            Player("C", 1, 1800),
            Player("D", 3, 1700)
        };
    }

    private static Player Player(string name, int startingRank, int twz) => new()
    {
        Id = Guid.Parse($"00000000-0000-0000-0000-{startingRank:000000000000}"),
        Name = name,
        StartingRank = startingRank,
        Rating = new RatingProfile { ManualTwz = twz }
    };
}
'@ | Set-Content -LiteralPath $testPath -Encoding utf8NoBOM
Write-Step 'ExtendedTiebreakTests ergänzt'

# Changelog und Handoff
$changeEntry = @'
## 0.20.1 - Erweiterte Wertungen für Swiss-Chess-Parität

- Wertungen um Buchholz Cut-2, Median-Buchholz, Progressivwertung, Koya und Schwarzsiege erweitert.
- Wertungsketten-Konfiguration im Dashboard um die neuen Kriterien ergänzt.
- Live-Tabelle, CSV-Export und Druckansicht zeigen die zusätzlichen Wertungsfelder an.
- Tests für erweiterte Wertungswerte und Sortierung nach Schwarzsiegen ergänzt.
- Fix-Forward für 0.20.0: Patchlogik ist jetzt robust gegen CRLF/LF-Zeilenenden.

'@
$changeContent = Read-Utf8 $changelog
if (-not $changeContent.Contains('## 0.20.1 - Erweiterte Wertungen')) {
    $changeContent = $changeContent.Replace("# Changelog`n`n", "# Changelog`n`n$changeEntry")
    Write-Utf8NoBom $changelog $changeContent
    Write-Step 'CHANGELOG.md ergänzt'
}

@'
# Handoff 0.20.1 - Erweiterte Wertungen

## Inhalt

Dieser Fix-Forward-Patch ersetzt den abgebrochenen v0.20.0-Skriptstand und erweitert die Swiss-Chess-Paritätsroadmap um konkrete Wertungsfunktionen:

- Buchholz Cut-2
- Median-Buchholz
- Progressivwertung
- Koya-Wertung
- Schwarzsiege

Die neuen Werte werden berechnet, als Sortierkriterien angeboten, in der Live-Tabelle angezeigt und in CSV-/HTML-Exporten ausgegeben.

## Nachkontrolle

Das Skript `scripts/After-Apply-V0.20.1.ps1` führt aus:

- `dotnet restore`
- `dotnet build`
- `dotnet test`
- `npm install`
- `npm run build`
- `scripts/Pack-Portable.ps1`

## Erwartung

Nach erfolgreicher Nachkontrolle:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; git status; git add .; git commit -m "Add extended tiebreak calculations"; git push
```
'@ | Set-Content -LiteralPath 'docs/HANDOFF_0_20_1.md' -Encoding utf8NoBOM
Write-Step 'Handoff ergänzt'

# Nachkontrolle
Write-Step 'dotnet restore...'
dotnet restore
Write-Step 'dotnet build...'
dotnet build
Write-Step 'dotnet test...'
dotnet test
Write-Step 'npm install...'
Push-Location 'src/SchachTurnierManager.WebApp'
npm install
Write-Step 'npm run build...'
npm run build
Pop-Location
Write-Step 'Pack-Portable...'
pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File '.\scripts\Pack-Portable.ps1'

Write-Step 'Nachkontrolle abgeschlossen. Bitte danach git status prüfen und committen.'
git status --short
