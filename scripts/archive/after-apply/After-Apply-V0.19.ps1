$ErrorActionPreference = 'Stop'

function Invoke-Step {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][scriptblock]$Command
    )

    Write-Host "[v0.19.0] $Name..." -ForegroundColor Cyan
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "Schritt fehlgeschlagen: $Name (ExitCode=$LASTEXITCODE)"
    }
}

function Set-TextFile {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Content
    )
    Set-Content -LiteralPath $Path -Value $Content -Encoding utf8NoBOM
}

function Replace-Required {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Pattern,
        [Parameter(Mandatory=$true)][string]$Replacement,
        [Parameter(Mandatory=$true)][string]$Description
    )

    $content = Get-Content -LiteralPath $Path -Raw
    $updated = [regex]::Replace($content, $Pattern, $Replacement)
    if ($updated -eq $content) {
        throw "Erwartete Stelle nicht gefunden in ${Path}: ${Description}"
    }
    Set-TextFile -Path $Path -Content $updated
    Write-Host "[v0.19.0] $Description" -ForegroundColor Green
}

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

# Alte defekte v0.18.0-Artefakte entfernen, falls sie nach dem abgebrochenen Lauf noch herumliegen.
Remove-Item -LiteralPath (Join-Path $root 'scripts/After-Apply-V0.18.ps1') -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $root 'docs/HANDOFF_0_18_0.md') -Force -ErrorAction SilentlyContinue

Replace-Required -Path 'src/SchachTurnierManager.WebApp/package.json' -Pattern '"version"\s*:\s*"0\.\d+\.\d+"' -Replacement '"version": "0.19.0"' -Description 'package.json auf 0.19.0 gesetzt'
Replace-Required -Path 'src/SchachTurnierManager.WebApp/package-lock.json' -Pattern '"version"\s*:\s*"0\.\d+\.\d+"' -Replacement '"version": "0.19.0"' -Description 'package-lock.json auf 0.19.0 gesetzt'
Replace-Required -Path 'src/SchachTurnierManager.WebApi/Program.cs' -Pattern 'version\s*=\s*"0\.\d+\.\d+"' -Replacement 'version = "0.19.0"' -Description 'API-Version auf 0.19.0 gesetzt'
Replace-Required -Path 'src/SchachTurnierManager.WebApp/src/main.tsx' -Pattern 'Lokaler Turnierleiter · v0\.\d+\.\d+' -Replacement 'Lokaler Turnierleiter · v0.19.0' -Description 'Dashboard-Version auf 0.19.0 gesetzt'

$changelogPath = Join-Path $root 'CHANGELOG.md'
$changelog = Get-Content -LiteralPath $changelogPath -Raw
if ($changelog -notmatch '## 0\.19\.0 - Swiss-Chess-Paritätsroadmap') {
    $entry = @'
## 0.19.0 - Swiss-Chess-Paritätsroadmap

- Funktionsmatrix für Swiss-Chess-/Swiss-Manager-artige Turnierverwaltung ergänzt.
- Offene Blöcke für Schweizer System, Mannschaftsturniere, Import/Export, Ratingauswertung, Druck, Betrieb und Support dokumentiert.
- Priorisierte Roadmap für die nächsten Entwicklungsphasen ergänzt.

'@
    $changelog = $changelog -replace '(# Changelog\s*)', "`$1`r`n$entry"
    Set-TextFile -Path $changelogPath -Content $changelog
    Write-Host '[v0.19.0] CHANGELOG.md ergänzt' -ForegroundColor Green
}
else {
    Write-Host '[v0.19.0] CHANGELOG.md enthält 0.19.0 bereits.' -ForegroundColor Yellow
}

Invoke-Step 'dotnet restore' { dotnet restore }
Invoke-Step 'dotnet build' { dotnet build }
Invoke-Step 'dotnet test' { dotnet test }

$webApp = Join-Path $root 'src/SchachTurnierManager.WebApp'
Set-Location $webApp
Invoke-Step 'npm install' { npm install }
Invoke-Step 'npm run build' { npm run build }

Set-Location $root
Invoke-Step 'Pack-Portable' { pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scripts/Pack-Portable.ps1') }

Write-Host '[v0.19.0] Nachkontrolle abgeschlossen. Bitte danach git status prüfen und committen.' -ForegroundColor Green
git status --short
