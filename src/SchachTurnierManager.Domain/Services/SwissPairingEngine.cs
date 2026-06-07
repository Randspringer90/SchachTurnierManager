using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Domain.Services;

public sealed class SwissPairingEngine
{
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

        var messages = new List<string>
        {
            "Schweizer-System V2: scoregruppenorientierte Greedy-Paarung mit Rematch-Vermeidung, Bye-Schutz und Farbpräferenzprüfung.",
            "Noch kein vollständiges FIDE-Dutch-System; Scoregroups, Floaters und Farbentscheidungen werden aber auditierbar protokolliert."
        };
        var scoreGroups = BuildScoreGroupMessages(active);
        var floaters = new List<string>();
        var colorNotes = new List<string>();
        var pairings = new List<Pairing>();
        var unpaired = active.Select(p => p.Player.Id).ToList();

        if (unpaired.Count % 2 == 1)
        {
            var bye = SelectByePlayer(active);
            unpaired.Remove(bye.Player.Id);
            pairings.Add(Pairing.Bye(pairings.Count + 1, bye.Player.Id) with
            {
                Notes = $"Bye: niedrigste Scoregruppe ohne bisheriges Bye bevorzugt. Punkte vor Runde: {bye.Points}."
            });
            messages.Add($"Bye vergeben an {bye.Player.Name} ({bye.Points} Punkte, bisheriges Bye: {(bye.HadBye ? "ja" : "nein")}).");
        }

        while (unpaired.Count > 0)
        {
            var firstId = unpaired[0];
            unpaired.RemoveAt(0);
            var first = profiles[firstId];
            var secondId = SelectBestOpponent(first, unpaired.Select(id => profiles[id]));
            var second = profiles[secondId];
            unpaired.Remove(secondId);

            if (first.OpponentIds.Contains(second.Player.Id))
            {
                messages.Add($"Rematch unvermeidbar im Greedy-Schritt: {first.Player.Name} gegen {second.Player.Name}.");
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
                Algorithm = "Swiss-ScoreGroup-Greedy-V2",
                RulesetVersion = "STM-0.4-swiss-scoregroups",
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
            penalty += 100000m;
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
