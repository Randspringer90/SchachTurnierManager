[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath,

    [string]$ArtifactRoot = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'output'),

    [string]$ExpectedVersion,

    [switch]$RequireCompleteSet,

    [switch]$RequireInstaller,

    [switch]$RequireSignedArtifacts
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-ExactProperties {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string[]]$Allowed,
        [Parameter(Mandatory = $true)][string[]]$Required,
        [Parameter(Mandatory = $true)][string]$Context
    )

    $names = @($Object.PSObject.Properties.Name)
    foreach ($name in $names) {
        if ($Allowed -notcontains $name) {
            throw "$Context enthaelt ein nicht erlaubtes Feld: $name"
        }
    }
    foreach ($name in $Required) {
        if ($names -notcontains $name) {
            throw "$Context fehlt Pflichtfeld: $name"
        }
    }
}

if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    throw "Update-Manifest nicht gefunden: $ManifestPath"
}
if (-not (Test-Path -LiteralPath $ArtifactRoot -PathType Container)) {
    throw "ArtifactRoot nicht gefunden: $ArtifactRoot"
}

$raw = Get-Content -Raw -LiteralPath $ManifestPath
try {
    $manifest = $raw | ConvertFrom-Json
}
catch {
    throw "Update-Manifest ist kein gueltiges JSON: $($_.Exception.Message)"
}

Assert-ExactProperties -Object $manifest -Allowed @('schemaVersion','product','version','channel','createdAtUtc','updateMode','artifacts') -Required @('schemaVersion','product','version','channel','createdAtUtc','updateMode','artifacts') -Context 'Manifest'

if ([int]$manifest.schemaVersion -ne 1) { throw 'Nur schemaVersion=1 ist freigegeben.' }
if ([string]$manifest.product -cne 'SchachTurnierManager') { throw 'Unerwartetes Produkt im Update-Manifest.' }
if ([string]$manifest.version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$') {
    throw "Ungueltige Manifest-Version: $($manifest.version)"
}
if ($ExpectedVersion -and [string]$manifest.version -cne $ExpectedVersion) {
    throw "Manifest-Version $($manifest.version) entspricht nicht ExpectedVersion $ExpectedVersion."
}
if ([string]$manifest.channel -notin @('stable','preview')) { throw 'Ungueltiger Release-Kanal.' }
if ([string]$manifest.updateMode -cne 'manual-only') {
    throw 'Nur updateMode=manual-only ist freigegeben; Auto-Update/Auto-Execute ist blockiert.'
}

$created = [DateTimeOffset]::MinValue
if (-not [DateTimeOffset]::TryParse([string]$manifest.createdAtUtc, [ref]$created)) {
    throw 'createdAtUtc ist kein gueltiger ISO-Zeitstempel.'
}
if (@($manifest.artifacts).Count -lt 1) {
    throw 'Update-Manifest enthaelt keine Artefakte.'
}

$artifactRootFull = [System.IO.Path]::GetFullPath($ArtifactRoot).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
)
$rootPrefix = $artifactRootFull + [System.IO.Path]::DirectorySeparatorChar
$seen = @{}
$types = New-Object System.Collections.Generic.HashSet[string]

