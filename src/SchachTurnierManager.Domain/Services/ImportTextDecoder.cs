using System.Text;

namespace SchachTurnierManager.Domain.Services;

/// <summary>
/// STM-IE-002: Dekodiert Import-Dateien aus dem Swiss-Manager-/Chess-Results-Oekosystem, die
/// haeufig nicht in UTF-8 vorliegen (Excel/Windows exportiert traditionell in der lokalen
/// Codepage). Erkennung: strikter UTF-8-Versuch zuerst (inkl. BOM-Behandlung); nur wenn die
/// Bytes keine gueltige UTF-8-Sequenz ergeben, Fallback auf Windows-1252 (deckt Umlaute/
/// franzoesische/spanische Namen weitgehend ab). Windows-1252 kann praktisch jede Bytefolge
/// dekodieren, ist also bewusst der letzte Schritt, nicht der erste.
/// </summary>
public static class ImportTextDecoder
{
    static ImportTextDecoder()
    {
        Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);
    }

    public static string Decode(byte[] bytes)
    {
        if (bytes.Length == 0)
        {
            return string.Empty;
        }

        if (TryDecodeStrictUtf8(bytes, out var utf8Text))
        {
            return utf8Text;
        }

        var windows1252 = Encoding.GetEncoding(1252);
        return windows1252.GetString(bytes);
    }

    private static bool TryDecodeStrictUtf8(byte[] bytes, out string text)
    {
        var strictUtf8 = new UTF8Encoding(encoderShouldEmitUTF8Identifier: false, throwOnInvalidBytes: true);
        try
        {
            var hasBom = bytes.Length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF;
            var span = hasBom ? bytes.AsSpan(3) : bytes.AsSpan();
            text = strictUtf8.GetString(span);
            return true;
        }
        catch (DecoderFallbackException)
        {
            text = string.Empty;
            return false;
        }
    }
}
