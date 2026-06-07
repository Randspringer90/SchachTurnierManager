using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

public sealed class PlayerCsvCodecTests
{
    [Fact]
    public void ImportPlayers_ReadsCommonChessFields()
    {
        const string csv = "Name;Verein;Geburtsjahr;Geschlecht;DWZ;DWZIndex;Elo;TWZ;FIDE-ID;DSB-ID;Titel;Status;Notizen\nAnna Beispiel;Ilmenauer SV;2014;Female;1450;7;1500;1510;123;DE-1;WCM;Active;U12";

        var player = Assert.Single(PlayerCsvCodec.ImportPlayers(csv));

        Assert.Equal("Anna Beispiel", player.Name);
        Assert.Equal("Ilmenauer SV", player.Club);
        Assert.Equal(2014, player.BirthYear);
        Assert.Equal(GenderCategory.Female, player.Gender);
        Assert.Equal(1450, player.Rating.Dwz);
        Assert.Equal(1510, player.Rating.ManualTwz);
    }

    [Fact]
    public void ExportPlayers_EscapesSemicolons()
    {
        var player = new Player { Name = "Name;mit Semikolon", Club = "Verein" };

        var csv = PlayerCsvCodec.ExportPlayers(new[] { player });

        Assert.Contains("\"Name;mit Semikolon\"", csv);
    }
}
