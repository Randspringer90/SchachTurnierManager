$ErrorActionPreference = 'Stop'

function Invoke-Step {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][scriptblock]$Command
    )

    Write-Host "[v0.15.0] $Name..." -ForegroundColor Cyan
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "Schritt fehlgeschlagen: $Name (ExitCode=$LASTEXITCODE)"
    }
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Content
    )
    Set-Content -LiteralPath $Path -Value $Content -Encoding utf8NoBOM
}

function Replace-Required {
    param(
        [Parameter(Mandatory=$true)][string]$Content,
        [Parameter(Mandatory=$true)][string]$Pattern,
        [Parameter(Mandatory=$true)][string]$Replacement,
        [Parameter(Mandatory=$true)][string]$Label
    )
    if ($Content -notmatch $Pattern) {
        throw "Patch-Anker nicht gefunden: $Label"
    }
    return [regex]::Replace($Content, $Pattern, $Replacement, 1)
}

function Insert-Before-Required {
    param(
        [Parameter(Mandatory=$true)][string]$Content,
        [Parameter(Mandatory=$true)][string]$Anchor,
        [Parameter(Mandatory=$true)][string]$Insertion,
        [Parameter(Mandatory=$true)][string]$Marker,
        [Parameter(Mandatory=$true)][string]$Label
    )
    if ($Content.Contains($Marker)) {
        return $Content
    }
    if (-not $Content.Contains($Anchor)) {
        throw "Patch-Anker nicht gefunden: $Label"
    }
    return $Content.Replace($Anchor, $Insertion + [Environment]::NewLine + [Environment]::NewLine + $Anchor)
}

function Insert-After-Line-Required {
    param(
        [Parameter(Mandatory=$true)][string]$Content,
        [Parameter(Mandatory=$true)][string]$AnchorLine,
        [Parameter(Mandatory=$true)][string]$Insertion,
        [Parameter(Mandatory=$true)][string]$Marker,
        [Parameter(Mandatory=$true)][string]$Label
    )
    if ($Content.Contains($Marker)) {
        return $Content
    }
    if (-not $Content.Contains($AnchorLine)) {
        throw "Patch-Anker nicht gefunden: $Label"
    }
    return $Content.Replace($AnchorLine, $AnchorLine + [Environment]::NewLine + $Insertion)
}

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$programPath = Join-Path $root 'src/SchachTurnierManager.WebApi/Program.cs'
if (Test-Path $programPath) {
    $program = Get-Content -LiteralPath $programPath -Raw
    $program = $program -replace 'version = "0\.14\.0"', 'version = "0.15.0"'
    Write-Utf8NoBom $programPath $program
}

$packagePath = Join-Path $root 'src/SchachTurnierManager.WebApp/package.json'
if (Test-Path $packagePath) {
    $package = Get-Content -LiteralPath $packagePath -Raw
    $package = $package -replace '"version"\s*:\s*"0\.14\.0"', '"version": "0.15.0"'
    Write-Utf8NoBom $packagePath $package
}

$lockPath = Join-Path $root 'src/SchachTurnierManager.WebApp/package-lock.json'
if (Test-Path $lockPath) {
    $lock = Get-Content -LiteralPath $lockPath -Raw
    $lock = $lock -replace '"version"\s*:\s*"0\.14\.0"', '"version": "0.15.0"'
    Write-Utf8NoBom $lockPath $lock
}

$mainPath = Join-Path $root 'src/SchachTurnierManager.WebApp/src/main.tsx'
$main = Get-Content -LiteralPath $mainPath -Raw
$main = $main -replace 'v0\.14\.0', 'v0.15.0'

