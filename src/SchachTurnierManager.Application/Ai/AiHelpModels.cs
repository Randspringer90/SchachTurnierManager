namespace SchachTurnierManager.Application.Ai;

public enum AiHelpMode
{
    Disabled = 0,
    LocalDocsOnly = 1,
    OpenAi = 2,
    Anthropic = 3,
    CustomHttp = 4
}

public sealed record AiHelpTopic(
    string Id,
    string Title,
    string Source,
    string Summary,
    string Body,
    IReadOnlyList<string> Tags);

public sealed record AiHelpStatus(
    bool IsConfigured,
    AiHelpMode Mode,
    string Provider,
    string Message,
    IReadOnlyList<AiHelpTopic> Topics);

public sealed record AiHelpRequest(string Question);

public sealed record AiHelpResponse(
    bool IsConfigured,
    AiHelpMode Mode,
    string Provider,
    string Answer,
    IReadOnlyList<string> Citations,
    IReadOnlyList<string> Warnings,
    IReadOnlyList<AiHelpTopic> Topics);
