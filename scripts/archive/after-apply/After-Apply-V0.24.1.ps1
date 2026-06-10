$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-Step([string]$Message) { Write-Host "[v0.24.1] $Message" }

function Resolve-ProjectPath([string]$Path) {
    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Path))
}

function Read-Text([string]$Path) {
    $fullPath = Resolve-ProjectPath $Path
    if (-not (Test-Path -LiteralPath $fullPath)) { throw "Datei nicht gefunden: $Path" }
    return [System.IO.File]::ReadAllText($fullPath, [System.Text.Encoding]::UTF8)
}

function Write-Text([string]$Path, [string]$Content) {
    $fullPath = Resolve-ProjectPath $Path
    $parent = Split-Path -Parent $fullPath
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    [System.IO.File]::WriteAllText($fullPath, $Content, [System.Text.UTF8Encoding]::new($false))
}

function Replace-Version([string]$Path) {
    $text = Read-Text $Path
    $updated = $text -replace '0\.24\.0', '0.24.1'
    $updated = $updated -replace 'v0\.24\.0', 'v0.24.1'
    if ($updated -ne $text) {
        Write-Text $Path $updated
        Write-Step "$Path auf 0.24.1 gesetzt"
    } else {
        Write-Step "$Path enthielt keine 0.24.0-Version mehr"
    }
}

function Ensure-Contains([string]$Path, [string]$Sentinel, [scriptblock]$Patch, [string]$Description) {
    $text = Read-Text $Path
    if ($text.Contains($Sentinel)) {
        Write-Step "$Description bereits vorhanden"
        return
    }
    $updated = & $Patch $text
    if ([string]::IsNullOrEmpty($updated) -or $updated -eq $text) {
        throw "Patch konnte nicht angewendet werden in ${Path}: ${Description}"
    }
    Write-Text $Path $updated
    Write-Step $Description
}

function Run-Step([string]$Name, [scriptblock]$Action) {
    Write-Step "$Name..."
    & $Action
    if ($LASTEXITCODE -ne 0) { throw "$Name ist fehlgeschlagen mit Exitcode $LASTEXITCODE." }
}

if (-not (Test-Path -LiteralPath '.\src\SchachTurnierManager.WebApp\src\main.tsx')) {
    throw 'Bitte im Projektwurzelverzeichnis D:\Schach\SchachTurnierManager ausführen.'
}

# Falls der alte versehentliche Pager-Output irgendwo wieder auftaucht, nicht erneut committen.
if (Test-Path -LiteralPath '.\tatus') {
    git rm '.\tatus'
    Write-Step 'versehentliche Datei tatus entfernt'
}

Replace-Version 'src/SchachTurnierManager.WebApi/Program.cs'
Replace-Version 'src/SchachTurnierManager.WebApp/package.json'
Replace-Version 'src/SchachTurnierManager.WebApp/package-lock.json'
Replace-Version 'src/SchachTurnierManager.WebApp/src/main.tsx'

$mainPath = 'src/SchachTurnierManager.WebApp/src/main.tsx'

$previewFunctions = @'
  function openNextRoundPreviewCsv() {
    if (!selectedTournament) {
      return;
    }
    window.open(`/api/tournaments/${selectedTournament.id}/pairings/preview-next-round/export.csv`, '_blank', 'noopener,noreferrer');
  }

  function openNextRoundPreviewPrint() {
    if (!selectedTournament) {
      return;
    }
    window.open(`/api/tournaments/${selectedTournament.id}/pairings/preview-next-round/print/html`, '_blank', 'noopener,noreferrer');
  }

'@
Ensure-Contains $mainPath 'openNextRoundPreviewCsv' {
    param($text)
    $anchor = '  function openTournamentExport(path: string) {'
    if (-not $text.Contains($anchor)) { throw 'Anker fuer Vorschau-Export-Funktionen nicht gefunden.' }
    return $text.Replace($anchor, $previewFunctions + $anchor)
} 'Frontend-Funktionen für Vorschau-CSV und Druckansicht ergänzt'

$warningBlock = @'
              {nextRoundPreview.pairingQuality.hasCriticalIssues && <div className="preview-warning critical"><strong>Kritische Vorschau:</strong> Bitte Paarungen, Rematches und Farbfolge prüfen, bevor die Runde wirklich ausgelost wird.</div>}
              {!nextRoundPreview.isSavable && <div className="preview-warning critical"><strong>Nicht speicherbar:</strong> Diese Vorschau darf nicht übernommen werden. Bitte Hinweise prüfen.</div>}
'@
Ensure-Contains $mainPath 'Kritische Vorschau:' {
    param($text)
    $pattern = '(?s)(\s*<div className="preview-metrics">\s*<span>\{nextRoundPreview\.boardCount\} Bretter</span>\s*<span>\{nextRoundPreview\.pairingQuality\.rematchCount\} Rematches</span>\s*<span>\{nextRoundPreview\.pairingQuality\.crossScoreGroupPairingCount\} Scoregruppen-Abweichungen</span>\s*<span>\{nextRoundPreview\.pairingQuality\.thirdSameColorRiskCount\} Farbfolge-Risiken</span>\s*<span>\{nextRoundPreview\.pairingQuality\.byeCount\} Bye</span>\s*</div>)'
    if (-not [regex]::IsMatch($text, $pattern)) { throw 'Anker fuer Warnboxen in der Vorschaukarte nicht gefunden.' }
    return [regex]::Replace($text, $pattern, { param($m) $m.Groups[1].Value + "`n" + $warningBlock.TrimEnd() }, 1)
} 'Warnboxen in der Vorschaukarte ergänzt'

