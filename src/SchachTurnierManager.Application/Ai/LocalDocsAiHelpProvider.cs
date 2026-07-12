using System.Text;

namespace SchachTurnierManager.Application.Ai;

public sealed class LocalDocsAiHelpProvider : IAiHelpProvider
{
    public AiHelpStatus GetStatus()
    {
        return new AiHelpStatus(
            IsConfigured: true,
            Mode: AiHelpMode.LocalDocsOnly,
            Provider: "local-docs",
            Message: "Lokale Docs-Hilfe aktiv; keine Cloud-Aufrufe.",
            Topics: LocalAiHelpKnowledgeBase.Topics);
    }

    public Task<AiHelpResponse> AskAsync(AiHelpRequest request, CancellationToken cancellationToken = default)
    {
        var matches = LocalAiHelpKnowledgeBase.Search(request.Question);
        var answer = BuildAnswer(matches);
        var response = new AiHelpResponse(
            IsConfigured: true,
            Mode: AiHelpMode.LocalDocsOnly,
            Provider: "local-docs",
            Answer: answer,
            Citations: matches.Select(topic => topic.Source).Distinct(StringComparer.OrdinalIgnoreCase).ToArray(),
            Warnings: ["Docs-only Antwort aus lokalen Runbook-Auszügen; keine Provider- oder Cloud-Anfrage."],
            Topics: matches);

        return Task.FromResult(response);
    }

    private static string BuildAnswer(IReadOnlyList<AiHelpTopic> matches)
    {
        if (matches.Count == 0)
        {
            return "Keine passende lokale Hilfestelle gefunden. Bitte Runbook, Operator-Card oder Collaboration-Doku prüfen.";
        }

        var builder = new StringBuilder();
        builder.AppendLine("Lokale Runbook-Hilfe:");
        foreach (var topic in matches)
        {
            builder.Append("- ");
            builder.Append(topic.Title);
            builder.Append(": ");
            builder.AppendLine(topic.Summary);
        }

        return builder.ToString().TrimEnd();
    }
}
