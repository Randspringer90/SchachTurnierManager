using SchachTurnierManager.Application.Ai;
using Xunit;

namespace SchachTurnierManager.Application.Tests;

public sealed class AiHelpProviderTests
{
    [Fact]
    public async Task DisabledProvider_ReturnsClearNotConfiguredMessageAndLocalTopics()
    {
        var provider = new DisabledAiHelpProvider("openai");

        var status = provider.GetStatus();
        var response = await provider.AskAsync(new AiHelpRequest("Wie teste ich QR am Handy?"));

        Assert.False(status.IsConfigured);
        Assert.Equal(AiHelpMode.Disabled, status.Mode);
        Assert.Equal("KI-Hilfe nicht konfiguriert", status.Message);
        Assert.Contains(status.Topics, topic => topic.Id == "qr-handy");
        Assert.False(response.IsConfigured);
        Assert.Contains("KI-Hilfe nicht konfiguriert", response.Answer);
        Assert.Contains(response.Topics, topic => topic.Id == "qr-handy");
    }

    [Fact]
    public async Task LocalDocsProvider_AnswersFromRunbookTopicsWithoutCloudProvider()
    {
        var provider = new LocalDocsAiHelpProvider();

        var response = await provider.AskAsync(new AiHelpRequest("Backup Restore Audit nach Runde"));

        Assert.True(response.IsConfigured);
        Assert.Equal(AiHelpMode.LocalDocsOnly, response.Mode);
        Assert.Equal("local-docs", response.Provider);
        Assert.Contains("Lokale Runbook-Hilfe", response.Answer);
        Assert.Contains(response.Topics, topic => topic.Id == "backup-restore");
        Assert.Contains(response.Citations, citation => citation.Contains("BERGFEST_MVP_RUNBOOK", StringComparison.Ordinal));
        Assert.Contains(response.Warnings, warning => warning.Contains("keine Provider- oder Cloud-Anfrage", StringComparison.Ordinal));
    }
}
