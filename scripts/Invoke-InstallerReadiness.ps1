[CmdletBinding()]
param(
    [string]$RunName = 'STM_RUN05_InstallerReadiness',
    [switch]$SkipReleaseGate,
    [switch]$SkipPublish,
    [switch]$BuildInstaller,
    [switch]$AllowMissingInnoSetup,
    [string]$InnoSetupCompiler
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$runDirectory = pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'New-RunLogBundle.ps1') -RunName $RunName -CreateOnly
$runDirectory = ($runDirectory | Select-Object -Last 1).Trim()
$summaryPath = Join-Path $runDirectory 'installer-readiness-summary.txt'
$desktopManifestPath = Join-Path $runDirectory 'desktop-package-manifest.txt'
$installerManifestPath = Join-Path $runDirectory 'installer-manifest.txt'
$manualChecklistPath = Join-Path $runDirectory 'manual-installer-test-checklist.txt'

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

function Find-InnoSetupCompiler {
    if (-not [string]::IsNullOrWhiteSpace($InnoSetupCompiler)) {
        if (Test-Path -LiteralPath $InnoSetupCompiler) { return (Resolve-Path -LiteralPath $InnoSetupCompiler).Path }
        throw "Angegebener Inno-Setup-Compiler nicht gefunden: $InnoSetupCompiler"
    }

    $command = Get-Command 'ISCC.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
    $candidates = @()
    if ($command) { $candidates += $command.Source }
    $candidates += @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
        "$env:LocalAppData\Programs\Inno Setup 6\ISCC.exe"
    )

    foreach ($candidate in $candidates | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique) {
        if (Test-Path -LiteralPath $candidate) { return (Resolve-Path -LiteralPath $candidate).Path }
    }

    return $null
}

function Write-DesktopManifest {
    $desktopRoot = Join-Path $root 'output\desktop'
    $required = @(
        (Join-Path $desktopRoot 'SchachTurnierManager.bat'),
        (Join-Path $desktopRoot 'README-Desktop.md'),
        (Join-Path $desktopRoot 'app\SchachTurnierManager.WebApi.exe'),
        (Join-Path $desktopRoot 'app\wwwroot\index.html')
    )

    $lines = @(
        "DesktopRoot: $desktopRoot",
        "Created: $(Get-Date -Format o)",
        ''
    )
    foreach ($path in $required) {
        if (Test-Path -LiteralPath $path) {
            $item = Get-Item -LiteralPath $path
            $hash = Get-FileHash -LiteralPath $path -Algorithm SHA256
            $lines += "OK  $($item.FullName)  Size=$($item.Length)  SHA256=$($hash.Hash)"
        }
        else {
            $lines += "FEHLT  $path"
        }
    }

    $lines | Set-Content -Encoding UTF8 -LiteralPath $desktopManifestPath
    if ($lines | Where-Object { $_ -like 'FEHLT*' }) {
        throw "Desktop-Paket unvollstaendig. Details: $desktopManifestPath"
    }
}

function Write-InstallerManifest {
    $installerRoot = Join-Path $root 'output\installer'
    $setupFiles = @()
    if (Test-Path -LiteralPath $installerRoot) {
        $setupFiles = @(Get-ChildItem -LiteralPath $installerRoot -Filter 'SchachTurnierManager_Setup_*.exe' -File | Sort-Object LastWriteTime -Descending)
    }

    $lines = @(
        "InstallerRoot: $installerRoot",
        "Created: $(Get-Date -Format o)",
        ''
    )
    foreach ($file in $setupFiles) {
        $hash = Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256
        $lines += "SETUP  $($file.FullName)  Size=$($file.Length)  SHA256=$($hash.Hash)"
    }
    if ($setupFiles.Count -eq 0) {
        $lines += 'Keine Setup-EXE gefunden.'
    }
    $lines | Set-Content -Encoding UTF8 -LiteralPath $installerManifestPath
    return $setupFiles.Count
}

