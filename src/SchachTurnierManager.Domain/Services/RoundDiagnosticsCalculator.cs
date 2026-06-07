using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Domain.Services;

public sealed class RoundDiagnosticsCalculator
{
    public IReadOnlyList<RoundDiagnostics> Calculate(TournamentState tournament)
    {
        return tournament.Rounds
            .OrderBy(round => round.RoundNumber)
            .Select(round => Calculate(tournament, round))
            .ToList();
    }

    public RoundDiagnostics Calculate(TournamentState tournament, TournamentRound round)
    {
        var players = tournament.Players.ToDictionary(player => player.Id, player => player.Name);
        var boards = round.Pairings
            .OrderBy(pairing => pairing.BoardNumber)
            .Select(pairing => CreateBoardDiagnostic(tournament, players, pairing))
            .ToList();

        var warnings = new List<string>();
        if (boards.Any(board => board.IsOpen))
        {
            warnings.Add($"Runde {round.RoundNumber} hat noch {boards.Count(board => board.IsOpen)} offene Bretter.");
        }

        foreach (var board in boards.Where(board => board.IsForfeit))
        {
            warnings.Add($"Brett {board.BoardNumber}: {board.ResultLabel} ist kampflos. {board.Note}");
        }

        foreach (var board in boards.Where(board => board.Result == GameResultKind.Bye))
        {
            warnings.Add($"Brett {board.BoardNumber}: Bye/Spielfrei zählt nur als Punkt, nicht für Gegnerwertungen oder Performance.");
        }

        if (round.IsVerified && boards.Any(board => board.IsOpen))
        {
            warnings.Add("Inkonsistenz: Runde ist geprüft, enthält aber noch offene Ergebnisse.");
        }

        return new RoundDiagnostics
        {
            RoundNumber = round.RoundNumber,
            ResultStatus = round.ResultStatus,
            IsComplete = boards.Count > 0 && boards.All(board => !board.IsOpen),
            IsLocked = round.IsLocked,
            IsVerified = round.IsVerified,
            OpenBoards = boards.Count(board => board.IsOpen),
            ForfeitBoards = boards.Count(board => board.IsForfeit),
            ByeBoards = boards.Count(board => board.Result == GameResultKind.Bye),
            Warnings = warnings,
            Boards = boards
        };
    }

    private static BoardDiagnostic CreateBoardDiagnostic(
        TournamentState tournament,
        IReadOnlyDictionary<Guid, string> players,
        Pairing pairing)
    {
        var kind = pairing.Result.Kind;
        return new BoardDiagnostic
        {
            BoardNumber = pairing.BoardNumber,
            White = PlayerName(players, pairing.WhitePlayerId),
            Black = pairing.BlackPlayerId is null ? "spielfrei" : PlayerName(players, pairing.BlackPlayerId),
            Result = kind,
            ResultLabel = ResultLabel(kind),
            IsOpen = kind == GameResultKind.NotPlayed,
            IsForfeit = ScoringRules.IsForfeit(kind),
            CountsForBuchholz = ResultPolicy.CountsAsOpponentForBuchholz(kind, tournament.Settings),
            CountsForDirectAndSonneborn = ResultPolicy.CountsAsGameForDirectAndSonneborn(kind, tournament.Settings),
            CountsForPerformance = ResultPolicy.CountsForPerformance(kind),
            Note = ResultPolicy.Explain(kind, tournament.Settings)
        };
    }

    private static string PlayerName(IReadOnlyDictionary<Guid, string> players, Guid? playerId)
    {
        return playerId is not null && players.TryGetValue(playerId.Value, out var name) ? name : "—";
    }

    private static string ResultLabel(GameResultKind kind)
    {
        return kind switch
        {
            GameResultKind.NotPlayed => "offen",
            GameResultKind.WhiteWin => "1-0",
            GameResultKind.Draw => "½-½",
            GameResultKind.BlackWin => "0-1",
            GameResultKind.WhiteForfeitWin => "+/-",
            GameResultKind.BlackForfeitWin => "-/+",
            GameResultKind.DoubleForfeit => "-/-",
            GameResultKind.Bye => "Bye",
            GameResultKind.ArmageddonWhiteWin => "Armageddon Weiß",
            GameResultKind.ArmageddonBlackWin => "Armageddon Schwarz",
            _ => kind.ToString()
        };
    }
}
