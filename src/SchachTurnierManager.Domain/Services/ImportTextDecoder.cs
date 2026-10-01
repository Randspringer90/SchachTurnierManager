using System.Text;

namespace SchachTurnierManager.Domain.Services;

/// <summary>
/// Decodes import files without guessing an encoding that contradicts their BOM.
/// Explicit Unicode signatures use strict decoding. Unmarked files retain the
/// existing strict UTF-8 first, Windows-1252 fallback behaviour.
/// </summary>
public static class ImportTextDecoder
{
    static ImportTextDecoder()
    {
        Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);
    }

    public static string Decode(byte[] bytes)
    {
        ArgumentNullException.ThrowIfNull(bytes);
        if (bytes.Length == 0)
        {
            return string.Empty;
        }

        Encoding? declaredEncoding = null;
        var signatureLength = 0;

        // UTF-32 LE shares the first two bytes with UTF-16 LE: longest first.
        if (bytes.Length >= 4 && bytes[0] == 0xFF && bytes[1] == 0xFE && bytes[2] == 0 && bytes[3] == 0)
        {
            declaredEncoding = new UTF32Encoding(false, false, true);
            signatureLength = 4;
        }
        else if (bytes.Length >= 4 && bytes[0] == 0 && bytes[1] == 0 && bytes[2] == 0xFE && bytes[3] == 0xFF)
        {
            declaredEncoding = new UTF32Encoding(true, false, true);
            signatureLength = 4;
        }
        else if (bytes.Length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF)
        {
            declaredEncoding = new UTF8Encoding(false, true);
            signatureLength = 3;
        }
        else if (bytes.Length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE)
        {
            declaredEncoding = new UnicodeEncoding(false, false, true);
            signatureLength = 2;
        }
        else if (bytes.Length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF)
        {
            declaredEncoding = new UnicodeEncoding(true, false, true);
            signatureLength = 2;
        }

        if (declaredEncoding is not null)
        {
            try
            {
                return declaredEncoding.GetString(bytes.AsSpan(signatureLength));
            }
            catch (DecoderFallbackException)
            {
                // Existing API handlers accept ArgumentException. Do not expose
                // decoder messages/inner exceptions containing imported bytes.
                throw new ArgumentException("Die Importdatei enthaelt ungueltige Unicode-Daten fuer ihre Byte-Reihenfolgemarkierung.", nameof(bytes));
            }
        }

        try
        {
            return new UTF8Encoding(false, true).GetString(bytes);
        }
        catch (DecoderFallbackException)
        {
            return Encoding.GetEncoding(1252).GetString(bytes);
        }
    }
}
