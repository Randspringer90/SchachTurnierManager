param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [ValidateRange(60, 3600)][int]$StepTimeoutSeconds = 900,
    [switch]$KeepPackage
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path $Root).Path
$gateBase = Join-Path $repoRoot 'tmp\portable-package-gate'
$gateRoot = Join-Path $gateBase (Get-Date -Format 'yyyyMMdd-HHmmss')
$outputRoot = Join-Path $gateRoot 'output'
$portableRoot = Join-Path $outputRoot 'portable'
$logRoot = Join-Path $repoRoot ("tmp\portable-package-gate-logs\{0}" -f (Split-Path -Leaf $gateRoot))
$packScript = Join-Path $repoRoot 'scripts\Pack-Portable.ps1'
$safetyScript = Join-Path $repoRoot 'scripts\Test-GitCommitSafety.ps1'

function Write-GateStep {
    param([Parameter(Mandatory = $true)][string]$Text)
    Write-Host "[PortableGate] $Text"
}

function Assert-UnderRepoTmp {
    param([Parameter(Mandatory = $true)][string]$Path)

    $repoFull = [System.IO.Path]::GetFullPath($repoRoot).TrimEnd('\', '/')
    $targetFull = [System.IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
    $tmpFull = [System.IO.Path]::GetFullPath((Join-Path $repoRoot 'tmp')).TrimEnd('\', '/')
    if (-not $targetFull.StartsWith($tmpFull + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Unsicherer Gate-Pfad ausserhalb von tmp/: $targetFull"
    }
    if (-not $targetFull.StartsWith($repoFull + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Unsicherer Gate-Pfad ausserhalb des Repositories: $targetFull"
    }
}

function Assert-Exists {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$Label fehlt: $Path"
    }
}

function Assert-NoForbiddenPackageFiles {
    $blockedPathRegex = '(?i)(^|[\\/])(local-input|local-data|logs|output|tmp|bin|obj|dist|node_modules)([\\/]|$)'
    $blockedFileRegex = '(?i)(^|[\\/])\.env(\.|$)|\.(db|sqlite|sqlite3|key|pem|pfx|p12|dump|dmp|log|zip|7z|rar)$'

    $files = Get-ChildItem -LiteralPath $portableRoot -Recurse -Force -File
    foreach ($file in $files) {
        $relative = [System.IO.Path]::GetRelativePath($portableRoot, $file.FullName) -replace '\\', '/'
        if ($relative -match $blockedPathRegex -or $relative -match $blockedFileRegex) {
            throw "Unerlaubte Datei im Portable-Paket: $relative"
        }
    }
}

function Assert-NoForbiddenStagedFiles {
    $blockedStagedRegex = '(?i)(^|/)(local-input|local-data|logs|output|tmp|bin|obj|dist|node_modules)(/|$)|\.(zip|7z|rar|nupkg|db|sqlite|sqlite3|log|dmp|dump|key|pem|pfx|p12)$|(^|/)\.env$|(^|/)\.env\.(?!example$)'
    $entries = git -C $repoRoot diff --cached --name-status
    foreach ($entry in $entries) {
        if ([string]::IsNullOrWhiteSpace($entry)) { continue }
        $parts = $entry -split "`t"
        foreach ($path in $parts[1..($parts.Length - 1)]) {
            $normalized = $path -replace '\\', '/'
            if ($normalized -match $blockedStagedRegex) {
                throw "Verbotene generierte/private Datei ist staged: $normalized"
            }
        }
    }
}

function Remove-DirectoryWithRetry {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [ValidateRange(1, 20)][int]$Attempts = 10,
        [switch]$WarnOnly
    )

    $aclAdjusted = $false
    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        try {
            Remove-Item -Recurse -Force -LiteralPath $Path -ErrorAction Stop
            return $true
        }
        catch {
            if (-not $aclAdjusted -and $attempt -ge 2) {
                try {
                    $sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
                    & icacls $Path /grant "*${sid}:(OI)(CI)F" /T /C *> $null
                    $aclAdjusted = $true
                }
                catch { }
            }
            if ($attempt -eq $Attempts) {
                if ($WarnOnly) {
                    Write-Warning "[PortableGate] Konnte gitignored Temp-Verzeichnis nicht entfernen: $Path ($($_.Exception.Message))"
                    return $false
                }
                throw
            }
            Start-Sleep -Milliseconds (250 * $attempt)
        }
    }
}

if (-not (Test-Path -LiteralPath (Join-Path $repoRoot 'SchachTurnierManager.sln'))) {
    throw "Root wirkt nicht wie der Projektordner: $repoRoot"
}
Assert-Exists $packScript 'Pack-Skript'
Assert-UnderRepoTmp $gateBase
Assert-UnderRepoTmp $gateRoot
Assert-UnderRepoTmp $outputRoot
Assert-UnderRepoTmp $logRoot

try {
    New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null

    Write-GateStep "Pruefe Staging auf private/generierte Dateien."
    Assert-NoForbiddenStagedFiles
    if (Test-Path -LiteralPath $safetyScript) {
        & pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $safetyScript -Staged
        if ($LASTEXITCODE -ne 0) {
            throw "Git-Sicherheitspruefung fuer staged Dateien ist fehlgeschlagen."
        }
    }

    Write-GateStep "Baue Portable-Paket in gitignored tmp/ mit Timeout ${StepTimeoutSeconds}s pro nativen Schritt."
    & $packScript -OutputRoot $outputRoot -LogRoot $logRoot -NoZip -StepTimeoutSeconds $StepTimeoutSeconds

    Write-GateStep "Pruefe Portable-Artefakte."
    Assert-Exists (Join-Path $portableRoot 'app') 'app-Verzeichnis'
    Assert-Exists (Join-Path $portableRoot 'data') 'data-Verzeichnis'
    Assert-Exists (Join-Path $portableRoot 'Start-SchachTurnierManager.bat') 'Start-BAT'
    Assert-Exists (Join-Path $portableRoot 'README-Portable.md') 'Portable-README'
    Assert-Exists (Join-Path $portableRoot 'app\SchachTurnierManager.WebApi.dll') 'WebApi-DLL'
    Assert-Exists (Join-Path $portableRoot 'app\wwwroot\index.html') 'Eingebettetes Dashboard'

    $dataFiles = @(Get-ChildItem -LiteralPath (Join-Path $portableRoot 'data') -Force)
    if ($dataFiles.Count -ne 0) {
        throw "data-Verzeichnis im Portable-Paket ist nicht leer."
    }
    Assert-NoForbiddenPackageFiles

    git -C $repoRoot check-ignore -q -- 'tmp/portable-package-gate/'
    if ($LASTEXITCODE -ne 0) {
        throw "tmp/portable-package-gate/ ist nicht gitignored."
    }

    Write-GateStep "OK: Portable-Paket ist baubar, synthetisch und nicht staged."
    Write-GateStep "Diagnose-Logs bleiben gitignored unter: $logRoot"
}
finally {
    if (-not $KeepPackage -and (Test-Path -LiteralPath $gateRoot)) {
        Assert-UnderRepoTmp $gateRoot
        if (Remove-DirectoryWithRetry $gateRoot -WarnOnly) {
            Write-GateStep "Gate-Artefakte aus tmp/ entfernt."
        }
    }
    elseif ($KeepPackage) {
        Write-GateStep "Gate-Artefakte behalten: $gateRoot"
    }
}
