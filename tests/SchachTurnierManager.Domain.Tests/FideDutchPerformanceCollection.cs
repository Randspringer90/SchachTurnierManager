using Xunit;

namespace SchachTurnierManager.Domain.Tests;

// Wall-clock and allocation assertions measure the production algorithm. Run
// this collection without competing Domain collections; all cases, assertions
// and the production timeout/resource limits remain active and unchanged.
[CollectionDefinition("FIDE Dutch Performance", DisableParallelization = true)]
public sealed class FideDutchPerformanceCollection
{
}
