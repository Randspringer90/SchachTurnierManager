using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Domain.Services;

public sealed class SwissPairingEngine
{
    // Wiederholungspaarungen müssen jede Kombination aus Punktdifferenz- und Farbstrafen
    // sicher dominieren, damit die globale Optimierung ein Rematch ausschließlich dann wählt,
    // wenn es keine rematchfreie vollständige Paarung mehr gibt ("nur wenn unvermeidbar").
    private const decimal RematchPenalty = 1_000_000_000m;

    // Exakte Minimum-Penalty-Paarung per Bitmaske ist für Vereins-/Open-Sektionen bis zu dieser
    // Größe schnell und speicherfreundlich. Größere Felder (große Opens) fallen bewusst auf die
    // dokumentierte Greedy-Heuristik zurück, bis ein vollständiges FIDE-Dutch verfügbar ist.
    private const int MaxPlayersForExactMatching = 20;

    public TournamentRound GenerateNextRound(TournamentState tournament)
    {
        var roundNumber = tournament.Rounds.Count + 1;
        var profiles = BuildProfiles(tournament);
        var active = profiles.Values
            .OrderByDescending(p => p.Points)
            .ThenByDescending(p => p.Twz)
            .ThenBy(p => p.StartingRank == 0 ? int.MaxValue : p.StartingRank)
            .ThenBy(p => p.Player.Name, StringComparer.OrdinalIgnoreCase)
            .ToList();

        var messages = new List<string>();
        var scoreGroups = BuildScoreGroupMessages(active);
        var floaters = new List<string>();
        var colorNotes = new List<string>();
        var pairings = new List<Pairing>();
        var toPair = new List<PlayerPairingProfile>(active);

        if (toPair.Count % 2 == 1)
        {
            var bye = SelectByePlayer(toPair);
            toPair.Remove(bye);
            pairings.Add(Pairing.Bye(pairings.Count + 1, bye.Player.Id) with
            {
                Notes = $"Bye: niedrigste Scoregruppe ohne bisheriges Bye bevorzugt. Punkte vor Runde: {bye.Points}."
            });
            messages.Add($"Bye vergeben an {bye.Player.Name} ({bye.Points} Punkte, bisheriges Bye: {(bye.HadBye ? "ja" : "nein")}).");
        }

        var (pairs, usedExact) = BuildPairs(toPair);

        messages.Insert(0, usedExact
            ? "Schweizer-System V2: global optimierte Minimum-Penalty-Paarung (exakte Maximum-Weight-Matching-Suche) mit Rematch-Vermeidung, Bye-Schutz und Farbpräferenzprüfung."
            : $"Schweizer-System V2: Greedy-Fallback aktiv (Feld > {MaxPlayersForExactMatching} Spieler; exakte Optimierung übersprungen) mit Rematch-Vermeidung, Bye-Schutz und Farbpräferenzprüfung.");
        messages.Insert(1, "Noch kein vollständiges FIDE-Dutch-System; Scoregroups, Floaters und Farbentscheidungen werden aber auditierbar protokolliert.");

        foreach (var (first, second) in pairs)
        {
            if (first.OpponentIds.Contains(second.Player.Id))
            {
                messages.Add($"Rematch unvermeidbar (global optimiert, keine rematchfreie Gesamtpaarung möglich): {first.Player.Name} gegen {second.Player.Name}.");
            }

            if (first.Points != second.Points)
            {
                var higher = first.Points > second.Points ? first : second;
                var lower = first.Points > second.Points ? second : first;
                floaters.Add($"{lower.Player.Name} floater hoch/runter gegen {higher.Player.Name}: {lower.Points} ↔ {higher.Points} Punkte.");
            }

            var colorDecision = ChooseColors(first, second);
            colorNotes.Add(colorDecision.Note);
            pairings.Add(Pairing.Game(pairings.Count + 1, colorDecision.White.Player.Id, colorDecision.Black.Player.Id) with
            {
                Notes = $"Score {colorDecision.White.Points}-{colorDecision.Black.Points}; {colorDecision.Note}"
            });
        }

        return new TournamentRound
        {
            RoundNumber = roundNumber,
            Pairings = pairings
                .OrderBy(p => p.IsBye)
                .ThenBy(p => p.BoardNumber)
                .Select((p, i) => p with { BoardNumber = i + 1 })
                .ToList(),
            Audit = new PairingAudit
            {
                Algorithm = "Swiss-ScoreGroup-Optimal-V2",
                RulesetVersion = "STM-0.41-swiss-optimal-matching",
                Messages = messages,
                ScoreGroups = scoreGroups,
                Floaters = floaters,
                ColorNotes = colorNotes
            }
        };
    }

