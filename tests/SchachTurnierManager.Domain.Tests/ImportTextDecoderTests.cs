using System.Text;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

/// <summary>
/// STM-IE-002: UTF-8-zuerst-dann-Windows-1252-Fallback fuer Import-Dateien, die haeufig nicht
/// in UTF-8 vorliegen (Excel/Windows-Export in lokaler Codepage).
/// </summary>
public sealed class ImportTextDecoderTests
{
    [Fact]
    public void Decode_ValidUtf8_ReturnsExactText()
    {
        var text = "Müller, Jürgen (Öhringen)";
        var bytes = Encoding.UTF8.GetBytes(text);

        Assert.Equal(text, ImportTextDecoder.Decode(bytes));
    }

    [Fact]
    public void Decode_Utf8WithBom_StripsBomAndReturnsExactText()
    {
        var text = "Weiß, Björn";
        var bytes = new byte[] { 0xEF, 0xBB, 0xBF }.Concat(Encoding.UTF8.GetBytes(text)).ToArray();

        Assert.Equal(text, ImportTextDecoder.Decode(bytes));
    }

    [Fact]
    public void Decode_Windows1252Bytes_FallsBackAndDecodesUmlauts()
    {
        // "Müller, Jürgen" einzelbyte-kodiert: ü/Ü liegen bei 0xFC/0xDC, identisch in
        // Windows-1252 und im eingebauten Latin1 (Unterschiede zwischen beiden liegen nur im
        // Bereich 0x80-0x9F, den wir hier nicht brauchen) - so kommt Latin1 ohne
        // CodePagesEncodingProvider aus und die Reihenfolge des Testaufbaus ist unabhaengig
        // vom statischen Konstruktor von ImportTextDecoder.
        var text = "Müller, Jürgen";
        var bytes = Encoding.Latin1.GetBytes(text);

        // Gegenprobe: Diese Bytes sind tatsaechlich kein gueltiges UTF-8.
        Assert.Throws<DecoderFallbackException>(() =>
            new UTF8Encoding(false, true).GetString(bytes));

        Assert.Equal(text, ImportTextDecoder.Decode(bytes));
    }

    [Fact]
    public void Decode_EmptyBytes_ReturnsEmptyString()
    {
        Assert.Equal(string.Empty, ImportTextDecoder.Decode(Array.Empty<byte>()));
    }
}
