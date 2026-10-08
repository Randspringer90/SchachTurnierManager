param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$RunName = 'STM_RUN50_ReleaseCandidateReadiness',
    [string]$BaseDirectory = 'D:\Temp',
    [switch]$BuildInstaller,
    [switch]$AllowMissingInnoSetup,
    [switch]$SignArtifacts,
    [ValidatePattern('^[A-Fa-f0-9]{40,64}$')]
    [string]$SigningCertificateThumbprint,
    [string]$TimestampServer,
    [switch]$RequireSignedArtifacts
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-SafeFileName([string]$Value) {
    $safe = $Value -replace '[^a-zA-Z0-9_.-]+', '_'
    if ([string]::IsNullOrWhiteSpace($safe)) { return 'run' }
    return $safe.Trim('_')
}

function ConvertTo-PowerShellLiteral([string]$Value) {
    return "'" + ($Value -replace "'", "''") + "'"
}

if ($SignArtifacts -and [string]::IsNullOrWhiteSpace($SigningCertificateThumbprint)) {
    throw '-SignArtifacts verlangt -SigningCertificateThumbprint.'
}
if (-not [string]::IsNullOrWhiteSpace($TimestampServer) -and -not $SignArtifacts) {
    throw '-TimestampServer ist nur zusammen mit -SignArtifacts zulaessig.'
}
if ($RequireSignedArtifacts -and -not $SignArtifacts) {
    throw '-RequireSignedArtifacts verlangt in diesem Rebuild-Lauf auch -SignArtifacts.'
}
if ($RequireSignedArtifacts -and -not $BuildInstaller) {
    throw '-RequireSignedArtifacts verlangt -BuildInstaller, damit die Setup-EXE mitgeprueft wird.'
}
if ($RequireSignedArtifacts -and $AllowMissingInnoSetup) {
    throw '-RequireSignedArtifacts ist nicht mit -AllowMissingInnoSetup vereinbar.'
}

function New-ReleaseRunDirectory {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$DirectoryRoot
    )

    $safeName = ConvertTo-SafeFileName $Name
    $leafName = $safeName + '_' + (Get-Date -Format yyyyMMdd_HHmmss)
    $candidate = Join-Path $DirectoryRoot $leafName
    New-Item -ItemType Directory -Force -Path $candidate | Out-Null
    return (Resolve-Path -LiteralPath $candidate).Path
}

$bundleScript = Join-Path $PSScriptRoot 'New-RunLogBundle.ps1'
$loggedCommandScript = Join-Path $PSScriptRoot 'Invoke-LoggedCommand.ps1'
$runDirectory = New-ReleaseRunDirectory -Name $RunName -DirectoryRoot $BaseDirectory
Write-Host "RUN_DIR=$runDirectory"

function Invoke-Logged {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$CommandLine
    )

    & $loggedCommandScript -RunDirectory $runDirectory -Name $Name -WorkingDirectory $Root -CommandLine $CommandLine
}

function Write-ArtifactManifest {
    if ([string]::IsNullOrWhiteSpace($runDirectory)) {
        return
    }

    $outputRoot = Join-Path $Root 'output'
    $manifestPath = Join-Path $runDirectory 'release-artifacts-manifest.txt'
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('Release candidate artifact manifest')
    $lines.Add("Root: $Root")
    $lines.Add("Created: $(Get-Date -Format o)")
    $lines.Add('')

    if (Test-Path -LiteralPath $outputRoot) {
        $files = @(Get-ChildItem -LiteralPath $outputRoot -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -in @('.zip', '.exe', '.json') } |
            Sort-Object FullName)
        if ($files.Count -eq 0) {
            $lines.Add('Keine Release-Artefakte unter output/ gefunden.')
        }
        foreach ($file in $files) {
            $hash = Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256
            $relative = $file.FullName.Substring($outputRoot.Length).TrimStart([char]'\', [char]'/')
            $separator = [char]9
            $lines.Add($relative + $separator + $file.Length + ' bytes' + $separator + 'SHA256=' + $hash.Hash)
        }
    }
    else {
        $lines.Add('output/ existiert noch nicht.')
    }

    $lines | Set-Content -Encoding UTF8 -LiteralPath $manifestPath
}

function Resolve-UploadZipPath {
    Write-ArtifactManifest
    $zipPath = & $bundleScript -RunDirectory $runDirectory -RunName $RunName
    if ([string]::IsNullOrWhiteSpace($zipPath)) {
        $zipPath = Join-Path (Split-Path -Parent $runDirectory) ("$(Split-Path -Leaf $runDirectory).zip")
    }

    if (-not (Test-Path -LiteralPath $zipPath -PathType Leaf)) {
        throw "Run-ZIP wurde nicht erzeugt: $zipPath"
    }

    return (Resolve-Path -LiteralPath $zipPath).Path
}

function Complete-RunBundle {
    $zipPath = Resolve-UploadZipPath
    Write-Host "UPLOAD_ZIP=$zipPath"
}

try {
    $signingSuffix = ''
    if ($SignArtifacts) {
        $signingSuffix = " -SignArtifacts -SigningCertificateThumbprint $(ConvertTo-PowerShellLiteral $SigningCertificateThumbprint)"
        if (-not [string]::IsNullOrWhiteSpace($TimestampServer)) {
            $signingSuffix += " -TimestampServer $(ConvertTo-PowerShellLiteral $TimestampServer)"
        }
    }

    Invoke-Logged -Name 'releasegate-full' -CommandLine 'pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-ReleaseGate.ps1'
    Invoke-Logged -Name 'secret-safety' -CommandLine 'pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-SecretSafetyReadiness.ps1'
    Invoke-Logged -Name 'publish-desktop' -CommandLine ("pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Publish-DesktopApp.ps1" + $signingSuffix)
    Invoke-Logged -Name 'portable-selfcontained' -CommandLine ("pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Pack-Portable.ps1 -SelfContained" + $signingSuffix)

    if ($BuildInstaller) {
        if ($AllowMissingInnoSetup) {
            Invoke-Logged -Name 'installer-readiness' -CommandLine ("pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-InstallerReadiness.ps1 -BuildInstaller -AllowMissingInnoSetup" + $signingSuffix)
        }
        else {
            Invoke-Logged -Name 'installer-build' -CommandLine ("pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build-Installer.ps1 -SkipPublish" + $signingSuffix)
        }
    }
    else {
        'Installer-Build uebersprungen. Fuer echten Setup-Test mit -BuildInstaller erneut ausfuehren.' |
            Set-Content -Encoding UTF8 -LiteralPath (Join-Path $runDirectory 'installer-build-skipped.txt')
    }

    $trustCommand = 'pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-ReleaseTrustReadiness.ps1'
    if ($BuildInstaller) { $trustCommand += ' -RequireInstaller' }
    if ($RequireSignedArtifacts) { $trustCommand += " -RequireSignedArtifacts -ExpectedSignerThumbprint $(ConvertTo-PowerShellLiteral $SigningCertificateThumbprint)" }
    Invoke-Logged -Name 'release-trust-readiness' -CommandLine $trustCommand

    Invoke-Logged -Name 'git-safety-final' -CommandLine 'pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-GitCommitSafety.ps1'
    Complete-RunBundle
}
catch {
    if (-not [string]::IsNullOrWhiteSpace($runDirectory)) {
        $_.Exception.ToString() | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $runDirectory 'FAILED.txt')
        Complete-RunBundle
    }
    throw
}
