using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Domain.Services;

/// <summary>
/// Ein Paarungs-Bracket nach C.04.3 Art. 1.3 — die Gruppe, die gerade gepaart wird.
/// Regelbelege: docs/FIDE_DUTCH_REFERENCE.md.
/// </summary>
/// <remarks>
/// Art. 1.3.2: Ein Bracket besteht aus den Spielern einer Punktgruppe (den <i>residents</i>) und
/// gegebenenfalls aus Spielern, die im vorigen Bracket ungepaart blieben — den <b>MDPs</b>
/// (moved-down players, Art. 1.4.1).
///
/// Wichtig zum Verständnis: Ein Bracket ist NICHT dasselbe wie eine Punktgruppe. Die Punktgruppe
/// ist eine reine Eigenschaft der Tabelle; das Bracket entsteht erst während der Auslosung und
/// hängt davon ab, wer aus dem Bracket darüber abgefloatet ist.
/// </remarks>
/// <param name="Mdps">
/// Spieler aus dem vorigen Bracket, in der Reihenfolge nach Art. 1.2. Leer bei homogenen Brackets.
/// </param>
/// <param name="Residents">Spieler der eigenen Punktgruppe, in der Reihenfolge nach Art. 1.2.</param>
public sealed record FideDutchBracket(
    IReadOnlyList<FideDutchPlayerProfile> Mdps,
    IReadOnlyList<FideDutchPlayerProfile> Residents)
{
    /// <summary>Alle Spieler des Brackets in der Reihenfolge nach Art. 1.2 (MDPs zuerst — sie haben
    /// mehr Punkte).</summary>
    public IReadOnlyList<FideDutchPlayerProfile> Players { get; } = Mdps.Concat(Residents).ToList();

    /// <summary>
    /// Art. 1.3.3: homogen, wenn alle Spieler dieselbe Punktzahl haben; sonst heterogen.
    /// </summary>
    /// <remarks>
    /// Praktisch heißt das: Sobald MDPs dabei sind, ist das Bracket heterogen — denn MDPs kommen aus
    /// einer höheren Punktgruppe. Der einzige Sonderfall ist ein MDP, der zufällig dieselbe Punktzahl
    /// hat wie die Residents; das kann bei Wertungssystemen mit anderen Punktwerten vorkommen,
    /// deshalb wird hier tatsächlich verglichen statt bloß <c>Mdps.Count</c> geprüft.
    /// </remarks>
    public bool IsHomogeneous => Players.Select(profile => profile.Points).Distinct().Count() <= 1;

    public bool IsHeterogeneous => !IsHomogeneous;

    /// <summary>Art. 3.1: <c>M0</c> — Zahl der MDPs aus dem vorigen Bracket. Kann 0 sein.</summary>
    public int M0 => Mdps.Count;

    /// <summary>
    /// Art. 3.1: die maximal mögliche Paarzahl in diesem Bracket, ohne Rücksicht auf die Kriterien.
    /// </summary>
    /// <remarks>
    /// ACHTUNG — das ist nur die OBERGRENZE aus der Spielerzahl. Die tatsächliche Paarzahl kann
    /// niedriger liegen, weil [C1] oder [C3] Paarungen verbieten (dann greift [C6]) oder weil das
    /// Vollständigkeitsgebot [C4] (Art. 2.2.1) zusätzliche Downfloats erzwingt, damit die folgenden
    /// Brackets überhaupt paarbar bleiben.
    ///
    /// Genau das passiert in Golden-Turnier A Runde 3: Die 1.0-Gruppe hätte hier MaxPairs = 3, darf
    /// aber nur 2 Paare bilden, weil sonst 5 und 7 übrig blieben, die nach [C3] nicht gegeneinander
    /// dürfen. Wer diese Zahl als verbindlich behandelt, paart falsch.
    /// </remarks>
    public int MaxPairsUpperBound => Players.Count / 2;

    /// <summary>Punktzahl der Residents — die Punktgruppe, um die dieses Bracket gebaut ist.</summary>
    public decimal ResidentPoints => Residents.Count > 0 ? Residents[0].Points : 0m;

    /// <summary>
    /// Art. 3.2: Teilt das Bracket in die Untergruppen S1 und S2.
    /// </summary>
    /// <param name="m1">
    /// Zahl der MDPs, die in diesem Bracket gepaart werden sollen (Art. 3.1). Bei homogenen Brackets
    /// bedeutungslos. Ist <paramref name="m1"/> kleiner als <see cref="M0"/>, landen die übrigen MDPs
    /// im <b>Limbo</b> (Art. 3.2.4) — sie können hier nicht gepaart werden und floaten zwangsläufig
    /// erneut ab.
    /// </param>
    public FideDutchSubgroups SplitIntoSubgroups(int m1)
    {
        if (IsHomogeneous)
        {
            // Art. 3.2.2: S1 = die ersten MaxPairs Spieler nach Art. 1.2, S2 = der Rest.
            var pairs = MaxPairsUpperBound;
            return new FideDutchSubgroups(
                S1: Players.Take(pairs).ToList(),
                S2: Players.Skip(pairs).ToList(),
                Limbo: Array.Empty<FideDutchPlayerProfile>());
        }

        // Art. 3.2.3: S1 = die paarbaren MDPs, S2 = ALLE uebrigen Residents.
        // Art. 3.2.4: die nicht in S1 aufgenommenen MDPs bilden den Limbo.
        var clamped = Math.Clamp(m1, 0, M0);
        return new FideDutchSubgroups(
            S1: Mdps.Take(clamped).ToList(),
            S2: Residents.ToList(),
            Limbo: Mdps.Skip(clamped).ToList());
    }

    public override string ToString() =>
        $"{(IsHomogeneous ? "homogen" : "heterogen")} · Residents {ResidentPoints} " +
        $"({string.Join(", ", Residents.Select(p => p.Tpn))})" +
        (M0 > 0 ? $" · MDPs ({string.Join(", ", Mdps.Select(p => p.Tpn))})" : string.Empty);
}

