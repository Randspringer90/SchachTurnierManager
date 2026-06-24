param(
    [string]$Configuration = "Release",
    [string]$Runtime = "",
    [switch]$SelfContained,
    [switch]$NoZip,
    [string]$OutputRoot = "",
    [string]$LogRoot = "",
    [ValidateRange(30, 3600)][int]$StepTimeoutSeconds = 900
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

$root = (Resolve-Path "$PSScriptRoot\..").Path
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $outputRoot = Join-Path $root "output"
}
elseif ([System.IO.Path]::IsPathRooted($OutputRoot)) {
    $outputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
}
else {
    $outputRoot = [System.IO.Path]::GetFullPath((Join-Path $root $OutputRoot))
}
$portableRoot = Join-Path $outputRoot "portable"
$appOutput = Join-Path $portableRoot "app"
$dataDir = Join-Path $portableRoot "data"
$webApp = Join-Path $root "src\SchachTurnierManager.WebApp"
$webAppDist = Join-Path $root "tmp\webapp-dist"
$webApiProject = Join-Path $root "src\SchachTurnierManager.WebApi\SchachTurnierManager.WebApi.csproj"
$packageJsonPath = Join-Path $webApp "package.json"
if ([string]::IsNullOrWhiteSpace($LogRoot)) {
    $logRoot = Join-Path $outputRoot "pack-portable-logs"
}
elseif ([System.IO.Path]::IsPathRooted($LogRoot)) {
    $logRoot = [System.IO.Path]::GetFullPath($LogRoot)
}
else {
    $logRoot = [System.IO.Path]::GetFullPath((Join-Path $root $LogRoot))
}
$version = "dev"
if (Test-Path $packageJsonPath) {
    $packageJson = Get-Content -Raw -Path $packageJsonPath | ConvertFrom-Json
    if ($packageJson.version) {
        $version = [string]$packageJson.version
    }
}

function Assert-SafeGeneratedPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $repoFull = [System.IO.Path]::GetFullPath($root).TrimEnd('\', '/')
    $targetFull = [System.IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
    if (-not $targetFull.StartsWith($repoFull + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Unsicherer Ausgabepfad ausserhalb des Repositories: $targetFull"
    }

    $relative = [System.IO.Path]::GetRelativePath($repoFull, $targetFull) -replace '\\', '/'
    if ($relative -eq "." -or [string]::IsNullOrWhiteSpace($relative)) {
        throw "Unsicherer Ausgabepfad zeigt auf das Repository-Root."
    }
    if ($relative -notmatch '^(output|tmp)(/|$)') {
        throw "Ausgabepfade muessen unter output/ oder tmp/ liegen: $relative"
    }
}

function Get-SafeLogName {
    param([Parameter(Mandatory = $true)][string]$Name)
    return ($Name -replace '[^A-Za-z0-9._-]+', '-').Trim('-')
}

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][scriptblock]$Command
    )

    Write-Host "[Pack-Portable] $Label..."
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "Schritt fehlgeschlagen: $Label (ExitCode=$LASTEXITCODE)"
    }
}

function Remove-DirectoryWithRetry {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [ValidateRange(1, 20)][int]$Attempts = 6
    )

    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        try {
            Remove-Item -Recurse -Force -LiteralPath $Path -ErrorAction Stop
            return $true
        }
        catch {
            if ($attempt -eq $Attempts) {
                Write-Warning "[Pack-Portable] Konnte altes Ausgabeverzeichnis nicht entfernen: $Path ($($_.Exception.Message))"
                return $false
            }
            Start-Sleep -Milliseconds (250 * $attempt)
        }
    }
}

function Invoke-NativeStep {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @(),
        [string]$WorkingDirectory = $root
    )

    New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
    $logName = "{0}-{1}" -f (Get-Date -Format "yyyyMMdd-HHmmss"), (Get-SafeLogName $Label)
    $stdoutLog = Join-Path $logRoot "$logName.out.log"
    $stderrLog = Join-Path $logRoot "$logName.err.log"
    Write-Host "[Pack-Portable] $Label... (Timeout ${StepTimeoutSeconds}s, Log: $stdoutLog)"

    $command = Get-Command $FilePath -ErrorAction Stop
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $command.Source
    foreach ($argument in $Arguments) {
        [void]$psi.ArgumentList.Add($argument)
    }
    $psi.WorkingDirectory = $WorkingDirectory
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $psi
    [void]$process.Start()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()

    $timeoutMs = [int][Math]::Min([int]::MaxValue, $StepTimeoutSeconds * 1000)
    if (-not $process.WaitForExit($timeoutMs)) {
        try { & taskkill /PID $process.Id /T /F *> $null } catch { }
        try { [void]$process.WaitForExit(5000) } catch { }
        try { [System.IO.File]::WriteAllText($stdoutLog, $stdoutTask.GetAwaiter().GetResult(), [System.Text.UTF8Encoding]::new($false)) } catch { }
        try {
            $timeoutStderr = $stderrTask.GetAwaiter().GetResult()
            if (-not [string]::IsNullOrEmpty($timeoutStderr)) {
                [System.IO.File]::WriteAllText($stderrLog, $timeoutStderr, [System.Text.UTF8Encoding]::new($false))
            }
        } catch { }
        throw "$Label hat das Timeout von ${StepTimeoutSeconds}s ueberschritten. Logs: $stdoutLog / $stderrLog"
    }
    $process.WaitForExit()

    [System.IO.File]::WriteAllText($stdoutLog, $stdoutTask.GetAwaiter().GetResult(), [System.Text.UTF8Encoding]::new($false))
    $stderrText = $stderrTask.GetAwaiter().GetResult()
    if (-not [string]::IsNullOrEmpty($stderrText)) {
        [System.IO.File]::WriteAllText($stderrLog, $stderrText, [System.Text.UTF8Encoding]::new($false))
    }

    if ($process.ExitCode -ne 0) {
        throw "$Label ist fehlgeschlagen mit Exitcode $($process.ExitCode). Logs: $stdoutLog / $stderrLog"
    }
}

