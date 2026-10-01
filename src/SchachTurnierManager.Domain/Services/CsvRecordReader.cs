using System.Text;

namespace SchachTurnierManager.Domain.Services;

/// <summary>
/// Reads comma/semicolon CSV records before any domain objects are created.
/// Quoted CR, LF and CRLF belong to the field, not to another player.
/// Invalid quote structure rejects the document without returning partial rows.
/// </summary>
public static class CsvRecordReader
{
    public static IReadOnlyList<CsvRecord> Read(string? csv, char separator)
    {
        if (separator is not (',' or ';'))
        {
            throw new ArgumentOutOfRangeException(nameof(separator));
        }

        if (string.IsNullOrEmpty(csv))
        {
            return Array.Empty<CsvRecord>();
        }

        var records = new List<CsvRecord>();
        var fields = new List<string>();
        var field = new StringBuilder();
        var state = FieldState.Start;
        var line = 1;
        var recordLine = 1;
        var hasSyntax = false;
        var start = csv[0] == '\uFEFF' ? 1 : 0;

        void FinishField()
        {
            fields.Add(field.ToString());
            field.Clear();
            state = FieldState.Start;
        }

        void FinishRecord()
        {
            FinishField();
            if (hasSyntax || fields.Any(value => !string.IsNullOrWhiteSpace(value)))
            {
                records.Add(new CsvRecord(recordLine, fields.ToArray()));
            }
            fields.Clear();
            hasSyntax = false;
        }

        ArgumentException Invalid(string detail) => new(
            $"CSV-Zeile {line} (Datensatz ab Zeile {recordLine}): {detail}", nameof(csv));

        for (var i = start; i < csv.Length; i++)
        {
            var ch = csv[i];
            if (state == FieldState.Quoted)
            {
                if (ch == '"')
                {
                    if (i + 1 < csv.Length && csv[i + 1] == '"')
                    {
                        field.Append('"');
                        i++;
                    }
                    else
                    {
                        state = FieldState.Closed;
                    }
                }
                else
                {
                    field.Append(ch);
                    if (ch == '\r')
                    {
                        if (i + 1 < csv.Length && csv[i + 1] == '\n')
                        {
                            field.Append(csv[++i]);
                        }
                        line++;
                    }
                    else if (ch == '\n')
                    {
                        line++;
                    }
                }
                continue;
            }

            if (ch == separator)
            {
                hasSyntax = true;
                FinishField();
            }
            else if (ch is '\r' or '\n')
            {
                FinishRecord();
                if (ch == '\r' && i + 1 < csv.Length && csv[i + 1] == '\n')
                {
                    i++;
                }
                recordLine = ++line;
            }
            else if (state == FieldState.Closed)
            {
                // Tolerate horizontal padding outside a quoted cell, not data.
                if (ch is not (' ' or '\t'))
                {
                    throw Invalid("Unerwarteter Text nach schliessendem Anfuehrungszeichen.");
                }
            }
            else if (ch == '"')
            {
                if (state == FieldState.Unquoted)
                {
                    throw Invalid("Anfuehrungszeichen innerhalb eines ungequoteten Feldes.");
                }
                field.Clear();
                hasSyntax = true;
                state = FieldState.Quoted;
            }
            else
            {
                field.Append(ch);
                if (ch is not (' ' or '\t'))
                {
                    state = FieldState.Unquoted;
                }
            }
        }

        if (state == FieldState.Quoted)
        {
            throw Invalid("Nicht geschlossenes Anfuehrungszeichen.");
        }
        if (hasSyntax || fields.Count > 0 || field.Length > 0)
        {
            FinishRecord();
        }
        return records;
    }

    private enum FieldState { Start, Unquoted, Quoted, Closed }
}

public sealed record CsvRecord(int LineNumber, IReadOnlyList<string> Fields);
