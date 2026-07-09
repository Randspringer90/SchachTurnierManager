[CmdletBinding()]
param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$RunName = 'STM_RUN52_ColleagueFreshRunTest',
    [string]$BaseDirectory = 'D:\Temp',
    [string]$PackageZip,
    [switch]$BuildPackage,
    [switch]$BuildInstaller,
    [switch]$AllowMissingInnoSetup,
    [string]$InnoSetupCompiler,
    [int]$Port = 5108,
    [int]$TimeoutSeconds = 40
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$loggedCommandScript = Join-Path $PSScriptRoot 'Invoke-LoggedCommand.ps1'

function ConvertTo-SafeFileName([string]$Value) {
    $safe = $Value -replace '[^a-zA-Z0-9_.-]+', '_'
    if ([string]::IsNullOrWhiteSpace($safe)) { return 'run' }
    return $safe.Trim('_')
}

function New-FreshRunDirectory {
    param(
        [Parameter(Mandatory = $true)][string]$RunName,
        [Parameter(Mandatory = $true)][string]$BaseDirectory
    )
    $safeRunName = ConvertTo-SafeFileName $RunName
    $directory = Join-Path $BaseDirectory ("${safeRunName}_$(Get-Date -Format yyyyMMdd_HHmmss)")
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    return (Resolve-Path -LiteralPath $directory).Path
}

function Resolve-UploadZipPath {
    param([Parameter(Mandatory = $true)][string]$RunDirectory)
    return (Join-Path (Split-Path -Parent $RunDirectory) ("$(Split-Path -Leaf $RunDirectory).zip"))
}

$runDirectory = New-FreshRunDirectory -RunName $RunName -BaseDirectory $BaseDirectory
Write-Host "RUN_DIR=$runDirectory"

function Write-RunFile {
    param([string]$Name, [string[]]$Content)
    $Content | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $runDirectory $Name)
}

function Complete-RunBundle {
    param([string]$Status = 'OK')
    $zipPath = Resolve-UploadZipPath -RunDirectory $runDirectory
    "Status=$Status" | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $runDirectory 'run-status.txt')
    Remove-Item -Force -LiteralPath $zipPath -ErrorAction SilentlyContinue
    Compress-Archive -Path (Join-Path $runDirectory '*') -DestinationPath $zipPath -Force
    if (-not (Test-Path -LiteralPath $zipPath -PathType Leaf)) {
        throw "Upload-ZIP wurde nicht erzeugt: $zipPath"
    }
    Write-Host "UPLOAD_ZIP=$zipPath"
}

function Invoke-Logged {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$CommandLine
    )
    pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $loggedCommandScript `
        -RunDirectory $runDirectory `
        -Name $Name `
        -WorkingDirectory $Root `
        -CommandLine $CommandLine
    if ($LASTEXITCODE -ne 0) {
        throw "$Name ist fehlgeschlagen (ExitCode=$LASTEXITCODE). Details im Run-ZIP."
    }
}

function Get-PackageVersion {
    $packageJsonPath = Join-Path $Root 'src\SchachTurnierManager.WebApp\package.json'
    $packageJson = Get-Content -Raw -LiteralPath $packageJsonPath | ConvertFrom-Json
    if ($packageJson.version) { return [string]$packageJson.version }
    return '0.0.0-dev'
}

function Get-AvailableLoopbackPort {
    param([int]$PreferredPort)
    for ($candidate = $PreferredPort; $candidate -lt ($PreferredPort + 50); $candidate++) {
        $listener = $null
        try {
            $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Parse('127.0.0.1'), $candidate)
            $listener.Start()
            return $candidate
        }
        catch {
            # belegt oder nicht nutzbar: naechsten Port testen
        }
        finally {
            if ($listener) { $listener.Stop() }
        }
    }
    throw "Kein freier Loopback-Port ab $PreferredPort gefunden."
}

function Assert-FileExists {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Label)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Label fehlt: $Path"
    }
}