    private static IReadOnlyList<string> BuildScoreGroupMessages(IReadOnlyList<PlayerPairingProfile> active)
    {
        return active
            .GroupBy(p => p.Points)
            .OrderByDescending(g => g.Key)
            .Select(g => $"Scoregruppe {g.Key}: {string.Join(", ", g.Select(p => p.Player.Name))}")
            .ToList();
    }

    private static PlayerPairingProfile SelectByePlayer(IReadOnlyList<PlayerPairingProfile> active)
    {
        var preferred = active.Where(p => !p.HadBye).ToList();
        var pool = preferred.Count > 0 ? preferred : active;
        return pool
            .OrderBy(p => p.Points)
            .ThenBy(p => p.Twz)
            .ThenByDescending(p => p.StartingRank)
            .ThenByDescending(p => p.Player.Name, StringComparer.OrdinalIgnoreCase)
            .First();
    }

    /// <summary>
    /// Erzeugt die Spielpaarungen für ein gerades Restfeld. Für Felder bis
    /// <see cref="MaxPlayersForExactMatching"/> wird ein exaktes Minimum-Penalty-Matching gesucht
    /// (garantiert rematchfrei, sofern überhaupt möglich, und minimiert Punkt-/Farbstrafen global);
    /// größere Felder nutzen die bisherige Greedy-Heuristik.
    /// </summary>
    private static (List<(PlayerPairingProfile First, PlayerPairingProfile Second)> Pairs, bool UsedExact) BuildPairs(
        IReadOnlyList<PlayerPairingProfile> players)
    {
        if (players.Count == 0)
        {
            return (new List<(PlayerPairingProfile, PlayerPairingProfile)>(), true);
        }

        if (players.Count <= MaxPlayersForExactMatching)
        {
            return (BuildExactPairs(players), true);
        }

        return (BuildGreedyPairs(players), false);
    }

    private static List<(PlayerPairingProfile First, PlayerPairingProfile Second)> BuildExactPairs(
        IReadOnlyList<PlayerPairingProfile> players)
    {
        var n = players.Count; // gerade
        var weights = new decimal[n, n];
        for (var i = 0; i < n; i++)
        {
            for (var j = i + 1; j < n; j++)
            {
                var penalty = PairingPenalty(players[i], players[j]);
                weights[i, j] = penalty;
                weights[j, i] = penalty;
            }
        }

        var size = 1 << n;
        var dp = new decimal[size];
        var choice = new int[size];
        Array.Fill(dp, decimal.MaxValue);
        dp[0] = 0m;

        for (var mask = 1; mask < size; mask++)
        {
            if (System.Numerics.BitOperations.PopCount((uint)mask) % 2 != 0)
            {
                continue;
            }

            var first = System.Numerics.BitOperations.TrailingZeroCount((uint)mask);
            var withoutFirst = mask & ~(1 << first);
            var best = decimal.MaxValue;
            var bestPartner = -1;

            var remaining = withoutFirst;
            while (remaining != 0)
            {
                var partner = System.Numerics.BitOperations.TrailingZeroCount((uint)remaining);
                remaining &= remaining - 1;

                var previous = mask & ~(1 << first) & ~(1 << partner);
                if (dp[previous] == decimal.MaxValue)
                {
                    continue;
                }

                var candidate = dp[previous] + weights[first, partner];
                if (candidate < best)
                {
                    best = candidate;
                    bestPartner = partner;
                }
            }

            dp[mask] = best;
            choice[mask] = bestPartner;
        }

        var pairs = new List<(PlayerPairingProfile, PlayerPairingProfile)>();
        var current = size - 1;
        while (current != 0)
        {
            var first = System.Numerics.BitOperations.TrailingZeroCount((uint)current);
            var partner = choice[current];
            pairs.Add((players[first], players[partner]));
            current &= ~(1 << first);
            current &= ~(1 << partner);
        }

        return pairs;
    }

    private static List<(PlayerPairingProfile First, PlayerPairingProfile Second)> BuildGreedyPairs(
        IReadOnlyList<PlayerPairingProfile> players)
    {
        var pairs = new List<(PlayerPairingProfile, PlayerPairingProfile)>();
        var byId = players.ToDictionary(p => p.Player.Id);
        var unpaired = players.Select(p => p.Player.Id).ToList();

        while (unpaired.Count > 0)
        {
            var firstId = unpaired[0];
            unpaired.RemoveAt(0);
            var first = byId[firstId];
            var secondId = SelectBestOpponent(first, unpaired.Select(id => byId[id]));
            unpaired.Remove(secondId);
            pairs.Add((first, byId[secondId]));
        }

        return pairs;
    }

