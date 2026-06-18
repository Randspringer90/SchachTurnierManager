using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Domain.Services;

public sealed class Chess960PositionService
{
    private static readonly int[] LightSquares = [1, 3, 5, 7];
    private static readonly int[] DarkSquares = [0, 2, 4, 6];
    private static readonly List<(int First, int Second)> KnightCombinations = BuildKnightCombinations();

    public Chess960StartPosition GenerateRandomPosition(int? seed = null)
    {
        var random = seed.HasValue ? new Random(seed.Value) : Random.Shared;
        return FromPositionNumber(random.Next(960), seed);
    }

    public Chess960StartPosition FromPositionNumber(int positionNumber, int? seed = null)
    {
        if (positionNumber is < 0 or > 959)
        {
            throw new ArgumentOutOfRangeException(nameof(positionNumber), "Chess960-Positionsnummer muss zwischen 0 und 959 liegen.");
        }

        var remainingNumber = positionNumber;
        var backRank = new char[8];

        var lightBishopIndex = remainingNumber % 4;
        remainingNumber /= 4;
        backRank[LightSquares[lightBishopIndex]] = 'B';

        var darkBishopIndex = remainingNumber % 4;
        remainingNumber /= 4;
        backRank[DarkSquares[darkBishopIndex]] = 'B';

        var remainingSquares = EmptySquares(backRank);
        var queenIndex = remainingNumber % 6;
        remainingNumber /= 6;
        backRank[remainingSquares[queenIndex]] = 'Q';

        remainingSquares = EmptySquares(backRank);
        var knightCombination = KnightCombinations[remainingNumber % 10];
        backRank[remainingSquares[knightCombination.First]] = 'N';
        backRank[remainingSquares[knightCombination.Second]] = 'N';

        remainingSquares = EmptySquares(backRank);
        backRank[remainingSquares[0]] = 'R';
        backRank[remainingSquares[1]] = 'K';
        backRank[remainingSquares[2]] = 'R';

        var whiteBackRank = new string(backRank);
        return new Chess960StartPosition
        {
            WhiteBackRank = whiteBackRank,
            BlackBackRank = whiteBackRank.ToLowerInvariant(),
            PositionNumber = positionNumber,
            Seed = seed
        };
    }

    public bool ValidatePosition(string position)
    {
        var normalized = Normalize(position);
        if (normalized.Length != 8)
        {
            return false;
        }

        if (normalized.Count(piece => piece == 'K') != 1
            || normalized.Count(piece => piece == 'Q') != 1
            || normalized.Count(piece => piece == 'R') != 2
            || normalized.Count(piece => piece == 'B') != 2
            || normalized.Count(piece => piece == 'N') != 2)
        {
            return false;
        }

        if (normalized.Any(piece => piece is not ('K' or 'Q' or 'R' or 'B' or 'N')))
        {
            return false;
        }

        var bishopSquares = normalized
            .Select((piece, index) => new { Piece = piece, Index = index })
            .Where(item => item.Piece == 'B')
            .Select(item => item.Index)
            .ToArray();
        if (bishopSquares[0] % 2 == bishopSquares[1] % 2)
        {
            return false;
        }

        var rookSquares = normalized
            .Select((piece, index) => new { Piece = piece, Index = index })
            .Where(item => item.Piece == 'R')
            .Select(item => item.Index)
            .Order()
            .ToArray();
        var kingSquare = normalized.IndexOf('K');
        return rookSquares[0] < kingSquare && kingSquare < rookSquares[1];
    }

    public int GetPositionNumber(string position)
    {
        var normalized = Normalize(position);
        if (!ValidatePosition(normalized))
        {
            throw new ArgumentException("Keine gültige Chess960-Grundreihe.", nameof(position));
        }

        var bishopSquares = normalized
            .Select((piece, index) => new { Piece = piece, Index = index })
            .Where(item => item.Piece == 'B')
            .Select(item => item.Index)
            .ToArray();
        var lightBishopIndex = Array.IndexOf(LightSquares, bishopSquares.Single(LightSquares.Contains));
        var darkBishopIndex = Array.IndexOf(DarkSquares, bishopSquares.Single(DarkSquares.Contains));

        var board = new char[8];
        board[LightSquares[lightBishopIndex]] = 'B';
        board[DarkSquares[darkBishopIndex]] = 'B';

        var remainingSquares = EmptySquares(board);
        var queenSquare = normalized.IndexOf('Q');
        var queenIndex = remainingSquares.IndexOf(queenSquare);
        board[queenSquare] = 'Q';

        remainingSquares = EmptySquares(board);
        var knightIndexes = normalized
            .Select((piece, index) => new { Piece = piece, Index = index })
            .Where(item => item.Piece == 'N')
            .Select(item => remainingSquares.IndexOf(item.Index))
            .Order()
            .ToArray();
        var knightCombinationIndex = KnightCombinations.IndexOf((knightIndexes[0], knightIndexes[1]));

        return lightBishopIndex
            + 4 * darkBishopIndex
            + 16 * queenIndex
            + 96 * knightCombinationIndex;
    }

    private static List<int> EmptySquares(IReadOnlyList<char> board)
    {
        return board
            .Select((piece, index) => new { Piece = piece, Index = index })
            .Where(item => item.Piece == '\0')
            .Select(item => item.Index)
            .ToList();
    }

    private static List<(int First, int Second)> BuildKnightCombinations()
    {
        var combinations = new List<(int First, int Second)>();
        for (var first = 0; first < 5; first++)
        {
            for (var second = first + 1; second < 5; second++)
            {
                combinations.Add((first, second));
            }
        }

        return combinations;
    }

    private static string Normalize(string position)
    {
        return string.IsNullOrWhiteSpace(position) ? string.Empty : position.Trim().ToUpperInvariant();
    }
}
