[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $true)]
    [string[]]$ArtifactPath,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Fa-f0-9]{40,64}$')]
    [string]$CertificateThumbprint,

    [string]$TimestampServer,

    [string]$SignToolPath,

    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,

    [switch]$ApproveSigning
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $IsWindows) {
    throw 'Authenticode-Signierung ist in diesem Projekt nur auf Windows freigegeben.'
}
if (-not $ApproveSigning) {
    throw 'Signierung ist eine mutierende Release-Aktion. Explizite Freigabe mit -ApproveSigning ist erforderlich.'
}

function Resolve-SignTool {
    if (-not [string]::IsNullOrWhiteSpace($SignToolPath)) {
        if (-not (Test-Path -LiteralPath $SignToolPath -PathType Leaf)) {
            throw "Angegebenes signtool.exe wurde nicht gefunden: $SignToolPath"
        }
        return (Resolve-Path -LiteralPath $SignToolPath).Path
    }

    $command = Get-Command 'signtool.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) {
        return $command.Source
    }

    $programFilesX86 = [Environment]::GetFolderPath('ProgramFilesX86')
    if (-not [string]::IsNullOrWhiteSpace($programFilesX86)) {
        $kitsRoot = Join-Path $programFilesX86 'Windows Kits\10\bin'
        if (Test-Path -LiteralPath $kitsRoot -PathType Container) {
            $candidates = @(Get-ChildItem -LiteralPath $kitsRoot -Directory -ErrorAction SilentlyContinue |
                Sort-Object Name -Descending |
                ForEach-Object { Join-Path $_.FullName 'x64\signtool.exe' } |
                Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
            if ($candidates.Count -gt 0) {
                return $candidates[0]
            }
        }
    }

    throw 'signtool.exe wurde nicht gefunden. Windows SDK/SignTool installieren oder -SignToolPath angeben.'
}

$normalizedThumbprint = ($CertificateThumbprint -replace '\s+', '').ToUpperInvariant()
$signTool = Resolve-SignTool

if (-not [string]::IsNullOrWhiteSpace($TimestampServer)) {
    $uri = $null
    if (-not [Uri]::TryCreate($TimestampServer, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne 'https') {
        throw 'TimestampServer muss eine absolute HTTPS-URL sein.'
    }
    $TimestampServer = $uri.AbsoluteUri
}

$outputRoot = Join-Path $Root 'output'
$outputRootFull = [System.IO.Path]::GetFullPath($outputRoot).TrimEnd([System.IO.Path]::DirectorySeparatorChar) +
    [System.IO.Path]::DirectorySeparatorChar

$resolvedArtifacts = foreach ($path in $ArtifactPath) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Signierartefakt wurde nicht gefunden: $path"
    }

    $fullPath = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $path).Path)
    if (-not $fullPath.StartsWith($outputRootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Signierung ausserhalb von output/ ist blockiert: $fullPath"
    }

    if ([System.IO.Path]::GetExtension($fullPath).ToLowerInvariant() -ne '.exe') {
        throw "Nur freigegebene Windows-EXE-Artefakte duerfen signiert werden: $fullPath"
    }

    $fullPath
}

foreach ($artifact in $resolvedArtifacts | Select-Object -Unique) {
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
    if ($signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid -or -not $signature.SignerCertificate) {
        throw "Authenticode-Signatur ist nach dem Signieren nicht gueltig: $artifact ($($signature.Status))"
    }

    $actualThumbprint = ($signature.SignerCertificate.Thumbprint -replace '\s+','').ToUpperInvariant()
    if ($actualThumbprint -cne $normalizedThumbprint) {
        throw "Unerwarteter Signer nach Signierung: $artifact"
    }

    $codeSigningOid = '1.3.6.1.5.5.7.3.3'
    $ekuOids = @($signature.SignerCertificate.Extensions |
        Where-Object { $_ -is [System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension] } |
        ForEach-Object { $_.EnhancedKeyUsages | ForEach-Object { $_.Value } })
    if ($ekuOids -notcontains $codeSigningOid) {
        throw "Signer-Zertifikat besitzt keine Code-Signing-EKU: $artifact"
    }

    $hash = Get-FileHash -LiteralPath $artifact -Algorithm SHA256
    Write-Host "SIGNED=$artifact"
    Write-Host "SIGNER_THUMBPRINT=$normalizedThumbprint"
    Write-Host "SHA256=$($hash.Hash)"
}
