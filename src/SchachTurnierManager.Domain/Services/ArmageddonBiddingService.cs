using System.Security.Cryptography;
using System.Text;
using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Domain.Services;

public sealed class ArmageddonBiddingService
{
    public string CreateCommitment(string playerSecret, TimeSpan bidTime, string salt)
    {
        var payload = $"{playerSecret}|{bidTime.TotalMilliseconds}|{salt}";
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(payload));
        return Convert.ToHexString(bytes);
    }

    public ArmageddonDecision Decide(TimeSpan whiteCandidateBid, TimeSpan blackCandidateBid, TieBidPolicy tiePolicy = TieBidPolicy.Rebid)
    {
        if (whiteCandidateBid < TimeSpan.Zero || blackCandidateBid < TimeSpan.Zero)
        {
            throw new ArgumentOutOfRangeException(nameof(whiteCandidateBid), "Gebotszeiten dürfen nicht negativ sein.");
        }

        if (whiteCandidateBid == blackCandidateBid)
        {
            return new ArmageddonDecision(null, ChessColor.None, whiteCandidateBid, tiePolicy, "Gleiches Gebot; Tie-Policy anwenden.");
        }

        var blackPlayerIsOriginalWhiteCandidate = whiteCandidateBid < blackCandidateBid;
        return blackPlayerIsOriginalWhiteCandidate
            ? new ArmageddonDecision(ArmageddonBidWinner.WhiteCandidate, ChessColor.Black, whiteCandidateBid, tiePolicy, "Niedrigeres Gebot erhält Schwarz und Remisodds.")
            : new ArmageddonDecision(ArmageddonBidWinner.BlackCandidate, ChessColor.Black, blackCandidateBid, tiePolicy, "Niedrigeres Gebot erhält Schwarz und Remisodds.");
    }
}

public enum TieBidPolicy
{
    Rebid = 0,
    RandomDraw = 1,
    LowerStartingRankChooses = 2
}

public enum ArmageddonBidWinner
{
    WhiteCandidate = 1,
    BlackCandidate = 2
}

public sealed record ArmageddonDecision(
    ArmageddonBidWinner? LowerBidder,
    ChessColor AssignedColor,
    TimeSpan AcceptedTime,
    TieBidPolicy TiePolicy,
    string Message);
