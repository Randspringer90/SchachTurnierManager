param(
    [switch]$NoPause
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$version = '0.22.2'
$root = Split-Path -Parent $PSScriptRoot

function Write-Step([string]$Message) {
    Write-Host "[v$version] $Message"
}

function Path-FromRoot([string]$RelativePath) {
    return Join-Path $root $RelativePath
}

function Get-Text([string]$RelativePath) {
    return Get-Content -LiteralPath (Path-FromRoot $RelativePath) -Raw -Encoding UTF8
}

function Set-Text([string]$RelativePath, [string]$Content) {
    $full = Path-FromRoot $RelativePath
    $parent = Split-Path -Parent $full
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Set-Content -LiteralPath $full -Value $Content -Encoding UTF8 -NoNewline
}

function Replace-VersionEverywhere([string]$RelativePath, [string]$Description) {
    $text = Get-Text $RelativePath
    $updated = $text -replace '0\.22\.1', $version
    $updated = $updated -replace '0\.22\.0', $version
    $updated = $updated -replace '0\.21\.0', $version
    $updated = $updated -replace '0\.20\.5', $version
    Set-Text $RelativePath $updated
    Write-Step $Description
}

function Set-PackageJsonVersion([string]$RelativePath, [string]$Description) {
    $text = Get-Text $RelativePath
    $pattern = '(?m)^(\s*"version"\s*:\s*")[^"]+("\s*,?)'
    if ($text -notmatch $pattern) {
        throw "Version nicht gefunden in ${RelativePath}"
    }
    $updated = [regex]::Replace($text, $pattern, "`${1}$version`${2}", 1)
    Set-Text $RelativePath $updated
    Write-Step $Description
}

function Set-PackageLockVersion([string]$RelativePath, [string]$Description) {
    $text = Get-Text $RelativePath
    $rx = [regex]'(?m)^(\s*"version"\s*:\s*")[^"]+("\s*,?)'
    $matches = $rx.Matches($text)
    if ($matches.Count -lt 1) {
        throw "Version nicht gefunden in ${RelativePath}"
    }

    $maxIndex = [Math]::Min(1, $matches.Count - 1)
    for ($i = $maxIndex; $i -ge 0; $i--) {
        $match = $matches[$i]
        $replacement = $match.Groups[1].Value + $version + $match.Groups[2].Value
        $text = $text.Remove($match.Index, $match.Length).Insert($match.Index, $replacement)
    }

    Set-Text $RelativePath $text
    Write-Step $Description
}

function Require-File([string]$RelativePath, [string]$Description) {
    if (-not (Test-Path -LiteralPath (Path-FromRoot $RelativePath))) {
        throw "${Description} fehlt: ${RelativePath}. Bitte Ausgabe schicken, nicht committen."
    }
}

function Require-Text([string]$RelativePath, [string]$Pattern, [string]$Description) {
    $text = Get-Text $RelativePath
    if ($text -notmatch $Pattern) {
        throw "${Description} nicht gefunden in ${RelativePath}. Bitte Ausgabe schicken, nicht committen."
    }
}

function Invoke-Step([string]$Name, [scriptblock]$Action) {
    Write-Step "$Name..."
    $global:LASTEXITCODE = 0
    & $Action
    if ($LASTEXITCODE -ne 0) {
        throw "$Name ist fehlgeschlagen mit Exitcode ${LASTEXITCODE}."
    }
}

foreach ($relative in @(
    'scripts/After-Apply-V0.22.ps1',
    'scripts/After-Apply-V0.22.1.ps1',
    'docs/HANDOFF_0_22_0.md',
    'docs/HANDOFF_0_22_1.md'
)) {
    $full = Path-FromRoot $relative
    if (Test-Path -LiteralPath $full) {
        Remove-Item -LiteralPath $full -Force
        Write-Step "Entfernt alten Zwischenstand: $relative"
    }
}

# Feature aus v0.22.0/v0.22.1 muss vorhanden sein. Dieser Patch stabilisiert nur den abgebrochenen Skriptlauf.
Require-File 'src/SchachTurnierManager.Domain/Models/NextRoundPreview.cs' 'NextRoundPreview-Modell'
Require-File 'tests/SchachTurnierManager.Application.Tests/NextRoundPreviewWorkflowTests.cs' 'Application-Tests für Auslosungsvorschau'
Require-Text 'src/SchachTurnierManager.Application/TournamentService.cs' 'PreviewNextRound' 'TournamentService.PreviewNextRound'
Require-Text 'src/SchachTurnierManager.WebApi/Program.cs' 'preview-next-round' 'API-Endpunkt für Auslosungsvorschau'

Replace-VersionEverywhere 'src/SchachTurnierManager.WebApi/Program.cs' 'API-Version auf 0.22.2 gesetzt'
Set-PackageJsonVersion 'src/SchachTurnierManager.WebApp/package.json' 'package.json auf 0.22.2 gesetzt'
Set-PackageLockVersion 'src/SchachTurnierManager.WebApp/package-lock.json' 'package-lock.json auf 0.22.2 gesetzt'
Replace-VersionEverywhere 'src/SchachTurnierManager.WebApp/src/main.tsx' 'Dashboard-Version auf 0.22.2 gesetzt'

$changelog = Get-Text 'CHANGELOG.md'
if ($changelog -notmatch '## 0\.22\.2') {
    $entry = @"
## 0.22.2

- Stabilisiert den abgebrochenen v0.22.1-Patchlauf.
- Entfernt defekte Zwischenstandsdateien aus v0.22.0 und v0.22.1.
- Behält die Auslosungsvorschau ohne Persistenz aus v0.22 bei.
- Nachkontrolle bricht bei fehlgeschlagenem Restore, Build, Test, Frontend-Build oder Portable-Packaging hart ab.

"@
    Set-Text 'CHANGELOG.md' ($entry + $changelog)
    Write-Step 'CHANGELOG.md ergänzt'
} else {
    Write-Step 'CHANGELOG.md enthält 0.22.2 bereits'
}

Invoke-Step 'dotnet restore' { dotnet restore (Path-FromRoot 'SchachTurnierManager.sln') }
Invoke-Step 'dotnet build' { dotnet build (Path-FromRoot 'SchachTurnierManager.sln') --no-restore }
Invoke-Step 'dotnet test' { dotnet test (Path-FromRoot 'SchachTurnierManager.sln') --no-build }

Push-Location (Path-FromRoot 'src/SchachTurnierManager.WebApp')
try {
    Invoke-Step 'npm install' { npm install }
    Invoke-Step 'npm run build' { npm run build }
}
finally {
    Pop-Location
}

Invoke-Step 'Pack-Portable' { & (Path-FromRoot 'scripts/Pack-Portable.ps1') -NoPause }

Write-Step 'Nachkontrolle abgeschlossen. Bitte danach git status prüfen und committen.'
git -C $root status --short

if (-not $NoPause) {
    Write-Host 'Fertig. Enter zum Schließen.'
    [void][Console]::ReadLine()
}
