using System.Text.Json;
using SchachTurnierManager.Application.External;
using SchachTurnierManager.Domain.Models;
using Xunit;

namespace SchachTurnierManager.Application.Tests;

public sealed class ExternalLookupPrivacyTests
{
    private sealed class FailingProvider(bool cancel = false) : IExternalPlayerLookupProvider
    {
        public ExternalPlayerSource Source => ExternalPlayerSource.Fide;
        public ExternalPlayerProviderInfo Info => new(Source, "Synthetic provider", true, true, "Synthetic failure", null);
        public Task<ExternalPlayerLookupResult> LookupByIdAsync(string externalId, CancellationToken cancellationToken = default) => SearchByNameAsync(externalId, cancellationToken);
        public Task<ExternalPlayerLookupResult> SearchByNameAsync(string name, CancellationToken cancellationToken = default) =>
            Task.FromException<ExternalPlayerLookupResult>(cancel ? new OperationCanceledException(cancellationToken) : new IOException("synthetic-private-database-path-marker"));
    }
    [Fact]
    public async Task UnexpectedProviderFailureDoesNotExposeTechnicalExceptionContent()
    {
        var service = new ExternalPlayerLookupService([new FailingProvider()]);
        var result = await service.SearchAllAsync("Synthetic name");
        Assert.DoesNotContain("synthetic-private-database-path-marker", JsonSerializer.Serialize(result));
        Assert.Equal(ExternalPlayerLookupStatus.Unavailable, Assert.Single(result.Sources).Status);
    }
    [Fact]
    public async Task CallerCancellationIsNotReportedAsACompletedSearch()
    {
        using var cancellation = new CancellationTokenSource(); cancellation.Cancel();
        var service = new ExternalPlayerLookupService([new FailingProvider(cancel: true)]);
        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => service.SearchAllAsync("Synthetic name", cancellation.Token));
    }
}