    private static Guid SelectBestOpponent(PlayerPairingProfile first, IEnumerable<PlayerPairingProfile> candidates)
    {
        return candidates
            .Select(candidate => new { Candidate = candidate, Penalty = PairingPenalty(first, candidate) })
            .OrderBy(x => x.Penalty)
            .ThenBy(x => Math.Abs(x.Candidate.Points - first.Points))
            .ThenByDescending(x => x.Candidate.Points)
            .ThenByDescending(x => x.Candidate.Twz)
            .ThenBy(x => x.Candidate.StartingRank == 0 ? int.MaxValue : x.Candidate.StartingRank)
            .ThenBy(x => x.Candidate.Player.Name, StringComparer.OrdinalIgnoreCase)
            .First()
            .Candidate.Player.Id;
    }

    private static decimal PairingPenalty(PlayerPairingProfile a, PlayerPairingProfile b)
    {
        var colorDecision = ChooseColors(a, b);
        var penalty = Math.Abs(a.Points - b.Points) * 1000m;
        if (a.OpponentIds.Contains(b.Player.Id))
        {
            penalty += RematchPenalty;
        }

        penalty += colorDecision.Penalty;
        return penalty;
    }

    private static ColorDecision ChooseColors(PlayerPairingProfile a, PlayerPairingProfile b)
    {
        var aWhitePenalty = ColorPenalty(a, ChessColor.White) + ColorPenalty(b, ChessColor.Black);
        var bWhitePenalty = ColorPenalty(b, ChessColor.White) + ColorPenalty(a, ChessColor.Black);

        if (aWhitePenalty < bWhitePenalty)
        {
            return CreateColorDecision(a, b, aWhitePenalty);
        }

        if (bWhitePenalty < aWhitePenalty)
        {
            return CreateColorDecision(b, a, bWhitePenalty);
        }

        if (a.ColorBalance > b.ColorBalance)
        {
            return CreateColorDecision(b, a, bWhitePenalty);
        }

        if (b.ColorBalance > a.ColorBalance)
        {
            return CreateColorDecision(a, b, aWhitePenalty);
        }

        return a.StartingRank <= b.StartingRank ? CreateColorDecision(a, b, aWhitePenalty) : CreateColorDecision(b, a, bWhitePenalty);
    }

    private static ColorDecision CreateColorDecision(PlayerPairingProfile white, PlayerPairingProfile black, decimal penalty)
    {
        var note = $"Farben: Weiß {white.Player.Name} (Bilanz {white.ColorBalance}, Präferenz {ColorPreferenceLabel(white.Preference)}) - Schwarz {black.Player.Name} (Bilanz {black.ColorBalance}, Präferenz {ColorPreferenceLabel(black.Preference)}), Penalty {penalty}.";
        return new ColorDecision(white, black, penalty, note);
    }

    private static decimal ColorPenalty(PlayerPairingProfile player, ChessColor assigned)
    {
        var penalty = 0m;
        var wouldBeBalance = player.ColorBalance + (assigned == ChessColor.White ? 1 : -1);
        penalty += Math.Abs(wouldBeBalance) * 10m;

        if (WouldCreateThirdSameColor(player, assigned))
        {
            penalty += 1000m;
        }

        penalty += player.Preference switch
        {
            ColorPreference.StrongWhite when assigned != ChessColor.White => 600m,
            ColorPreference.StrongBlack when assigned != ChessColor.Black => 600m,
            ColorPreference.MildWhite when assigned != ChessColor.White => 60m,
            ColorPreference.MildBlack when assigned != ChessColor.Black => 60m,
            _ => 0m
        };

        return penalty;
    }

    private static bool WouldCreateThirdSameColor(PlayerPairingProfile player, ChessColor assigned)
    {
        return player.LastTwoColors.Count == 2 && player.LastTwoColors[0] == assigned && player.LastTwoColors[1] == assigned;
    }

    private static string ColorPreferenceLabel(ColorPreference preference)
    {
        return preference switch
        {
            ColorPreference.StrongWhite => "stark Weiß",
            ColorPreference.MildWhite => "leicht Weiß",
            ColorPreference.MildBlack => "leicht Schwarz",
            ColorPreference.StrongBlack => "stark Schwarz",
            _ => "neutral"
        };
    }