foreach ($artifact in @($manifest.artifacts)) {
    Assert-ExactProperties -Object $artifact -Allowed @('artifactType','fileName','relativePath','sizeBytes','sha256','signature') -Required @('artifactType','fileName','relativePath','sizeBytes','sha256','signature') -Context 'Artefakt'
    Assert-ExactProperties -Object $artifact.signature -Allowed @('kind','status','signerThumbprint') -Required @('kind','status','signerThumbprint') -Context 'Artefakt.signature'

    $type = [string]$artifact.artifactType
    if ($type -notin @('desktop-zip','portable-zip','installer-exe')) {
        throw "Nicht freigegebener Artefakttyp: $type"
    }
    [void]$types.Add($type)

    $relative = ([string]$artifact.relativePath).Replace('\','/')
    if ([string]::IsNullOrWhiteSpace($relative) -or [System.IO.Path]::IsPathRooted($relative)) {
        throw "Unsicherer Artefaktpfad: $relative"
    }
    if (@($relative -split '/') -contains '..') {
        throw "Path-Traversal im Artefaktpfad blockiert: $relative"
    }
    if ($relative -match '^[a-zA-Z][a-zA-Z0-9+.-]*://') {
        throw "URL statt lokalem Artefaktpfad ist blockiert: $relative"
    }
    if ($seen.ContainsKey($relative.ToLowerInvariant())) {
        throw "Doppelter Artefaktpfad im Manifest: $relative"
    }
    $seen[$relative.ToLowerInvariant()] = $true

    $fullPath = [System.IO.Path]::GetFullPath((Join-Path $artifactRootFull $relative))
    if (-not $fullPath.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Artefakt verlaesst ArtifactRoot: $relative"
    }
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        throw "Manifest-Artefakt fehlt lokal: $relative"
    }

    $item = Get-Item -LiteralPath $fullPath
    if ([long]$artifact.sizeBytes -ne [long]$item.Length) {
        throw "Groesse stimmt nicht: $relative"
    }

    $expectedHash = ([string]$artifact.sha256).ToUpperInvariant()
    if ($expectedHash -notmatch '^[A-F0-9]{64}$') {
        throw "Ungueltiger SHA256-Wert: $relative"
    }
    $actualHash = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($actualHash -ne $expectedHash) {
        throw "SHA256 stimmt nicht: $relative"
    }

    $expectedName = [System.IO.Path]::GetFileName($relative)
    if ([string]$artifact.fileName -cne $expectedName) {
        throw "fileName passt nicht zu relativePath: $relative"
    }

    if ($type -eq 'installer-exe') {
        if ([string]$artifact.signature.kind -cne 'authenticode') {
            throw 'Installer-EXE muss signature.kind=authenticode verwenden.'
        }

        if ($RequireSignedArtifacts) {
            if (-not $IsWindows -or -not (Get-Command Get-AuthenticodeSignature -ErrorAction SilentlyContinue)) {
                throw 'Authenticode kann auf diesem System nicht verifiziert werden; Release-Abnahme bleibt blockiert.'
            }

            $actualSignature = Get-AuthenticodeSignature -FilePath $fullPath
            if ($actualSignature.Status -ne [System.Management.Automation.SignatureStatus]::Valid) {
                throw "Installer ist nicht gueltig Authenticode-signiert: $relative ($($actualSignature.Status))"
            }

            if ([string]$artifact.signature.status -cne 'Valid') {
                throw "Manifest weist Installer nicht als gueltig signiert aus: $relative"
            }

            $actualThumbprint = ($actualSignature.SignerCertificate.Thumbprint -replace '\s+','').ToUpperInvariant()
            $manifestThumbprint = ([string]$artifact.signature.signerThumbprint -replace '\s+','').ToUpperInvariant()
            if ([string]::IsNullOrWhiteSpace($manifestThumbprint) -or $manifestThumbprint -cne $actualThumbprint) {
                throw "Signer-Thumbprint stimmt nicht: $relative"
            }
        }
    }
    elseif ([string]$artifact.signature.status -cne 'NotApplicable') {
        throw "ZIP-Artefakt muss signature.status=NotApplicable verwenden: $relative"
    }
}

if ($RequireCompleteSet) {
    foreach ($requiredType in @('desktop-zip','portable-zip')) {
        if (-not $types.Contains($requiredType)) {
            throw "Vollstaendiger Release-Satz fehlt: $requiredType"
        }
    }
}
if ($RequireInstaller -and -not $types.Contains('installer-exe')) {
    throw 'Release-Abnahme verlangt eine Installer-EXE, aber das Manifest enthaelt keine.'
}

Write-Host "UPDATE_MANIFEST_VALID=YES"
Write-Host "UPDATE_VERSION=$($manifest.version)"
Write-Host "UPDATE_ARTIFACTS=$(@($manifest.artifacts).Count)"
Write-Host "UPDATE_MODE=$($manifest.updateMode)"
