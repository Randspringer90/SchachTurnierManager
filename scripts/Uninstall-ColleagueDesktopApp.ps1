[CmdletBinding()]
param(
    [string]$InstallDirectory = (Join-Path $env:LOCALAPPDATA 'Programs\SchachTurnierManager'),
    [string]$ShortcutDirectory = (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\SchachTurnierManager'),
    [string]$UserDataDirectory = (Join-Path $env:LOCALAPPDATA 'SchachTurnierManager'),
    [switch]$RemoveUserData,
    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-UninstallInfo([string]$Message) {
    if (-not $Quiet) { Write-Host $Message }
}

function Get-CheckedRemovalDirectory([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path) -or -not [IO.Path]::IsPathRooted($Path) -or
        ([Environment]::OSVersion.Platform -eq 'Win32NT' -and $Path -notmatch '^[A-Za-z]:[\\/]')) {
        throw 'Loeschziel muss ein vollstaendiger lokaler Verzeichnispfad sein.'
    }
    $full = [IO.Path]::GetFullPath($Path).TrimEnd('\','/')
    if ($full -eq [IO.Path]::GetPathRoot($full).TrimEnd('\','/')) { throw 'Ein Laufwerksroot ist kein Installationsziel.' }
    foreach ($folder in @('Windows','System','ProgramFiles','ProgramFilesX86','CommonApplicationData','UserProfile','DesktopDirectory','ApplicationData','LocalApplicationData')) {
        $protected = [Environment]::GetFolderPath($folder)
        if (-not $protected) { continue }
        $protected = [IO.Path]::GetFullPath($protected).TrimEnd('\','/')
        if ($protected.Equals($full,[StringComparison]::OrdinalIgnoreCase) -or
            $protected.StartsWith($full + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or
            ($folder -in @('Windows','System','ProgramFiles','ProgramFilesX86','CommonApplicationData') -and
             $full.StartsWith($protected + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase))) {
            throw 'Ein geschuetztes Stammverzeichnis oder dessen Vorfahr darf nicht geloescht werden.'
        }
    }
    $cursor = $full
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Loeschziel hat einen Reparse-Pfad.' }
        }
        $cursor = [IO.Path]::GetDirectoryName($cursor)
    }
    return $full
}
function Assert-RemovalTree([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $pending = [Collections.Generic.Stack[string]]::new()
    $pending.Push($Path)
    while ($pending.Count) {
        $directory = $pending.Pop()
        foreach ($entry in Get-ChildItem -LiteralPath $directory -Force -ErrorAction Stop) {
            if (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Reparse-Eintrag im Loeschziel; keine rekursive Loeschung.' }
            if ($entry.PSIsContainer) { $pending.Push($entry.FullName) }
        }
    }
}

$InstallDirectory = Get-CheckedRemovalDirectory $InstallDirectory
$ShortcutDirectory = Get-CheckedRemovalDirectory $ShortcutDirectory
$UserDataDirectory = Get-CheckedRemovalDirectory $UserDataDirectory
$manifestPath = Join-Path $InstallDirectory 'INSTALLATION_MANIFEST.txt'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw 'Installationsmanifest fehlt; vorhandene Dateien bleiben erhalten.' }
Assert-RemovalTree $InstallDirectory
$lines = @(Get-Content -LiteralPath $manifestPath)
if ($lines.Count -eq 0 -or $lines[0] -cne 'SchachTurnierManager Installation') { throw 'Unbekanntes Installationsmanifest.' }
$manifest = @{}
foreach ($line in $lines | Select-Object -Skip 1) {
    if ($line -notmatch '^([^=]+)=(.*)$') { continue }
    if ($manifest.ContainsKey($Matches[1])) { throw 'Mehrdeutiges Installationsmanifest.' }
    $manifest[$Matches[1]] = $Matches[2]
}
if (-not $manifest.ContainsKey('InstallDirectory') -or
    -not (Get-CheckedRemovalDirectory $manifest.InstallDirectory).Equals($InstallDirectory,[StringComparison]::OrdinalIgnoreCase) -or
    ($manifest.ContainsKey('AppId') -and $manifest.AppId -cne 'SchachTurnierManager')) { throw 'Installationsmanifest passt nicht zum Loeschziel.' }
if (-not $RemoveUserData -and (Test-Path -LiteralPath $UserDataDirectory) -and
    ($UserDataDirectory.Equals($InstallDirectory,[StringComparison]::OrdinalIgnoreCase) -or
     $UserDataDirectory.StartsWith($InstallDirectory + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase))) {
    throw 'Benutzerdaten liegen im Installationsziel; ohne Datenfreigabe bleibt es erhalten.'
}
if ($RemoveUserData) { Assert-RemovalTree $UserDataDirectory }
$ownedShortcuts = [Collections.Generic.List[string]]::new()
foreach ($kind in @('StartMenuShortcut','DesktopShortcut')) {
    if (-not $manifest.ContainsKey($kind) -or [string]::IsNullOrWhiteSpace($manifest[$kind])) { continue }
    $expected = if ($kind -eq 'StartMenuShortcut') { Join-Path $ShortcutDirectory 'SchachTurnierManager.lnk' }
        else { Join-Path ([Environment]::GetFolderPath('DesktopDirectory')) 'SchachTurnierManager.lnk' }
    $path = [IO.Path]::GetFullPath($manifest[$kind])
    if (-not $path.Equals([IO.Path]::GetFullPath($expected),[StringComparison]::OrdinalIgnoreCase)) { throw 'Verknuepfungsmanifest passt nicht zum ausgewaehlten Ziel.' }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
    $item = Get-Item -LiteralPath $path -Force
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Verknuepfung wurde durch einen Reparse-Eintrag ersetzt.' }
    $hashKey = $kind + 'Sha256'
    if (-not $manifest.ContainsKey($hashKey)) { Write-UninstallInfo 'LEGACY_SHORTCUT_KEPT=YES'; continue }
    if ($manifest[$hashKey] -cnotmatch '^[A-Fa-f0-9]{64}$' -or
        (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ine $manifest[$hashKey]) {
        Write-UninstallInfo 'MODIFIED_SHORTCUT_KEPT=YES'; continue
    }
    $ownedShortcuts.Add($path)
}
# Every recursive target has been resolved and checked before the first removal.
foreach ($shortcut in $ownedShortcuts) { Remove-Item -LiteralPath $shortcut -Force -ErrorAction Stop }
if ((Test-Path -LiteralPath $ShortcutDirectory -PathType Container) -and
    @(Get-ChildItem -LiteralPath $ShortcutDirectory -Force -ErrorAction Stop).Count -eq 0) {
    Remove-Item -LiteralPath $ShortcutDirectory -Force -ErrorAction Stop
}
Remove-Item -LiteralPath $InstallDirectory -Recurse -Force -ErrorAction Stop

if ($RemoveUserData) {
    if (Test-Path -LiteralPath $UserDataDirectory) { Remove-Item -LiteralPath $UserDataDirectory -Recurse -Force -ErrorAction Stop }
    Write-UninstallInfo "USER_DATA_REMOVED=$UserDataDirectory"
}
else {
    Write-UninstallInfo "USER_DATA_KEPT=$UserDataDirectory"
}

Write-UninstallInfo "UNINSTALLED=$InstallDirectory"
