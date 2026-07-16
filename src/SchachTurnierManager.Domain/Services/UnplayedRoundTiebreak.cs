using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Domain.Services;

/// <summary>
/// Reine, zustandslose Modellierung der FIDE-Behandlung ungespielter Runden
/// (Bye, kampfloser Sieg/Niederlage, nicht gepaart) für Buchholz und verwandte
/// gegnerbasierte Wertungen.
///
/// Fachliche Grundlage: FIDE Handbook C.07 „Play-Off and Tie-Break Regulations“
/// (Fassung gültig ab 1. März 2026), insbesondere Art. 16.2 (Kategorien
/// ungespielter Runden), Art. 16.3 (angepasster Gegnerstand), Art. 16.4
/// (Dummy für die eigene Wertung) und Art. 16.5 (VUR-Streichregel).
///
/// Annahme/Scope: Diese Klasse implementiert ausschließlich die *eigene* Wertung
/// nach Art. 16.4 — jede eigene ungespielte Runde zählt wie eine Partie gegen
/// einen virtuellen Gegner ("Dummy"), der das Turnier mit der eigenen Endpunktzahl
/// des Spielers abschließt. Seit STM-FACH-001 ist das Modell opt-in über
/// <see cref="TournamentSettings.UnplayedRoundBuchholzMode"/> in
/// <see cref="StandingsCalculator"/> verdrahtet (Buchholz/Cut-1/Cut-2/Median);
/// der Default-Modus hält bestehende Wertungs-Baselines unverändert.
///
/// Der Scope bleibt bewusst auf Buchholz/Cut/Median im Schweizer System begrenzt.
/// Sonneborn-Berger, Direktvergleich und Performance werden nicht verändert.
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
    /// Dummy-Punktzahl nach FIDE C.07 (03/2026) Art. 16.4 inklusive Obergrenze:
    /// die eigene Endpunktzahl, gedeckelt durch <paramref name="cap"/>
    /// (Art. 16.4.1: Punktzahl des vorgesehenen Gegners bei kampflosen Ergebnissen;
    /// Art. 16.4.2: Remispunkte × Rundenzahl bei Byes und übrigen ungespielten Runden).
    /// </summary>
    public static decimal DummyOpponentScore(decimal playerOwnFinalScore, decimal cap) =>
        Math.Min(VirtualOpponentScore(playerOwnFinalScore), cap);

    /// <summary>
    /// Baut die eine kanonische, aufsteigend sortierte Beitragsliste für Buchholz
    /// und alle davon abgeleiteten Cut-/Median-Werte. Im Defaultmodus werden
    /// virtuelle Beiträge verworfen.
    /// </summary>
    public static IReadOnlyList<BuchholzScoreEntry> BuildCanonicalScoreList(
        UnplayedRoundBuchholzMode mode,
        IEnumerable<BuchholzScoreEntry> realOpponentScores,
        IEnumerable<BuchholzScoreEntry> virtualOpponentScores)
    {
        var scores = realOpponentScores.ToList();

        if (mode == UnplayedRoundBuchholzMode.FideVirtualOpponent)
        {
            scores.AddRange(virtualOpponentScores);
        }

        return scores.OrderBy(entry => entry.Score).ToList();
    }

    /// <summary>
    /// Wendet Cut-/Median-Streicher auf die kanonische Liste an. Im FIDE-Modus
    /// wird bei jedem niedrigsten Streicher zuerst der niedrigste Beitrag aus einer
    /// freiwillig ungespielten Runde (VUR) entfernt (Art. 16.5); weitere höchste
    /// Streicher bleiben normale Maximalwert-Streicher. Das bisherige Verhalten bei
    /// zu kurzen Listen bleibt aus Rückwärtskompatibilitätsgründen unverändert.
    /// </summary>
    public static decimal SumAfterDropping(
        UnplayedRoundBuchholzMode mode,
        IReadOnlyList<BuchholzScoreEntry> orderedScores,
        int lowest,
        int highest)
    {
        if (orderedScores.Count <= lowest + highest)
        {
            return orderedScores.Sum(entry => entry.Score);
        }

        var remaining = orderedScores.ToList();
        for (var index = 0; index < lowest; index++)
        {
            var removeAt = 0;
            if (mode == UnplayedRoundBuchholzMode.FideVirtualOpponent)
            {
                var lowestVurIndex = remaining.FindIndex(entry => entry.IsVoluntaryUnplayedRound);
                if (lowestVurIndex >= 0)
                {
                    removeAt = lowestVurIndex;
                }
            }

            remaining.RemoveAt(removeAt);
        }

        for (var index = 0; index < highest; index++)
        {
            remaining.RemoveAt(remaining.Count - 1);
        }

        return remaining.Sum(entry => entry.Score);
    }

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

    /// <summary>
    /// Variante mit bereits berechneten (z. B. nach Art. 16.4.1/16.4.2 gedeckelten)
    /// Dummy-Punktzahlen je eigener ungespielter Runde. Außerhalb des FIDE-Modus
    /// werden die virtuellen Werte ignoriert (Default-Verhalten bleibt unverändert).
    /// </summary>
    public static IReadOnlyList<decimal> BuildBuchholzScoreList(
        UnplayedRoundBuchholzMode mode,
        IEnumerable<decimal> realOpponentScores,
        IEnumerable<decimal> virtualOpponentScores)
    {
        var scores = realOpponentScores.ToList();

        if (mode == UnplayedRoundBuchholzMode.FideVirtualOpponent)
        {
            scores.AddRange(virtualOpponentScores);
        }

        scores.Sort();
        return scores;
    }
}

/// <summary>
/// Ein kanonischer Buchholz-Beitrag. Die VUR-Markierung bleibt bis zur Anwendung
/// der Cut-/Median-Modifikatoren erhalten und verhindert, dass Art. 16.5 durch eine
/// vorzeitige Reduktion auf reine Dezimalwerte verloren geht.
/// </summary>
public sealed record BuchholzScoreEntry(decimal Score, bool IsVoluntaryUnplayedRound = false);
