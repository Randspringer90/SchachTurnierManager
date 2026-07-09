using Xunit;

namespace SchachTurnierManager.Application.Tests;

public sealed class OperationalGuardTests
{
    [Fact]
    public void Repository_BlocksLocalSecretsAndTransientHandoffFiles()
    {
        var gitignore = File.ReadAllText(FindRepositoryFile(".gitignore"));
        var gitSafety = File.ReadAllText(FindRepositoryFile("scripts", "Test-GitCommitSafety.ps1"));

        Assert.Contains(".secrets/local/", gitignore);
        Assert.Contains("secrets/local/", gitignore);
        Assert.Contains("*.dpapi.txt", gitignore);
        Assert.Contains("NEXT_PROMPT.md", gitignore);
        Assert.Contains("NEXT_PROMPT", gitSafety);
        Assert.Contains("contentPattern", gitSafety);
    }

    [Fact]
    public void SecretScripts_UseWindowsDpapiPatternAndDoNotPrintSecretValuesByDefault()
    {
        var setSecret = File.ReadAllText(FindRepositoryFile("scripts", "Set-LocalSecret.ps1"));
        var getSecret = File.ReadAllText(FindRepositoryFile("scripts", "Get-LocalSecret.ps1"));
        var readiness = File.ReadAllText(FindRepositoryFile("scripts", "Invoke-SecretSafetyReadiness.ps1"));
        var runBundle = File.ReadAllText(FindRepositoryFile("scripts", "New-RunLogBundle.ps1"));

        Assert.Contains("ConvertFrom-SecureString", setSecret);
        Assert.Contains(".secrets/local", setSecret);
        Assert.Contains("ConvertTo-SecureString", getSecret);
        Assert.Contains("AsPlainTextForChildProcessOnly", getSecret);
        Assert.Contains("Trim()", getSecret);
        Assert.Contains("Lokales Secret ist leer oder unlesbar", getSecret);
        Assert.Contains("Windows-DPAPI", getSecret);
        Assert.Contains("DirectorySeparatorChar", getSecret);
        Assert.Contains("AltDirectorySeparatorChar", getSecret);
        Assert.DoesNotContain("[char]'\\'", getSecret);
        Assert.Contains("Set-Content -Encoding UTF8 -NoNewline", setSecret);
        Assert.Contains("Value logged: no", readiness);
        Assert.Contains("DPAPI-Datei ist leer oder nur Whitespace", readiness);
        Assert.Contains("New-SecretRunDirectory", readiness);
        Assert.Contains("RUN_DIR=", readiness);
        Assert.Contains("UPLOAD_ZIP=", readiness);
        Assert.DoesNotContain("$runDirectory = & $bundleScript -RunName $RunName -CreateOnly", readiness);
        Assert.Contains("Write-Output $zipPath", runBundle);
        Assert.DoesNotContain("Write-Host $zipPath", runBundle);
    }

    [Fact]
    public void ReleaseCandidateReadiness_BundlesBuildInstallAndSafetyChecks()
    {
        var releaseScript = File.ReadAllText(FindRepositoryFile("scripts", "Invoke-ReleaseCandidateReadiness.ps1"));

        Assert.Contains("Invoke-ReleaseGate.ps1", releaseScript);
        Assert.Contains("Invoke-SecretSafetyReadiness.ps1", releaseScript);
        Assert.Contains("Publish-DesktopApp.ps1", releaseScript);
        Assert.Contains("Pack-Portable.ps1 -SelfContained", releaseScript);
        Assert.Contains("release-artifacts-manifest.txt", releaseScript);
        Assert.Contains("UPLOAD_ZIP=", releaseScript);
        Assert.Contains("New-ReleaseRunDirectory", releaseScript);
        Assert.Contains("RUN_DIR=", releaseScript);
        Assert.Contains("Resolve-UploadZipPath", releaseScript);
        Assert.Contains("Test-Path -LiteralPath $zipPath", releaseScript);
        Assert.DoesNotContain("UPLOAD_ZIP=$zip\"", releaseScript);
        Assert.DoesNotContain("$runDirectory = & $bundleScript -RunName $RunName -CreateOnly", releaseScript);
    }

    [Fact]
    public void AgentSkills_DocumentReleaseLoggingAndSecurityOwnership()
    {
        Assert.True(File.Exists(FindRepositoryFile(".agents", "skills", "release-operations.md")));
        Assert.True(File.Exists(FindRepositoryFile(".agents", "skills", "logging-observability.md")));
        Assert.True(File.Exists(FindRepositoryFile(".agents", "skills", "repository-security.md")));
        Assert.True(File.Exists(FindRepositoryFile("docs", "architecture", "RELEASE_OPERATIONS.md")));
    }


    [Fact]
    public void ColleagueInstallReadiness_BuildsStandalonePackageWithChecksumsAndDocs()
    {
        var scriptPath = FindRepositoryFile("scripts", "Invoke-ColleagueInstallReadiness.ps1");
        var script = File.ReadAllText(scriptPath);
        var docs = File.ReadAllText(FindRepositoryFile("docs", "release", "COLLEAGUE_INSTALLATION.md"));

        Assert.Contains("Publish-DesktopApp.ps1", script);
        Assert.Contains("Pack-Portable.ps1 -SelfContained", script);
        Assert.Contains("Invoke-InstallerReadiness.ps1", script);
        Assert.Contains("README_START_HIER.txt", script);
        Assert.Contains("KOLLEGENPAKET_MANIFEST.txt", script);
        Assert.Contains("CHECKSUMS_SHA256.txt", script);
        Assert.Contains("KOLLEGENPAKET=", script);
        Assert.Contains("UPLOAD_ZIP=", script);
        Assert.Contains("New-ColleagueRunDirectory", script);
        Assert.Contains("Resolve-UploadZipPath", script);
        Assert.Contains("Test-Path -LiteralPath $expectedUploadZip", script);
        Assert.DoesNotContain("$runDirectory = pwsh.exe", script);
        Assert.DoesNotContain("Select-Object -Last 1).ToString()", script);
        Assert.DoesNotContain("System.Object[]", script);
        Assert.Contains("AllowMissingInnoSetup", script);
        Assert.Contains(".secrets/local/", script);
        Assert.Contains("Keine .NET-Installation", script);
        Assert.Contains("Keine Verbindung zu anderen lokalen Projekten", script);

        Assert.Contains("SchachTurnierManager_Kollegenpaket", docs);
        Assert.Contains("%LocalAppData%\\SchachTurnierManager", docs);
        Assert.Contains(".secrets/local/", docs);
        Assert.Contains("DPAPI", docs);
        Assert.True(File.Exists(FindRepositoryFile(".agents", "skills", "colleague-installation.md")));
    }

    private static string FindRepositoryFile(params string[] relativeParts)
    {
        var current = new DirectoryInfo(AppContext.BaseDirectory);
        while (current is not null)
        {
            var candidate = Path.Combine(new[] { current.FullName }.Concat(relativeParts).ToArray());
            if (File.Exists(candidate))
            {
                return candidate;
            }

            current = current.Parent;
        }

        throw new FileNotFoundException(
            $"Repository file not found: {Path.Combine(relativeParts)}",
            Path.Combine(relativeParts));
    }
}
