using System;
using System.Collections.Concurrent;
using System.Globalization;
using System.IO;
using System.Linq;
using Microsoft.Extensions.Logging;

namespace SchachTurnierManager.WebApi.Logging;

/// <summary>
/// Minimaler lokaler File-Logger ohne externe Abhaengigkeiten.
/// Ziel: installierte/portable Versionen schreiben nachvollziehbare Betriebslogs,
/// ohne Querystrings oder typische Secret-Werte ungefiltert abzulegen.
/// </summary>
public sealed class BoundedFileLoggerProvider : ILoggerProvider
{
    private readonly ConcurrentDictionary<string, BoundedFileLogger> loggers = new(StringComparer.Ordinal);
    private readonly object syncRoot = new();
    private readonly string directory;
    private readonly string filePrefix;
    private readonly int retainedFileCount;
    private readonly long maxFileSizeBytes;

    public BoundedFileLoggerProvider(string directory, string filePrefix, int retainedFileCount = 14, long maxFileSizeBytes = 5 * 1024 * 1024)
    {
        if (string.IsNullOrWhiteSpace(directory))
        {
            throw new ArgumentException("Log directory must not be empty.", nameof(directory));
        }

        this.directory = directory;
        this.filePrefix = string.IsNullOrWhiteSpace(filePrefix) ? "schachturniermanager" : filePrefix;
        this.retainedFileCount = Math.Max(1, retainedFileCount);
        this.maxFileSizeBytes = Math.Max(128 * 1024, maxFileSizeBytes);
        Directory.CreateDirectory(this.directory);
    }

    public ILogger CreateLogger(string categoryName)
    {
        return loggers.GetOrAdd(categoryName, category => new BoundedFileLogger(category, this));
    }

    public void Dispose()
    {
        loggers.Clear();
    }

    private void Write(LogLevel logLevel, string categoryName, EventId eventId, string message, Exception? exception)
    {
        if (string.IsNullOrWhiteSpace(message) && exception is null)
        {
            return;
        }

        var timestamp = DateTimeOffset.Now.ToString("yyyy-MM-dd HH:mm:ss.fff zzz", CultureInfo.InvariantCulture);
        var safeMessage = RedactSensitiveContent(message);
        var safeException = exception is null ? string.Empty : Environment.NewLine + RedactSensitiveContent(exception.ToString());
        var line = $"{timestamp} [{logLevel}] {categoryName} ({eventId.Id}) {safeMessage}{safeException}{Environment.NewLine}";

        lock (syncRoot)
        {
            Directory.CreateDirectory(directory);
            var path = ResolveCurrentLogFilePath();
            File.AppendAllText(path, line);
            PruneOldLogs();
        }
    }

    private string ResolveCurrentLogFilePath()
    {
        var date = DateTimeOffset.Now.ToString("yyyyMMdd", CultureInfo.InvariantCulture);
        var basePath = Path.Combine(directory, $"{filePrefix}-{date}.log");
        if (!File.Exists(basePath) || new FileInfo(basePath).Length < maxFileSizeBytes)
        {
            return basePath;
        }

        for (var index = 1; index < 1000; index++)
        {
            var candidate = Path.Combine(directory, $"{filePrefix}-{date}-{index:D3}.log");
            if (!File.Exists(candidate) || new FileInfo(candidate).Length < maxFileSizeBytes)
            {
                return candidate;
            }
        }

        return basePath;
    }

    private void PruneOldLogs()
    {
        var files = Directory.GetFiles(directory, $"{filePrefix}-*.log")
            .Select(path => new FileInfo(path))
            .OrderByDescending(file => file.LastWriteTimeUtc)
            .ToArray();

        foreach (var file in files.Skip(retainedFileCount))
        {
            try
            {
                file.Delete();
            }
            catch (IOException)
            {
                // Wenn Windows die Datei gerade haelt, bleibt sie bis zum naechsten Schreibvorgang liegen.
            }
            catch (UnauthorizedAccessException)
            {
                // Keine harte App-Stoerung nur wegen Log-Rotation.
            }
        }
    }

    private static string RedactSensitiveContent(string value)
    {
        if (string.IsNullOrEmpty(value))
        {
            return value;
        }

        var safe = value;
        foreach (var marker in new[] { "password", "passwd", "pwd", "secret", "token", "api_key", "apikey", "access_token", "refresh_token" })
        {
            safe = RedactKeyValue(safe, marker + "=");
            safe = RedactKeyValue(safe, marker + ":");
        }

        return safe;
    }

    private static string RedactKeyValue(string value, string marker)
    {
        var searchIndex = 0;
        while (true)
        {
            var index = value.IndexOf(marker, searchIndex, StringComparison.OrdinalIgnoreCase);
            if (index < 0)
            {
                return value;
            }

            var valueStart = index + marker.Length;
            var valueEnd = valueStart;
            while (valueEnd < value.Length && !char.IsWhiteSpace(value[valueEnd]) && value[valueEnd] is not ';' and not '&' and not ',')
            {
                valueEnd++;
            }

            value = value[..valueStart] + "***" + value[valueEnd..];
            searchIndex = valueStart + 3;
        }
    }

    private sealed class BoundedFileLogger : ILogger
    {
        private readonly string categoryName;
        private readonly BoundedFileLoggerProvider provider;

        public BoundedFileLogger(string categoryName, BoundedFileLoggerProvider provider)
        {
            this.categoryName = categoryName;
            this.provider = provider;
        }

        public IDisposable? BeginScope<TState>(TState state) where TState : notnull => NullScope.Instance;

        public bool IsEnabled(LogLevel logLevel) => logLevel != LogLevel.None;

        public void Log<TState>(LogLevel logLevel, EventId eventId, TState state, Exception? exception, Func<TState, Exception?, string> formatter)
        {
            if (!IsEnabled(logLevel))
            {
                return;
            }

            if (formatter is null)
            {
                throw new ArgumentNullException(nameof(formatter));
            }

            provider.Write(logLevel, categoryName, eventId, formatter(state, exception), exception);
        }
    }

    private sealed class NullScope : IDisposable
    {
        public static readonly NullScope Instance = new();

        public void Dispose()
        {
        }
    }
}
