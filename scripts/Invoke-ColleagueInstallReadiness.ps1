[CmdletBinding()]
param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$RunName = 'STM_RUN51_ColleagueInstallReadiness',
    [string]$BaseDirectory = 'D:\Temp',
    [switch]$BuildInstaller,
    [switch]$AllowMissingInnoSetup,
    [string]$InnoSetupCompiler
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

function New-ColleagueRunDirectory {
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

$runDirectory = New-ColleagueRunDirectory -RunName $RunName -BaseDirectory $BaseDirectory
if ([string]::IsNullOrWhiteSpace($runDirectory) -or -not (Test-Path -LiteralPath $runDirectory -PathType Container)) {
    throw 'RunDirectory konnte nicht erzeugt werden.'
}
Write-Host "RUN_DIR=$runDirectory"

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

function Copy-FileIfExists {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$DestinationDirectory
    )

    if (Test-Path -LiteralPath $Source -PathType Leaf) {
        New-Item -ItemType Directory -Force -Path $DestinationDirectory | Out-Null
        Copy-Item -LiteralPath $Source -Destination (Join-Path $DestinationDirectory (Split-Path -Leaf $Source)) -Force
        return $true
    }
    return $false
}

function Write-Checksums {
    param([Parameter(Mandatory = $true)][string]$Directory)

    $checksumPath = Join-Path $Directory 'CHECKSUMS_SHA256.txt'
    $lines = New-Object System.Collections.Generic.List[string]
    $files = @(Get-ChildItem -LiteralPath $Directory -File | Sort-Object Name)
    foreach ($file in $files) {
        if ($file.Name -eq 'CHECKSUMS_SHA256.txt') { continue }
        $hash = Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256
        $lines.Add("$($hash.Hash)  $($file.Name)")
    }
    if ($lines.Count -eq 0) {
        $lines.Add('Keine Dateien fuer SHA256-Pruefsummen gefunden.')
    }
    $lines | Set-Content -Encoding UTF8 -LiteralPath $checksumPath
    return $checksumPath
}

function Complete-RunBundle {
    param([string]$KitZipPath)

    if (-not [string]::IsNullOrWhiteSpace($KitZipPath)) {
        "KOLLEGENPAKET=$KitZipPath" | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $runDirectory 'colleague-kit-path.txt')
    }

    $expectedUploadZip = Resolve-UploadZipPath -RunDirectory $runDirectory
    pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $bundleScript -RunDirectory $runDirectory -RunName $RunName -RepositoryRoot $Root | Out-Null

    if (-not (Test-Path -LiteralPath $expectedUploadZip -PathType Leaf)) {
        throw "Upload-ZIP wurde nicht erzeugt: $expectedUploadZip"
    }
    Write-Host "UPLOAD_ZIP=$expectedUploadZip"
}

