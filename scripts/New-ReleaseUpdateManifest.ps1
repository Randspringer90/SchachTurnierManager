[CmdletBinding()]
param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$ArtifactRoot = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'output'),
    [string]$OutputPath,
    [ValidateSet('stable', 'preview')]
    [string]$Channel = 'stable',
    [string[]]$ArtifactPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-PackageVersion {
    $packageJsonPath = Join-Path $Root 'src\SchachTurnierManager.WebApp\package.json'
    if (-not (Test-Path -LiteralPath $packageJsonPath -PathType Leaf)) {
        throw "package.json nicht gefunden: $packageJsonPath"
    }

    $package = Get-Content -Raw -LiteralPath $packageJsonPath | ConvertFrom-Json
    $version = [string]$package.version
    if ($version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$') {
        throw "Ungueltige Release-Version in package.json: $version"
    }

    return $version
}

function Get-SignatureInfo([string]$Path) {
    if ([System.IO.Path]::GetExtension($Path).ToLowerInvariant() -ne '.exe') {
        return [ordered]@{
            kind = 'none'
            status = 'NotApplicable'
            signerThumbprint = $null
        }
    }

    if (-not $IsWindows -or -not (Get-Command Get-AuthenticodeSignature -ErrorAction SilentlyContinue)) {
        return [ordered]@{
            kind = 'authenticode'
            status = 'Unknown'
            signerThumbprint = $null
        }
    }

    $signature = Get-AuthenticodeSignature -FilePath $Path
    $thumbprint = if ($signature.SignerCertificate) {
        ($signature.SignerCertificate.Thumbprint -replace '\s+', '').ToUpperInvariant()
    } else {
        $null
    }

    return [ordered]@{
        kind = 'authenticode'
        status = [string]$signature.Status
        signerThumbprint = $thumbprint
    }
}

function Get-ArtifactType([string]$Name) {
    if ($Name -match '^SchachTurnierManager_Desktop_.+\.zip$') { return 'desktop-zip' }
    if ($Name -match '^SchachTurnierManager_Portable_.+\.zip$') { return 'portable-zip' }
    if ($Name -match '^SchachTurnierManager_Setup_.+\.exe$') { return 'installer-exe' }
    throw "Nicht freigegebener Release-Artefakttyp: $Name"
}

$artifactRootFull = [System.IO.Path]::GetFullPath($ArtifactRoot).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
)
if (-not (Test-Path -LiteralPath $artifactRootFull -PathType Container)) {
    throw "ArtifactRoot existiert nicht: $artifactRootFull"
}

$version = Get-PackageVersion
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $releaseDir = Join-Path $artifactRootFull 'release'
    New-Item -ItemType Directory -Force -Path $releaseDir | Out-Null
    $OutputPath = Join-Path $releaseDir "SchachTurnierManager_Update_$version.json"
}

$selected = @()
if ($ArtifactPath -and $ArtifactPath.Count -gt 0) {
    foreach ($path in $ArtifactPath) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Release-Artefakt fehlt: $path"
        }
        $selected += Get-Item -LiteralPath $path
    }
}
else {
    $selected += Get-ChildItem -LiteralPath $artifactRootFull -File -Filter "SchachTurnierManager_Desktop_$version.zip" -ErrorAction SilentlyContinue
    $selected += Get-ChildItem -LiteralPath $artifactRootFull -File -Filter "SchachTurnierManager_Portable_$version.zip" -ErrorAction SilentlyContinue

    $installerRoot = Join-Path $artifactRootFull 'installer'
    if (Test-Path -LiteralPath $installerRoot -PathType Container) {
        $selected += Get-ChildItem -LiteralPath $installerRoot -File -Filter "SchachTurnierManager_Setup_$version.exe" -ErrorAction SilentlyContinue
    }
}

$selected = @($selected | Sort-Object FullName -Unique)
if ($selected.Count -eq 0) {
    throw "Keine freigegebenen Release-Artefakte fuer Version $version gefunden."
}

$rootPrefix = $artifactRootFull + [System.IO.Path]::DirectorySeparatorChar
$artifacts = foreach ($item in $selected) {
    $fullPath = [System.IO.Path]::GetFullPath($item.FullName)
    if (-not $fullPath.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Release-Artefakt liegt ausserhalb des ArtifactRoot: $fullPath"
    }

    $relative = [System.IO.Path]::GetRelativePath($artifactRootFull, $fullPath).Replace('\', '/')
    if ([System.IO.Path]::IsPathRooted($relative) -or (@($relative -split '/') -contains '..')) {
        throw "Unsicherer relativer Artefaktpfad: $relative"
    }

    $hash = Get-FileHash -LiteralPath $fullPath -Algorithm SHA256
    [ordered]@{
        artifactType = Get-ArtifactType -Name $item.Name
        fileName = $item.Name
        relativePath = $relative
        sizeBytes = [long]$item.Length
        sha256 = $hash.Hash.ToUpperInvariant()
        signature = Get-SignatureInfo -Path $fullPath
    }
}

$manifest = [ordered]@{
    schemaVersion = 1
    product = 'SchachTurnierManager'
    version = $version
    channel = $Channel
    createdAtUtc = [DateTime]::UtcNow.ToString('o')
    updateMode = 'manual-only'
    artifacts = @($artifacts)
}

$outputDirectory = Split-Path -Parent $OutputPath
if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
    New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
}
$manifest | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 -LiteralPath $OutputPath

Write-Host "UPDATE_MANIFEST=$OutputPath"
Write-Host "UPDATE_VERSION=$version"
Write-Host "UPDATE_ARTIFACTS=$($artifacts.Count)"