function Test-ChecksumFile {
    param([Parameter(Mandatory = $true)][string]$Directory)
    $checksumPath = Join-Path $Directory 'CHECKSUMS_SHA256.txt'
    Assert-FileExists -Path $checksumPath -Label 'CHECKSUMS_SHA256.txt'
    $results = New-Object System.Collections.Generic.List[string]
    $lines = Get-Content -LiteralPath $checksumPath
    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line -notmatch '^([A-Fa-f0-9]{64})\s+(.+)$') {
            throw "Ungueltige Checksum-Zeile: $line"
        }
        $expectedHash = $matches[1].ToUpperInvariant()
        $fileName = $matches[2].Trim()
        $filePath = Join-Path $Directory $fileName
        Assert-FileExists -Path $filePath -Label "Checksum-Datei $fileName"
        $actualHash = (Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash.ToUpperInvariant()
        if ($actualHash -ne $expectedHash) {
            throw "SHA256 mismatch fuer $fileName. Erwartet $expectedHash, erhalten $actualHash"
        }
        $results.Add("OK $fileName $actualHash")
    }
    if ($results.Count -eq 0) { throw 'Keine pruefbaren SHA256-Zeilen gefunden.' }
    Write-RunFile -Name 'checksum-verification.txt' -Content $results
}

function Wait-ForHttpOk {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [int]$TimeoutSeconds = 40
    )
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $lastError = $null
    do {
        try {
            $response = Invoke-WebRequest -UseBasicParsing -Uri $Url -TimeoutSec 3
            if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 300) { return $response }
        }
        catch {
            $lastError = $_.Exception.Message
            Start-Sleep -Milliseconds 500
        }
    } while ((Get-Date) -lt $deadline)
    throw "HTTP-Check fehlgeschlagen fuer $Url. Letzter Fehler: $lastError"
}

