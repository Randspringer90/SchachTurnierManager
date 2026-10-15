# Liefert den Basisordner fuer Run-Ordner und Upload-ZIPs (STM-INFRA-005).
# Reihenfolge: STM_RUN_BASE_DIRECTORY -> vorhandenes D:\Temp -> D:\Temp auf einem
# festen Laufwerk D: -> %TEMP%\SchachTurnierManager. So bleibt die Konvention auf
# Rechnern mit Datenpartition erhalten, ohne frische/andere Maschinen zu brechen.
[CmdletBinding()]
param(
    [string]$PreferredDirectory = 'D:\Temp',
    [string]$FallbackDirectory = (Join-Path ([IO.Path]::GetTempPath()) 'SchachTurnierManager')
)

Set-StrictMode -Version Latest

$override = [Environment]::GetEnvironmentVariable('STM_RUN_BASE_DIRECTORY')
if (-not [string]::IsNullOrWhiteSpace($override)) { return $override }

if (Test-Path -LiteralPath $PreferredDirectory -PathType Container) { return $PreferredDirectory }

try {
    $root = [IO.Path]::GetPathRoot($PreferredDirectory)
    if ($IsWindows -and -not [string]::IsNullOrEmpty($root)) {
        $drive = [IO.DriveInfo]::new($root)
        if ($drive.IsReady -and $drive.DriveType -eq [IO.DriveType]::Fixed) { return $PreferredDirectory }
    }
}
catch {
    # Unbekanntes oder ungueltiges Laufwerk: Fallback verwenden.
}

return $FallbackDirectory
