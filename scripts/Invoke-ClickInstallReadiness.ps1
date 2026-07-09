[CmdletBinding()]
param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$RunName = 'STM_RUN53_ClickInstallReadiness',
    [string]$BaseDirectory = 'D:\Temp',
    [switch]$BuildPackage,
    [switch]$BuildInstaller,
    [switch]$AllowMissingInnoSetup,
    [string]$InnoSetupCompiler,
    [int]$Port = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$bundleScript = Join-Path $PSScriptRoot 'New-RunLogBundle.ps1'
$loggedCommandScript = Join-Path $PSScriptRoot 'Invoke-LoggedCommand.ps1'

function ConvertTo-SafeFileName([string]$Value) {
    $safe = $Value -replace '[^a-zA-Z0-9_.-]+', '_'
    if ([string]::IsNullOrWhiteSpace($safe)) { return 'run' }
    return $safe.Trim('_')
}

function New-ClickRunDirectory {
    param([string]$RunName, [string]$BaseDirectory)
    $safeRunName = ConvertTo-SafeFileName $RunName
    $directory = Join-Path $BaseDirectory ("${safeRunName}_$(Get-Date -Format yyyyMMdd_HHmmss)")
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    return (Resolve-Path -LiteralPath $directory).Path
}

function Resolve-UploadZipPath([string]$RunDirectory) {
    return (Join-Path (Split-Path -Parent $RunDirectory) ("$(Split-Path -Leaf $RunDirectory).zip"))
}

function Complete-RunBundle {
    $expectedUploadZip = Resolve-UploadZipPath -RunDirectory $runDirectory
    pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $bundleScript -RunDirectory $runDirectory -RunName $RunName -RepositoryRoot $Root | Out-Null
    if (-not (Test-Path -LiteralPath $expectedUploadZip -PathType Leaf)) {
        throw "Upload-ZIP wurde nicht erzeugt: $expectedUploadZip"
    }
    Write-Host "UPLOAD_ZIP=$expectedUploadZip"
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
    if (-not (Test-Path -LiteralPath $packageJsonPath -PathType Leaf)) { return '0.0.0-dev' }
    $packageJson = Get-Content -Raw -LiteralPath $packageJsonPath | ConvertFrom-Json
    if ($packageJson.version) { return [string]$packageJson.version }
    return '0.0.0-dev'
}

function Get-AvailableLoopbackPort {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $listener.Start()
    try { return ([int]$listener.LocalEndpoint.Port) }
    finally { $listener.Stop() }
}

function Test-Checksums {
    param([Parameter(Mandatory = $true)][string]$PackageDirectory)

    $checksumPath = Join-Path $PackageDirectory 'CHECKSUMS_SHA256.txt'
    if (-not (Test-Path -LiteralPath $checksumPath -PathType Leaf)) { throw 'CHECKSUMS_SHA256.txt fehlt im Paket.' }

    $lines = @(Get-Content -LiteralPath $checksumPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($lines.Count -eq 0) { throw 'CHECKSUMS_SHA256.txt ist leer.' }

    foreach ($line in $lines) {
        if ($line -notmatch '^(?<hash>[A-Fa-f0-9]{64})\s+(?<name>.+)$') { throw "Ungueltige Checksum-Zeile: $line" }
        $expectedHash = $Matches['hash'].ToUpperInvariant()
        $name = $Matches['name'].Trim()
        $filePath = Join-Path $PackageDirectory $name
        if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) { throw "Checksum-Datei fehlt: $name" }
        $actualHash = (Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash.ToUpperInvariant()
        if ($actualHash -ne $expectedHash) { throw "Checksum passt nicht fuer $name" }
    }
}

function Test-InstalledAppSmoke {
    param(
        [Parameter(Mandatory = $true)][string]$InstallDirectory,
        [Parameter(Mandatory = $true)][string]$DataDirectory,
        [Parameter(Mandatory = $true)][int]$Port
    )

    $exe = Join-Path $InstallDirectory 'app\SchachTurnierManager.WebApi.exe'
    $wwwroot = Join-Path $InstallDirectory 'app\wwwroot'
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw "Installierte EXE fehlt: $exe" }
    if (-not (Test-Path -LiteralPath $wwwroot -PathType Container)) { throw "Installiertes wwwroot fehlt: $wwwroot" }

    New-Item -ItemType Directory -Force -Path $DataDirectory | Out-Null
    $env:ASPNETCORE_URLS = "http://127.0.0.1:$Port"
    $env:SchachTurnierManager__DataDirectory = $DataDirectory
    $process = Start-Process -FilePath $exe -WorkingDirectory (Split-Path -Parent $exe) -PassThru -WindowStyle Minimized
    try {
        $healthUrl = "http://127.0.0.1:$Port/api/health"
        $dashboardUrl = "http://127.0.0.1:$Port/"
        $tournamentsUrl = "http://127.0.0.1:$Port/api/tournaments"
        $ready = $false
        for ($i = 0; $i -lt 45; $i++) {
            try {
                $response = Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 2
                if ($response.StatusCode -eq 200) { $ready = $true; break }
            }
            catch { Start-Sleep -Seconds 1 }
        }
        if (-not $ready) { throw 'Installierte App war nach 45 Sekunden nicht erreichbar.' }

        $dashboard = Invoke-WebRequest -Uri $dashboardUrl -UseBasicParsing -TimeoutSec 5
        if ($dashboard.StatusCode -ne 200) { throw "Dashboard StatusCode=$($dashboard.StatusCode)" }

        $tournaments = Invoke-WebRequest -Uri $tournamentsUrl -UseBasicParsing -TimeoutSec 5
        if ($tournaments.StatusCode -ne 200) { throw "Tournaments StatusCode=$($tournaments.StatusCode)" }
    }
    finally {
        Remove-Item Env:\ASPNETCORE_URLS -ErrorAction SilentlyContinue
        Remove-Item Env:\SchachTurnierManager__DataDirectory -ErrorAction SilentlyContinue
        if ($process -and -not $process.HasExited) {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            $process.WaitForExit(5000) | Out-Null
        }
    }

    $sqlite = Get-ChildItem -LiteralPath $DataDirectory -Filter '*.sqlite' -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $sqlite) { throw 'Isolierte SQLite-Datenbank wurde nicht im Testdatenordner erzeugt.' }
}

