using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Domain.Services;

/// <summary>
/// Baut die <see cref="FideDutchPlayerProfile"/> für eine Auslosung auf (STM-FACH-002).
/// Regelbelege: docs/FIDE_DUTCH_REFERENCE.md.
/// </summary>
/// <remarks>
/// Bewusst getrennt vom Paarungsverfahren. Der Grund ist praktisch: Die drei Regeln, an denen
/// FIDE-Dutch am leichtesten falsch umgesetzt wird (Farbfolge ohne ungespielte Runden,
/// Rematch-Sperre nur bei tatsächlich gespielten Partien, Freilos-Sperre nach kampflosem Sieg)
/// stecken alle hier — und lassen sich hier einzeln gegen die Checklisten einer zugelassenen
/// Referenz-Engine prüfen, ohne dass ein einziges Bracket gebildet sein muss.
/// </remarks>
public sealed class FideDutchProfileBuilder
{
    private readonly StandingsCalculator _standings = new();

    /// <summary>
    /// Erzeugt die Profile aller aktiven Spieler, sortiert nach C.04.3 Art. 1.2:
    /// Punkte absteigend, dann Startnummer (TPN) aufsteigend.
    /// </summary>
    /// <remarks>
    /// Das Rating taucht hier bewusst NICHT als Sortierkriterium auf. Es ist nach C.04.2 Art. 2.2
    /// bereits einmalig vor dem Turnier in die Startnummer eingeflossen und wird während der
    /// Auslosung nicht erneut herangezogen. (Die V2-Engine sortiert zusätzlich nach TWZ — das ist
    /// dort in Ordnung, für FIDE-Dutch wäre es regelwidrig.)
    /// </remarks>
    public IReadOnlyList<FideDutchPlayerProfile> Build(TournamentState tournament)
    {
        var standings = _standings.Calculate(tournament).ToDictionary(row => row.PlayerId);
        var states = tournament.Players
            .Where(player => player.IsActive)
            .ToDictionary(player => player.Id, player => new MutableState());

        var rounds = tournament.Rounds.OrderBy(round => round.RoundNumber).ToList();
        var lastRoundNumber = rounds.Count;

        // Punktestand MITLAUFEN lassen. Fuer die Float-Erkennung (Art. 1.4.2) zaehlt die Punktzahl
        // VOR der jeweiligen Runde, nicht der Endstand: Wer in R4 als Fuehrender gegen einen
        // Schwaecheren antritt, hat einen Downfloat bekommen - auch wenn er die Partie verliert und
        // am Ende gleichauf liegt.
        var pointsBeforeRound = states.Keys.ToDictionary(id => id, _ => 0m);

        foreach (var round in rounds)
        {
            var isLastRound = round.RoundNumber == lastRoundNumber;
            var isTwoRoundsBack = round.RoundNumber == lastRoundNumber - 1;

            foreach (var pairing in round.Pairings)
            {
                ApplyPairing(pairing, states, pointsBeforeRound, round.RoundNumber, isLastRound, isTwoRoundsBack);
            }

            AddRoundPoints(round, pointsBeforeRound, tournament.Settings.ScoringSystem);
        }

        return states
            .Select(entry => new FideDutchPlayerProfile(
                Player: tournament.Players.First(player => player.Id == entry.Key),
                Points: standings.TryGetValue(entry.Key, out var row) ? row.Points : 0m,
                Tpn: TpnOf(tournament, entry.Key),
                PlayedColours: entry.Value.Colours,
                ColourByRound: entry.Value.ColourByRound,
                PlayedOpponentIds: entry.Value.PlayedOpponentIds,
                IsByeIneligible: entry.Value.IsByeIneligible,
                FloatLastRound: entry.Value.FloatLastRound,
                FloatTwoRoundsBack: entry.Value.FloatTwoRoundsBack))
            .OrderByDescending(profile => profile.Points)
            .ThenBy(profile => profile.Tpn)
            .ToList();
    }

    /// <summary>Addiert die Punkte der Runde auf den mitlaufenden Stand.</summary>
    private static void AddRoundPoints(
        TournamentRound round,
        Dictionary<Guid, decimal> points,
        ScoringSystem scoringSystem)
    {
        foreach (var pairing in round.Pairings)
        {
            if (pairing.WhitePlayerId is { } white && points.ContainsKey(white))
            {
                points[white] += ScoringRules.ScoreFor(pairing.Result, isWhite: true, scoringSystem);
            }

            if (pairing.BlackPlayerId is { } black && points.ContainsKey(black))
            {
                points[black] += ScoringRules.ScoreFor(pairing.Result, isWhite: false, scoringSystem);
            }
        }
    }

