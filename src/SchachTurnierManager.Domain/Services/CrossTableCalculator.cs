using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Domain.Services;

public sealed class CrossTableCalculator
{
    private readonly StandingsCalculator _standings = new();

    public CrossTable Calculate(TournamentState tournament)
    {
        var standingRows = _standings.Calculate(tournament);
        var orderedPlayers = standingRows
            .Select(row => new CrossTablePlayer
            {
                PlayerId = row.PlayerId,
                Name = row.Name,
                Rank = row.Rank,
                StartingRank = row.StartingRank,
                Points = row.Points
            })
            .ToList();

        var rankByPlayerId = orderedPlayers.ToDictionary(player => player.PlayerId, player => player.Rank);
        var playersById = tournament.Players.ToDictionary(player => player.Id);

        var rows = orderedPlayers
            .Select(player => new CrossTableRow
            {
                PlayerId = player.PlayerId,
                Name = player.Name,
                Rank = player.Rank,
                Points = player.Points,
                Cells = orderedPlayers
                    .Select(opponent => CreateCell(tournament, player.PlayerId, opponent.PlayerId, rankByPlayerId, playersById))
                    .ToList()
            })
            .ToList();

        return new CrossTable
        {
            Players = orderedPlayers,
            Rows = rows
        };
    }

    private static CrossTableCell CreateCell(
        TournamentState tournament,
        Guid playerId,
        Guid opponentId,
        IReadOnlyDictionary<Guid, int> rankByPlayerId,
        IReadOnlyDictionary<Guid, Player> playersById)
    {
        if (playerId == opponentId)
        {
            return new CrossTableCell
            {
                PlayerId = playerId,
                OpponentId = opponentId,
                IsSelf = true,
                ResultLabel = "—"
            };
        }

        foreach (var round in tournament.Rounds.OrderBy(r => r.RoundNumber))
        {
            foreach (var pairing in round.Pairings)
            {
                if (pairing.WhitePlayerId == playerId && pairing.BlackPlayerId == opponentId)
                {
                    return BuildGameCell(playerId, opponentId, round.RoundNumber, pairing, ChessColor.White, tournament.Settings.ScoringSystem);
                }

                if (pairing.BlackPlayerId == playerId && pairing.WhitePlayerId == opponentId)
                {
                    return BuildGameCell(playerId, opponentId, round.RoundNumber, pairing, ChessColor.Black, tournament.Settings.ScoringSystem);
                }
            }
        }

        return new CrossTableCell
        {
            PlayerId = playerId,
            OpponentId = opponentId,
            ResultLabel = string.Empty,
            Notes = playersById.ContainsKey(opponentId) && rankByPlayerId.ContainsKey(opponentId) ? null : "Gegner nicht gefunden."
        };
    }

    private static CrossTableCell BuildGameCell(Guid playerId, Guid opponentId, int roundNumber, Pairing pairing, ChessColor color, ScoringSystem scoringSystem)
    {
        var isWhite = color == ChessColor.White;
        var points = pairing.Result.Kind == GameResultKind.NotPlayed
            ? (decimal?)null
            : ScoringRules.ScoreFor(pairing.Result, isWhite, scoringSystem);

        return new CrossTableCell
        {
            PlayerId = playerId,
            OpponentId = opponentId,
            RoundNumber = roundNumber,
            BoardNumber = pairing.BoardNumber,
            Color = color,
            ResultLabel = FormatResult(pairing.Result.Kind, isWhite),
            Points = points,
            IsBye = pairing.IsBye,
            Notes = pairing.Notes
        };
    }

    private static string FormatResult(GameResultKind kind, bool isWhitePerspective)
    {
        return kind switch
        {
            GameResultKind.NotPlayed => "offen",
            GameResultKind.WhiteWin or GameResultKind.WhiteForfeitWin => isWhitePerspective ? "1" : "0",
            GameResultKind.BlackWin or GameResultKind.BlackForfeitWin => isWhitePerspective ? "0" : "1",
            GameResultKind.Draw => "½",
            GameResultKind.DoubleForfeit => "0",
            GameResultKind.Bye => "+",
            GameResultKind.ArmageddonWhiteWin => isWhitePerspective ? "A+" : "A-",
            GameResultKind.ArmageddonBlackWin => isWhitePerspective ? "A-" : "A+",
            _ => "?"
        };
    }
}
