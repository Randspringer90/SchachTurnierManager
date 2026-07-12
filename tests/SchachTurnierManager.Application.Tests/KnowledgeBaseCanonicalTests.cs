using System;
using System.IO;
using System.Text.Json;
using System.Text.RegularExpressions;
using Xunit;

namespace SchachTurnierManager.Application.Tests;

// STM-INT-001: Die kanonische lokale KI-Hilfe/Wissensbasis liegt im Frontend
// (providerlos/offline). Diese Tests sichern die Kanonik ab, nachdem das tote
// Backend-Modul Application.Ai entfernt wurde.
public sealed class KnowledgeBaseCanonicalTests
{
    private static string RepoRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !File.Exists(Path.Combine(dir.FullName, "SchachTurnierManager.sln")))
        {
            dir = dir.Parent;
        }
        Assert.True(dir is not null, "Repo-Root (SchachTurnierManager.sln) nicht gefunden.");
        return dir!.FullName;
    }

    private static string KnowledgeBasePath() => Path.Combine(
        RepoRoot(), "src", "SchachTurnierManager.WebApp", "src", "knowledge", "localKnowledgeBase.json");

    [Fact]
    public void CanonicalKnowledgeBase_Exists_And_IsValidJson()
    {
        var path = KnowledgeBasePath();
        Assert.True(File.Exists(path), $"Kanonische Wissensbasis fehlt: {path}");

        using var doc = JsonDocument.Parse(File.ReadAllText(path));
        var root = doc.RootElement;

        // Providerloser Offline-Betrieb: providerMode vorhanden, Themen nicht leer.
        Assert.True(root.TryGetProperty("providerMode", out _), "providerMode fehlt.");
        Assert.True(root.TryGetProperty("topics", out var topics), "topics fehlt.");
        Assert.Equal(JsonValueKind.Array, topics.ValueKind);
        Assert.True(topics.GetArrayLength() > 0, "Wissensbasis hat keine Themen.");
    }

    [Fact]
    public void CanonicalKnowledgeBase_ContainsNoSecretsOrOwnerPaths()
    {
        var content = File.ReadAllText(KnowledgeBasePath());

        Assert.DoesNotMatch(new Regex(@"[A-Za-z]:\\Schach", RegexOptions.IgnoreCase), content);
        Assert.DoesNotMatch(
            new Regex(@"gh[pousr]_[0-9A-Za-z]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----"),
            content);
    }

    [Fact]
    public void RemovedBackendAiModule_IsGone()
    {
        // Das tote Application.Ai-Modul darf nicht wieder auftauchen (keine widerspruechliche API).
        var aiDir = Path.Combine(RepoRoot(), "src", "SchachTurnierManager.Application", "Ai");
        Assert.False(Directory.Exists(aiDir), "Entferntes Backend-Modul Application/Ai ist wieder vorhanden.");
    }
}
