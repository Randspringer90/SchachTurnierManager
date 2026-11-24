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

function Expand-CheckedDesktopArchive([string]$ArchivePath, [string]$Destination) {
    # Validate the complete central directory before creating any payload files.
    # Limits cover both declared sizes and bytes actually read from the stream.
    if ((Get-Item -LiteralPath $ArchivePath).Length -gt 512MB) { throw 'Desktop-Archiv ist zu gross.' }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($ArchivePath)
    try {
        if ($archive.Entries.Count -gt 20000) { throw 'Zu viele Archiveintraege.' }
        $paths = [Collections.Generic.Dictionary[string,bool]]::new([StringComparer]::OrdinalIgnoreCase)
        $declaredTotal = 0L
        foreach ($entry in $archive.Entries) {
            $name = $entry.FullName.Replace('\','/')
            $directory = $name.EndsWith('/')
            $relative = $name.TrimEnd('/')
            $parts = $relative.Split('/')
            if (-not $relative -or $name.StartsWith('/') -or $name.Length -gt 240 -or
                @($parts | Where-Object { -not $_ -or $_ -in @('.','..') -or $_ -match '[\x00-\x1f<>:"|?*]' -or $_ -match '[. ]$' -or $_ -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)' }).Count) {
                throw 'Ungueltiger Archiveintrag.'
            }
            $unixType = ($entry.ExternalAttributes -shr 16) -band 0xF000
            if ($unixType -notin @(0,0x8000,0x4000) -or ($entry.ExternalAttributes -band 0x400) -ne 0) { throw 'Link-/Spezialdatei im Desktop-Archiv.' }
            if ($paths.ContainsKey($relative)) { throw 'Mehrdeutiger Archiveintrag.' }
            $paths.Add($relative,$directory)
            if ($entry.Length -gt 512MB -or ($directory -and $entry.Length -ne 0)) { throw 'Archiveintrag ist zu gross oder ungueltig.' }
            $declaredTotal += $entry.Length
            if ($declaredTotal -gt 2GB) { throw 'Entpacktes Desktop-Archiv ist zu gross.' }
        }
        foreach ($relative in $paths.Keys) {
            $parent = $relative
            while ($parent.Contains('/')) {
                $parent = $parent.Substring(0,$parent.LastIndexOf('/'))
                if ($paths.ContainsKey($parent) -and -not $paths[$parent]) { throw 'Datei-/Verzeichniskollision im Archiv.' }
            }
        }
        $actualTotal = 0L
        $buffer = [byte[]]::new(65536)
        foreach ($entry in $archive.Entries) {
            $target = [IO.Path]::GetFullPath((Join-Path $Destination $entry.FullName))
            if (-not $target.StartsWith($Destination.TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Archiveintrag verlaesst das Entpackziel.' }
            if ($entry.FullName.EndsWith('/') -or $entry.FullName.EndsWith('\')) { [IO.Directory]::CreateDirectory($target) | Out-Null; continue }
            [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
            $inputStream = $entry.Open()
            try {
                $outputStream = [IO.File]::Open($target,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
                try {
                    $actualEntry = 0L
                    while (($count = $inputStream.Read($buffer,0,$buffer.Length)) -gt 0) {
                        $actualEntry += $count; $actualTotal += $count
                        if ($actualEntry -gt $entry.Length -or $actualEntry -gt 512MB -or $actualTotal -gt 2GB) { throw 'Archivgroessenlimit beim Entpacken ueberschritten.' }
                        $outputStream.Write($buffer,0,$count)
                    }
                    if ($actualEntry -ne $entry.Length) { throw 'Archivgroesse stimmt nicht ueberein.' }
                } finally { $outputStream.Dispose() }
            } finally { $inputStream.Dispose() }
        }
    } finally { $archive.Dispose() }
}

function Assert-OwnedShortcut([string]$Path, [string]$ManifestKey, [string[]]$Manifest) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $item = Get-Item -LiteralPath $Path -Force
    $binding = @($Manifest | Where-Object { $_ -like ($ManifestKey + '=*') })
    $hashes = @($Manifest | Where-Object { $_ -like ($ManifestKey + 'Sha256=*') })
    if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or
        $binding.Count -ne 1 -or $hashes.Count -ne 1 -or
        -not $binding[0].Substring($ManifestKey.Length + 1).Equals($Path,[StringComparison]::OrdinalIgnoreCase) -or
        $hashes[0].Substring($ManifestKey.Length + 'Sha256='.Length) -notmatch '^[A-Fa-f0-9]{64}$' -or
        (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -cne $hashes[0].Substring($ManifestKey.Length + 'Sha256='.Length).ToUpperInvariant()) {
        throw 'Vorhandene Verknuepfung ist nicht unveraendert dieser Installation zugeordnet.'
    }
}

function Get-CheckedInstallPath([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path) -or -not [IO.Path]::IsPathRooted($Path) -or
        ([Environment]::OSVersion.Platform -eq 'Win32NT' -and $Path -notmatch '^[A-Za-z]:[\\/]')) { throw 'Installationsziel muss ein vollstaendiger lokaler Pfad sein.' }
    $full = [IO.Path]::GetFullPath($Path).TrimEnd('\','/')
    if ($full -eq [IO.Path]::GetPathRoot($full).TrimEnd('\','/')) { throw 'Ein Laufwerksroot ist kein Installationsziel.' }
    foreach ($folder in @('Windows','System','ProgramFiles','ProgramFilesX86','CommonApplicationData','UserProfile','DesktopDirectory','ApplicationData','LocalApplicationData')) {
        $protected = [Environment]::GetFolderPath($folder)
        if (-not $protected) { continue }
        $protected = [IO.Path]::GetFullPath($protected).TrimEnd('\','/')
        if ($protected.Equals($full,[StringComparison]::OrdinalIgnoreCase) -or
            $protected.StartsWith($full + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or
            ($folder -in @('Windows','System','ProgramFiles','ProgramFilesX86','CommonApplicationData') -and
             $full.StartsWith($protected + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase))) { throw 'Geschuetztes Installationsziel.' }
    }
    $cursor = $full
    while ($cursor) {
        if ((Test-Path -LiteralPath $cursor) -and
            ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Installationsziel hat eine Reparse-Pfadkomponente.' }
        $cursor = [IO.Path]::GetDirectoryName($cursor)
    }
    return $full
}

$InstallDirectory = Get-CheckedInstallPath $InstallDirectory
$ShortcutDirectory = Get-CheckedInstallPath $ShortcutDirectory
$existingLines = @()
if ((Test-Path -LiteralPath $InstallDirectory) -and @(Get-ChildItem -LiteralPath $InstallDirectory -Force).Count -gt 0) {
    $existingManifest = Join-Path $InstallDirectory 'INSTALLATION_MANIFEST.txt'
    if (-not (Test-Path -LiteralPath $existingManifest -PathType Leaf)) { throw 'Vorhandenes Installationsziel hat keinen Eigentumsnachweis; Dateien bleiben erhalten.' }
    $existingLines = @(Get-Content -LiteralPath $existingManifest)
    $bindings = @($existingLines | Where-Object { $_ -like 'InstallDirectory=*' })
    if ($existingLines[0] -cne 'SchachTurnierManager Installation' -or $bindings.Count -ne 1 -or
        -not (Get-CheckedInstallPath ($bindings[0].Substring('InstallDirectory='.Length))).Equals($InstallDirectory,[StringComparison]::OrdinalIgnoreCase)) {
        throw 'Vorhandenes Manifest passt nicht zum Installationsziel.'
    }
    $pending = [Collections.Generic.Stack[string]]::new()
    $pending.Push($InstallDirectory)
    while ($pending.Count) {
        foreach ($entry in Get-ChildItem -LiteralPath $pending.Pop() -Force) {
            if (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Reparse-Eintrag im vorhandenen Installationsziel.' }
            if ($entry.PSIsContainer) { $pending.Push($entry.FullName) }
        }
    }
}

$startMenuShortcut = Join-Path $ShortcutDirectory 'SchachTurnierManager.lnk'
Assert-OwnedShortcut $startMenuShortcut 'StartMenuShortcut' $existingLines
$desktopShortcutPath = $null
if ($DesktopShortcut) {
    $desktopDirectory = [Environment]::GetFolderPath('DesktopDirectory')
    if (-not $desktopDirectory) { throw 'Desktopverzeichnis ist nicht verfuegbar.' }
    $desktopShortcutPath = Join-Path $desktopDirectory 'SchachTurnierManager.lnk'
    Assert-OwnedShortcut $desktopShortcutPath 'DesktopShortcut' $existingLines
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
    Expand-CheckedDesktopArchive -ArchivePath $desktopZip.FullName -Destination $tempRoot

    $starter = Join-Path $tempRoot 'SchachTurnierManager.bat'
    $exe = Join-Path $tempRoot 'app\SchachTurnierManager.WebApi.exe'
    $wwwroot = Join-Path $tempRoot 'app\wwwroot'

    if (-not (Test-Path -LiteralPath $starter -PathType Leaf)) { throw 'Desktop-Starter SchachTurnierManager.bat fehlt im Desktop-ZIP.' }
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw 'SchachTurnierManager.WebApi.exe fehlt im Desktop-ZIP.' }
    if (-not (Test-Path -LiteralPath $wwwroot -PathType Container)) { throw 'wwwroot fehlt im Desktop-ZIP.' }

    Write-InstallInfo "[Install] Installiere nach $InstallDirectory..."
    if (Test-Path -LiteralPath $InstallDirectory) { Remove-Item -LiteralPath $InstallDirectory -Recurse -Force -ErrorAction Stop }
    Copy-DirectoryContent -SourceDirectory $tempRoot -DestinationDirectory $InstallDirectory

    $installedStarter = Join-Path $InstallDirectory 'SchachTurnierManager.bat'
    $installedExe = Join-Path $InstallDirectory 'app\SchachTurnierManager.WebApi.exe'
    if (-not (Test-Path -LiteralPath $installedStarter -PathType Leaf)) { throw 'Installation unvollstaendig: Starter fehlt.' }
    if (-not (Test-Path -LiteralPath $installedExe -PathType Leaf)) { throw 'Installation unvollstaendig: WebApi-EXE fehlt.' }

    New-AppShortcut -ShortcutPath $startMenuShortcut -TargetPath $installedStarter -WorkingDirectory $InstallDirectory

    if ($DesktopShortcut) {
        New-AppShortcut -ShortcutPath $desktopShortcutPath -TargetPath $installedStarter -WorkingDirectory $InstallDirectory
    }

    @(
        'SchachTurnierManager Installation',
        'AppId=SchachTurnierManager',
        "InstalledAt=$(Get-Date -Format o)",
        "PackageDirectory=$resolvedPackageDirectory",
        "DesktopZip=$($desktopZip.Name)",
        "InstallDirectory=$InstallDirectory",
        "StartMenuShortcut=$startMenuShortcut",
        "StartMenuShortcutSha256=$((Get-FileHash -LiteralPath $startMenuShortcut -Algorithm SHA256).Hash)",
        "DesktopShortcut=$desktopShortcutPath",
        "DesktopShortcutSha256=$(if ($desktopShortcutPath) { (Get-FileHash -LiteralPath $desktopShortcutPath -Algorithm SHA256).Hash } else { '' })",
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