try {
    $version = Get-PackageVersion
    $outputRoot = Join-Path $Root 'output'
    $kitRoot = Join-Path $outputRoot 'colleague-install'
    $kitZip = Join-Path $outputRoot "SchachTurnierManager_Kollegenpaket_$version.zip"

    Invoke-Logged -Name 'releasegate-skip-pack' -CommandLine 'pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-ReleaseGate.ps1 -SkipPack'
    Invoke-Logged -Name 'publish-desktop' -CommandLine 'pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Publish-DesktopApp.ps1'
    Invoke-Logged -Name 'portable-selfcontained' -CommandLine 'pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Pack-Portable.ps1 -SelfContained'

    if ($BuildInstaller) {
        $installerCommand = 'pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-InstallerReadiness.ps1 -BuildInstaller'
        if ($AllowMissingInnoSetup) { $installerCommand += ' -AllowMissingInnoSetup' }
        if (-not [string]::IsNullOrWhiteSpace($InnoSetupCompiler)) { $installerCommand += " -InnoSetupCompiler `"$InnoSetupCompiler`"" }
        Invoke-Logged -Name 'installer-readiness' -CommandLine $installerCommand
    }

    Remove-Item -Recurse -Force -LiteralPath $kitRoot -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $kitRoot | Out-Null

    $desktopZip = Join-Path $outputRoot "SchachTurnierManager_Desktop_$version.zip"
    $portableZip = Join-Path $outputRoot "SchachTurnierManager_Portable_$version.zip"
    $copied = New-Object System.Collections.Generic.List[string]
    if (Copy-FileIfExists -Source $desktopZip -DestinationDirectory $kitRoot) { $copied.Add((Split-Path -Leaf $desktopZip)) }
    if (Copy-FileIfExists -Source $portableZip -DestinationDirectory $kitRoot) { $copied.Add((Split-Path -Leaf $portableZip)) }

    $installerRoot = Join-Path $outputRoot 'installer'
    $setupFile = $null
    if (Test-Path -LiteralPath $installerRoot) {
        $setupFile = Get-ChildItem -LiteralPath $installerRoot -Filter 'SchachTurnierManager_Setup_*.exe' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($setupFile) {
            Copy-Item -LiteralPath $setupFile.FullName -Destination (Join-Path $kitRoot $setupFile.Name) -Force
            $copied.Add($setupFile.Name)
        }
    }

    if ($copied.Count -eq 0) {
        throw 'Es wurden keine Release-Artefakte fuer das Kollegenpaket gefunden.'
    }

    $readme = @"
SchachTurnierManager $version - Kollegeninstallation
====================================================

Empfohlene Reihenfolge
----------------------
1. Falls eine Setup-EXE enthalten ist: SchachTurnierManager_Setup_$version.exe per Doppelklick starten.
2. Falls keine Setup-EXE enthalten ist: SchachTurnierManager_Desktop_$version.zip vollstaendig entpacken und SchachTurnierManager.bat per Doppelklick starten.
3. Portable-ZIP nur verwenden, wenn bewusst eine portable Variante getestet werden soll.

Was der Kollege braucht
-----------------------
- Windows 10/11.
- Keine .NET-Installation.
- Kein Node/npm.
- Keine Verbindung zu anderen lokalen Projekten.

Daten und Logs
--------------
- Turnierdaten liegen standardmaessig unter %LocalAppData%\SchachTurnierManager.
- Lokale Logs/Run-Diagnosen liegen nicht im Installationspaket.
- Lokale Secrets muessen je Windows-Benutzer/Rechner neu gesetzt werden und bleiben unter .secrets/local/ gitignored.

Pruefung
--------
- Nach dem Start muss http://127.0.0.1:5088/api/health status=ok liefern.
- Das Dashboard oeffnet sich unter http://127.0.0.1:5088/.
- CHECKSUMS_SHA256.txt enthaelt Pruefsummen fuer die ausgelieferten Artefakte.

Hinweis
-------
Die Setup-EXE ist unsigniert. SmartScreen-Warnungen sind bis zu einer spaeteren Signaturentscheidung erwartbar.
"@
    $readme | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $kitRoot 'README_START_HIER.txt')

    $manifest = @(
        'SchachTurnierManager Kollegenpaket',
        "Version: $version",
        "Created: $(Get-Date -Format o)",
        "Root: $Root",
        "InstallerIncluded: $([bool]$setupFile)",
        'Artifacts:',
        ($copied | ForEach-Object { "- $_" })
    )
    $manifest | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $kitRoot 'KOLLEGENPAKET_MANIFEST.txt')
    Write-Checksums -Directory $kitRoot | Out-Null

    Remove-Item -Force -LiteralPath $kitZip -ErrorAction SilentlyContinue
    Compress-Archive -Path (Join-Path $kitRoot '*') -DestinationPath $kitZip -Force
    $hash = Get-FileHash -LiteralPath $kitZip -Algorithm SHA256
    @(
        "KOLLEGENPAKET=$kitZip",
        "SHA256=$($hash.Hash)",
        "Version=$version",
        "InstallerIncluded=$([bool]$setupFile)",
        "Artifacts=$($copied -join ', ')"
    ) | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $runDirectory 'colleague-install-summary.txt')

    Write-Host "KOLLEGENPAKET=$kitZip"
    Complete-RunBundle -KitZipPath $kitZip
}
catch {
    if (-not [string]::IsNullOrWhiteSpace($runDirectory) -and (Test-Path -LiteralPath $runDirectory -PathType Container)) {
        $_.Exception.ToString() | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $runDirectory 'FAILED.txt')
        Complete-RunBundle -KitZipPath $null
    }
    throw
}
