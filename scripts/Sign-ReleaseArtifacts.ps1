[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $true)]
    [string[]]$ArtifactPath,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Fa-f0-9]{40,64}$')]
    [string]$CertificateThumbprint,

    [string]$TimestampServer,

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

$normalizedThumbprint = ($CertificateThumbprint -replace '\s+', '').ToUpperInvariant()
$certificate = Get-ChildItem -Path Cert:\CurrentUser\My |
    Where-Object { ($_.Thumbprint -replace '\s+', '').ToUpperInvariant() -eq $normalizedThumbprint } |
    Select-Object -First 1

if (-not $certificate) {
    throw "Code-Signing-Zertifikat wurde in Cert:\CurrentUser\My nicht gefunden: $normalizedThumbprint"
}
if (-not $certificate.HasPrivateKey) {
    throw 'Das ausgewaehlte Zertifikat besitzt keinen privaten Schluessel.'
}

$codeSigningOid = '1.3.6.1.5.5.7.3.3'
$ekuOids = @($certificate.Extensions |
    Where-Object { $_ -is [System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension] } |
    ForEach-Object { $_.EnhancedKeyUsages | ForEach-Object { $_.Value } })
if ($ekuOids -notcontains $codeSigningOid) {
    throw 'Das ausgewaehlte Zertifikat ist nicht fuer Code Signing (EKU 1.3.6.1.5.5.7.3.3) freigegeben.'
}
if ($certificate.NotAfter -le (Get-Date)) {
    throw 'Das ausgewaehlte Code-Signing-Zertifikat ist abgelaufen.'
}

$outputRoot = (Join-Path $Root 'output')
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

    $parameters = @{
        FilePath      = $artifact
        Certificate   = $certificate
        HashAlgorithm = 'SHA256'
    }
    if (-not [string]::IsNullOrWhiteSpace($TimestampServer)) {
        $uri = $null
        if (-not [Uri]::TryCreate($TimestampServer, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne 'https') {
            throw 'TimestampServer muss eine absolute HTTPS-URL sein.'
        }
        $parameters.TimestampServer = $uri.AbsoluteUri
    }

    $signature = Set-AuthenticodeSignature @parameters
    if ($signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid) {
        throw "Authenticode-Signierung ist nicht gueltig: $artifact ($($signature.Status): $($signature.StatusMessage))"
    }

    $hash = Get-FileHash -LiteralPath $artifact -Algorithm SHA256
    Write-Host "SIGNED=$artifact"
    Write-Host "SIGNER_THUMBPRINT=$normalizedThumbprint"
    Write-Host "SHA256=$($hash.Hash)"
}
