param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$RunName = 'STM_RUN50_ReleaseCandidateReadiness',
    [string]$BaseDirectory = 'D:\Temp',
    [switch]$BuildInstaller,
    [switch]$AllowMissingInnoSetup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-SafeFileName([string]$Value) {
    $safe = $Value -replace '[^a-zA-Z0-9_.-]+', '_'
    if ([string]::IsNullOrWhiteSpace($safe)) { return 'run' }
    return $safe.Trim('_')
}

function New-ReleaseRunDirectory {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$DirectoryRoot
    )

    $safeName = ConvertTo-SafeFileName $Name
    $candidate = Join-Path $DirectoryRoot ("${safeName}_$(Get-Date -Format yyyyMMdd_HHmmss)")
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
        $files = @(Get-ChildItem -LiteralPath $outputRoot -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @('.zip', '.exe') } | Sort-Object FullName)
        if ($files.Count -eq 0) {
            $lines.Add('Keine ZIP-/EXE-Artefakte unter output/ gefunden.')
        }
        foreach ($file in $files) {
            $hash = Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256
            $relative = $file.FullName.Substring($outputRoot.Length).TrimStart([char]'\', [char]'/')
            $lines.Add("$relative`t$($file.Length) bytes`tSHA256=$($hash.Hash)")
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
    Invoke-Logged -Name 'releasegate-full' -CommandLine 'pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-ReleaseGate.ps1'
    Invoke-Logged -Name 'secret-safety' -CommandLine 'pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-SecretSafetyReadiness.ps1'
    Invoke-Logged -Name 'publish-desktop' -CommandLine 'pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Publish-DesktopApp.ps1'
    Invoke-Logged -Name 'portable-selfcontained' -CommandLine 'pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Pack-Portable.ps1 -SelfContained'

    if ($BuildInstaller) {
        if ($AllowMissingInnoSetup) {
            Invoke-Logged -Name 'installer-readiness' -CommandLine 'pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-InstallerReadiness.ps1 -BuildInstaller -AllowMissingInnoSetup'
        }
        else {
            Invoke-Logged -Name 'installer-build' -CommandLine 'pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build-Installer.ps1 -SkipPublish'
        }
    }
    else {
        'Installer-Build uebersprungen. Fuer echten Setup-Test mit -BuildInstaller erneut ausfuehren.' | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $runDirectory 'installer-build-skipped.txt')
    }

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