@(
    '# Manueller Installer-Test (RUN-05)',
    '',
    '1. Setup-EXE aus output\installer starten.',
    '2. Standardpfad belassen oder Testpfad wählen; keine Adminrechte erforderlich.',
    '3. Desktop-/Startmenü-Verknüpfung starten.',
    '4. Dashboard muss unter http://127.0.0.1:5088/ öffnen.',
    '5. Testturnier mit 4 synthetischen Spielern anlegen.',
    '6. App schließen und erneut starten; Testturnier muss weiter vorhanden sein.',
    '7. Deinstallation aus Windows Apps/Programme durchführen.',
    '8. Prüfen: %LocalAppData%\SchachTurnierManager bleibt erhalten (Daten werden nicht gelöscht).',
    '9. Testdaten anschließend manuell löschen, wenn sie nicht mehr gebraucht werden.',
    '10. Erwartete SmartScreen-Warnung dokumentieren: EXE ist unsigniert; keine Zertifikatskäufe ohne Freigabe.'
) | Set-Content -Encoding UTF8 -LiteralPath $manualChecklistPath

$version = Get-PackageVersion
$inno = Find-InnoSetupCompiler

@(
    "RUN-05 Installer-Readiness",
    "Created: $(Get-Date -Format o)",
    "RepositoryRoot: $root",
    "RunDirectory: $runDirectory",
    "Version: $version",
    "BuildInstaller: $($BuildInstaller.IsPresent)",
    "SkipReleaseGate: $($SkipReleaseGate.IsPresent)",
    "SkipPublish: $($SkipPublish.IsPresent)",
    "InnoSetupCompiler: $(if ($inno) { $inno } else { 'NICHT GEFUNDEN' })",
    ''
) | Set-Content -Encoding UTF8 -LiteralPath $summaryPath

if (-not $SkipReleaseGate) {
    Invoke-Logged 'releasegate-skip-pack' 'pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-ReleaseGate.ps1 -SkipPack'
    Add-Summary 'ReleaseGate -SkipPack: OK'
}
else {
    Add-Summary 'ReleaseGate -SkipPack: uebersprungen'
}

if (-not $SkipPublish) {
    Invoke-Logged 'publish-desktop-nozip' 'pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Publish-DesktopApp.ps1 -NoZip'
    Add-Summary 'Desktop-Publish: OK'
}
else {
    Add-Summary 'Desktop-Publish: uebersprungen'
}

Write-DesktopManifest
Add-Summary "Desktop-Manifest: $desktopManifestPath"

if ($BuildInstaller) {
    if (-not $inno) {
        Add-Summary 'Installer-Build: BLOCKIERT - ISCC.exe/Inno Setup 6 nicht gefunden.'
        Add-Summary 'Naechster Schritt: Inno Setup 6 lokal installieren oder Pfad per -InnoSetupCompiler angeben.'
        if (-not $AllowMissingInnoSetup) {
            $zip = pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'New-RunLogBundle.ps1') -RunDirectory $runDirectory -RunName $RunName
            Write-Host "UPLOAD_ZIP=$zip"
            exit 2
        }
    }
    else {
        Invoke-Logged 'build-installer-skippublish' 'pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build-Installer.ps1 -SkipPublish'
        $count = Write-InstallerManifest
        if ($count -lt 1) { throw 'Installer-Build meldete OK, aber keine Setup-EXE wurde gefunden.' }
        Add-Summary "Installer-Build: OK ($count Setup-Datei(en))"
        Add-Summary "Installer-Manifest: $installerManifestPath"
    }
}
else {
    Add-Summary 'Installer-Build: nicht angefordert; Readiness/Publishescript geprueft.'
    if (-not $inno) {
        Add-Summary 'Hinweis: ISCC.exe/Inno Setup 6 ist aktuell nicht auffindbar.'
    }
}

Add-Summary "Manuelle Checkliste: $manualChecklistPath"
$zipPath = pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'New-RunLogBundle.ps1') -RunDirectory $runDirectory -RunName $RunName
Write-Host "UPLOAD_ZIP=$zipPath"