    private static Dictionary<Guid, PlayerPairingProfile> BuildProfiles(TournamentState tournament)
    {
        var standings = new StandingsCalculator().Calculate(tournament).ToDictionary(s => s.PlayerId);
        var profiles = tournament.Players
            .Where(p => p.IsActive)
            .ToDictionary(p => p.Id, p => new MutableProfile(p, standings.TryGetValue(p.Id, out var row) ? row.Points : 0m, p.Twz(tournament.Settings.TwzSource)));

        foreach (var round in tournament.Rounds.OrderBy(r => r.RoundNumber))
        {
            foreach (var pairing in round.Pairings)
            {
                if (pairing.WhitePlayerId is null)
                {
                    continue;
                }

                if (pairing.IsBye || pairing.BlackPlayerId is null)
                {
                    if (profiles.TryGetValue(pairing.WhitePlayerId.Value, out var byeProfile))
                    {
                        byeProfile.HadBye = true;
                    }
                    continue;
                }

                if (profiles.TryGetValue(pairing.WhitePlayerId.Value, out var white))
                {
                    white.WhiteCount++;
                    white.Colors.Add(ChessColor.White);
                    white.OpponentIds.Add(pairing.BlackPlayerId.Value);
                }

                if (profiles.TryGetValue(pairing.BlackPlayerId.Value, out var black))
                {
                    black.BlackCount++;
                    black.Colors.Add(ChessColor.Black);
                    black.OpponentIds.Add(pairing.WhitePlayerId.Value);
                }
            }
        }

        return profiles.ToDictionary(kv => kv.Key, kv => kv.Value.ToImmutable());
    }

    private sealed class MutableProfile(Player player, decimal points, int twz)
    {
        public Player Player { get; } = player;
        public decimal Points { get; } = points;
        public int Twz { get; } = twz;
        public int StartingRank => Player.StartingRank == 0 ? int.MaxValue : Player.StartingRank;
        public int WhiteCount { get; set; }
        public int BlackCount { get; set; }
        public bool HadBye { get; set; }
        public HashSet<Guid> OpponentIds { get; } = new();
        public List<ChessColor> Colors { get; } = new();

        public PlayerPairingProfile ToImmutable()
        {
            var lastTwo = Colors.Count <= 2 ? Colors.ToList() : Colors.TakeLast(2).ToList();
            return new PlayerPairingProfile(
                Player,
                Points,
                Twz,
                StartingRank,
                WhiteCount,
                BlackCount,
                HadBye,
                OpponentIds.ToHashSet(),
                lastTwo,
                DeterminePreference(WhiteCount, BlackCount, lastTwo));
        }
    }

    private static ColorPreference DeterminePreference(int whiteCount, int blackCount, IReadOnlyList<ChessColor> lastTwo)
    {
        if (lastTwo.Count == 2 && lastTwo[0] == ChessColor.White && lastTwo[1] == ChessColor.White)
        {
            return ColorPreference.StrongBlack;
        }

        if (lastTwo.Count == 2 && lastTwo[0] == ChessColor.Black && lastTwo[1] == ChessColor.Black)
        {
            return ColorPreference.StrongWhite;
        }

        var balance = whiteCount - blackCount;
        if (balance >= 2)
        {
            return ColorPreference.StrongBlack;
        }

        if (balance <= -2)
        {
            return ColorPreference.StrongWhite;
        }

        if (balance == 1 || lastTwo.LastOrDefault() == ChessColor.White)
        {
            return ColorPreference.MildBlack;
        }

        if (balance == -1 || lastTwo.LastOrDefault() == ChessColor.Black)
        {
            return ColorPreference.MildWhite;
        }

        return ColorPreference.None;
    }

    private sealed record PlayerPairingProfile(
        Player Player,
        decimal Points,
        int Twz,
        int StartingRank,
        int WhiteCount,
        int BlackCount,
        bool HadBye,
        HashSet<Guid> OpponentIds,
        IReadOnlyList<ChessColor> LastTwoColors,
        ColorPreference Preference)
    {
        public int ColorBalance => WhiteCount - BlackCount;
    }

    private sealed record ColorDecision(PlayerPairingProfile White, PlayerPairingProfile Black, decimal Penalty, string Note);

    private enum ColorPreference
    {
        None = 0,
        MildWhite = 1,
        StrongWhite = 2,
        MildBlack = 3,
        StrongBlack = 4
    }
}