$process = $null
try {
    $version = Get-PackageVersion
    $outputRoot = Join-Path $Root 'output'

    if ($BuildPackage) {
        $command = 'pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-ColleagueInstallReadiness.ps1'
        if ($BuildInstaller) { $command += ' -BuildInstaller' }
        if ($AllowMissingInnoSetup) { $command += ' -AllowMissingInnoSetup' }
        if (-not [string]::IsNullOrWhiteSpace($InnoSetupCompiler)) { $command += " -InnoSetupCompiler `"$InnoSetupCompiler`"" }
        Invoke-Logged -Name 'build-colleague-package' -CommandLine $command
    }

    if ([string]::IsNullOrWhiteSpace($PackageZip)) {
        $PackageZip = Join-Path $outputRoot "SchachTurnierManager_Kollegenpaket_$version.zip"
    }
    Assert-FileExists -Path $PackageZip -Label 'Kollegenpaket'

    $packageHash = Get-FileHash -LiteralPath $PackageZip -Algorithm SHA256
    Write-RunFile -Name 'package-under-test.txt' -Content @(
        "PackageZip=$PackageZip",
        "Version=$version",
        "SHA256=$($packageHash.Hash)"
    )

    $kitExtract = Join-Path $runDirectory 'kollegenpaket-entpackt'
    $desktopExtract = Join-Path $runDirectory 'desktop-frischordner'
    $dataDirectory = Join-Path $runDirectory 'isolated-data'
    New-Item -ItemType Directory -Force -Path $kitExtract, $desktopExtract, $dataDirectory | Out-Null

    Expand-Archive -LiteralPath $PackageZip -DestinationPath $kitExtract -Force
    Assert-FileExists -Path (Join-Path $kitExtract 'README_START_HIER.txt') -Label 'README_START_HIER.txt'
    Assert-FileExists -Path (Join-Path $kitExtract 'KOLLEGENPAKET_MANIFEST.txt') -Label 'KOLLEGENPAKET_MANIFEST.txt'
    Test-ChecksumFile -Directory $kitExtract

    $desktopZip = Get-ChildItem -LiteralPath $kitExtract -File -Filter 'SchachTurnierManager_Desktop_*.zip' -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -First 1
    if (-not $desktopZip) { throw 'Desktop-ZIP fehlt im Kollegenpaket.' }
    Expand-Archive -LiteralPath $desktopZip.FullName -DestinationPath $desktopExtract -Force

    $starterCandidates = @(Get-ChildItem -LiteralPath $desktopExtract -Recurse -File -Filter '*.bat' -ErrorAction SilentlyContinue | Where-Object { $_.Name -in @('SchachTurnierManager.bat', 'Start-SchachTurnierManager.bat') })
    if ($starterCandidates.Count -eq 0) { throw 'Kein Doppelklick-Starter (*.bat) im Desktop-Paket gefunden.' }

    $exe = Get-ChildItem -LiteralPath $desktopExtract -Recurse -File -Filter 'SchachTurnierManager.WebApi.exe' -ErrorAction SilentlyContinue | Sort-Object FullName | Select-Object -First 1
    if (-not $exe) { throw 'SchachTurnierManager.WebApi.exe fehlt im Desktop-Paket.' }

    $webRootIndex = Get-ChildItem -LiteralPath $desktopExtract -Recurse -File -Filter 'index.html' -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match '[\\/]wwwroot[\\/]index\.html$' } | Select-Object -First 1
    if (-not $webRootIndex) { throw 'Eingebettetes Dashboard wwwroot/index.html fehlt im Desktop-Paket.' }

    $selectedPort = Get-AvailableLoopbackPort -PreferredPort $Port
    Write-Host "PORT=$selectedPort"
    Write-RunFile -Name 'fresh-run-input.txt' -Content @(
        "PreferredPort=$Port",
        "SelectedPort=$selectedPort",
        "DataDirectory=$dataDirectory",
        "Starter=$($starterCandidates[0].FullName)",
        "Exe=$($exe.FullName)",
        "DashboardIndex=$($webRootIndex.FullName)"
    )

    $stdoutPath = Join-Path $runDirectory 'desktop-process.stdout.log'
    $stderrPath = Join-Path $runDirectory 'desktop-process.stderr.log'
    $oldUrls = $env:ASPNETCORE_URLS
    $oldData = $env:SchachTurnierManager__DataDirectory
    try {
        $env:ASPNETCORE_URLS = "http://127.0.0.1:$selectedPort"
        $env:SchachTurnierManager__DataDirectory = $dataDirectory
        $process = Start-Process -FilePath $exe.FullName -WorkingDirectory $exe.DirectoryName -PassThru -NoNewWindow -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
        Start-Sleep -Milliseconds 750
        if ($process.HasExited) {
            throw "Desktop-Prozess wurde direkt beendet (ExitCode=$($process.ExitCode))."
        }

        $health = Wait-ForHttpOk -Url "http://127.0.0.1:$selectedPort/api/health" -TimeoutSeconds $TimeoutSeconds
        $dashboard = Wait-ForHttpOk -Url "http://127.0.0.1:$selectedPort/" -TimeoutSeconds 10
        $tournaments = Wait-ForHttpOk -Url "http://127.0.0.1:$selectedPort/api/tournaments" -TimeoutSeconds 10

        $database = Join-Path $dataDirectory 'SchachTurnierManager.sqlite'
        Assert-FileExists -Path $database -Label 'isolierte SQLite-Datenbank'

        Write-RunFile -Name 'fresh-run-result.txt' -Content @(
            'FreshRun=OK',
            "HealthStatus=$($health.StatusCode)",
            "DashboardStatus=$($dashboard.StatusCode)",
            "TournamentsStatus=$($tournaments.StatusCode)",
            "Database=$database",
            "ProcessId=$($process.Id)",
            "Port=$selectedPort"
        )
    }
    finally {
        $env:ASPNETCORE_URLS = $oldUrls
        $env:SchachTurnierManager__DataDirectory = $oldData
        if ($process -and -not $process.HasExited) {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            $process.WaitForExit(5000) | Out-Null
        }
    }

    $manifest = Get-ChildItem -LiteralPath $kitExtract -File | Sort-Object Name | ForEach-Object { "$($_.Name) $($_.Length) bytes" }
    Write-RunFile -Name 'kollegenpaket-dateien.txt' -Content $manifest
    Write-Host 'FRESH_RUN=OK'
    Complete-RunBundle -Status 'OK'
}
catch {
    if ($process -and -not $process.HasExited) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    }
    $_.Exception.ToString() | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $runDirectory 'FAILED.txt')
    Complete-RunBundle -Status 'FAILED'
    throw
}
