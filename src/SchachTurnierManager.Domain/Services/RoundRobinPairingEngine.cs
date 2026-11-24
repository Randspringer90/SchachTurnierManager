using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Domain.Services;

public sealed class RoundRobinPairingEngine
{
    public const string BergerVersion = "RoundRobin-Berger-v2";
    public const string LegacyVersion = "RoundRobin-CircleMethod";

    public IReadOnlyList<TournamentRound> GenerateAllRounds(IReadOnlyList<Player> players, TwzSource twzSource)
    {
        if (players.Count(player => player.IsActive) < 2) return Array.Empty<TournamentRound>();
        var plan = CreatePlan(players, twzSource);
        var count = plan.ParticipantOrder.Count;
        return Enumerable.Range(1, count % 2 == 0 ? count - 1 : count)
            .Select(round => GenerateRound(plan, round)).ToArray();
    }

    public RoundRobinPlan CreatePlan(IReadOnlyList<Player> players, TwzSource twzSource)
    {
        var plan = new RoundRobinPlan
        {
            AlgorithmVersion = BergerVersion,
            ParticipantOrder = players.Where(player => player.IsActive)
                .OrderByDescending(player => player.Twz(twzSource))
                .ThenBy(player => player.StartingRank == 0 ? int.MaxValue : player.StartingRank)
                .ThenBy(player => player.Name, StringComparer.OrdinalIgnoreCase)
                .ThenBy(player => player.Id).Select(player => player.Id).ToArray()
        };
        ValidatePlan(plan);
        return plan;
    }

    public TournamentRound GenerateRound(RoundRobinPlan plan, int roundNumber)
    {
        ValidatePlan(plan);
        var seeds = plan.ParticipantOrder.Select(id => (Guid?)id).ToList();
        if (seeds.Count % 2 == 1) seeds.Add(null);
        var count = seeds.Count;
        if (roundNumber < 1 || roundNumber >= count)
            throw new InvalidOperationException("Alle Runden des Jeder-gegen-jeden-Spielplans wurden bereits erzeugt.")
                .WithErrorCode("ROUND_ROBIN_COMPLETE");
        var pairings = new List<Pairing>(count / 2);
        if (plan.AlgorithmVersion == BergerVersion)
        {
            // FIDE C.05 Annex 1: fixed final seed; the other seeds advance by
            // half the even field. The highest seed is the bye for odd fields.
            var movingCount = count - 1;
            var pivot = (int)((long)(roundNumber - 1) * (count / 2) % movingCount);
            AddPair(pairings, roundNumber % 2 == 1 ? seeds[pivot] : seeds[^1],
                roundNumber % 2 == 1 ? seeds[^1] : seeds[pivot]);
            for (var offset = 1; offset < count / 2; offset++)
                AddPair(pairings, seeds[(pivot + offset) % movingCount], seeds[(pivot - offset + movingCount) % movingCount]);
        }
        else
        {
            // Preserve the original rotation AND colours for existing events.
            // Indexing the rotation directly keeps a single round O(n).
            var shift = roundNumber - 1;
            Guid? At(int position) => position == 0 ? seeds[0]
                : seeds[1 + (position - 1 - shift + count - 1) % (count - 1)];
            for (var board = 0; board < count / 2; board++)
            {
                var a = At(board);
                var b = At(count - 1 - board);
                if ((roundNumber + board) % 2 == 0) AddPair(pairings, a, b);
                else AddPair(pairings, b, a);
            }
        }
        return new TournamentRound
        {
            RoundNumber = roundNumber,
            Pairings = pairings,
            Audit = new PairingAudit
            {
                Algorithm = plan.AlgorithmVersion,
                Messages = new[] { $"Versionierter Rundenturnier-Spielplan für {plan.ParticipantOrder.Count} Teilnehmer; Reihenfolge ab Runde 1 festgelegt." }
            }
        };
    }

