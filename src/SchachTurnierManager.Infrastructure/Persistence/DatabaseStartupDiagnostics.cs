namespace SchachTurnierManager.Infrastructure.Persistence;

/// <summary>
/// Ergebnis einer Vorab-Prüfung des SQLite-Datenverzeichnisses. Wird beim Start ausgewertet,
/// damit ein "disk I/O error" nicht als kryptischer Stacktrace endet, sondern als verständlicher
/// Hinweis für die Person am Turniertisch.
/// </summary>
public sealed record DatabaseProbeResult
{
    public required string DatabasePath { get; init; }
    public required string Directory { get; init; }
    public bool DirectoryExists { get; init; }
    public bool DirectoryWritable { get; init; }
    public bool DatabaseFileReadOnly { get; init; }
    public string? Error { get; init; }

    public bool IsHealthy => DirectoryExists && DirectoryWritable && !DatabaseFileReadOnly && Error is null;
}

/// <summary>
/// Lokale, abhängigkeitsfreie Startdiagnose für die SQLite-Datei. Keine Cloud, keine externen Dienste.
/// </summary>
public static class DatabaseStartupDiagnostics
{
    /// <summary>
    /// Prüft, ob das Datenverzeichnis existiert, beschreibbar ist und die DB-Datei nicht schreibgeschützt ist.
    /// Legt das Verzeichnis bei Bedarf an. Wirft nie – Fehler werden im Ergebnis gemeldet.
    /// </summary>
    public static DatabaseProbeResult Probe(string databaseFullPath)
    {
        var directory = Path.GetDirectoryName(databaseFullPath) ?? string.Empty;
        if (string.IsNullOrWhiteSpace(directory))
        {
            directory = Directory.GetCurrentDirectory();
        }

        var directoryExists = false;
        var directoryWritable = false;
        var databaseReadOnly = false;
        string? error = null;

        try
        {
            Directory.CreateDirectory(directory);
            directoryExists = Directory.Exists(directory);

            // Schreibprobe mit einer Wegwerf-Datei – beweist echten Schreibzugriff inkl. WAL-/Journal-Anlage.
            var probePath = Path.Combine(directory, $".stm-write-probe-{Guid.NewGuid():N}.tmp");
            File.WriteAllText(probePath, "ok");
            File.Delete(probePath);
            directoryWritable = true;

            if (File.Exists(databaseFullPath))
            {
                databaseReadOnly = (File.GetAttributes(databaseFullPath) & FileAttributes.ReadOnly) == FileAttributes.ReadOnly;
            }
        }
        catch (Exception ex)
        {
            error = ex.Message;
        }

        return new DatabaseProbeResult
        {
            DatabasePath = databaseFullPath,
            Directory = directory,
            DirectoryExists = directoryExists,
            DirectoryWritable = directoryWritable,
            DatabaseFileReadOnly = databaseReadOnly,
            Error = error
        };
    }

    /// <summary>
    /// Erzeugt eine mehrzeilige, handlungsorientierte Klartextmeldung für einen DB-I/O-Fehler.
    /// </summary>
    public static string BuildFailureReport(string databaseFullPath, DatabaseProbeResult probe, string? exceptionMessage = null)
    {
        var lines = new List<string>
        {
            "SchachTurnierManager: Die lokale Turnierdatenbank konnte nicht initialisiert werden.",
            $"  Datenbankdatei : {databaseFullPath}",
            $"  Verzeichnis    : {probe.Directory}",
            $"  Verzeichnis vorhanden : {(probe.DirectoryExists ? "ja" : "NEIN")}",
            $"  Verzeichnis beschreibbar: {(probe.DirectoryWritable ? "ja" : "NEIN")}",
            $"  DB-Datei schreibgeschützt: {(probe.DatabaseFileReadOnly ? "JA" : "nein")}"
        };

        if (!string.IsNullOrWhiteSpace(exceptionMessage))
        {
            lines.Add($"  Technischer Fehler: {exceptionMessage}");
        }
        else if (!string.IsNullOrWhiteSpace(probe.Error))
        {
            lines.Add($"  Technischer Fehler: {probe.Error}");
        }

        lines.Add("Mögliche Ursachen und Abhilfe:");
        lines.Add("  - Datenverzeichnis liegt in einem Sync-/Cloud-Ordner (OneDrive/Dropbox) -> lokalen Pfad verwenden.");
        lines.Add("  - Antivirus/Backup sperrt die Datei -> Ausnahme setzen oder Tool kurz schließen.");
        lines.Add("  - Eine zweite laufende Instanz hält .sqlite-wal/-shm offen -> nur eine Instanz starten.");
        lines.Add("  - Verzeichnis nicht beschreibbar -> SchachTurnierManager:DataDirectory auf beschreibbaren Pfad setzen.");
        lines.Add("  - Reststände .sqlite-wal / .sqlite-shm löschen, wenn kein Prozess mehr läuft.");

        return string.Join(Environment.NewLine, lines);
    }
}
