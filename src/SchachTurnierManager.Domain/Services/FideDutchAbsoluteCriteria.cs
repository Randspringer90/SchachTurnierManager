using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Domain.Services;

/// <summary>
/// Die absoluten Kriterien [C1]–[C3] aus C.04.3 Art. 2.1 und die Topscorer-Bestimmung (Art. 1.8).
/// Regelbelege: docs/FIDE_DUTCH_REFERENCE.md.
/// </summary>
/// <remarks>
/// Absolut heißt: Diese Kriterien dürfen NIE verletzt werden — kein Abwägen, keine Strafgewichte,
/// keine Ausnahme an Brett 1. Genau darin unterscheidet sich FIDE-Dutch von der V2-Engine, die
/// Rematches über eine sehr hohe Strafe nur unwahrscheinlich macht.
///
/// Eine Instanz gilt für GENAU EINE Auslosung: Ob es Topscorer gibt, hängt daran, ob die kommende
/// Runde die Schlussrunde ist. Deshalb wird das einmal beim Erzeugen festgelegt und nicht bei jeder
/// Abfrage neu geraten.
/// </remarks>
public sealed class FideDutchAbsoluteCriteria
{
    private readonly IReadOnlySet<Guid> _topscorerIds;

    private FideDutchAbsoluteCriteria(IReadOnlySet<Guid> topscorerIds, bool isFinalRound, decimal topscorerThreshold)
    {
        _topscorerIds = topscorerIds;
        IsFinalRound = isFinalRound;
        TopscorerThreshold = topscorerThreshold;
    }

    /// <summary>Ist die auszulosende Runde die Schlussrunde? Nur dann gibt es Topscorer (Art. 1.8).</summary>
    public bool IsFinalRound { get; }

    /// <summary>Punktzahl, die für den Topscorer-Status ÜBERSCHRITTEN werden muss (0, wenn keine Schlussrunde).</summary>
    public decimal TopscorerThreshold { get; }

    /// <summary>
    /// Bestimmt die Topscorer für die kommende Runde nach Art. 1.8.
    /// </summary>
    /// <remarks>
    /// Art. 1.8 im Wortlaut: Topscorer sind Spieler mit über 50 % der maximal möglichen Punktzahl —
    /// <b>bei der Auslosung der Schlussrunde</b>. Vor der Schlussrunde gibt es also KEINE Topscorer,
    /// und [C3] gilt dort ausnahmslos für jeden. Das wird leicht übersehen: Man liest „Topscorer" und
    /// denkt an die Tabellenspitze, aber der Begriff existiert in Runde 3 von 5 schlicht nicht.
    ///
    /// „Über 50 %" ist echt größer: Wer nach vier Runden genau 2.0 hat, ist kein Topscorer.
    /// </remarks>
    public static FideDutchAbsoluteCriteria ForRound(
        TournamentState tournament,
        IReadOnlyList<FideDutchPlayerProfile> profiles)
    {
        var roundsPlayed = tournament.Rounds.Count;
        var upcomingRound = roundsPlayed + 1;
        var isFinalRound = upcomingRound >= tournament.Settings.PlannedRounds;

        if (!isFinalRound)
        {
            return new FideDutchAbsoluteCriteria(new HashSet<Guid>(), isFinalRound: false, topscorerThreshold: 0m);
        }

        var winPoints = ScoringRules.ScoreFor(
            new GameResult(GameResultKind.WhiteWin), isWhite: true, tournament.Settings.ScoringSystem);
        var maximumPossible = roundsPlayed * winPoints;
        var threshold = maximumPossible / 2m;

        var topscorers = profiles
            .Where(profile => profile.Points > threshold)
            .Select(profile => profile.Player.Id)
            .ToHashSet();

        return new FideDutchAbsoluteCriteria(topscorers, isFinalRound: true, threshold);
    }

    public bool IsTopscorer(FideDutchPlayerProfile profile) => _topscorerIds.Contains(profile.Player.Id);

