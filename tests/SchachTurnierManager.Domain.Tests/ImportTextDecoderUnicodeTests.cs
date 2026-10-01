using System.Text;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

public sealed class ImportTextDecoderUnicodeTests
{
    private static Encoding EncodingFor(string kind) => kind switch
    {
        "utf8" => new UTF8Encoding(true, true),
        "utf16le" => new UnicodeEncoding(false, true, true),
        "utf16be" => new UnicodeEncoding(true, true, true),
        "utf32le" => new UTF32Encoding(false, true, true),
        "utf32be" => new UTF32Encoding(true, true, true),
        _ => throw new ArgumentOutOfRangeException(nameof(kind))
    };

    private static byte[] WithSignature(string kind, string text)
    {
        var encoding = EncodingFor(kind);
        return encoding.GetPreamble().Concat(encoding.GetBytes(text)).ToArray();
    }

    [Theory]
    [InlineData("utf8")]
    [InlineData("utf16le")]
    [InlineData("utf16be")]
    [InlineData("utf32le")]
    [InlineData("utf32be")]
    public void Decode_DeclaredUnicode_PreservesTextAndLineEndings(string kind)
    {
        const string text = "Name,Club\r\nSynthetic \u00DC\u00F1\u4E2D\U0001F600,Example\n";
        Assert.Equal(text, ImportTextDecoder.Decode(WithSignature(kind, text)));
    }

    [Theory]
    [InlineData("utf8")]
    [InlineData("utf16le")]
    [InlineData("utf16be")]
    [InlineData("utf32le")]
    [InlineData("utf32be")]
    public void Decode_SignatureOnly_IsEmpty(string kind)
    {
        Assert.Equal(string.Empty, ImportTextDecoder.Decode(EncodingFor(kind).GetPreamble()));
    }

    [Theory]
    [InlineData("utf8")]
    [InlineData("utf16le")]
    [InlineData("utf16be")]
    [InlineData("utf32le")]
    [InlineData("utf32be")]
    public void Decode_StripsOnlyTheInitialSignature(string kind)
    {
        const string text = "\uFEFFSynthetic\uFEFF";
        Assert.Equal(text, ImportTextDecoder.Decode(WithSignature(kind, text)));
    }

    [Theory]
    [InlineData("utf8")]
    [InlineData("utf16le")]
    [InlineData("utf16be")]
    [InlineData("utf32le")]
    [InlineData("utf32be")]
    public void Decode_SwissManagerImport_ReceivesIntactHeaderAndPlayer(string kind)
    {
        var text = ImportTextDecoder.Decode(WithSignature(kind, "Name,Club\r\nSynthetic \u00DC,Example\r\n"));
        var result = SwissManagerCsvCodec.ImportPlayers(text);
        Assert.Empty(result.Errors);
        var player = Assert.Single(result.Players);
        Assert.Equal("Synthetic \u00DC", player.Name);
        Assert.Equal("Example", player.Club);
    }

    [Theory]
    [InlineData("EFBBBFC328")]
    [InlineData("EFBBBF80")]
    [InlineData("FFFE41")]
    [InlineData("FEFFD800")]
    [InlineData("FFFE00DC")]
    [InlineData("FFFE0000410000")]
    [InlineData("FFFE000000001100")]
    [InlineData("0000FEFF00110000")]
    [InlineData("0000FEFF0000D800")]
    public void Decode_MalformedDeclaredUnicode_DoesNotFallBackOrLeakBytes(string hex)
    {
        var error = Assert.Throws<ArgumentException>(() => ImportTextDecoder.Decode(Convert.FromHexString(hex)));
        Assert.Equal("bytes", error.ParamName);
        Assert.Null(error.InnerException);
        Assert.DoesNotContain(hex, error.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void Decode_UnmarkedUtf8_RemainsCompatible()
    {
        const string text = "Synthetic \u00DC\U0001F600\r\n";
        Assert.Equal(text, ImportTextDecoder.Decode(Encoding.UTF8.GetBytes(text)));
        Assert.Equal(string.Empty, ImportTextDecoder.Decode(Array.Empty<byte>()));
    }

    [Fact]
    public void Decode_UnmarkedWindows1252_RemainsCompatible()
    {
        var bytes = new byte[] { 0x53, 0xFC, 0x20, 0x80, 0x20, 0x96 };
        Assert.Equal("S\u00FC \u20AC \u2013", ImportTextDecoder.Decode(bytes));
    }

    [Fact]
    public void Decode_DoesNotMutateInput()
    {
        var bytes = WithSignature("utf32le", "Synthetic");
        var before = bytes.ToArray();
        Assert.Equal("Synthetic", ImportTextDecoder.Decode(bytes));
        Assert.Equal(before, bytes);
    }

    [Fact]
    public void Decode_Null_IsAnArgumentError()
    {
        Assert.Throws<ArgumentNullException>(() => ImportTextDecoder.Decode(null!));
    }
}