/// <summary>
/// Die Untergruppen eines Brackets nach C.04.3 Art. 3.2.
/// </summary>
/// <param name="S1">Die Spieler, die als erste ihres Paares gesetzt werden.</param>
/// <param name="S2">Die Spieler, gegen die S1 gepaart wird.</param>
/// <param name="Limbo">
/// MDPs, die in diesem Bracket nicht gepaart werden können (Art. 3.2.4). Sie sind gesetzte
/// Downfloater — „bound to double-float".
/// </param>
public sealed record FideDutchSubgroups(
    IReadOnlyList<FideDutchPlayerProfile> S1,
    IReadOnlyList<FideDutchPlayerProfile> S2,
    IReadOnlyList<FideDutchPlayerProfile> Limbo);

/// <summary>
/// Bildet Punktgruppen und Brackets nach C.04.3 Art. 1.3 und 1.9.2.
/// </summary>
public static class FideDutchScoreGroups
{
    /// <summary>
    /// Art. 1.3.1: Eine Punktgruppe umfasst alle Spieler mit derselben Punktzahl.
    /// Art. 1.9.2: Die Auslosung beginnt bei der OBERSTEN Punktgruppe und läuft abwärts.
    /// </summary>
    /// <remarks>
    /// Die Profile kommen bereits nach Art. 1.2 sortiert aus dem
    /// <see cref="FideDutchProfileBuilder"/> (Punkte absteigend, dann TPN aufsteigend); die
    /// Reihenfolge innerhalb der Gruppen bleibt hier erhalten.
    /// </remarks>
    public static IReadOnlyList<IReadOnlyList<FideDutchPlayerProfile>> Build(
        IReadOnlyList<FideDutchPlayerProfile> profiles)
    {
        return profiles
            .GroupBy(profile => profile.Points)
            .OrderByDescending(group => group.Key)
            .Select(group => (IReadOnlyList<FideDutchPlayerProfile>)group
                .OrderBy(profile => profile.Tpn)
                .ToList())
            .ToList();
    }

    /// <summary>
    /// Baut das Bracket für eine Punktgruppe, ergänzt um die Absteiger aus dem vorigen Bracket
    /// (Art. 1.3.2). Beide Listen werden nach Art. 1.2 geordnet.
    /// </summary>
    public static FideDutchBracket ToBracket(
        IReadOnlyList<FideDutchPlayerProfile> scoreGroup,
        IReadOnlyList<FideDutchPlayerProfile> movedDownPlayers)
    {
        return new FideDutchBracket(
            Mdps: movedDownPlayers
                .OrderByDescending(profile => profile.Points)
                .ThenBy(profile => profile.Tpn)
                .ToList(),
            Residents: scoreGroup
                .OrderBy(profile => profile.Tpn)
                .ToList());
    }
}
