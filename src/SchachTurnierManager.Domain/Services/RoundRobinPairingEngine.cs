using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Domain.Services;

public sealed class RoundRobinPairingEngine
{
    public IReadOnlyList<TournamentRound> GenerateAllRounds(IReadOnlyList<Player> players, TwzSource twzSource)
    {
        var seeded = players
            .Where(p => p.IsActive)
            .OrderByDescending(p => p.Twz(twzSource))
            .ThenBy(p => p.StartingRank == 0 ? int.MaxValue : p.StartingRank)
            .ThenBy(p => p.Name, StringComparer.OrdinalIgnoreCase)
            .Select(p => (Guid?)p.Id)
            .ToList();

        if (seeded.Count < 2)
        {
            return Array.Empty<TournamentRound>();
        }

        if (seeded.Count % 2 == 1)
        {
            seeded.Add(null);
        }

        var n = seeded.Count;
        var rounds = new List<TournamentRound>();
        var rotation = seeded.ToList();

        for (var roundNumber = 1; roundNumber <= n - 1; roundNumber++)
        {
            var pairings = new List<Pairing>();
            for (var i = 0; i < n / 2; i++)
            {
                var a = rotation[i];
                var b = rotation[n - 1 - i];
                if (a is null && b is null)
                {
                    continue;
                }

                if (a is null && b is not null)
                {
                    pairings.Add(Pairing.Bye(pairings.Count + 1, b.Value));
                    continue;
                }

                if (b is null && a is not null)
                {
                    pairings.Add(Pairing.Bye(pairings.Count + 1, a.Value));
                    continue;
                }

                var aWhite = (roundNumber + i) % 2 == 0;
                pairings.Add(aWhite
                    ? Pairing.Game(pairings.Count + 1, a!.Value, b!.Value)
                    : Pairing.Game(pairings.Count + 1, b!.Value, a!.Value));
            }

            rounds.Add(new TournamentRound
            {
                RoundNumber = roundNumber,
                Pairings = pairings,
                Audit = new PairingAudit
                {
                    Algorithm = "RoundRobin-CircleMethod",
                    Messages = new[] { $"Berger-/Circle-Methode für {players.Count(p => p.IsActive)} aktive Spieler." }
                }
            });

            var last = rotation[^1];
            rotation.RemoveAt(n - 1);
            rotation.Insert(1, last);
        }

        return rounds;
    }
}