    private static void ApplyPairing(
        Pairing pairing,
        Dictionary<Guid, MutableState> states,
        Dictionary<Guid, decimal> pointsBeforeRound,
        int roundNumber,
        bool isLastRound,
        bool isTwoRoundsBack)
    {
        // Freilos: keine Farbe, kein Gegner, aber volle Siegpunktzahl (C.04.1 Art. 3).
        // Es sperrt weitere Freilose ([C2]) und gilt als Downfloat (Art. 1.4.3).
        if (pairing.IsBye || pairing.BlackPlayerId is null)
        {
            if (pairing.WhitePlayerId is { } byePlayer && states.TryGetValue(byePlayer, out var byeState))
            {
                byeState.IsByeIneligible = true;
                byeState.SetFloat(FideFloat.Down, isLastRound, isTwoRoundsBack);
            }

            return;
        }

        if (pairing.WhitePlayerId is not { } white || pairing.BlackPlayerId is not { } black)
        {
            return;
        }

        var playedAtTheBoard = pairing.Result.IsOverTheBoard;

        if (playedAtTheBoard)
        {
            // Nur tatsaechlich gespielte Partien zaehlen fuer Farbfolge und Rematch-Sperre.
            if (states.TryGetValue(white, out var whiteState))
            {
                whiteState.Colours.Add(ChessColor.White);
                whiteState.ColourByRound[roundNumber] = ChessColor.White;
                whiteState.PlayedOpponentIds.Add(black);
            }

            if (states.TryGetValue(black, out var blackState))
            {
                blackState.Colours.Add(ChessColor.Black);
                blackState.ColourByRound[roundNumber] = ChessColor.Black;
                blackState.PlayedOpponentIds.Add(white);
            }

            ApplyFloats(white, black, states, pointsBeforeRound, isLastRound, isTwoRoundsBack);
            return;
        }

        // Kampflos oder ungespielt: C.04.2 Art. 3.4 - die Runde gilt fuer die Farbfolge als nicht
        // stattgefunden, und Art. 3.5 - die beiden duerfen spaeter noch gepaart werden. Es wird also
        // WEDER eine Farbe NOCH ein Gegner vermerkt.
        //
        // Eine Wirkung bleibt: Wer ohne zu spielen die volle Siegpunktzahl bekommt, erhaelt kein
        // Freilos mehr ([C2], Art. 2.1.2) und gilt als Downfloat (Art. 1.4.3).
        ApplyUnplayedSideEffects(pairing, white, black, states);
    }

    private static void ApplyUnplayedSideEffects(
        Pairing pairing,
        Guid white,
        Guid black,
        Dictionary<Guid, MutableState> states)
    {
        var forfeitWinner = pairing.Result.Kind switch
        {
            GameResultKind.WhiteForfeitWin => (Guid?)white,
            GameResultKind.BlackForfeitWin => black,
            _ => null
        };

        if (forfeitWinner is { } winner && states.TryGetValue(winner, out var winnerState))
        {
            winnerState.IsByeIneligible = true;
        }
    }

    /// <summary>
    /// Art. 1.4.2: Haben zwei Spieler mit unterschiedlicher Punktzahl gegeneinander gespielt, erhält
    /// der höher platzierte einen Downfloat, der niedrigere einen Upfloat. Bei gleicher Punktzahl
    /// bekommt niemand einen Float (Art. 1.4.4).
    /// </summary>
    private static void ApplyFloats(
        Guid white,
        Guid black,
        Dictionary<Guid, MutableState> states,
        Dictionary<Guid, decimal> pointsBeforeRound,
        bool isLastRound,
        bool isTwoRoundsBack)
    {
        var whitePoints = pointsBeforeRound.GetValueOrDefault(white);
        var blackPoints = pointsBeforeRound.GetValueOrDefault(black);

        if (whitePoints == blackPoints)
        {
            return;
        }

        var higher = whitePoints > blackPoints ? white : black;
        var lower = whitePoints > blackPoints ? black : white;

        if (states.TryGetValue(higher, out var higherState))
        {
            higherState.SetFloat(FideFloat.Down, isLastRound, isTwoRoundsBack);
        }

        if (states.TryGetValue(lower, out var lowerState))
        {
            lowerState.SetFloat(FideFloat.Up, isLastRound, isTwoRoundsBack);
        }
    }

    private static int TpnOf(TournamentState tournament, Guid playerId)
    {
        var player = tournament.Players.First(entry => entry.Id == playerId);
        return player.StartingRank == 0 ? int.MaxValue : player.StartingRank;
    }

    private sealed class MutableState
    {
        public List<ChessColor> Colours { get; } = new();
        public Dictionary<int, ChessColor> ColourByRound { get; } = new();
        public HashSet<Guid> PlayedOpponentIds { get; } = new();
        public bool IsByeIneligible { get; set; }
        public FideFloat FloatLastRound { get; private set; } = FideFloat.None;
        public FideFloat FloatTwoRoundsBack { get; private set; } = FideFloat.None;

        public void SetFloat(FideFloat value, bool isLastRound, bool isTwoRoundsBack)
        {
            if (isLastRound)
            {
                FloatLastRound = value;
            }
            else if (isTwoRoundsBack)
            {
                FloatTwoRoundsBack = value;
            }
        }
    }
}
