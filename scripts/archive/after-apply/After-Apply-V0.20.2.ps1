$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $Root

function Read-Text([string]$Path) {
    $full = Join-Path $Root $Path
    if (-not (Test-Path -LiteralPath $full)) {
        throw "Datei nicht gefunden: ${Path}"
    }
    return [System.IO.File]::ReadAllText($full)
}

function Write-Text([string]$Path, [string]$Content) {
    $full = Join-Path $Root $Path
    $dir = Split-Path -Parent $full
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir | Out-Null
    }
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($full, $Content, $utf8NoBom)
}

function Replace-Once([string]$Path, [string]$Old, [string]$New, [string]$Description) {
    $content = Read-Text $Path
    if (-not $content.Contains($Old)) {
        throw "Erwartete Stelle nicht gefunden in ${Path}: ${Description}"
    }
    $updated = $content.Replace($Old, $New)
    if ($updated -eq $content) {
        throw "Ersetzung hat keinen Effekt in ${Path}: ${Description}"
    }
    Write-Text $Path $updated
    Write-Host "[v0.20.2] ${Description}"
}

function Replace-Regex([string]$Path, [string]$Pattern, [string]$Replacement, [string]$Description) {
    $content = Read-Text $Path
    if (-not [regex]::IsMatch($content, $Pattern)) {
        throw "Erwartete Regex-Stelle nicht gefunden in ${Path}: ${Description}"
    }
    $updated = [regex]::Replace($content, $Pattern, $Replacement, 1)
    Write-Text $Path $updated
    Write-Host "[v0.20.2] ${Description}"
}

function Run-Step([string]$Name, [scriptblock]$Command) {
    Write-Host "[v0.20.2] ${Name}..."
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "${Name} ist fehlgeschlagen mit Exitcode ${LASTEXITCODE}."
    }
}

# Versionen anheben.
Replace-Regex 'src/SchachTurnierManager.WebApi/Program.cs' 'version = "0\.20\.1"' 'version = "0.20.2"' 'API-Version auf 0.20.2 gesetzt'
Replace-Regex 'src/SchachTurnierManager.WebApp/package.json' '"version"\s*:\s*"0\.20\.1"' '"version": "0.20.2"' 'package.json auf 0.20.2 gesetzt'
Replace-Regex 'src/SchachTurnierManager.WebApp/package-lock.json' '"version"\s*:\s*"0\.20\.1"' '"version": "0.20.2"' 'package-lock.json auf 0.20.2 gesetzt'
Replace-Regex 'src/SchachTurnierManager.WebApp/src/main.tsx' 'Lokaler Turnierleiter · v0\.20\.1' 'Lokaler Turnierleiter · v0.20.2' 'Dashboard-Version auf 0.20.2 gesetzt'

# Der v0.20.1-Funktionsumfang war fachlich richtig, aber ein älterer stabiler Export-Test erwartete den alten CSV-Header.
$testPath = 'tests/SchachTurnierManager.Domain.Tests/TournamentExportFormatterTests.cs'
$oldAssertion = 'Assert.Contains("Rang;Name;TWZ;Punkte;Siege;Direktvergleich;Buchholz", document.Content);'
$newAssertion = 'Assert.Contains("Rang;Name;TWZ;Punkte;Siege;Schwarzsiege;Direktvergleich;Buchholz;Buchholz Cut-1;Buchholz Cut-2;Median-Buchholz;Sonneborn-Berger;Progressiv;Koya;Gegnerschnitt;TPR;Heldenwert", document.Content);'
Replace-Once $testPath $oldAssertion $newAssertion 'CSV-Export-Test auf erweiterten Tabellenkopf aktualisiert'

# CHANGELOG ergänzen.
$changelogPath = 'CHANGELOG.md'
$changelog = Read-Text $changelogPath
if (-not $changelog.Contains('## 0.20.2 - Teststabilisierung erweiterte Wertungen')) {
    $entry = @'
## 0.20.2 - Teststabilisierung erweiterte Wertungen

- Stabilisiert den CSV-Export-Test nach der Erweiterung der Tabellenwertungsspalten in 0.20.1.
- Versionen auf `0.20.2` angehoben.
- Nachkontrollskript bricht nun hart ab, sobald `dotnet test`, Frontend-Build oder Packaging fehlschlagen.

'@
    $changelog = $changelog.Replace("# Changelog`r`n`r`n", "# Changelog`r`n`r`n$entry")
    $changelog = $changelog.Replace("# Changelog`n`n", "# Changelog`n`n$entry")
    Write-Text $changelogPath $changelog
    Write-Host '[v0.20.2] CHANGELOG.md ergänzt'
}
else {
    Write-Host '[v0.20.2] CHANGELOG.md war bereits ergänzt'
}

Run-Step 'dotnet restore' { dotnet restore }
Run-Step 'dotnet build' { dotnet build --no-restore }
Run-Step 'dotnet test' { dotnet test --no-build }
Run-Step 'npm install' { Push-Location 'src/SchachTurnierManager.WebApp'; npm install; Pop-Location }
Run-Step 'npm run build' { Push-Location 'src/SchachTurnierManager.WebApp'; npm run build; Pop-Location }
Run-Step 'Pack-Portable' { pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File '.\scripts\Pack-Portable.ps1' }

Write-Host '[v0.20.2] Nachkontrolle abgeschlossen. Bitte danach git status prüfen und committen.'
git status --short
