namespace SchachTurnierManager.Application.Ai;

public interface IAiHelpProvider
{
    AiHelpStatus GetStatus();

    Task<AiHelpResponse> AskAsync(AiHelpRequest request, CancellationToken cancellationToken = default);
}
