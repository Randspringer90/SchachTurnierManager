using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Domain.Services;

public sealed class SwissPairingEngine
{
    public TournamentRound GenerateNextRound(TournamentState tournament)
    {
        var roundNumber = tournament.Rounds.Count + 1;
        var standings = new StandingsCalculator().Calculate(tournament).ToDictionary(s => s.PlayerId);
        var active = tournament.Players
            .Where(p => p.IsActive)
            .OrderByDescending(p => standings.TryGetValue(p.Id, out var row) ? row.Points : 0m)
            .ThenByDescending(p => p.Twz(tournament.Settings.TwzSource))
            .ThenBy(p => p.StartingRank == 0 ? int.MaxValue : p.StartingRank)
            .ThenBy(p => p.Name, StringComparer.OrdinalIgnoreCase)
            .ToList();

        var messages = new List<string>
        {
            "Basis-Schweizer-System V1: Punktgruppen-nah, deterministisch, keine Wiederholung wenn vermeidbar.",
            "Noch nicht als vollständiges FIDE-Dutch-System zu verstehen; die Architektur trennt diesen Algorithmus bewusst austauschbar."
        };

        var pairings = new List<Pairing>();
        var unpaired = active.Select(p => p.Id).ToList();

        if (unpaired.Count % 2 == 1)
        {
            var byePlayer = active
                .Where(p => !HasHadBye(tournament, p.Id))
                .OrderBy(p => standings.TryGetValue(p.Id, out var row) ? row.Points : 0m)
                .ThenBy(p => p.Twz(tournament.Settings.TwzSource))
                .ThenByDescending(p => p.StartingRank)
                .FirstOrDefault() ?? active.Last();

            unpaired.Remove(byePlayer.Id);
            pairings.Add(Pairing.Bye(pairings.Count + 1, byePlayer.Id));
            messages.Add($"Bye vergeben an {byePlayer.Name}.");
        }

        while (unpaired.Count > 0)
        {
            var first = unpaired[0];
            unpaired.RemoveAt(0);
            var candidateIndex = unpaired.FindIndex(candidate => !HavePlayed(tournament, first, candidate));
            if (candidateIndex < 0)
            {
                candidateIndex = 0;
                messages.Add("Eine Wiederholung konnte im Greedy-Basissystem nicht vollständig vermieden werden.");
            }

            var second = unpaired[candidateIndex];
            unpaired.RemoveAt(candidateIndex);
            var (white, black) = ChooseColors(tournament, first, second);
            pairings.Add(Pairing.Game(pairings.Count + 1, white, black));
        }

        return new TournamentRound
        {
            RoundNumber = roundNumber,
            Pairings = pairings.OrderBy(p => p.IsBye).ThenBy(p => p.BoardNumber).Select((p, i) => p with { BoardNumber = i + 1 }).ToList(),
            Audit = new PairingAudit
            {
                Algorithm = "Swiss-Basic-Greedy-V1",
                Messages = messages
            }
        };
    }

    private static bool HasHadBye(TournamentState tournament, Guid playerId)
    {
        return tournament.Rounds.SelectMany(r => r.Pairings).Any(p => p.IsBye && p.WhitePlayerId == playerId);
    }

    private static bool HavePlayed(TournamentState tournament, Guid a, Guid b)
    {
        return tournament.Rounds.SelectMany(r => r.Pairings).Any(p =>
            p.WhitePlayerId is not null && p.BlackPlayerId is not null &&
            ((p.WhitePlayerId == a && p.BlackPlayerId == b) || (p.WhitePlayerId == b && p.BlackPlayerId == a)));
    }

    private static (Guid White, Guid Black) ChooseColors(TournamentState tournament, Guid a, Guid b)
    {
        var aBalance = ColorBalance(tournament, a);
        var bBalance = ColorBalance(tournament, b);

        if (aBalance > bBalance)
        {
            return (b, a);
        }

        if (bBalance > aBalance)
        {
            return (a, b);
        }

        var aLast = LastColor(tournament, a);
        var bLast = LastColor(tournament, b);
        if (aLast == ChessColor.White && bLast != ChessColor.White)
        {
            return (b, a);
        }

        if (bLast == ChessColor.White && aLast != ChessColor.White)
        {
            return (a, b);
        }

        return string.CompareOrdinal(a.ToString("N"), b.ToString("N")) <= 0 ? (a, b) : (b, a);
    }

    private static int ColorBalance(TournamentState tournament, Guid playerId)
    {
        var white = 0;
        var black = 0;
        foreach (var pairing in tournament.Rounds.SelectMany(r => r.Pairings))
        {
            if (pairing.WhitePlayerId == playerId && pairing.BlackPlayerId is not null) white++;
            if (pairing.BlackPlayerId == playerId) black++;
        }

        return white - black;
    }

    private static ChessColor LastColor(TournamentState tournament, Guid playerId)
    {
        foreach (var pairing in tournament.Rounds.SelectMany(r => r.Pairings).Reverse())
        {
            if (pairing.WhitePlayerId == playerId && pairing.BlackPlayerId is not null) return ChessColor.White;
            if (pairing.BlackPlayerId == playerId) return ChessColor.Black;
        }

        return ChessColor.None;
    }
}
