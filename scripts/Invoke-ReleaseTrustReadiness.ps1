[CmdletBinding()]
param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$ArtifactRoot = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'output'),
    [string]$ManifestPath,
    [ValidateSet('stable','preview')]
    [string]$Channel = 'stable',
    [switch]$RequireInstaller,
    [switch]$RequireSignedArtifacts,
    [string]$ExpectedSignerThumbprint
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/ReleaseTrustValidation.ps1')
if ($RequireSignedArtifacts) {
    if ([string]::IsNullOrWhiteSpace($ExpectedSignerThumbprint)) { throw 'RequireSignedArtifacts verlangt -ExpectedSignerThumbprint.' }
    $ExpectedSignerThumbprint = ConvertTo-StmSignerThumbprint -Value $ExpectedSignerThumbprint
}
elseif (-not [string]::IsNullOrWhiteSpace($ExpectedSignerThumbprint)) {
    throw 'ExpectedSignerThumbprint ist nur mit -RequireSignedArtifacts zulaessig.'
}
$Root = Resolve-StmReleasePath -Path $Root -Kind Directory
$ArtifactRoot = Resolve-StmReleasePath -Path $ArtifactRoot -Kind Directory

function Get-Version {
    $packageJson = Get-Content -Raw -LiteralPath (Join-Path $Root 'src\SchachTurnierManager.WebApp\package.json') | ConvertFrom-Json
    return [string]$packageJson.version
}

function Assert-ValidAuthenticode([string]$Path) {
    $full = Resolve-StmReleasePath -Path $Path -Boundary $ArtifactRoot -Kind File
    Get-StmCheckedAuthenticodeSignature -Path $full -ExpectedSignerThumbprint $ExpectedSignerThumbprint | Out-Null
}

$version = Get-Version
if ($version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$') {
    throw "Ungueltige Release-Version: $version"
}

if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    $releaseDirectory = Resolve-StmReleasePath -Path (Join-Path $ArtifactRoot 'release') -Boundary $ArtifactRoot -Kind Directory -AllowMissing
    New-Item -ItemType Directory -Force -Path $releaseDirectory | Out-Null
    $ManifestPath = Join-Path $releaseDirectory "SchachTurnierManager_Update_$version.json"
}

if ($RequireSignedArtifacts) {
    Assert-ValidAuthenticode -Path (Join-Path $ArtifactRoot 'desktop\app\SchachTurnierManager.WebApi.exe')
    Assert-ValidAuthenticode -Path (Join-Path $ArtifactRoot 'portable\app\SchachTurnierManager.WebApi.exe')
}

$manifestArgs = @(
    '-NoLogo','-NoProfile','-ExecutionPolicy','Bypass',
    '-File',(Join-Path $PSScriptRoot 'New-ReleaseUpdateManifest.ps1'),
    '-Root',$Root,
    '-ArtifactRoot',$ArtifactRoot,
    '-OutputPath',$ManifestPath,
    '-Channel',$Channel
)
& pwsh @manifestArgs
if ($LASTEXITCODE -ne 0) {
    throw "New-ReleaseUpdateManifest.ps1 fehlgeschlagen (ExitCode=$LASTEXITCODE)."
}

$validationArgs = @(
    '-NoLogo','-NoProfile','-ExecutionPolicy','Bypass',
    '-File',(Join-Path $PSScriptRoot 'Test-ReleaseUpdateManifest.ps1'),
    '-ManifestPath',$ManifestPath,
    '-ArtifactRoot',$ArtifactRoot,
    '-ExpectedVersion',$version,
    '-RequireCompleteSet'
)
if ($RequireInstaller) { $validationArgs += '-RequireInstaller' }
if ($RequireSignedArtifacts) { $validationArgs += @('-RequireSignedArtifacts', '-ExpectedSignerThumbprint', $ExpectedSignerThumbprint) }

& pwsh @validationArgs
if ($LASTEXITCODE -ne 0) {
    throw "Test-ReleaseUpdateManifest.ps1 fehlgeschlagen (ExitCode=$LASTEXITCODE)."
}

Write-Host 'RELEASE_TRUST_READINESS=OK'
Write-Host "RELEASE_TRUST_VERSION=$version"
Write-Host "RELEASE_TRUST_MANIFEST=$ManifestPath"
Write-Host "RELEASE_TRUST_SIGNED_REQUIRED=$($RequireSignedArtifacts.IsPresent)"
