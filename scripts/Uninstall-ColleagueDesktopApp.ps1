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

$shortcut = Join-Path $ShortcutDirectory 'SchachTurnierManager.lnk'
Remove-Item -LiteralPath $shortcut -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $ShortcutDirectory -Recurse -Force -ErrorAction SilentlyContinue

$desktopShortcut = Join-Path ([Environment]::GetFolderPath('DesktopDirectory')) 'SchachTurnierManager.lnk'
Remove-Item -LiteralPath $desktopShortcut -Force -ErrorAction SilentlyContinue

Remove-Item -LiteralPath $InstallDirectory -Recurse -Force -ErrorAction SilentlyContinue

if ($RemoveUserData) {
    Remove-Item -LiteralPath $UserDataDirectory -Recurse -Force -ErrorAction SilentlyContinue
    Write-UninstallInfo "USER_DATA_REMOVED=$UserDataDirectory"
}
else {
    Write-UninstallInfo "USER_DATA_KEPT=$UserDataDirectory"
}

Write-UninstallInfo "UNINSTALLED=$InstallDirectory"