if (-not $main.Contains('type PlayerImportPreview =')) {
    $previewTypes = @'
type PlayerImportPreview = {
  replaceExisting: boolean;
  rows: PlayerImportPreviewRow[];
  globalWarnings: string[];
  totalRows: number;
  importableRows: number;
  warningRows: number;
  blockingRows: number;
  likelyDuplicateRows: number;
  hasBlockingIssues: boolean;
};

type PlayerImportPreviewRow = {
  rowNumber: number;
  player: Player;
  profile: ExternalPlayerProfile;
  duplicateCheck: ExternalPlayerDuplicateCheck;
  warnings: string[];
  blockingIssues: string[];
  status: number;
};
'@
    $pattern = '(?s)(type ExternalPlayerApplyResult = \{\s*player: Player;\s*created: boolean;\s*updated: boolean;\s*duplicateCheck: ExternalPlayerDuplicateCheck;\s*changedFields: string\[\];\s*message: string;\s*\};)'
    $main = Replace-Required -Content $main -Pattern $pattern -Replacement ('$1' + [Environment]::NewLine + [Environment]::NewLine + $previewTypes.TrimEnd()) -Label 'ExternalPlayerApplyResult types'
}

$helperFunctions = @'
function importPreviewStatusLabel(status: number): string {
  switch (status) {
    case 0: return 'bereit';
    case 1: return 'Warnung';
    case 2: return 'blockiert';
    default: return String(status);
  }
}

function importPreviewStatusClass(status: number): string {
  switch (status) {
    case 0: return 'preview-ready';
    case 1: return 'preview-warning-row';
    case 2: return 'preview-blocked-row';
    default: return '';
  }
}

function importPreviewMessages(row: PlayerImportPreviewRow): string[] {
  return [...row.blockingIssues, ...row.warnings];
}
'@
$main = Insert-Before-Required -Content $main -Anchor 'function settingsToForm(tournament?: Tournament): SettingsForm {' -Insertion $helperFunctions.TrimEnd() -Marker 'function importPreviewStatusLabel' -Label 'import preview helper functions'

$main = Insert-After-Line-Required -Content $main -AnchorLine '  const [replacePlayers, setReplacePlayers] = React.useState(false);' -Insertion '  const [importPreview, setImportPreview] = React.useState<PlayerImportPreview | null>(null);' -Marker 'const [importPreview, setImportPreview]' -Label 'import preview state'

if (-not $main.Contains('async function previewPlayersImport()')) {
    $newImportFunctions = @'
  async function previewPlayersImport() {
    if (!selectedTournament) {
      setError('Bitte zuerst ein Turnier auswählen.');
      return;
    }

    setError(null);
    const preview = await requestJson<PlayerImportPreview>(`/api/tournaments/${selectedTournament.id}/players/preview-import.csv`, {
      method: 'POST',
      body: JSON.stringify({ content: csvContent, replaceExisting: replacePlayers })
    });
    setImportPreview(preview);
    const blockerText = preview.hasBlockingIssues ? ' Blockierende Probleme müssen vor dem Import behoben werden.' : '';
    setStatus(`CSV geprüft: ${preview.totalRows} Zeilen · ${preview.importableRows} importierbar · ${preview.warningRows} Warnung(en) · ${preview.blockingRows} blockiert.${blockerText}`);
  }

  async function importPlayers() {
    if (!selectedTournament) {
      return;
    }

    if (!importPreview) {
      setError('Bitte CSV zuerst prüfen.');
      return;
    }

    if (importPreview.replaceExisting !== replacePlayers) {
      setError('Die Importoption wurde seit der Vorschau geändert. Bitte CSV erneut prüfen.');
      return;
    }

    if (importPreview.hasBlockingIssues) {
      setError('CSV enthält blockierende Probleme. Bitte zuerst korrigieren und erneut prüfen.');
      return;
    }

    setError(null);
    const imported = await requestJson<Player[]>(`/api/tournaments/${selectedTournament.id}/players/import.csv`, {
      method: 'POST',
      body: JSON.stringify({ content: csvContent, replaceExisting: replacePlayers })
    });
    setImportPreview(null);
    setStatus(`${imported.length} Teilnehmer importiert.`);
    await refresh(selectedTournament.id);
  }
'@
    $pattern = '(?s)  async function importPlayers\(\) \{.*?\r?\n  \}\r?\n\r?\n  async function exportPlayers\(\)'
    $main = Replace-Required -Content $main -Pattern $pattern -Replacement ($newImportFunctions.TrimEnd() + [Environment]::NewLine + [Environment]::NewLine + '  async function exportPlayers()') -Label 'importPlayers function block'
}

