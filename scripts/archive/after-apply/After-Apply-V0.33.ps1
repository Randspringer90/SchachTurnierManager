Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Write-Step {
    param([string]$Message)
    Write-Host "[v0.33.0] $Message"
}

function Set-TextFileUtf8NoBom {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $path = Join-Path $Root $RelativePath
    if (Test-Path -LiteralPath $path) {
        $content = [System.IO.File]::ReadAllText($path)
        [System.IO.File]::WriteAllText($path, $content, $Utf8NoBom)
        Write-Step "$RelativePath als UTF-8 ohne BOM gespeichert"
    }
}

function Replace-Version {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $path = Join-Path $Root $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Datei nicht gefunden: $RelativePath"
    }

    $text = [System.IO.File]::ReadAllText($path)
    $updated = $text.Replace('0.32.0', '0.33.0')
    if ($updated -eq $text) {
        if ($text.Contains('0.33.0')) {
            Write-Step "$RelativePath ist bereits auf 0.33.0"
        } else {
            Write-Step "$RelativePath enthielt keine 0.32.0-Version mehr"
        }
    } else {
        [System.IO.File]::WriteAllText($path, $updated, $Utf8NoBom)
        Write-Step "$RelativePath auf 0.33.0 gesetzt"
    }
}

function Add-ChangelogEntry {
    $path = Join-Path $Root 'CHANGELOG.md'
    if (-not (Test-Path -LiteralPath $path)) {
        throw 'CHANGELOG.md nicht gefunden.'
    }

    $text = [System.IO.File]::ReadAllText($path)
    if ($text.Contains('## 0.33.0')) {
        Write-Step 'CHANGELOG.md enthaelt 0.33.0 bereits'
        return
    }

    $entry = @'
## 0.33.0 - Forfeit/Bye Regression Gate

- Zusätzliche Domain-Regressionstests für kampflose Ergebnisse und Bye/Spielfrei ergänzt.
- Forfeit-Tiebreak-Policies `ExcludeForfeitsFromTiebreaks`, `CountForfeitOpponentForBuchholzOnly` und `CountForfeitsAsNormalGames` werden in Mehr-Runden-Szenarien abgesichert.
- Bye mit `CountByeAsWin` wird als Sieg gezählt, bleibt aber ohne Gegnerwertung, Sonneborn-Berger, Gegnerschnitt und Performance.
- Keine Änderung an Auslosungslogik, Wertungsberechnung, Speicherformat oder UI.

'@

    [System.IO.File]::WriteAllText($path, $entry + $text, $Utf8NoBom)
    Write-Step 'CHANGELOG.md ergaenzt'
}

function Invoke-NativeStep {
    param([string]$Name, [scriptblock]$Script)
    Write-Step "$Name..."
    & $Script
    if ($LASTEXITCODE -ne 0) {
        throw "$Name ist fehlgeschlagen mit Exitcode $LASTEXITCODE."
    }
}

Push-Location $Root
try {
    Replace-Version 'src/SchachTurnierManager.WebApi/Program.cs'
    Replace-Version 'src/SchachTurnierManager.WebApp/package.json'
    Replace-Version 'src/SchachTurnierManager.WebApp/package-lock.json'
    Replace-Version 'src/SchachTurnierManager.WebApp/src/main.tsx'
    Add-ChangelogEntry

    @(
        'CHANGELOG.md',
        'src/SchachTurnierManager.WebApi/Program.cs',
        'src/SchachTurnierManager.WebApp/package.json',
        'src/SchachTurnierManager.WebApp/package-lock.json',
        'src/SchachTurnierManager.WebApp/src/main.tsx',
        'tests/SchachTurnierManager.Domain.Tests/ForfeitByeRegressionGateTests.cs',
        'docs/HANDOFF_0_33_0.md',
        'scripts/After-Apply-V0.33.ps1'
    ) | ForEach-Object { Set-TextFileUtf8NoBom $_ }

    $releaseGate = Join-Path $Root 'scripts/Invoke-ReleaseGate.ps1'
    if (-not (Test-Path -LiteralPath $releaseGate)) {
        throw 'Release-Gate nicht gefunden. Bitte zuerst v0.30.0 sauber einspielen.'
    }

    Invoke-NativeStep 'Release-Gate' { pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $releaseGate -Root $Root }

    Write-Step 'Nachkontrolle abgeschlossen. Aktueller Git-Status:'
    git status --short
} finally {
    Pop-Location
}
