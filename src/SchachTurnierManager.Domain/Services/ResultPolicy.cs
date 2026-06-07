using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Domain.Services;

public static class ResultPolicy
{
    public static bool CountsAsOpponentForBuchholz(GameResultKind kind, TournamentSettings settings)
    {
        if (ScoringRules.IsOverTheBoard(kind))
        {
            return true;
        }

        if (!ScoringRules.IsForfeit(kind))
        {
            return false;
        }

        return settings.ForfeitTiebreakPolicy is ForfeitTiebreakPolicy.CountForfeitOpponentForBuchholzOnly
            or ForfeitTiebreakPolicy.CountForfeitsAsNormalGames;
    }

    public static bool CountsAsGameForDirectAndSonneborn(GameResultKind kind, TournamentSettings settings)
    {
        if (ScoringRules.IsOverTheBoard(kind))
        {
            return true;
        }

        if (!ScoringRules.IsForfeit(kind))
        {
            return false;
        }

        return settings.ForfeitTiebreakPolicy == ForfeitTiebreakPolicy.CountForfeitsAsNormalGames;
    }

    public static bool CountsForPerformance(GameResultKind kind)
    {
        return ScoringRules.IsOverTheBoard(kind);
    }

    public static string Explain(GameResultKind kind, TournamentSettings settings)
    {
        return kind switch
        {
            GameResultKind.Bye => "Bye/Spielfrei: Punkte zählen, aber kein Gegner für Buchholz, Sonneborn-Berger, Direktvergleich oder Performance.",
            GameResultKind.DoubleForfeit => settings.ForfeitTiebreakPolicy switch
            {
                ForfeitTiebreakPolicy.CountForfeitsAsNormalGames => "Doppelte kampflose Niederlage: zählt gemäß Turniereinstellung als Wertungspartie für direkte Wertungen, aber nicht für Performance.",
                ForfeitTiebreakPolicy.CountForfeitOpponentForBuchholzOnly => "Doppelte kampflose Niederlage: Gegner zählt für Buchholz/Gegnerschnitt, aber nicht für Direktvergleich, Sonneborn-Berger oder Performance.",
                _ => "Doppelte kampflose Niederlage: Punkte zählen, aber die Partie wird aus Gegnerwertungen und Performance herausgenommen."
            },
            GameResultKind.WhiteForfeitWin or GameResultKind.BlackForfeitWin => settings.ForfeitTiebreakPolicy switch
            {
                ForfeitTiebreakPolicy.CountForfeitsAsNormalGames => "Kampfloses Ergebnis: Punkte zählen und die Partie zählt gemäß Turniereinstellung wie eine normale Partie für Buchholz/SB/Direktvergleich, aber nicht für Performance.",
                ForfeitTiebreakPolicy.CountForfeitOpponentForBuchholzOnly => "Kampfloses Ergebnis: Punkte zählen; der Gegner zählt für Buchholz/Gegnerschnitt, aber nicht für Direktvergleich, SB oder Performance.",
                _ => "Kampfloses Ergebnis: Punkte zählen, aber die Partie zählt nicht für Buchholz, SB, Direktvergleich, Gegnerschnitt oder Performance."
            },
            GameResultKind.NotPlayed => "Offenes Ergebnis: Runde ist noch nicht vollständig.",
            _ => "Gespielte Partie: zählt normal für Punkte, Wertungen und Performance."
        };
    }
}
