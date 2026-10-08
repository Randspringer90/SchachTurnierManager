namespace SchachTurnierManager.Domain.Services;

/// <summary>Kontrollierter Ressourcenabbruch. Eine unbewiesene Teilpaarung wird nie ausgegeben.</summary>
public sealed class FideDutchPairingResourceLimitException : InvalidOperationException
{
    public FideDutchPairingResourceLimitException(string resource, long limit)
        : base($"FIDE-Dutch: Ressourcenlimit {resource} ({limit}) erreicht; Abbruch ohne Teilergebnis.")
    {
        Resource = resource;
        Limit = limit;
    }

    public string Resource { get; }
    public long Limit { get; }
}

/// <summary>Eine Suchinstanz: monotone Arbeit und explizit begrenzte, gleichzeitig gehaltene Daten.</summary>
internal sealed class FideDutchSearchBudget
{
    private readonly FideDutchSearchOptions _options;
    private readonly int _playerCount;
    private readonly TimeSpan _timeout;
    private readonly System.Diagnostics.Stopwatch _clock = System.Diagnostics.Stopwatch.StartNew();
    private long _steps;
    private long _candidates;
    private long _cachedPairs;
    private long _memoStates;
    private long _keyCharacters;
    private long _exchanges;
    private long _exchangeIndices;
    private int _depth;

    public FideDutchSearchBudget(FideDutchSearchOptions options, int playerCount)
    {
        _options = options;
        options.Validate();
        _playerCount = playerCount;
        if (playerCount > options.MaxPlayers)
        {
            throw new FideDutchPairingResourceLimitException(nameof(options.MaxPlayers), options.MaxPlayers);
        }

        _timeout = options.ResolveTimeout(playerCount);
        ThrowIfExceeded();
    }

    public void ThrowIfExceeded()
    {
        Add(ref _steps, 1, _options.MaxSearchSteps, nameof(_options.MaxSearchSteps));
        if (_options.EnforceTimeout && _clock.Elapsed >= _timeout)
        {
            throw new FideDutchPairingTimeoutException(_playerCount, _timeout);
        }
    }

    public void CheckPlayerCount(int playerCount)
    {
        if (playerCount > _options.MaxPlayers)
        {
            throw new FideDutchPairingResourceLimitException(nameof(_options.MaxPlayers), _options.MaxPlayers);
        }
    }

    public void Candidate() => Add(ref _candidates, 1, _options.MaxGeneratedCandidates, nameof(_options.MaxGeneratedCandidates));
    public void CachedPair() => Add(ref _cachedPairs, 1, _options.MaxCachedPairDecisions, nameof(_options.MaxCachedPairDecisions));
    public void MemoState() => Add(ref _memoStates, 1, _options.MaxMemoizedStates, nameof(_options.MaxMemoizedStates));
    public void RetainKeyCharacters(int count) => Add(ref _keyCharacters, count, _options.MaxRetainedKeyCharacters, nameof(_options.MaxRetainedKeyCharacters));
    public void ReleaseKeyCharacters(int count) => _keyCharacters -= count;

    public void RetainExchange(int indexCount)
    {
        // Beide Limits werden VOR Anlage/Kopie eines Deskriptors geprüft.
        Ensure(_exchanges, 1, _options.MaxRetainedExchanges, nameof(_options.MaxRetainedExchanges));
        Ensure(_exchangeIndices, indexCount, _options.MaxRetainedExchangeIndices, nameof(_options.MaxRetainedExchangeIndices));
        _exchanges++;
        _exchangeIndices += indexCount;
    }

    public void ReleaseExchanges(int count, int indexCount)
    {
        _exchanges -= count;
        _exchangeIndices -= indexCount;
    }

    public IDisposable EnterRecursion()
    {
        if (_depth >= _options.MaxRecursionDepth)
        {
            throw new FideDutchPairingResourceLimitException(nameof(_options.MaxRecursionDepth), _options.MaxRecursionDepth);
        }

        _depth++;
        return new DepthLease(this);
    }

    private static void Add(ref long current, long count, long limit, string resource)
    {
        Ensure(current, count, limit, resource);
        current += count;
    }

    private static void Ensure(long current, long count, long limit, string resource)
    {
        if (count < 0 || count > limit - current)
        {
            throw new FideDutchPairingResourceLimitException(resource, limit);
        }
    }

    private sealed class DepthLease(FideDutchSearchBudget owner) : IDisposable
    {
        private bool _disposed;
        public void Dispose()
        {
            if (!_disposed)
            {
                owner._depth--;
                _disposed = true;
            }
        }
    }
}
