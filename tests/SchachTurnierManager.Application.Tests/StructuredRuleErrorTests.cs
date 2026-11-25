using Xunit;

namespace SchachTurnierManager.Application.Tests;

public sealed class StructuredRuleErrorTests
{
    [Theory]
    [InlineData("")]
    [InlineData(" ")]
    public void EmptyTournamentName_PreservesExceptionContractAndAddsStableCode(string name)
    {
        var store = new InMemoryTournamentStore();
        var service = new TournamentService(store);

        var error = Assert.Throws<ArgumentException>(() => service.CreateTournament(name));

        Assert.Equal("name", error.ParamName);
        Assert.Contains("Turniername darf nicht leer sein.", error.Message);
        Assert.Equal("TOURNAMENT_NAME_REQUIRED", error.Data["stm.error.code"]);
        Assert.Empty(store.List());
    }
}