Assert-SafeGeneratedPath $portableRoot
Assert-SafeGeneratedPath $logRoot

if (Test-Path -LiteralPath $portableRoot) {
    if (-not (Remove-DirectoryWithRetry $portableRoot)) {
        $fallbackName = "portable-{0}" -f (Get-Date -Format "yyyyMMdd-HHmmss")
        $portableRoot = Join-Path $outputRoot $fallbackName
        $appOutput = Join-Path $portableRoot "app"
        $dataDir = Join-Path $portableRoot "data"
        Assert-SafeGeneratedPath $portableRoot
        Write-Warning "[Pack-Portable] Nutze alternatives Ausgabeverzeichnis: $portableRoot"
    }
}

Write-Host "[Pack-Portable] Ziel: $portableRoot"
New-Item -ItemType Directory -Force -Path $appOutput, $dataDir | Out-Null

Push-Location $webApp
try {
    $nodeModules = Join-Path $webApp "node_modules"
    if (Test-Path $nodeModules) {
        Write-Host "[Pack-Portable] node_modules vorhanden - npm install wird uebersprungen."
    }
    else {
        if (Test-Path (Join-Path $webApp "package-lock.json")) {
            Invoke-NativeStep "npm ci" "npm.cmd" @("ci") $webApp
        }
        else {
            Invoke-NativeStep "npm install" "npm.cmd" @("install") $webApp
        }
    }
    Invoke-NativeStep "npm run build" "npm.cmd" @("run", "build") $webApp
}
finally {
    Pop-Location
}

$publishArgs = @(
    "publish",
    $webApiProject,
    "-c", $Configuration,
    "-m:1",
    "-o", $appOutput,
    "/p:PublishSingleFile=false",
    "/p:STMDisableIncrementalPublishClean=true"
)
if ([string]::IsNullOrWhiteSpace($Runtime)) {
    $publishArgs += @(
        "--no-restore",
        "/p:UseAppHost=false"
    )
}
else {
    $publishArgs += @(
        "-r", $Runtime,
        "--self-contained", $SelfContained.IsPresent.ToString().ToLowerInvariant(),
        "/p:UseAppHost=true"
    )
}
$assetsPath = Join-Path (Split-Path $webApiProject) "obj\project.assets.json"
if ([string]::IsNullOrWhiteSpace($Runtime) -and -not (Test-Path $assetsPath)) {
    Invoke-NativeStep "dotnet restore" "dotnet" @("restore", $webApiProject, "-v", "minimal") $root
}
Invoke-NativeStep "dotnet publish" "dotnet" $publishArgs $root

$wwwroot = Join-Path $appOutput "wwwroot"
New-Item -ItemType Directory -Force -Path $wwwroot | Out-Null
Copy-Item -Path (Join-Path $webAppDist "*") -Destination $wwwroot -Recurse -Force
Copy-Item -Path (Join-Path $root "scripts\Start-Portable.bat") -Destination (Join-Path $portableRoot "Start-SchachTurnierManager.bat") -Force

@"
# SchachTurnierManager Portable $version

Start:

    Start-SchachTurnierManager.bat

Dashboard:

    http://127.0.0.1:5088/

API-Healthcheck:

    http://127.0.0.1:5088/api/health

Datenbank:

    data\SchachTurnierManager.sqlite

Hinweise:

- Dieses Paket ist eine portable lokale Version.
- Standard ist framework-dependent ohne Runtime-Identifier: Start-BAT nutzt `dotnet app\SchachTurnierManager.WebApi.dll`.
- Dafür muss .NET 10 Runtime/SDK installiert sein.
- Für eine EXE oder ein paketiertes .NET kann Pack-Portable.ps1 mit -Runtime win-x64 und optional -SelfContained ausgeführt werden.
- Keine Dateien aus app\ manuell bearbeiten.
- Für Backups im Dashboard JSON-Export verwenden.
"@ | Set-Content -Encoding UTF8 (Join-Path $portableRoot "README-Portable.md")

if (-not $NoZip) {
    $zipName = "SchachTurnierManager_Portable_$version.zip"
    $zipPath = Join-Path $outputRoot $zipName
    if (Test-Path $zipPath) {
        try {
            Remove-Item -Force $zipPath -ErrorAction Stop
        }
        catch {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $zipPath = Join-Path $outputRoot "SchachTurnierManager_Portable_$version-$timestamp.zip"
            Write-Warning "[Pack-Portable] Bestehende ZIP ist gesperrt: $zipName. Erstelle stattdessen: $(Split-Path -Leaf $zipPath)"
        }
    }
    Invoke-Checked "ZIP erstellen" { Compress-Archive -Path (Join-Path $portableRoot "*") -DestinationPath $zipPath -Force }
    Write-Host "[Pack-Portable] ZIP erstellt: $zipPath"
}

Write-Host "[Pack-Portable] Portable Paket erstellt: $portableRoot"
Write-Host "[Pack-Portable] Start: $portableRoot\Start-SchachTurnierManager.bat"
