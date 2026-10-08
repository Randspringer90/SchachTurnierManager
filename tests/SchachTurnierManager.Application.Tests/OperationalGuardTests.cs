using Xunit;

namespace SchachTurnierManager.Application.Tests;

public sealed class OperationalGuardTests
{
    [Fact]
    public void PowerShellScripts_DoNotAssignToAutomaticVariables()
    {
        // STM-INFRA-004: $input ist in PowerShell die automatische Variable fuer den
        // Pipeline-/stdin-Enumerator. Eine eigene Zuweisung darauf laesst ein Skript bei
        // offenem stdin blockieren - reproduziert 2026-07-17: Invoke-SafePullRequestReview.ps1
        // lief mit geschlossenem stdin in 7 s durch, mit offenem stdin gar nicht.
        // Dieser Test deckt die ganze Klasse ab, nicht nur den einen Fundort.
        var scriptsRoot = FindRepositoryDirectory("scripts");
        var reserved = new[] { "input", "args", "error", "host", "home", "pwd", "matches", "psitem", "_" };
        var offenders = new List<string>();

        foreach (var script in Directory.EnumerateFiles(scriptsRoot, "*.ps1", SearchOption.AllDirectories))
        {
            if (script.Contains($"{Path.DirectorySeparatorChar}archive{Path.DirectorySeparatorChar}"))
            {
                continue;
            }

            var lines = File.ReadAllLines(script);
            for (var i = 0; i < lines.Length; i++)
            {
                foreach (var name in reserved)
                {
                    // Zuweisung der Form "$name =" am Zeilenanfang (ohne Vergleiche wie -eq).
                    var pattern = $@"^\s*\${name}\s*=[^=]";
                    if (System.Text.RegularExpressions.Regex.IsMatch(
                            lines[i], pattern, System.Text.RegularExpressions.RegexOptions.IgnoreCase))
                    {
                        offenders.Add($"{Path.GetFileName(script)}:{i + 1} weist der automatischen Variablen ${name} zu");
                    }
                }
            }
        }

        Assert.Empty(offenders);
    }

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
        Assert.Contains("publicationPattern", gitSafety);
        Assert.Contains("png|jpe?g|gif|webp|bmp|tiff?", gitSafety);
        Assert.Contains("external-publication-pattern", gitSafety);
    }

    [Fact]
    public void CodexAdapter_ExemptsOnlyTheTwoTrackedAdapterFiles()
    {
        var gitignore = File.ReadAllText(FindRepositoryFile(".gitignore"));
        var gitSafety = File.ReadAllText(FindRepositoryFile("scripts", "Test-GitCommitSafety.ps1"));

        // The directory stays ignored/blocked; a real local Codex config
        // (config.toml, auth material, session state) must never be committable.
        Assert.Contains(".codex/*", gitignore);
        Assert.Contains("!.codex/README.md", gitignore);
        Assert.Contains("!.codex/config.example.toml", gitignore);
        Assert.DoesNotContain("!.codex/config.toml", gitignore);

        // The safety gate exemption must be an explicit file allowlist, never a
        // prefix match that would let new files slip through.
        Assert.Contains("Test-IsAllowedTrackedCodexAdapter", gitSafety);
        Assert.Contains("'.codex/README.md', '.codex/config.example.toml'", gitSafety);

        // Publish the example as documentation; real .codex state stays local.
        // These are supported CLI settings, rather than fictitious Git permissions.
        var exampleConfig = File.ReadAllText(FindRepositoryFile("docs", "architecture", "codex-config.example.toml"));
        Assert.Contains("approval_policy = \"on-request\"", exampleConfig);
        Assert.Contains("sandbox_mode = \"workspace-write\"", exampleConfig);
        Assert.Contains("network_access = false", exampleConfig);
        Assert.DoesNotContain("allow_no_verify =", exampleConfig);
        Assert.DoesNotContain("allow_force_push =", exampleConfig);
        var agentRules = File.ReadAllText(FindRepositoryFile("AGENTS.md"));
        Assert.Contains("Kein Force-Push/History-Rewrite", agentRules);
        Assert.Contains("scripts/Commit-If-Green.ps1", agentRules);
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
    public void RunLogBundle_BaseDirectoryFallsBackToTempWhenNoDDriveExists()
    {
        // STM-REL-001: Die D:\Temp-Konvention gilt nur auf Rechnern mit Datenpartition.
        // Auf Maschinen ohne D: muss der Default auf %TEMP% ausweichen, statt auf einen
        // nicht existierenden Pfad zu zeigen. Der Default wird hier real ausgewertet.
        var runBundle = File.ReadAllText(FindRepositoryFile("scripts", "New-RunLogBundle.ps1"));

        Assert.Contains("Test-Path -LiteralPath 'D:\\'", runBundle);
        Assert.Contains("Join-Path $env:TEMP 'SchachTurnierManager'", runBundle);
        // Der Default darf kein hart verdrahtetes D:\Temp mehr sein.
        Assert.DoesNotContain("[string]$BaseDirectory = 'D:\\Temp',", runBundle);
    }

    [Fact]
    public void ReleaseGate_RunsDependencySupplyChainSafetyBeforeRestore()
    {
        var releaseGate = File.ReadAllText(FindRepositoryFile("scripts", "Invoke-ReleaseGate.ps1"));
        var dependencyGate = File.ReadAllText(FindRepositoryFile("scripts", "Test-DependencySupplyChainSafety.ps1"));

        var dependencyGateIndex = releaseGate.IndexOf("Test-DependencySupplyChainSafety.ps1", StringComparison.Ordinal);
        var restoreIndex = releaseGate.IndexOf("dotnet restore", StringComparison.Ordinal);

        Assert.True(dependencyGateIndex >= 0, "Dependency-Safety-Gate fehlt im ReleaseGate.");
        Assert.True(restoreIndex > dependencyGateIndex, "Dependency-Safety-Gate muss vor dotnet restore laufen.");
        Assert.Contains("Directory.Packages.props", dependencyGate);
        Assert.Contains("package-lock.json", dependencyGate);
        Assert.Contains("registry\\.npmjs\\.org", dependencyGate);
        Assert.Contains("allowedLicenses", dependencyGate);
        Assert.Contains("reviewedLifecyclePackages", dependencyGate);
        Assert.Contains("Offline/read-only", dependencyGate);
        Assert.DoesNotContain("npm audit", dependencyGate, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("dotnet restore", dependencyGate, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void ReleaseCandidateReadiness_BundlesBuildInstallAndSafetyChecks()
    {
        var releaseScript = File.ReadAllText(FindRepositoryFile("scripts", "Invoke-ReleaseCandidateReadiness.ps1"));

        Assert.Contains("Invoke-ReleaseGate.ps1", releaseScript);
        Assert.Contains("Invoke-SecretSafetyReadiness.ps1", releaseScript);
        Assert.Contains("Publish-DesktopApp.ps1", releaseScript);
        Assert.Contains("Pack-Portable.ps1 -SelfContained", releaseScript);
        Assert.Contains("Invoke-ReleaseTrustReadiness.ps1", releaseScript);
        Assert.Contains("RequireSignedArtifacts", releaseScript);
        Assert.Contains("SignArtifacts", releaseScript);
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
    public void ReleaseTrustScripts_AreManualFailClosedAndKeepPrivateKeysOutOfRepository()
    {
        var signScript = File.ReadAllText(FindRepositoryFile("scripts", "Sign-ReleaseArtifacts.ps1"));
        var newManifest = File.ReadAllText(FindRepositoryFile("scripts", "New-ReleaseUpdateManifest.ps1"));
        var testManifest = File.ReadAllText(FindRepositoryFile("scripts", "Test-ReleaseUpdateManifest.ps1"));
        var trustReadiness = File.ReadAllText(FindRepositoryFile("scripts", "Invoke-ReleaseTrustReadiness.ps1"));
        var trustContract = File.ReadAllText(FindRepositoryFile("scripts", "Test-ReleaseTrustReadiness.ps1"));
        var validationHelper = File.ReadAllText(FindRepositoryFile("scripts", "lib", "ReleaseTrustValidation.ps1"));
        var releaseGate = File.ReadAllText(FindRepositoryFile("scripts", "Invoke-ReleaseGate.ps1"));
        var docs = File.ReadAllText(FindRepositoryFile("docs", "release", "SIGNING_AND_UPDATES.md"));
        var schema = File.ReadAllText(FindRepositoryFile("docs", "release", "release-update-manifest.schema.json"));

        Assert.Contains("ApproveSigning", signScript);
        Assert.Contains("signtool.exe", signScript, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("/sha1", signScript);
        Assert.Contains("/fd", signScript);
        Assert.Contains("SHA256", signScript);
        Assert.Contains("Get-AuthenticodeSignature", signScript);
        Assert.Contains("Assert-StmReleaseSignature", signScript);
        Assert.Contains("1.3.6.1.5.5.7.3.3", validationHelper);
        Assert.Contains("-Boundary $outputRoot", signScript);
        Assert.Contains("Release path leaves its approved boundary.", validationHelper);
        Assert.Contains("ReparsePoint", validationHelper);
        Assert.DoesNotContain(".pfx", signScript, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("password", signScript, StringComparison.OrdinalIgnoreCase);

        Assert.Contains("manual-only", newManifest);
        Assert.Contains("Get-FileHash", newManifest);
        Assert.Contains("Get-AuthenticodeSignature", newManifest);
        Assert.Contains("Path-Traversal", testManifest);
        Assert.Contains("RequireSignedArtifacts", testManifest);
        Assert.Contains("Get-StmCheckedAuthenticodeSignature", testManifest);
        Assert.Contains("Get-AuthenticodeSignature", validationHelper);
        Assert.Contains("ExpectedSignerThumbprint", testManifest);
        Assert.Contains("Assert-StmReleaseArchivePayload", testManifest);
        Assert.Contains("Get-StmBoundedStreamSha256", validationHelper);
        Assert.Contains("Test-ReleaseSigningValidation.ps1", trustContract);
        Assert.Contains("SHA256 stimmt nicht", testManifest);
        Assert.DoesNotContain("Invoke-WebRequest", newManifest);
        Assert.DoesNotContain("Invoke-RestMethod", newManifest);
        Assert.DoesNotContain("Invoke-WebRequest", testManifest);
        Assert.DoesNotContain("Invoke-RestMethod", testManifest);

        Assert.Contains("RequireCompleteSet", trustReadiness);
        Assert.Contains("Assert-ValidAuthenticode", trustReadiness);
        Assert.Contains("RELEASE_TRUST_READINESS=OK", trustReadiness);
        Assert.Contains("RELEASE_TRUST_READINESS=OK", trustContract);
        Assert.Contains("Path-Traversal", trustContract);
        Assert.Contains("Invoke-ReleaseTrustReadiness.ps1", releaseGate);
        Assert.Contains("RequireCompleteReleaseSet", releaseGate);
        Assert.Contains("RequireCompleteReleaseSet ist mit SkipPack nicht zulaessig", releaseGate);

        Assert.Contains("\"updateMode\"", schema);
        Assert.Contains("\"manual-only\"", schema);
        Assert.Contains("keine automatischen Downloads", docs, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("Private Keys", docs);
        Assert.Contains("kein automatischer Installer-Start", docs, StringComparison.OrdinalIgnoreCase);
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



    [Fact]
    public void ColleagueFreshRunTest_VerifiesPackageChecksumDesktopStartAndIsolatedData()
    {
        var script = File.ReadAllText(FindRepositoryFile("scripts", "Invoke-ColleagueFreshRunTest.ps1"));
        var docs = File.ReadAllText(FindRepositoryFile("docs", "release", "COLLEAGUE_FRESH_RUN_TEST.md"));

        Assert.Contains("SchachTurnierManager_Kollegenpaket_", script);
        Assert.Contains("CHECKSUMS_SHA256.txt", script);
        Assert.Contains("README_START_HIER.txt", script);
        Assert.Contains("KOLLEGENPAKET_MANIFEST.txt", script);
        Assert.Contains("SchachTurnierManager_Desktop_*.zip", script);
        Assert.Contains("SchachTurnierManager.WebApi.exe", script);
        Assert.Contains("wwwroot", script);
        Assert.Contains("Get-AvailableLoopbackPort", script);
        Assert.Contains("ASPNETCORE_URLS", script);
        Assert.Contains("SchachTurnierManager__DataDirectory", script);
        Assert.Contains("/api/health", script);
        Assert.Contains("/api/tournaments", script);
        Assert.Contains("FRESH_RUN=OK", script);
        Assert.Contains("UPLOAD_ZIP=", script);
        Assert.DoesNotContain("System.Object[]", script);

        Assert.Contains("frischen Ordner", docs);
        Assert.Contains("isolierten Testdatenordner", docs);
        Assert.Contains("DPAPI-Secrets", docs);
        Assert.True(File.Exists(FindRepositoryFile(".agents", "skills", "colleague-fresh-run.md")));
    }

    [Fact]
    public void ClickInstallReadiness_VerifiesInstallUninstallShortcutsAndFreshSmoke()
    {
        var installScript = File.ReadAllText(FindRepositoryFile("scripts", "Install-ColleagueDesktopApp.ps1"));
        var uninstallScript = File.ReadAllText(FindRepositoryFile("scripts", "Uninstall-ColleagueDesktopApp.ps1"));
        var readiness = File.ReadAllText(FindRepositoryFile("scripts", "Invoke-ClickInstallReadiness.ps1"));
        var colleaguePackageScript = File.ReadAllText(FindRepositoryFile("scripts", "Invoke-ColleagueInstallReadiness.ps1"));
        var docs = File.ReadAllText(FindRepositoryFile("docs", "release", "CLICK_INSTALLER.md"));

        Assert.Contains("SchachTurnierManager_Desktop_*.zip", installScript);
        Assert.Contains("Programs\\SchachTurnierManager", installScript);
        Assert.Contains("WScript.Shell", installScript);
        Assert.Contains("INSTALLATION_MANIFEST.txt", installScript);
        Assert.Contains("ShortcutDirectory", installScript);
        Assert.Contains("RemoveUserData", uninstallScript);

        Assert.Contains("Invoke-ColleagueInstallReadiness.ps1", readiness);
        Assert.Contains("Install-SchachTurnierManager.cmd", readiness);
        Assert.Contains("Uninstall-SchachTurnierManager.cmd", readiness);
        Assert.Contains("Test-Checksums", readiness);
        Assert.Contains("Test-InstalledAppSmoke", readiness);
        Assert.Contains("CLICK_INSTALL=OK", readiness);
        Assert.Contains("UPLOAD_ZIP=", readiness);
        Assert.DoesNotContain("System.Object[]", readiness);

        Assert.Contains("Install-ColleagueDesktopApp.ps1", colleaguePackageScript);
        Assert.Contains("Install-SchachTurnierManager.cmd", colleaguePackageScript);
        Assert.Contains("Uninstall-SchachTurnierManager.cmd", colleaguePackageScript);
        Assert.Contains("ClickInstallFiles", colleaguePackageScript);

        Assert.Contains("Doppelklick", docs);
        Assert.Contains("%LocalAppData%\\Programs\\SchachTurnierManager", docs);
        Assert.Contains("Startmenue-Shortcut", docs);
        Assert.Contains("DPAPI-Secrets", docs);
        Assert.True(File.Exists(FindRepositoryFile(".agents", "skills", "click-installation.md")));
    }


    [Fact]
    public void RuntimeLogging_WritesToBoundedProjectLogsWithoutSecretsOrQuerystrings()
    {
        var gitignore = File.ReadAllText(FindRepositoryFile(".gitignore"));
        var appsettings = File.ReadAllText(FindRepositoryFile("src", "SchachTurnierManager.WebApi", "appsettings.json"));
        var devSettings = File.ReadAllText(FindRepositoryFile("src", "SchachTurnierManager.WebApi", "appsettings.Development.json"));
        var program = File.ReadAllText(FindRepositoryFile("src", "SchachTurnierManager.WebApi", "Program.cs"));
        var provider = File.ReadAllText(FindRepositoryFile("src", "SchachTurnierManager.WebApi", "Logging", "BoundedFileLoggerProvider.cs"));
        var desktopStarter = File.ReadAllText(FindRepositoryFile("scripts", "Start-Desktop.bat"));
        var portableStarter = File.ReadAllText(FindRepositoryFile("scripts", "Start-Portable.bat"));
        var readiness = File.ReadAllText(FindRepositoryFile("scripts", "Invoke-LoggingReadiness.ps1"));
        var cleanGenerated = File.ReadAllText(FindRepositoryFile("scripts", "Clean-Generated.ps1"));
        var gitSafety = File.ReadAllText(FindRepositoryFile("scripts", "Test-GitCommitSafety.ps1"));

        Assert.Contains("BoundedFileLoggerProvider", program);
        Assert.Contains("runtimeLogDirectory", program);
        Assert.Contains("FindRepositoryRoot", program);
        Assert.Contains("SchachTurnierManager:LogDirectory", program);
        Assert.Contains("SchachTurnierManager:FileLogging:RetainedFileCount", program);
        Assert.Contains("storage = \"local\"", program);
        Assert.DoesNotContain("directory = runtimeLogDirectory", program);
        Assert.DoesNotContain("databasePath = databaseFullPath", program);
        Assert.Contains("Path.Value", program);
        Assert.DoesNotContain("QueryString", program);

        Assert.Contains("FileLogging", appsettings);
        Assert.Contains("RetainedFileCount", appsettings);
        Assert.Contains("MaxFileSizeBytes", appsettings);
        Assert.Contains("\"LogDirectory\": \"logs\"", devSettings);

        Assert.Contains("RedactSensitiveContent", provider);
        Assert.Contains("token", provider, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("api_key", provider, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("PruneOldLogs", provider);

        Assert.Contains("SchachTurnierManager__LogDirectory", desktopStarter);
        Assert.Contains(@"set ""DATA_DIR=%LOCALAPPDATA%\SchachTurnierManager""", desktopStarter);
        Assert.Contains(@"set ""LOG_DIR=%DATA_DIR%\logs""", desktopStarter);
        Assert.Contains("SchachTurnierManager__LogDirectory", portableStarter);
        Assert.Contains(@"%ROOT%logs", portableStarter);

        Assert.Contains("LOGGING_READINESS=OK", readiness);
        Assert.Contains("/api/health?token=should-not-appear", readiness);
        Assert.Contains("should-not-appear", readiness);
        Assert.Contains("HTTP GET /api/tournaments", readiness);
        Assert.DoesNotContain("System.Object[]", readiness);

        Assert.Contains("!logs/README.md", gitignore);
        Assert.Contains("System.Object[]", gitignore);
        Assert.Contains("System.Object[]", cleanGenerated);
        Assert.Contains("Test-IsAllowedTrackedLogAnchor", gitSafety);
        Assert.Contains("logs/README.md", gitSafety);
        Assert.Contains("README.md", cleanGenerated);
        Assert.True(File.Exists(FindRepositoryFile("logs", "README.md")));
        Assert.True(File.Exists(FindRepositoryFile("logs", ".gitkeep")));
        Assert.True(File.Exists(FindRepositoryFile(".agents", "skills", "runtime-logging.md")));
        Assert.True(File.Exists(FindRepositoryFile("docs", "architecture", "RUNTIME_LOGGING.md")));
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

    private static string FindRepositoryDirectory(params string[] relativeParts)
    {
        var current = new DirectoryInfo(AppContext.BaseDirectory);
        while (current is not null)
        {
            var candidate = Path.Combine(new[] { current.FullName }.Concat(relativeParts).ToArray());
            if (Directory.Exists(candidate))
            {
                return candidate;
            }

            current = current.Parent;
        }

        throw new DirectoryNotFoundException($"Repository directory not found: {Path.Combine(relativeParts)}");
    }
}
