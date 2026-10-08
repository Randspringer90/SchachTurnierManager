[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $true)]
    [string[]]$ArtifactPath,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Fa-f0-9]{40}$')]
    [string]$CertificateThumbprint,

    [string]$TimestampServer,

    [string]$SignToolPath,

    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,

    [switch]$ApproveSigning
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/ReleaseTrustValidation.ps1')
$Root = Resolve-StmReleasePath -Path $Root -Kind Directory

if (-not $IsWindows) {
    throw 'Authenticode-Signierung ist in diesem Projekt nur auf Windows freigegeben.'
}
if (-not $ApproveSigning) {
    throw 'Signierung ist eine mutierende Release-Aktion. Explizite Freigabe mit -ApproveSigning ist erforderlich.'
}

function Resolve-SignTool {
    if (-not [string]::IsNullOrWhiteSpace($SignToolPath)) {
        return (Resolve-StmReleasePath -Path $SignToolPath -Kind File)
    }

    $command = Get-Command 'signtool.exe' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) {
        return (Resolve-StmReleasePath -Path $command.Source -Kind File)
    }

    $programFilesX86 = [Environment]::GetFolderPath('ProgramFilesX86')
    if (-not [string]::IsNullOrWhiteSpace($programFilesX86)) {
        $kitsRoot = Resolve-StmReleasePath -Path (Join-Path $programFilesX86 'Windows Kits\10\bin') -Kind Directory -AllowMissing
        if (Test-Path -LiteralPath $kitsRoot -PathType Container) {
            $candidates = @(Get-ChildItem -LiteralPath $kitsRoot -Directory -ErrorAction SilentlyContinue |
                Sort-Object Name -Descending |
                ForEach-Object { Join-Path $_.FullName 'x64\signtool.exe' } |
                Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
            if ($candidates.Count -gt 0) {
                return (Resolve-StmReleasePath -Path $candidates[0] -Kind File)
            }
        }
    }

    throw 'signtool.exe wurde nicht gefunden. Windows SDK/SignTool installieren oder -SignToolPath angeben.'
}

$normalizedThumbprint = ConvertTo-StmSignerThumbprint -Value $CertificateThumbprint
$signTool = Resolve-SignTool
if ([IO.Path]::GetFileName($signTool) -ine 'signtool.exe') { throw 'Only the native signtool.exe is accepted.' }

if (-not [string]::IsNullOrWhiteSpace($TimestampServer)) {
    $uri = $null
    if (-not [Uri]::TryCreate($TimestampServer, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne 'https') {
        throw 'TimestampServer muss eine absolute HTTPS-URL sein.'
    }
    $TimestampServer = $uri.AbsoluteUri
}

$outputRoot = Resolve-StmReleasePath -Path (Join-Path $Root 'output') -Kind Directory

$resolvedArtifacts = foreach ($path in $ArtifactPath) {
    $fullPath = Resolve-StmReleasePath -Path $path -Boundary $outputRoot -Kind File

    if ([System.IO.Path]::GetExtension($fullPath).ToLowerInvariant() -ne '.exe') {
        throw "Nur freigegebene Windows-EXE-Artefakte duerfen signiert werden: $fullPath"
    }

    $fullPath
}

foreach ($artifact in $resolvedArtifacts | Select-Object -Unique) {
    $artifact = Resolve-StmReleasePath -Path $artifact -Boundary $outputRoot -Kind File
    if (-not $PSCmdlet.ShouldProcess($artifact, "Authenticode SHA256 mit Zertifikat $normalizedThumbprint signieren")) {
        continue
    }

    $arguments = @('sign','/sha1',$normalizedThumbprint,'/fd','SHA256','/v')
    if (-not [string]::IsNullOrWhiteSpace($TimestampServer)) {
        $arguments += @('/tr',$TimestampServer,'/td','SHA256')
    }
    $arguments += $artifact

    & $signTool @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "signtool.exe fehlgeschlagen (ExitCode=$LASTEXITCODE): $artifact"
    }

    $signature = Get-AuthenticodeSignature -FilePath $artifact
    Assert-StmReleaseSignature -Signature $signature -ExpectedSignerThumbprint $normalizedThumbprint

    $hash = Get-FileHash -LiteralPath $artifact -Algorithm SHA256
    Write-Host "SIGNED=$artifact"
    Write-Host "SIGNER_THUMBPRINT=$normalizedThumbprint"
    Write-Host "SHA256=$($hash.Hash)"
}
