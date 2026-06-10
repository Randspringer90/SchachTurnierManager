Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$Version = '0.36.0'

function Write-Step {
    param([string]$Message)
    Write-Host "[v$Version] $Message"
}

function Read-Text {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $path = Join-Path $Root $RelativePath
    if (-not (Test-Path -LiteralPath $path)) { throw "Datei nicht gefunden: $RelativePath" }
    return [System.IO.File]::ReadAllText($path)
}

function Write-Text {
    param([Parameter(Mandatory = $true)][string]$RelativePath, [Parameter(Mandatory = $true)][string]$Content)
    $path = Join-Path $Root $RelativePath
    $parent = Split-Path -Parent $path
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [System.IO.File]::WriteAllText($path, $Content, $Utf8NoBom)
}

function Normalize-TextFile {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $path = Join-Path $Root $RelativePath
    if (Test-Path -LiteralPath $path) {
        $content = [System.IO.File]::ReadAllText($path)
        [System.IO.File]::WriteAllText($path, $content, $Utf8NoBom)
        Write-Step "$RelativePath als UTF-8 ohne BOM gespeichert"
    }
}

function Set-VersionInFile {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $text = Read-Text $RelativePath
    $updated = $text
    foreach ($old in @('0.35.3','0.35.2','0.35.1','0.35.0','0.34.1')) {
        $updated = $updated.Replace($old, $Version)
    }
    if ($updated -ne $text) {
        Write-Text $RelativePath $updated
        Write-Step "$RelativePath auf $Version gesetzt"
    } elseif ($text.Contains($Version)) {
        Write-Step "$RelativePath ist bereits auf $Version"
    } else {
        Write-Step "$RelativePath enthielt keine bekannte Vorversion"
    }
}

function Ensure-Changelog {
    $relativePath = 'CHANGELOG.md'
    $text = Read-Text $relativePath
    $marker = '## 0.36.0 - Audit-Journal Query Foundation'
    if ($text.Contains($marker)) {
        Write-Step 'CHANGELOG.md enthält 0.36.0 bereits'
        return
    }

    $entry = @'
## 0.36.0 - Audit-Journal Query Foundation

- AuditJournalQueryService ergänzt, um das persistente Audit-Journal nach Schweregrad, Aktion, Runde, Brett, Spieler und Freitext zu filtern.
- AuditJournalStatistics ergänzt für Info-/Warn-/Kritisch-Zählungen sowie Runden-, Brett- und Spielerbezüge.
- Regressionstests für Sortierung, Paging, Suche und Statistikzählungen ergänzt.

'@
    Write-Text $relativePath ($entry + $text)
    Write-Step 'CHANGELOG.md ergänzt'
}

function Require-File {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    if (-not (Test-Path -LiteralPath (Join-Path $Root $RelativePath))) {
        throw "Erwartete Patch-Datei fehlt nach dem Entpacken: $RelativePath"
    }
    Write-Step "$RelativePath vorhanden"
}

function Invoke-Step {
    param([Parameter(Mandatory = $true)][string]$Name, [Parameter(Mandatory = $true)][scriptblock]$Command)
    Write-Step "$Name..."
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$Name ist fehlgeschlagen mit Exitcode $LASTEXITCODE."
    }
}

try {
    Set-VersionInFile 'src/SchachTurnierManager.WebApi/Program.cs'
    Set-VersionInFile 'src/SchachTurnierManager.WebApp/package.json'
    Set-VersionInFile 'src/SchachTurnierManager.WebApp/package-lock.json'
    Set-VersionInFile 'src/SchachTurnierManager.WebApp/src/main.tsx'

    Require-File 'src/SchachTurnierManager.Domain/Services/AuditJournalQueryService.cs'
    Require-File 'tests/SchachTurnierManager.Domain.Tests/AuditJournalQueryServiceTests.cs'
    Require-File 'docs/HANDOFF_0_36_0.md'

    Ensure-Changelog

    foreach ($file in @(
        'CHANGELOG.md',
        'src/SchachTurnierManager.WebApi/Program.cs',
        'src/SchachTurnierManager.WebApp/package.json',
        'src/SchachTurnierManager.WebApp/package-lock.json',
        'src/SchachTurnierManager.WebApp/src/main.tsx',
        'src/SchachTurnierManager.Domain/Services/AuditJournalQueryService.cs',
        'tests/SchachTurnierManager.Domain.Tests/AuditJournalQueryServiceTests.cs',
        'docs/HANDOFF_0_36_0.md',
        'scripts/After-Apply-V0.36.ps1'
    )) {
        Normalize-TextFile $file
    }

    Invoke-Step 'Release-Gate' { & (Join-Path $Root 'scripts/Invoke-ReleaseGate.ps1') }

    Write-Step 'Nachkontrolle abgeschlossen. Aktueller Git-Status:'
    git -C $Root status --short
}
catch {
    Write-Error $_
    exit 1
}
