[CmdletBinding()]
param(
    [string]$PackageDirectory = (Split-Path -Parent $PSCommandPath),
    [string]$InstallDirectory = (Join-Path $env:LOCALAPPDATA 'Programs\SchachTurnierManager'),
    [string]$ShortcutDirectory = (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\SchachTurnierManager'),
    [switch]$DesktopShortcut,
    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-InstallInfo([string]$Message) {
    if (-not $Quiet) { Write-Host $Message }
}

function New-AppShortcut {
    param(
        [Parameter(Mandatory = $true)][string]$ShortcutPath,
        [Parameter(Mandatory = $true)][string]$TargetPath,
        [Parameter(Mandatory = $true)][string]$WorkingDirectory
    )

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ShortcutPath) | Out-Null
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($ShortcutPath)
    $shortcut.TargetPath = $TargetPath
    $shortcut.WorkingDirectory = $WorkingDirectory
    $shortcut.Description = 'SchachTurnierManager starten'
    $shortcut.Save()
}

function Copy-DirectoryContent {
    param(
        [Parameter(Mandatory = $true)][string]$SourceDirectory,
        [Parameter(Mandatory = $true)][string]$DestinationDirectory
    )

    New-Item -ItemType Directory -Force -Path $DestinationDirectory | Out-Null
    Get-ChildItem -LiteralPath $SourceDirectory -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $DestinationDirectory -Recurse -Force
    }
}

$resolvedPackageDirectory = (Resolve-Path -LiteralPath $PackageDirectory).Path
$desktopZip = Get-ChildItem -LiteralPath $resolvedPackageDirectory -Filter 'SchachTurnierManager_Desktop_*.zip' -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $desktopZip) {
    throw "Desktop-ZIP wurde nicht gefunden in: $resolvedPackageDirectory"
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("SchachTurnierManager_install_" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

try {
    Write-InstallInfo "[Install] Entpacke $($desktopZip.Name)..."
    Expand-Archive -LiteralPath $desktopZip.FullName -DestinationPath $tempRoot -Force

    $starter = Join-Path $tempRoot 'SchachTurnierManager.bat'
    $exe = Join-Path $tempRoot 'app\SchachTurnierManager.WebApi.exe'
    $wwwroot = Join-Path $tempRoot 'app\wwwroot'

    if (-not (Test-Path -LiteralPath $starter -PathType Leaf)) { throw 'Desktop-Starter SchachTurnierManager.bat fehlt im Desktop-ZIP.' }
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw 'SchachTurnierManager.WebApi.exe fehlt im Desktop-ZIP.' }
    if (-not (Test-Path -LiteralPath $wwwroot -PathType Container)) { throw 'wwwroot fehlt im Desktop-ZIP.' }

    Write-InstallInfo "[Install] Installiere nach $InstallDirectory..."
    Remove-Item -LiteralPath $InstallDirectory -Recurse -Force -ErrorAction SilentlyContinue
    Copy-DirectoryContent -SourceDirectory $tempRoot -DestinationDirectory $InstallDirectory

    $installedStarter = Join-Path $InstallDirectory 'SchachTurnierManager.bat'
    $installedExe = Join-Path $InstallDirectory 'app\SchachTurnierManager.WebApi.exe'
    if (-not (Test-Path -LiteralPath $installedStarter -PathType Leaf)) { throw 'Installation unvollstaendig: Starter fehlt.' }
    if (-not (Test-Path -LiteralPath $installedExe -PathType Leaf)) { throw 'Installation unvollstaendig: WebApi-EXE fehlt.' }

    $startMenuShortcut = Join-Path $ShortcutDirectory 'SchachTurnierManager.lnk'
    New-AppShortcut -ShortcutPath $startMenuShortcut -TargetPath $installedStarter -WorkingDirectory $InstallDirectory

    $desktopShortcutPath = $null
    if ($DesktopShortcut) {
        $desktopShortcutPath = Join-Path ([Environment]::GetFolderPath('DesktopDirectory')) 'SchachTurnierManager.lnk'
        New-AppShortcut -ShortcutPath $desktopShortcutPath -TargetPath $installedStarter -WorkingDirectory $InstallDirectory
    }

    @(
        'SchachTurnierManager Installation',
        "InstalledAt=$(Get-Date -Format o)",
        "PackageDirectory=$resolvedPackageDirectory",
        "DesktopZip=$($desktopZip.Name)",
        "InstallDirectory=$InstallDirectory",
        "StartMenuShortcut=$startMenuShortcut",
        "DesktopShortcut=$desktopShortcutPath",
        "UserDataDefault=%LocalAppData%\SchachTurnierManager",
        "UserLogDefault=%LocalAppData%\SchachTurnierManager\logs"
    ) | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $InstallDirectory 'INSTALLATION_MANIFEST.txt')

    Write-InstallInfo "INSTALLED=$InstallDirectory"
    Write-InstallInfo "STARTER=$installedStarter"
    Write-InstallInfo "SHORTCUT=$startMenuShortcut"
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