$exportButtons = @'
                <button type="button" className="secondary" onClick={openNextRoundPreviewPrint}>Druckansicht öffnen</button>
                <button type="button" className="secondary" onClick={openNextRoundPreviewCsv}>CSV exportieren</button>
'@
Ensure-Contains $mainPath 'Druckansicht öffnen' {
    param($text)
    $closeButton = '                <button type="button" className="secondary" onClick={() => setNextRoundPreview(null)}>Vorschau schließen</button>'
    if (-not $text.Contains($closeButton)) { throw 'Anker fuer Vorschau-Aktionsbuttons nicht gefunden.' }
    return $text.Replace($closeButton, $exportButtons.TrimEnd() + "`n" + $closeButton)
} 'Preview-Aktionsbuttons um Druck/CSV ergänzt'

$cssPath = 'src/SchachTurnierManager.WebApp/src/styles.css'
$previewCss = @'
.preview-warning {
  padding: 0.75rem 0.85rem;
  border-radius: 0.75rem;
  border: 1px solid rgba(245, 158, 11, 0.55);
  background: rgba(146, 64, 14, 0.18);
  color: #fde68a;
}

.preview-warning.critical {
  border-color: rgba(248, 113, 113, 0.72);
  background: rgba(127, 29, 29, 0.24);
  color: #fecaca;
}

.preview-actions {
  flex-wrap: wrap;
}
'@
Ensure-Contains $cssPath '.preview-warning' {
    param($text)
    return $text.TrimEnd() + "`n`n" + $previewCss.TrimEnd() + "`n"
} 'CSS für Vorschau-Warnungen ergänzt'

$changelogPath = 'CHANGELOG.md'
$changelog = Read-Text $changelogPath
if (-not $changelog.Contains('## 0.24.1')) {
    $entry = @'
## 0.24.1

- Vervollständigt die Dashboard-Integration der Auslosungsvorschau-Exports.
- Ergänzt die fehlenden Buttons für Druckansicht und CSV-Export in der Vorschaukarte.
- Ergänzt deutliche Warnboxen für kritische oder nicht speicherbare Vorschauen.
- Baut das Portable-Paket nach der Korrektur neu.

'@
    Write-Text $changelogPath ($entry + $changelog.TrimStart())
    Write-Step 'CHANGELOG.md ergänzt'
} else {
    Write-Step 'CHANGELOG.md enthält v0.24.1 bereits'
}

$handoffPath = 'docs/HANDOFF_0_24_1.md'
$handoff = @'
# Handoff 0.24.1 – Dashboard-Integration der Vorschau-Exports vervollständigt

## Anlass

v0.24.0 wurde nach einem abgebrochenen Apply-Script bereits committed. Backend, Export-Formatter und Tests waren teilweise vorhanden, aber die UI-Erweiterung der Vorschaukarte wurde nicht vollständig angewendet.

## Inhalt

- Version auf 0.24.1 angehoben
- Buttons in der Vorschaukarte ergänzt:
  - Druckansicht öffnen
  - CSV exportieren
- Warnboxen in der Vorschaukarte ergänzt:
  - kritische Vorschau
  - nicht speicherbare Vorschau
- CSS für Vorschau-Warnungen ergänzt
- CHANGELOG nachgetragen
- Portable-Paket wird nach erfolgreicher Prüfung neu gebaut

## Nachkontrolle

- `dotnet restore`
- `dotnet build`
- `dotnet test`
- `npm install`
- `npm run build`
- `scripts\Pack-Portable.ps1`
- `git status --short`
'@
Write-Text $handoffPath $handoff
Write-Step 'Handoff ergänzt'

foreach ($path in @(
    'src/SchachTurnierManager.WebApi/Program.cs',
    'src/SchachTurnierManager.Application/TournamentService.cs',
    'src/SchachTurnierManager.Domain/Services/TournamentExportFormatter.cs',
    'tests/SchachTurnierManager.Domain.Tests/TournamentExportFormatterTests.cs',
    'src/SchachTurnierManager.WebApp/package.json',
    'src/SchachTurnierManager.WebApp/package-lock.json',
    'src/SchachTurnierManager.WebApp/src/main.tsx',
    'src/SchachTurnierManager.WebApp/src/styles.css',
    'CHANGELOG.md',
    'docs/HANDOFF_0_24_0.md',
    'docs/HANDOFF_0_24_1.md',
    'scripts/After-Apply-V0.24.ps1',
    'scripts/After-Apply-V0.24.1.ps1'
)) {
    if (Test-Path -LiteralPath $path) {
        Write-Text $path (Read-Text $path)
        Write-Step "$path als UTF-8 ohne BOM gespeichert"
    }
}

Run-Step 'dotnet restore' { dotnet restore }
Run-Step 'dotnet build' { dotnet build --no-restore }
Run-Step 'dotnet test' { dotnet test --no-build }
Push-Location 'src/SchachTurnierManager.WebApp'
try {
    Run-Step 'npm install' { npm install }
    Run-Step 'npm run build' { npm run build }
}
finally {
    Pop-Location
}
Run-Step 'Pack-Portable' { pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File '.\scripts\Pack-Portable.ps1' }
Write-Step 'Nachkontrolle abgeschlossen. Aktueller Git-Status:'
git status --short
