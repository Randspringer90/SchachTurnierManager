param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [switch]$SkipPack,
    [switch]$NoNpmInstall,
    [switch]$NoDotnetTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-NativeStep {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][scriptblock]$Script
    )

    Write-Host "[ReleaseGate] $Name..."
    & $Script
    if ($LASTEXITCODE -ne 0) {
        throw "$Name ist fehlgeschlagen mit Exitcode $LASTEXITCODE."
    }
}

function Write-NodeEngineHint {
    $nodeVersionRaw = $null
    try {
        $nodeVersionRaw = (& node --version 2>$null)
    } catch {
        Write-Warning 'Node.js konnte nicht ermittelt werden. npm run build wird wahrscheinlich fehlschlagen.'
        return
    }

    if (-not $nodeVersionRaw) {
        Write-Warning 'Node.js konnte nicht ermittelt werden. npm run build wird wahrscheinlich fehlschlagen.'
        return
    }

    $nodeVersion = $nodeVersionRaw.TrimStart('v')
    $parts = $nodeVersion.Split('.') | ForEach-Object { [int]$_ }
    $isSupported = $false
    if ($parts[0] -gt 22) {
        $isSupported = $true
    } elseif ($parts[0] -eq 22 -and $parts[1] -ge 12) {
        $isSupported = $true
    } elseif ($parts[0] -eq 20 -and $parts[1] -ge 21) {
        $isSupported = $true
    }

    if ($isSupported) {
        Write-Host "[ReleaseGate] Node.js $nodeVersionRaw passt zur Vite/Rolldown-Engine-Anforderung."
    } else {
        Write-Warning "Node.js $nodeVersionRaw ist unter der Vite/Rolldown-Anforderung (^20.21.0 || >=22.12.0). Der Build lief bisher trotzdem, aber ein Update ist empfohlen."
    }
}

function Assert-NoKnownBadFiles {
    $badFiles = @('tatus')
    foreach ($badFile in $badFiles) {
        $path = Join-Path $Root $badFile
        if (Test-Path -LiteralPath $path) {
            throw "Bekannte versehentliche Datei gefunden: $badFile. Bitte entfernen, bevor committed wird."
        }
    }
}

$webApp = Join-Path $Root 'src/SchachTurnierManager.WebApp'
if (-not (Test-Path -LiteralPath (Join-Path $Root 'SchachTurnierManager.sln'))) {
    throw "Root wirkt nicht wie der Projektordner: $Root"
}
if (-not (Test-Path -LiteralPath (Join-Path $webApp 'package.json'))) {
    throw "WebApp package.json nicht gefunden: $webApp"
}

Push-Location $Root
try {
    Assert-NoKnownBadFiles
    Write-NodeEngineHint

    $dependencyReport = @()
    Invoke-NativeStep 'Dependency supply-chain safety' {
        $script:dependencyReport = @(pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'scripts/Test-DependencySupplyChainSafety.ps1') -Root $Root 2>&1)
        $script:dependencyReport | ForEach-Object { Write-Host $_ }
    }
    # PARTIAL provenance or minimum-only NuGet pins are allowed but must stay visible in the verdict.
    $dependencyLimits = @($dependencyReport | ForEach-Object { [string]$_ } | Where-Object { $_ -match '^DEPENDENCY_(PROVENANCE=PARTIAL|NUGET_PINNING=MINIMUM_ONLY)' })
    $lockPath = Join-Path $webApp 'package-lock.json'
    $lockHashBefore = (Get-FileHash -LiteralPath $lockPath -Algorithm SHA256).Hash

    Invoke-NativeStep 'dotnet restore' { dotnet restore }
    Invoke-NativeStep 'dotnet build' { dotnet build }
    if (-not $NoDotnetTest) {
        Invoke-NativeStep 'dotnet test' { dotnet test }
    } else {
        Write-Host '[ReleaseGate] dotnet test übersprungen.'
    }

    Push-Location $webApp
    try {
        # npm ci installs exactly the checked lockfile; npm install could rewrite it.
        $npmInstallCommand = 'ci'
        if (-not $NoNpmInstall) {
            Invoke-NativeStep "npm $npmInstallCommand" { pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'scripts/Invoke-NpmSafe.ps1') -WorkingDirectory $webApp -NpmCommand $npmInstallCommand -NoAudit -NoFund }
        } else {
            Write-Host "[ReleaseGate] npm $npmInstallCommand übersprungen."
        }
        # STM-FE-014: the frontend test suite guards the extracted modules and the
        # in-app confirmation dialogs, so it has to run before `npm run build`.
        Invoke-NativeStep 'npm test' { pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'scripts/Invoke-NpmSafe.ps1') -WorkingDirectory $webApp -NpmCommand run -NpmScript test }
        Invoke-NativeStep 'npm run build' { pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'scripts/Invoke-NpmSafe.ps1') -WorkingDirectory $webApp -NpmCommand run -NpmScript build }
    } finally {
        Pop-Location
    }

    function Assert-LockfileUnchanged([string]$Stage) {
        if ((Get-FileHash -LiteralPath $lockPath -Algorithm SHA256).Hash -ne $lockHashBefore) {
            throw "package-lock.json wurde $Stage veraendert; von der geprueften Lockfile darf nicht abgewichen werden."
        }
    }
    # Check before packaging so a deviation never reaches a package build.
    Assert-LockfileUnchanged 'vor der Paketierung'

    if (-not $SkipPack) {
        Invoke-NativeStep 'Pack-Portable' { pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'scripts/Pack-Portable.ps1') }
    } else {
        Write-Host '[ReleaseGate] Pack-Portable übersprungen.'
    }

    Assert-NoKnownBadFiles
    Assert-LockfileUnchanged 'waehrend der Paketierung'
    $limitNote = if ($dependencyLimits.Count) { ' Einschraenkung: ' + ($dependencyLimits -join '; ') + ' (keine vollstaendige Herkunftsfreigabe).' } else { '' }
    if ($SkipPack) {
        Write-Host "[ReleaseGate] Gruen: Restore, Build, Tests und Frontend-Build erfolgreich; Paketierung uebersprungen.$limitNote"
    } else {
        Write-Host "[ReleaseGate] Gruen: Restore, Build, Tests, Frontend-Build und Paketierung erfolgreich.$limitNote"
    }
    git status --short
} finally {
    Pop-Location
}
