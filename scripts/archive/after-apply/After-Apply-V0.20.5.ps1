$ErrorActionPreference = 'Stop'

function Invoke-Step {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][scriptblock]$Action
    )

    Write-Host "[v0.20.5] $Name..."
    & $Action
    if ($LASTEXITCODE -ne 0) {
        throw "${Name} ist fehlgeschlagen mit Exitcode ${LASTEXITCODE}."
    }
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText((Resolve-Path -LiteralPath $Path), $Content, $utf8NoBom)
}

function Set-VersionInFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][string]$Replacement,
        [Parameter(Mandatory = $true)][string]$Description
    )

    $content = Get-Content -LiteralPath $Path -Raw
    if ($content -notmatch $Pattern) {
        throw "Erwartete Stelle nicht gefunden in ${Path}: ${Description}"
    }

    $content = [System.Text.RegularExpressions.Regex]::Replace($content, $Pattern, $Replacement)
    Write-Utf8NoBom -Path $Path -Content $content
    Write-Host "[v0.20.5] $Description"
}

$root = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')
Set-Location $root

# Kaputte Zwischenstandsartefakte aus fehlgeschlagenen Fix-Forward-Versuchen entfernen, falls sie lokal herumliegen.
$obsoletePaths = @(
    'scripts/After-Apply-V0.20.3.ps1',
    'scripts/After-Apply-V0.20.4.ps1',
    'docs/HANDOFF_0_20_3.md',
    'docs/HANDOFF_0_20_4.md'
)
foreach ($obsoletePath in $obsoletePaths) {
    if (Test-Path -LiteralPath $obsoletePath) {
        Remove-Item -LiteralPath $obsoletePath -Force
        Write-Host "[v0.20.5] Entfernt: $obsoletePath"
    }
}

Set-VersionInFile -Path 'src/SchachTurnierManager.WebApi/Program.cs' -Pattern 'version = "0\.\d+\.\d+"' -Replacement 'version = "0.20.5"' -Description 'API-Version auf 0.20.5 gesetzt'
Set-VersionInFile -Path 'src/SchachTurnierManager.WebApp/package.json' -Pattern '"version": "0\.\d+\.\d+"' -Replacement '"version": "0.20.5"' -Description 'package.json auf 0.20.5 gesetzt'
Set-VersionInFile -Path 'src/SchachTurnierManager.WebApp/package-lock.json' -Pattern '"version": "0\.\d+\.\d+"' -Replacement '"version": "0.20.5"' -Description 'package-lock.json auf 0.20.5 gesetzt'
Set-VersionInFile -Path 'src/SchachTurnierManager.WebApp/src/main.tsx' -Pattern 'Lokaler Turnierleiter · v0\.\d+\.\d+' -Replacement 'Lokaler Turnierleiter · v0.20.5' -Description 'Dashboard-Version auf 0.20.5 gesetzt'

$testPath = 'tests/SchachTurnierManager.Domain.Tests/TournamentExportFormatterTests.cs'
$testContent = Get-Content -LiteralPath $testPath -Raw
$actualHeader = 'Rang;Name;TWZ;Punkte;Siege;Schwarzsiege;Direktvergleich;Buchholz;Buchholz Cut-1;Buchholz Cut-2;Median Buchholz;Sonneborn-Berger;Koya;Progressiv;Gegnerschnitt;TPR;Heldenwert'
$expectedAssert = '        Assert.Contains("' + $actualHeader + '", document.Content);'
$headerAssertPattern = '        Assert\.Contains\("Rang;Name;TWZ;Punkte;Siege;[^\r\n]*", document\.Content\);'
$headerAssertRegex = [System.Text.RegularExpressions.Regex]::new($headerAssertPattern)
if (-not $headerAssertRegex.IsMatch($testContent)) {
    throw "Erwartete Stelle nicht gefunden in ${testPath}: CSV-Export-Test Tabellenkopf"
}
$testContent = $headerAssertRegex.Replace($testContent, $expectedAssert, 1)
Write-Utf8NoBom -Path $testPath -Content $testContent
Write-Host '[v0.20.5] CSV-Export-Test auf tatsächlichen erweiterten Tabellenkopf angepasst'

$changeLogPath = 'CHANGELOG.md'
$changeLog = Get-Content -LiteralPath $changeLogPath -Raw
if ($changeLog -notmatch '## 0\.20\.5') {
    $entry = @'

## 0.20.5 - Export-Test für erweiterte Wertungen stabilisiert

- CSV-Export-Test auf den tatsächlich exportierten erweiterten Tabellenkopf angepasst.
- Fehlgeschlagene lokale Zwischenstandsartefakte aus v0.20.3/v0.20.4 werden beim Fix-Forward entfernt.
- Nachkontrolle bricht weiterhin hart ab, wenn Build, Tests, Frontend-Build oder Portable-Paket fehlschlagen.
'@
    if ($changeLog -match '# Changelog') {
        $changeLog = $changeLog -replace '# Changelog', "# Changelog$entry"
    }
    else {
        $changeLog = "# Changelog$entry`r`n`r`n$changeLog"
    }
    Write-Utf8NoBom -Path $changeLogPath -Content $changeLog
    Write-Host '[v0.20.5] CHANGELOG.md ergänzt'
}

Invoke-Step 'dotnet restore' { dotnet restore }
Invoke-Step 'dotnet build' { dotnet build --no-restore }
Invoke-Step 'dotnet test' { dotnet test --no-build }

Push-Location 'src/SchachTurnierManager.WebApp'
try {
    Invoke-Step 'npm install' { npm install }
    Invoke-Step 'npm run build' { npm run build }
}
finally {
    Pop-Location
}

Invoke-Step 'Pack-Portable' { pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File '.\scripts\Pack-Portable.ps1' }

Write-Host '[v0.20.5] Nachkontrolle abgeschlossen. Bitte danach git status prüfen und committen.'
git status --short
