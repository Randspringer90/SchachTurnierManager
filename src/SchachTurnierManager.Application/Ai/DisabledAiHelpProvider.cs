namespace SchachTurnierManager.Application.Ai;

public sealed class DisabledAiHelpProvider : IAiHelpProvider
{
    public const string NotConfiguredMessage = "KI-Hilfe nicht konfiguriert";

    private readonly string _provider;

    public DisabledAiHelpProvider(string provider = "disabled")
    {
        _provider = string.IsNullOrWhiteSpace(provider) ? "disabled" : provider.Trim();
    }

    public AiHelpStatus GetStatus()
    {
        return new AiHelpStatus(
            IsConfigured: false,
            Mode: AiHelpMode.Disabled,
            Provider: _provider,
            Message: NotConfiguredMessage,
            Topics: LocalAiHelpKnowledgeBase.Topics);
    }

    public Task<AiHelpResponse> AskAsync(AiHelpRequest request, CancellationToken cancellationToken = default)
    {
        var matches = LocalAiHelpKnowledgeBase.Search(request.Question);
        var response = new AiHelpResponse(
            IsConfigured: false,
            Mode: AiHelpMode.Disabled,
            Provider: _provider,
            Answer: $"{NotConfiguredMessage}. Lokale Hilfethemen bleiben ohne Provider nutzbar.",
            Citations: matches.Select(topic => topic.Source).Distinct(StringComparer.OrdinalIgnoreCase).ToArray(),
            Warnings: [NotConfiguredMessage],
            Topics: matches);

        return Task.FromResult(response);
    }
}
