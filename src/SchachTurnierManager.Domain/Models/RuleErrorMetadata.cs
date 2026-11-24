namespace SchachTurnierManager.Domain.Models;

/// <summary>Stable presentation codes without changing exception types or audit messages.</summary>
public static class RuleErrorMetadata
{
    private const string CodeKey = "stm.error.code";

    public static TException WithErrorCode<TException>(this TException error, string code)
        where TException : Exception
    {
        ArgumentNullException.ThrowIfNull(error);
        if (!IsValidCode(code))
        {
            throw new ArgumentException("Invalid rule error code.", nameof(code));
        }

        error.Data[CodeKey] = code;
        return error;
    }

    public static string? GetErrorCode(Exception error)
    {
        ArgumentNullException.ThrowIfNull(error);
        return error.Data[CodeKey] is string code && IsValidCode(code) ? code : null;
    }

    private static bool IsValidCode(string? code) => code is { Length: > 0 and <= 80 }
        && char.IsAsciiLetterUpper(code[0])
        && code.All(character => char.IsAsciiLetterUpper(character)
            || char.IsAsciiDigit(character) || character == '_');
}