    /// <summary>
    /// [C1] (Art. 2.1.1) / C.04.1 Art. 2: Zwei Teilnehmer spielen nicht mehr als einmal gegeneinander.
    /// </summary>
    /// <remarks>
    /// Maßgeblich ist, ob tatsächlich am Brett GESPIELT wurde. Eine kampflos gewertete Begegnung
    /// zählt nicht: Nach C.04.2 Art. 3.5 dürfen zwei Teilnehmer, die nicht gegeneinander gespielt
    /// haben, später noch gepaart werden. Das steckt bereits in
    /// <see cref="FideDutchPlayerProfile.PlayedOpponentIds"/>.
    /// </remarks>
    public static bool WouldBeRematch(FideDutchPlayerProfile a, FideDutchPlayerProfile b) =>
        a.PlayedOpponentIds.Contains(b.Player.Id);

    /// <summary>
    /// [C2] (Art. 2.1.2) / C.04.1 Art. 4: Wer bereits ein Freilos hatte ODER ohne zu spielen die
    /// volle Siegpunktzahl bekommen hat, erhält kein weiteres Freilos.
    /// </summary>
    public static bool MayReceiveBye(FideDutchPlayerProfile profile) => !profile.IsByeIneligible;

    /// <summary>
    /// [C3] (Art. 2.1.3): Nicht-Topscorer mit derselben ABSOLUTEN Farbpräferenz treffen nicht
    /// aufeinander.
    /// </summary>
    /// <remarks>
    /// Drei Bedingungen müssen zusammenkommen, damit gesperrt wird — jede einzelne davon wird gern
    /// falsch gelesen:
    /// <list type="number">
    /// <item>BEIDE Präferenzen sind <b>absolut</b>. Zwei starke oder eine starke plus eine absolute
    /// sind erlaubt. (Und „absolut" hat nach Art. 1.7.1 zwei Auslöser — siehe
    /// <see cref="FideDutchPlayerProfile.Preference"/>.)</item>
    /// <item>Es ist <b>dieselbe</b> Farbe. Absolut Weiß gegen absolut Schwarz ist völlig in Ordnung
    /// und wird von Art. 5.2.1 sogar beidseitig erfüllt.</item>
    /// <item>BEIDE sind <b>Nicht-Topscorer</b>. Ist auch nur einer Topscorer, greift [C3] nicht —
    /// und vor der Schlussrunde ist niemand Topscorer (Art. 1.8).</item>
    /// </list>
    /// </remarks>
    public bool IsForbiddenByColour(FideDutchPlayerProfile a, FideDutchPlayerProfile b)
    {
        if (!a.Preference.IsAbsolute || !b.Preference.IsAbsolute)
        {
            return false;
        }

        if (a.Preference.Colour != b.Preference.Colour)
        {
            return false;
        }

        return !IsTopscorer(a) && !IsTopscorer(b);
    }

    /// <summary>
    /// Dürfen die beiden überhaupt gegeneinander gepaart werden? Prüft [C1] und [C3].
    /// ([C2] betrifft das Freilos und wird über <see cref="MayReceiveBye"/> geprüft.)
    /// </summary>
    public bool MayBePaired(FideDutchPlayerProfile a, FideDutchPlayerProfile b) =>
        !WouldBeRematch(a, b) && !IsForbiddenByColour(a, b);

    /// <summary>
    /// Warum ist diese Paarung unzulässig? Liefert die Fundstelle für den Audit-Trail, oder
    /// <c>null</c>, wenn sie zulässig ist (C.04.1 Art. 9: Erklärbarkeit).
    /// </summary>
    public string? ExplainRejection(FideDutchPlayerProfile a, FideDutchPlayerProfile b)
    {
        if (WouldBeRematch(a, b))
        {
            return $"[C1] (C.04.3 Art. 2.1.1): {a.Player.Name} und {b.Player.Name} haben bereits gegeneinander gespielt.";
        }

        if (IsForbiddenByColour(a, b))
        {
            var colour = a.Preference.Colour == ChessColor.White ? "Weiß" : "Schwarz";
            return $"[C3] (C.04.3 Art. 2.1.3): {a.Player.Name} und {b.Player.Name} haben beide die absolute " +
                   $"Farbpräferenz {colour} und sind keine Topscorer.";
        }

        return null;
    }
}