    public RoundRobinPlan ReconstructLegacyPlan(TournamentState tournament)
    {
        // Board order and the old colour rule uniquely encode the original
        // seeds. Never guess from today's ratings, names or only a partial round.
        if (tournament.Rounds.Count == 0 || tournament.Rounds.Any(round =>
                round is null || round.Audit is null || round.Pairings is null ||
                round.Audit.Algorithm != LegacyVersion || round.Pairings.Any(pair => pair is null || pair.IsManualOverride)))
            throw HistoryError();
        if (tournament.Rounds.Select(round => round.RoundNumber).Distinct().Count() != tournament.Rounds.Count)
            throw HistoryError();
        var first = tournament.Rounds.SingleOrDefault(round => round.RoundNumber == 1);
        if (first is null || first.Pairings.Count == 0) throw HistoryError();
        var boards = first.Pairings.OrderBy(pair => pair.BoardNumber).ToArray();
        var seeds = new Guid?[boards.Length * 2];
        var ids = boards.SelectMany(pair => new[] { pair.WhitePlayerId, pair.BlackPlayerId })
            .Where(id => id.HasValue).Select(id => id!.Value).ToArray();
        if (ids.Length < 2 || ids.Distinct().Count() != ids.Length ||
            seeds.Length - ids.Length is < 0 or > 1) throw HistoryError();
        for (var index = 0; index < boards.Length; index++)
        {
            var pair = boards[index];
            if (pair.BoardNumber != index + 1 || pair.WhitePlayerId is null) throw HistoryError();
            if (pair.BlackPlayerId is null)
            {
                if (index != 0 || ids.Length % 2 != 1) throw HistoryError();
                seeds[0] = pair.WhitePlayerId;
            }
            else
            {
                var aWasWhite = (1 + index) % 2 == 0;
                seeds[index] = aWasWhite ? pair.WhitePlayerId : pair.BlackPlayerId;
                seeds[seeds.Length - 1 - index] = aWasWhite ? pair.BlackPlayerId : pair.WhitePlayerId;
            }
        }
        var plan = new RoundRobinPlan
        {
            AlgorithmVersion = LegacyVersion,
            ParticipantOrder = seeds.Where(id => id.HasValue).Select(id => id!.Value).ToArray()
        };
        ValidateHistory(tournament, plan);
        return plan;
    }

    public void ValidateHistory(TournamentState tournament, RoundRobinPlan plan)
    {
        ValidatePlan(plan);
        var playerIds = tournament.Players.Select(player => player.Id).ToHashSet();
        if (plan.ParticipantOrder.Any(id => !playerIds.Contains(id))) throw HistoryError();
        if (tournament.Rounds.Any(round => round is null || round.Audit is null || round.Pairings is null || round.Pairings.Any(pair => pair is null))) throw HistoryError();
        var rounds = tournament.Rounds.OrderBy(round => round.RoundNumber).ToArray();
        for (var index = 0; index < rounds.Length; index++)
        {
            var actual = rounds[index];
            if (actual.RoundNumber != index + 1 || actual.Audit.Algorithm != plan.AlgorithmVersion) throw HistoryError();
            var expected = GenerateRound(plan, actual.RoundNumber).Pairings;
            var boards = actual.Pairings.OrderBy(pair => pair.BoardNumber).ToArray();
            if (boards.Length != expected.Count) throw HistoryError();
            for (var board = 0; board < boards.Length; board++)
                if (boards[board].BoardNumber != expected[board].BoardNumber ||
                    boards[board].WhitePlayerId != expected[board].WhitePlayerId ||
                    boards[board].BlackPlayerId != expected[board].BlackPlayerId) throw HistoryError();
        }
    }

    private static void ValidatePlan(RoundRobinPlan plan)
    {
        if (plan is null || plan.AlgorithmVersion is not BergerVersion and not LegacyVersion ||
            plan.ParticipantOrder is null || plan.ParticipantOrder.Count < 2 ||
            plan.ParticipantOrder.Any(id => id == Guid.Empty) ||
            plan.ParticipantOrder.Distinct().Count() != plan.ParticipantOrder.Count)
            throw HistoryError();
    }

    private static void AddPair(List<Pairing> pairings, Guid? white, Guid? black)
    {
        if (white is null && black is null) throw HistoryError();
        pairings.Add(white is null || black is null
            ? Pairing.Bye(pairings.Count + 1, (white ?? black)!.Value)
            : Pairing.Game(pairings.Count + 1, white.Value, black.Value));
    }

    private static InvalidOperationException HistoryError() => new InvalidOperationException(
        "Der gespeicherte Rundenturnier-Spielplan ist unbekannt, mehrdeutig oder passt nicht zu allen vorhandenen Runden. " +
        "Runden und Ergebnisse bleiben erhalten. Vor der Fortsetzung den ursprünglichen Spielplan ausdrücklich prüfen; keine automatische Neuplanung.")
        .WithErrorCode("ROUND_ROBIN_HISTORY_INVALID");
}