$oldTextarea = '                <textarea value={csvContent} onChange={(event: React.ChangeEvent<HTMLTextAreaElement>) => setCsvContent(event.target.value)} rows={7} />'
$newTextarea = '                <textarea value={csvContent} onChange={(event: React.ChangeEvent<HTMLTextAreaElement>) => { setCsvContent(event.target.value); setImportPreview(null); }} rows={7} />'
if ($main.Contains($oldTextarea)) {
    $main = $main.Replace($oldTextarea, $newTextarea)
}

$oldReplaceCheckbox = '                <label className="checkbox"><input type="checkbox" checked={replacePlayers} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setReplacePlayers(event.target.checked)} /> vorhandene Teilnehmer ersetzen</label>'
$newReplaceCheckbox = '                <label className="checkbox"><input type="checkbox" checked={replacePlayers} onChange={(event: React.ChangeEvent<HTMLInputElement>) => { setReplacePlayers(event.target.checked); setImportPreview(null); }} /> vorhandene Teilnehmer ersetzen</label>'
if ($main.Contains($oldReplaceCheckbox)) {
    $main = $main.Replace($oldReplaceCheckbox, $newReplaceCheckbox)
}

if (-not $main.Contains('Import prüfen')) {
    $oldActions = @'
                <div className="actions">
                  <button type="button" onClick={() => void importPlayers()} disabled={!selectedTournament}>CSV importieren</button>
                  <button type="button" className="secondary" onClick={() => void exportPlayers()} disabled={!selectedTournament}>CSV exportieren</button>
                </div>
'@
    $newActions = @'
                <div className="actions">
                  <button type="button" onClick={() => void previewPlayersImport()} disabled={!selectedTournament || !csvContent.trim()}>Import prüfen</button>
                  <button type="button" onClick={() => void importPlayers()} disabled={!selectedTournament || !importPreview || importPreview.hasBlockingIssues}>CSV importieren</button>
                  <button type="button" className="secondary" onClick={() => void exportPlayers()} disabled={!selectedTournament}>CSV exportieren</button>
                </div>
                {importPreview && (
                  <div className="import-preview">
                    <div className={`preview-summary ${importPreview.hasBlockingIssues ? 'blocked' : importPreview.warningRows > 0 ? 'warning' : 'ready'}`}>
                      <strong>{importPreview.hasBlockingIssues ? 'Import blockiert' : importPreview.warningRows > 0 ? 'Import mit Warnungen möglich' : 'Import bereit'}</strong>
                      <span>{importPreview.totalRows} Zeilen · {importPreview.importableRows} importierbar · {importPreview.warningRows} Warnung(en) · {importPreview.blockingRows} blockiert · {importPreview.likelyDuplicateRows} mögliche Dublette(n)</span>
                    </div>
                    {importPreview.globalWarnings.length > 0 && (
                      <ul className="message-list critical">
                        {importPreview.globalWarnings.map((warning, index) => <li key={`import-global-${index}`}>{warning}</li>)}
                      </ul>
                    )}
                    <div className="table-scroll compact import-preview-table">
                      <table>
                        <thead><tr><th>Zeile</th><th>Teilnehmer</th><th>Status</th><th>Dubletten</th><th>Hinweise</th></tr></thead>
                        <tbody>
                          {importPreview.rows.map(row => (
                            <tr key={`import-preview-${row.rowNumber}`} className={importPreviewStatusClass(row.status)}>
                              <td>{row.rowNumber}</td>
                              <td>{row.player.name}<small>{row.player.fideId ? `FIDE ${row.player.fideId}` : row.player.nationalId ? `DSB ${row.player.nationalId}` : row.player.club ?? ''}</small></td>
                              <td>{importPreviewStatusLabel(row.status)}</td>
                              <td>{row.duplicateCheck.matches.length === 0 ? '—' : row.duplicateCheck.matches.map(match => `${match.playerName} (${duplicateKindLabel(match.kind)}, ${match.score})`).join('; ')}</td>
                              <td>{importPreviewMessages(row).length === 0 ? <span className="ok">ok</span> : <ul className="message-list">{importPreviewMessages(row).map((message, index) => <li key={`import-row-${row.rowNumber}-${index}`}>{message}</li>)}</ul>}</td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  </div>
                )}
'@
    if (-not $main.Contains($oldActions)) {
        throw 'Patch-Anker nicht gefunden: CSV actions block'
    }
    $main = $main.Replace($oldActions, $newActions)
}

if ($main -notmatch 'PlayerImportPreview') {
    throw 'main.tsx enthält nach Patch keine PlayerImportPreview-Typen.'
}
if ($main -notmatch 'previewPlayersImport') {
    throw 'main.tsx enthält nach Patch keine previewPlayersImport-Funktion.'
}
Write-Utf8NoBom $mainPath $main

$stylesPath = Join-Path $root 'src/SchachTurnierManager.WebApp/src/styles.css'
$styles = Get-Content -LiteralPath $stylesPath -Raw
if (-not $styles.Contains('.import-preview')) {
    $styles += @'

.import-preview {
  margin-top: 1rem;
  display: grid;
  gap: 0.75rem;
}

.preview-summary {
  display: grid;
  gap: 0.25rem;
  padding: 0.75rem;
  border-radius: 0.75rem;
  border: 1px solid var(--border);
  background: rgba(255, 255, 255, 0.04);
}

.preview-summary.ready {
  border-color: rgba(66, 185, 131, 0.65);
}

.preview-summary.warning {
  border-color: rgba(245, 158, 11, 0.75);
}

.preview-summary.blocked {
  border-color: rgba(239, 68, 68, 0.75);
}

.import-preview-table table {
  min-width: 760px;
}

.preview-ready td {
  background: rgba(66, 185, 131, 0.06);
}

.preview-warning-row td {
  background: rgba(245, 158, 11, 0.08);
}

.preview-blocked-row td {
  background: rgba(239, 68, 68, 0.08);
}

.message-list {
  margin: 0.25rem 0 0;
  padding-left: 1rem;
}

.message-list.critical {
  color: var(--danger);
}
'@
    Write-Utf8NoBom $stylesPath $styles
}

$changelogPath = Join-Path $root 'CHANGELOG.md'
if (Test-Path $changelogPath) {
    $changelog = Get-Content -LiteralPath $changelogPath -Raw
    if (-not $changelog.Contains('## 0.15.0 - CSV-Importvorschau im Dashboard')) {
        $entry = @'
## 0.15.0 - CSV-Importvorschau im Dashboard

- Dashboard-Button „Import prüfen“ ergänzt, bevor echte Teilnehmerdaten verändert werden.
- CSV-Vorschau zeigt importierbare, warnende und blockierte Zeilen mit Dublettenhinweisen.
- CSV-Import wird blockiert, solange keine aktuelle Vorschau vorliegt oder blockierende Probleme vorhanden sind.
- Versionsanzeige und Portable-Paket auf `0.15.0` angehoben.

'@
        $changelog = $changelog.Replace('# Changelog' + [Environment]::NewLine + [Environment]::NewLine, '# Changelog' + [Environment]::NewLine + [Environment]::NewLine + $entry)
        Write-Utf8NoBom $changelogPath $changelog
    }
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

Write-Host '[v0.15.0] Nachkontrolle abgeschlossen. Bitte danach git status prüfen und committen.' -ForegroundColor Green
git status --short