$runDirectory = New-ClickRunDirectory -RunName $RunName -BaseDirectory $BaseDirectory
Write-Host "RUN_DIR=$runDirectory"

try {
    $version = Get-PackageVersion
    $outputRoot = Join-Path $Root 'output'
    $packageZip = Join-Path $outputRoot "SchachTurnierManager_Kollegenpaket_$version.zip"

    if ($BuildPackage -or -not (Test-Path -LiteralPath $packageZip -PathType Leaf)) {
        $command = 'pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-ColleagueInstallReadiness.ps1'
        if ($BuildInstaller) { $command += ' -BuildInstaller' }
        if ($AllowMissingInnoSetup) { $command += ' -AllowMissingInnoSetup' }
        if (-not [string]::IsNullOrWhiteSpace($InnoSetupCompiler)) { $command += " -InnoSetupCompiler `"$InnoSetupCompiler`"" }
        Invoke-Logged -Name 'build-colleague-package' -CommandLine $command
    }

    if (-not (Test-Path -LiteralPath $packageZip -PathType Leaf)) { throw "Kollegenpaket fehlt: $packageZip" }

    $freshRoot = Join-Path $runDirectory 'fresh-click-install'
    $packageRoot = Join-Path $freshRoot 'package'
    $installRoot = Join-Path $freshRoot 'installed-app'
    $shortcutRoot = Join-Path $freshRoot 'shortcuts'
    $dataRoot = Join-Path $freshRoot 'user-data'
    New-Item -ItemType Directory -Force -Path $packageRoot | Out-Null
    Expand-Archive -LiteralPath $packageZip -DestinationPath $packageRoot -Force

    foreach ($required in @('README_START_HIER.txt', 'KOLLEGENPAKET_MANIFEST.txt', 'CHECKSUMS_SHA256.txt', 'Install-SchachTurnierManager.cmd', 'Install-SchachTurnierManager.ps1', 'Uninstall-SchachTurnierManager.cmd', 'Uninstall-SchachTurnierManager.ps1')) {
        if (-not (Test-Path -LiteralPath (Join-Path $packageRoot $required) -PathType Leaf)) { throw "Paketdatei fehlt: $required" }
    }

    Test-Checksums -PackageDirectory $packageRoot

    $installScript = Join-Path $packageRoot 'Install-SchachTurnierManager.ps1'
    $uninstallScript = Join-Path $packageRoot 'Uninstall-SchachTurnierManager.ps1'
    Invoke-Logged -Name 'click-install' -CommandLine "pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$installScript`" -PackageDirectory `"$packageRoot`" -InstallDirectory `"$installRoot`" -ShortcutDirectory `"$shortcutRoot`" -Quiet"

    if (-not (Test-Path -LiteralPath (Join-Path $shortcutRoot 'SchachTurnierManager.lnk') -PathType Leaf)) { throw 'Startmenue-Shortcut wurde im Testordner nicht erzeugt.' }
    if (-not (Test-Path -LiteralPath (Join-Path $installRoot 'INSTALLATION_MANIFEST.txt') -PathType Leaf)) { throw 'Installationsmanifest fehlt.' }

    $effectivePort = $Port
    if ($effectivePort -le 0) { $effectivePort = Get-AvailableLoopbackPort }
    Write-Host "PORT=$effectivePort"
    Test-InstalledAppSmoke -InstallDirectory $installRoot -DataDirectory $dataRoot -Port $effectivePort

    Invoke-Logged -Name 'click-uninstall' -CommandLine "pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$uninstallScript`" -InstallDirectory `"$installRoot`" -ShortcutDirectory `"$shortcutRoot`" -UserDataDirectory `"$dataRoot`" -RemoveUserData -Quiet"
    if (Test-Path -LiteralPath $installRoot) { throw 'Installationsordner wurde beim Uninstall-Test nicht entfernt.' }
    if (Test-Path -LiteralPath (Join-Path $shortcutRoot 'SchachTurnierManager.lnk')) { throw 'Shortcut wurde beim Uninstall-Test nicht entfernt.' }

    @(
        'CLICK_INSTALL=OK',
        "Package=$packageZip",
        "FreshRoot=$freshRoot",
        "InstallRoot=$installRoot",
        "ShortcutRoot=$shortcutRoot",
        "Port=$effectivePort"
    ) | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $runDirectory 'click-install-summary.txt')

    Write-Host 'CLICK_INSTALL=OK'
    Complete-RunBundle
}
catch {
    $_.Exception.ToString() | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $runDirectory 'FAILED.txt')
    Complete-RunBundle
    throw
}
