[CmdletBinding()]
param(
    [string]$RunName = 'STM_RUN03_PortableFreshFolder',
    [int]$Port = 5098,
    [switch]$SkipReleaseGate,
    [switch]$SkipPack,
    [switch]$FrameworkDependent,
    [int]$StartTimeoutSeconds = 45
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$runDirectory = pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'New-RunLogBundle.ps1') -RunName $RunName -CreateOnly
$runDirectory = ($runDirectory | Select-Object -Last 1).Trim()
$summaryPath = Join-Path $runDirectory 'portable-fresh-folder-summary.txt'
$packageManifestPath = Join-Path $runDirectory 'portable-package-manifest.txt'
$smokeLogPath = Join-Path $runDirectory 'portable-smoke.log'
$backendStdoutPath = Join-Path $runDirectory 'portable-backend.stdout.log'
$backendStderrPath = Join-Path $runDirectory 'portable-backend.stderr.log'
$extractedRoot = Join-Path $runDirectory 'fresh-extract'
$dataDirectory = Join-Path $runDirectory 'fresh-data'

function Add-Summary([string]$Line) {
    $Line | Add-Content -Encoding UTF8 -LiteralPath $summaryPath
}

function Invoke-Logged([string]$Name, [string]$CommandLine) {
    pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Invoke-LoggedCommand.ps1') `
        -RunDirectory $runDirectory `
        -Name $Name `
        -WorkingDirectory $root `
        -CommandLine $CommandLine
    if ($LASTEXITCODE -ne 0) {
        throw "$Name ist fehlgeschlagen (ExitCode=$LASTEXITCODE). Details im Run-ZIP."
    }
}

function Get-PackageVersion {
    $packageJsonPath = Join-Path $root 'src\SchachTurnierManager.WebApp\package.json'
    if (-not (Test-Path $packageJsonPath)) { return '0.0.0-dev' }
    $packageJson = Get-Content -Raw -LiteralPath $packageJsonPath | ConvertFrom-Json
    if ($packageJson.version) { return [string]$packageJson.version }
    return '0.0.0-dev'
}

function Test-PortFree([int]$CandidatePort) {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Parse('127.0.0.1'), $CandidatePort)
    try {
        $listener.Start()
        return $true
    }
    catch {
        return $false
    }
    finally {
        try { $listener.Stop() } catch { }
    }
}

function Resolve-PortableRoot([string]$ExtractRoot) {
    $directStart = Join-Path $ExtractRoot 'Start-SchachTurnierManager.bat'
    if (Test-Path -LiteralPath $directStart) { return $ExtractRoot }

    $startCandidates = Get-ChildItem -LiteralPath $ExtractRoot -Recurse -Filter 'Start-SchachTurnierManager.bat' -File -ErrorAction SilentlyContinue
    if ($startCandidates.Count -eq 1) {
        return $startCandidates[0].Directory.FullName
    }

    $manifestLines = @(
        "ExtractRoot: $ExtractRoot",
        "Created: $(Get-Date -Format o)",
        'FEHLT  Start-SchachTurnierManager.bat wurde weder direkt noch eindeutig rekursiv gefunden.',
        '',
        'Top-level Inhalt:'
    )
    $manifestLines += Get-ChildItem -LiteralPath $ExtractRoot -Force | ForEach-Object { "  $($_.Mode) $($_.FullName)" }
    $manifestLines | Set-Content -Encoding UTF8 -LiteralPath $packageManifestPath
    throw "Portable-Startdatei wurde im entpackten ZIP nicht eindeutig gefunden. Details: $packageManifestPath"
}

function Write-PortableManifest([string]$ZipPath, [string]$ExtractRoot, [string]$PortableRoot) {
    $requiredFiles = @(
        (Join-Path $PortableRoot 'Start-SchachTurnierManager.bat'),
        (Join-Path $PortableRoot 'README-Portable.md'),
        (Join-Path $PortableRoot 'app\SchachTurnierManager.WebApi.exe'),
        (Join-Path $PortableRoot 'app\wwwroot\index.html')
    )
    $optionalEmptyDirectories = @(
        (Join-Path $PortableRoot 'data')
    )

    $zipItem = Get-Item -LiteralPath $ZipPath
    $zipHash = Get-FileHash -LiteralPath $ZipPath -Algorithm SHA256
    $lines = @(
        "PortableZip: $($zipItem.FullName)",
        "PortableZipSize: $($zipItem.Length)",
        "PortableZipSHA256: $($zipHash.Hash)",
        "ExtractRoot: $ExtractRoot",
        "PortableRoot: $PortableRoot",
        "Created: $(Get-Date -Format o)",
        ''
    )

    $hasMissingRequired = $false
    foreach ($path in $requiredFiles) {
        if (Test-Path -LiteralPath $path) {
            $item = Get-Item -LiteralPath $path
            $hash = Get-FileHash -LiteralPath $path -Algorithm SHA256
            $lines += "OK  FILE  $($item.FullName)  Size=$($item.Length)  SHA256=$($hash.Hash)"
        }
        else {
            $hasMissingRequired = $true
            $lines += "FEHLT  REQUIRED  $path"
        }
    }

    foreach ($path in $optionalEmptyDirectories) {
        if (Test-Path -LiteralPath $path) {
            $item = Get-Item -LiteralPath $path
            $lines += "OK  OPTIONAL_DIR  $($item.FullName)"
        }
        else {
            $lines += "WARN OPTIONAL_DIR_FEHLT  $path  (leere Ordner werden von Compress-Archive nicht zuverlaessig ins ZIP uebernommen; Smoke nutzt separaten Test-Datenordner)"
        }
    }

    $lines += ''
    $lines += 'PortableRoot-Inhalt (Tiefe 3):'
    $trimChars = [char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $separatorPattern = '[\\/]'
    $lines += Get-ChildItem -LiteralPath $PortableRoot -Recurse -Force -ErrorAction SilentlyContinue |
        ForEach-Object {
            $relativePath = $_.FullName.Substring($PortableRoot.Length).TrimStart($trimChars)
            $depth = @(($relativePath -split $separatorPattern) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count
            if ($depth -le 3) {
                if ($_.PSIsContainer) { "DIR   $($_.FullName)" } else { "FILE  $($_.FullName)  Size=$($_.Length)" }
            }
        } |
        Where-Object { $_ }

    $lines | Set-Content -Encoding UTF8 -LiteralPath $packageManifestPath
    if ($hasMissingRequired) {
        throw "Portable-Paket unvollstaendig. Details: $packageManifestPath"
    }
}

function Invoke-PortableSmoke([string]$PortableRoot, [string]$DataDir, [int]$SmokePort) {
    if (-not (Test-PortFree $SmokePort)) {
        throw "Port $SmokePort ist belegt. Bitte einen anderen Port per -Port angeben."
    }

    New-Item -ItemType Directory -Force -Path $DataDir | Out-Null
    $exe = Join-Path $PortableRoot 'app\SchachTurnierManager.WebApi.exe'
    if (-not (Test-Path -LiteralPath $exe)) { throw "Portable-WebApi-EXE fehlt: $exe" }

    $url = "http://127.0.0.1:$SmokePort"
    $healthUrl = "$url/api/health"

    @(
        "SmokeStart: $(Get-Date -Format o)",
        "Exe: $exe",
        "Url: $url",
        "DataDirectory: $DataDir"
    ) | Set-Content -Encoding UTF8 -LiteralPath $smokeLogPath

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $exe
    $psi.WorkingDirectory = Split-Path -Parent $exe
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.Environment['ASPNETCORE_URLS'] = $url
    $psi.Environment['SchachTurnierManager__DataDirectory'] = $DataDir

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $psi
    [void]$process.Start()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()

    try {
        $deadline = (Get-Date).AddSeconds($StartTimeoutSeconds)
        $health = $null
        while ((Get-Date) -lt $deadline) {
            if ($process.HasExited) {
                throw "Backend-Prozess wurde vor Healthcheck beendet (ExitCode=$($process.ExitCode))."
            }

            try {
                $response = Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 2
                if ($response.StatusCode -eq 200) {
                    $health = $response.Content | ConvertFrom-Json
                    break
                }
            }
            catch {
                Start-Sleep -Seconds 1
            }
        }

        if ($null -eq $health) {
            throw "Backend war nach $StartTimeoutSeconds Sekunden nicht gesund: $healthUrl"
        }

        if ($health.status -ne 'ok') { throw "Health.status war nicht ok: $($health.status)" }
        if (-not $health.embeddedDashboard) { throw 'Health meldet embeddedDashboard=false; wwwroot/index.html fehlt oder wird nicht erkannt.' }

        $dashboard = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 5
        if ($dashboard.StatusCode -ne 200) { throw "Dashboard-Index lieferte Status $($dashboard.StatusCode)." }
        if ($dashboard.Content -notmatch '<!doctype html|<div id="root"') { throw 'Dashboard-Index sieht nicht wie die gebaute WebApp aus.' }

        $tournaments = Invoke-WebRequest -Uri "$url/api/tournaments" -UseBasicParsing -TimeoutSec 5
        if ($tournaments.StatusCode -ne 200) { throw "Turnierliste lieferte Status $($tournaments.StatusCode)." }

        $databasePath = [string]$health.databasePath
        if (-not (Test-Path -LiteralPath $databasePath)) { throw "SQLite-Datei aus Health wurde nicht angelegt: $databasePath" }
        if (-not $databasePath.StartsWith($DataDir, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "SQLite-Datei liegt nicht im Test-Datenordner. Pfad: $databasePath"
        }

        @(
            "Health: OK",
            "DashboardIndex: OK",
            "TournamentList: OK",
            "EmbeddedDashboard: $($health.embeddedDashboard)",
            "Version: $($health.version)",
            "DatabasePath: $databasePath"
        ) | Add-Content -Encoding UTF8 -LiteralPath $smokeLogPath
    }
    finally {
        if ($process -and -not $process.HasExited) {
            try { $process.Kill($true) } catch { }
            try { $process.WaitForExit(10000) | Out-Null } catch { }
        }
        try { $stdoutTask.GetAwaiter().GetResult() | Set-Content -Encoding UTF8 -LiteralPath $backendStdoutPath } catch { $_ | Out-String | Set-Content -Encoding UTF8 -LiteralPath $backendStdoutPath }
        try { $stderrTask.GetAwaiter().GetResult() | Set-Content -Encoding UTF8 -LiteralPath $backendStderrPath } catch { $_ | Out-String | Set-Content -Encoding UTF8 -LiteralPath $backendStderrPath }
    }
}

$version = Get-PackageVersion
@(
    'RUN-03 Portable-ZIP-Frischordner-Test',
    "Created: $(Get-Date -Format o)",
    "RepositoryRoot: $root",
    "RunDirectory: $runDirectory",
    "Version: $version",
    "Port: $Port",
    "FrameworkDependent: $($FrameworkDependent.IsPresent)",
    ''
) | Set-Content -Encoding UTF8 -LiteralPath $summaryPath

try {
    if (-not $SkipReleaseGate) {
        Invoke-Logged 'releasegate-skip-pack' 'pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-ReleaseGate.ps1 -SkipPack'
        Add-Summary 'ReleaseGate -SkipPack: OK'
    }
    else {
        Add-Summary 'ReleaseGate -SkipPack: uebersprungen'
    }

    if (-not $SkipPack) {
        $packCommand = 'pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Pack-Portable.ps1'
        if (-not $FrameworkDependent) { $packCommand += ' -SelfContained' }
        Invoke-Logged 'pack-portable' $packCommand
        Add-Summary "Pack-Portable: OK ($(if ($FrameworkDependent) { 'framework-dependent' } else { 'self-contained' }))"
    }
    else {
        Add-Summary 'Pack-Portable: uebersprungen'
    }

    $portableZip = Join-Path $root "output\SchachTurnierManager_Portable_$version.zip"
    if (-not (Test-Path -LiteralPath $portableZip)) {
        throw "Portable-ZIP wurde nicht gefunden: $portableZip"
    }

    Remove-Item -Recurse -Force -LiteralPath $extractedRoot -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $extractedRoot | Out-Null
    Expand-Archive -LiteralPath $portableZip -DestinationPath $extractedRoot -Force
    Add-Summary "Portable-ZIP extrahiert: $extractedRoot"

    $portableRoot = Resolve-PortableRoot -ExtractRoot $extractedRoot
    Add-Summary "Portable-Root erkannt: $portableRoot"

    Write-PortableManifest -ZipPath $portableZip -ExtractRoot $extractedRoot -PortableRoot $portableRoot
    Add-Summary "Portable-Manifest: $packageManifestPath"

    Invoke-PortableSmoke -PortableRoot $portableRoot -DataDir $dataDirectory -SmokePort $Port
    Add-Summary 'Portable-Smoke: OK (Health, Dashboard, Turnierliste, SQLite-Datenpfad)'
}
catch {
    Add-Summary "FEHLER: $($_.Exception.Message)"
    $zipPath = pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'New-RunLogBundle.ps1') -RunDirectory $runDirectory -RunName $RunName
    Write-Host "UPLOAD_ZIP=$zipPath"
    throw
}

$zipPath = pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'New-RunLogBundle.ps1') -RunDirectory $runDirectory -RunName $RunName
Write-Host "UPLOAD_ZIP=$zipPath"
