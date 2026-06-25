using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Domain.Services;

/// <summary>
/// Reine, zustandslose Modellierung der FIDE-Behandlung ungespielter Runden
/// (Bye, kampfloser Sieg/Niederlage, nicht gepaart) für Buchholz und verwandte
/// gegnerbasierte Wertungen.
///
/// Fachliche Grundlage: FIDE Handbook C.07 „Play-Off and Tie-Break Regulations“
/// (Fassung gültig ab 2024), insbesondere Art. 16.2 (Kategorien ungespielter
/// Runden) und Art. 16.4 (virtueller Gegner für die eigene Wertung).
///
/// Annahme/Scope: Diese Klasse implementiert ausschließlich die *eigene* Wertung
/// nach Art. 16.4 — jede eigene ungespielte Runde zählt wie eine Partie gegen
/// einen virtuellen Gegner, der das Turnier mit der eigenen Endpunktzahl des
/// Spielers abschließt. Die Klasse ist bewusst noch nicht in den
/// <see cref="StandingsCalculator"/> verdrahtet, damit bestehende Wertungs-Baselines
/// unverändert bleiben (Default-Modus = bisheriges Verhalten). Die Integration ist
/// in docs/TIEBREAK_UNPLAYED_ROUNDS.md skizziert.
/// </summary>
public static class UnplayedRoundTiebreak
{
    /// <summary>
    /// True, wenn das Ergebnis aus Sicht des betreffenden Spielers eine ungespielte
    /// Runde ist (kein Brettergebnis): offen, Bye, kampfloser Sieg/Niederlage,
    /// doppelt kampflos. Over-the-board-Ergebnisse (inkl. Armageddon) sind gespielt.
    /// </summary>
    public static bool IsUnplayedRound(GameResultKind kind) =>
        kind is GameResultKind.NotPlayed
            or GameResultKind.Bye
            or GameResultKind.WhiteForfeitWin
            or GameResultKind.BlackForfeitWin
            or GameResultKind.DoubleForfeit;

    /// <summary>
    /// Punktzahl des virtuellen Gegners nach Art. 16.4: identisch mit der eigenen
    /// Endpunktzahl des Spielers.
    /// </summary>
    public static decimal VirtualOpponentScore(decimal playerOwnFinalScore) => playerOwnFinalScore;

    /// <summary>
    /// Zusätzlicher Buchholz-Beitrag aus den eigenen ungespielten Runden des Spielers.
    /// Im Modus <see cref="UnplayedRoundBuchholzMode.IgnoreUnplayedRounds"/> immer 0
    /// (bisheriges Verhalten), im Modus <see cref="UnplayedRoundBuchholzMode.FideVirtualOpponent"/>
    /// die eigene Endpunktzahl je ungespielter Runde.
    /// </summary>
    public static decimal OwnUnplayedBuchholzContribution(
        UnplayedRoundBuchholzMode mode,
        decimal playerOwnFinalScore,
        int unplayedRoundCount)
    {
        if (unplayedRoundCount <= 0)
        {
            return 0m;
        }

        return mode switch
        {
            UnplayedRoundBuchholzMode.FideVirtualOpponent => VirtualOpponentScore(playerOwnFinalScore) * unplayedRoundCount,
            _ => 0m
        };
    }

    /// <summary>
    /// Baut die aufsteigend sortierte Liste der Gegner-Punktzahlen, die Buchholz und
    /// die Cut-/Median-Varianten verwenden. Reale Gegner stammen aus
    /// <paramref name="realOpponentScores"/> (bereits gemäß ForfeitTiebreakPolicy
    /// gefiltert); im FIDE-Modus werden je eigener ungespielter Runde virtuelle
    /// Gegner mit der eigenen Endpunktzahl ergänzt. Aufsteigende Sortierung erlaubt
    /// es den Aufrufern, die niedrigsten Werte für Buchholz-Cut zu streichen.
    /// </summary>
    public static IReadOnlyList<decimal> BuildBuchholzScoreList(
        UnplayedRoundBuchholzMode mode,
        IEnumerable<decimal> realOpponentScores,
        decimal playerOwnFinalScore,
        int unplayedRoundCount)
    {
        var scores = realOpponentScores.ToList();

        if (mode == UnplayedRoundBuchholzMode.FideVirtualOpponent && unplayedRoundCount > 0)
        {
            var virtualScore = VirtualOpponentScore(playerOwnFinalScore);
            for (var i = 0; i < unplayedRoundCount; i++)
            {
                scores.Add(virtualScore);
            }
        }

        scores.Sort();
        return scores;
    }
}
