$ErrorActionPreference = 'Stop'

function Invoke-Step {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][scriptblock]$Command
    )

    Write-Host "[v0.16.0] $Name..." -ForegroundColor Cyan
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "Schritt fehlgeschlagen: $Name (ExitCode=$LASTEXITCODE)"
    }
}

function Replace-Required {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Old,
        [Parameter(Mandatory=$true)][string]$New,
        [string]$Description = $Old
    )

    $content = Get-Content -LiteralPath $Path -Raw
    if ($content.Contains($New)) {
        return
    }

    if (-not $content.Contains($Old)) {
        throw "Erwartete Stelle nicht gefunden in $Path: $Description"
    }

    $content = $content.Replace($Old, $New)
    Set-Content -LiteralPath $Path -Value $content -Encoding utf8NoBOM
}

function Replace-RegexRequired {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Pattern,
        [Parameter(Mandatory=$true)][string]$Replacement,
        [Parameter(Mandatory=$true)][string]$Verify,
        [string]$Description = $Pattern
    )

    $content = Get-Content -LiteralPath $Path -Raw
    if ($content.Contains($Verify)) {
        return
    }

    $updated = [regex]::Replace($content, $Pattern, $Replacement, [Text.RegularExpressions.RegexOptions]::Singleline)
    if ($updated -eq $content) {
        throw "Erwartete Regex-Stelle nicht gefunden in $Path: $Description"
    }

    Set-Content -LiteralPath $Path -Value $updated -Encoding utf8NoBOM
}

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$program = Join-Path $root 'src/SchachTurnierManager.WebApi/Program.cs'
$packageJson = Join-Path $root 'src/SchachTurnierManager.WebApp/package.json'
$packageLock = Join-Path $root 'src/SchachTurnierManager.WebApp/package-lock.json'
$mainTsx = Join-Path $root 'src/SchachTurnierManager.WebApp/src/main.tsx'
$styles = Join-Path $root 'src/SchachTurnierManager.WebApp/src/styles.css'
$changelog = Join-Path $root 'CHANGELOG.md'

# Versionsnummern vereinheitlichen
(Get-Content -LiteralPath $program -Raw).Replace('version = "0.15.0"', 'version = "0.16.0"') | Set-Content -LiteralPath $program -Encoding utf8NoBOM
(Get-Content -LiteralPath $packageJson -Raw).Replace('"version": "0.15.0"', '"version": "0.16.0"') | Set-Content -LiteralPath $packageJson -Encoding utf8NoBOM
(Get-Content -LiteralPath $packageLock -Raw).Replace('"version": "0.15.0"', '"version": "0.16.0"') | Set-Content -LiteralPath $packageLock -Encoding utf8NoBOM
(Get-Content -LiteralPath $mainTsx -Raw).Replace('Lokaler Turnierleiter · v0.15.0', 'Lokaler Turnierleiter · v0.16.0') | Set-Content -LiteralPath $mainTsx -Encoding utf8NoBOM

# Changelog ergänzen
$change = Get-Content -LiteralPath $changelog -Raw
if (-not $change.Contains('## 0.16.0 - CSV-Import bewusst bestätigen und Vorlagen')) {
    $entry = @"
# Changelog

## 0.16.0 - CSV-Import bewusst bestätigen und Vorlagen

- CSV-Import mit Warnungen muss im Dashboard bewusst bestätigt werden, bevor der Import ausgeführt werden kann.
- CSV-Beispielvorlage kann direkt im Dashboard eingefügt werden.
- Änderungen an CSV-Inhalt oder Ersetzen-Option verwerfen Vorschau und Warnungsbestätigung automatisch.
- Importstatus und Bedienhinweise im Dashboard präzisiert.

"@
    $change = $change -replace '^# Changelog\s*', $entry
    Set-Content -LiteralPath $changelog -Value $change -Encoding utf8NoBOM
}

# Beispielvorlage ergänzen
Replace-RegexRequired -Path $mainTsx `
    -Pattern '(const emptyPlayerForm: PlayerForm = \{.*?\};\s*)const defaultTiebreaks' `
    -Replacement ('$1' + @'
const sampleCsvTemplate = `Name;Verein;Geburtsjahr;Geschlecht;DWZ;DWZIndex;Elo;TWZ;FIDE-ID;DSB-ID;Titel;Status;Notizen
Geisshirt, Marco;Ilmenauer SV;1990;männlich;1987;;1968;;4610563;;CM;Active;Beispielzeile bitte vor Import prüfen
Musterfrau, Anna;Beispielverein;2012;weiblich;1200;;1300;;;;Active;U14-Beispiel
`;

const defaultTiebreaks
'@) `
    -Verify 'const sampleCsvTemplate = `Name;Verein;Geburtsjahr;Geschlecht;DWZ;DWZIndex;Elo;TWZ;FIDE-ID;DSB-ID;Titel;Status;Notizen'

# Bestätigungs-State ergänzen
Replace-Required -Path $mainTsx `
    -Old '  const [importPreview, setImportPreview] = React.useState<PlayerImportPreview | null>(null);' `
    -New "  const [importPreview, setImportPreview] = React.useState<PlayerImportPreview | null>(null);`r`n  const [confirmWarningImport, setConfirmWarningImport] = React.useState(false);" `
    -Description 'confirmWarningImport-State nach importPreview'

# Hilfsfunktion für Vorlage ergänzen
Replace-Required -Path $mainTsx `
    -Old @'
  async function previewPlayersImport() {
'@ `
    -New @'
  function useSampleCsvTemplate(): void {
    setCsvContent(sampleCsvTemplate);
    setReplacePlayers(false);
    setImportPreview(null);
    setConfirmWarningImport(false);
    setStatus('CSV-Beispielvorlage eingefügt. Bitte Daten anpassen und danach Import prüfen.');
  }

  async function previewPlayersImport() {
'@ `
    -Description 'useSampleCsvTemplate vor previewPlayersImport'

# Vorschau setzt Bestätigung zurück
Replace-Required -Path $mainTsx `
    -Old '    setImportPreview(preview);' `
    -New "    setImportPreview(preview);`r`n    setConfirmWarningImport(false);" `
    -Description 'Warnungsbestätigung nach Preview zurücksetzen'

# Import mit Warnungen muss bestätigt werden
Replace-Required -Path $mainTsx `
    -Old @'
    if (importPreview.hasBlockingIssues) {
      setError('CSV enthält blockierende Probleme. Bitte zuerst korrigieren und erneut prüfen.');
      return;
    }

    setError(null);
'@ `
    -New @'
    if (importPreview.hasBlockingIssues) {
      setError('CSV enthält blockierende Probleme. Bitte zuerst korrigieren und erneut prüfen.');
      return;
    }

    if (importPreview.warningRows > 0 && !confirmWarningImport) {
      setError('CSV enthält Warnungen oder mögliche Dubletten. Bitte Warnungen bewusst bestätigen oder CSV korrigieren und erneut prüfen.');
      return;
    }

    setError(null);
'@ `
    -Description 'Warnungsbestätigung vor CSV-Import'

# Nach Import Bestätigung zurücksetzen
Replace-Required -Path $mainTsx `
    -Old @'
    setImportPreview(null);
    setStatus(`${imported.length} Teilnehmer importiert.`);
'@ `
    -New @'
    setImportPreview(null);
    setConfirmWarningImport(false);
    setStatus(`${imported.length} Teilnehmer importiert.`);
'@ `
    -Description 'Warnungsbestätigung nach Import zurücksetzen'

# CSV-Änderungen setzen Bestätigung zurück und Importbutton/Template erweitern
Replace-Required -Path $mainTsx `
    -Old @'
                <textarea value={csvContent} onChange={(event: React.ChangeEvent<HTMLTextAreaElement>) => { setCsvContent(event.target.value); setImportPreview(null); }} rows={7} />
                <label className="checkbox"><input type="checkbox" checked={replacePlayers} onChange={(event: React.ChangeEvent<HTMLInputElement>) => { setReplacePlayers(event.target.checked); setImportPreview(null); }} /> vorhandene Teilnehmer ersetzen</label>
                <div className="actions">
                  <button type="button" onClick={() => void previewPlayersImport()} disabled={!selectedTournament || !csvContent.trim()}>Import prüfen</button>
                  <button type="button" onClick={() => void importPlayers()} disabled={!selectedTournament || !importPreview || importPreview.hasBlockingIssues}>CSV importieren</button>
                  <button type="button" className="secondary" onClick={() => void exportPlayers()} disabled={!selectedTournament}>CSV exportieren</button>
                </div>
'@ `
    -New @'
                <textarea value={csvContent} onChange={(event: React.ChangeEvent<HTMLTextAreaElement>) => { setCsvContent(event.target.value); setImportPreview(null); setConfirmWarningImport(false); }} rows={7} />
                <label className="checkbox"><input type="checkbox" checked={replacePlayers} onChange={(event: React.ChangeEvent<HTMLInputElement>) => { setReplacePlayers(event.target.checked); setImportPreview(null); setConfirmWarningImport(false); }} /> vorhandene Teilnehmer ersetzen</label>
                <div className="actions">
                  <button type="button" className="secondary" onClick={() => useSampleCsvTemplate()}>CSV-Vorlage einsetzen</button>
                  <button type="button" onClick={() => void previewPlayersImport()} disabled={!selectedTournament || !csvContent.trim()}>Import prüfen</button>
                  <button type="button" onClick={() => void importPlayers()} disabled={!selectedTournament || !importPreview || importPreview.hasBlockingIssues || (importPreview.warningRows > 0 && !confirmWarningImport)}>CSV importieren</button>
                  <button type="button" className="secondary" onClick={() => void exportPlayers()} disabled={!selectedTournament}>CSV exportieren</button>
                </div>
'@ `
    -Description 'CSV-Importaktionen mit Vorlage und Warnungsbestätigung'

# Bestätigung im Preview-Block anzeigen
Replace-Required -Path $mainTsx `
    -Old @'
                    {importPreview.globalWarnings.length > 0 && (
                      <ul className="message-list critical">
                        {importPreview.globalWarnings.map((warning, index) => <li key={`import-global-${index}`}>{warning}</li>)}
                      </ul>
                    )}
                    <div className="table-scroll compact import-preview-table">
'@ `
    -New @'
                    {importPreview.globalWarnings.length > 0 && (
                      <ul className="message-list critical">
                        {importPreview.globalWarnings.map((warning, index) => <li key={`import-global-${index}`}>{warning}</li>)}
                      </ul>
                    )}
                    {importPreview.warningRows > 0 && !importPreview.hasBlockingIssues && (
                      <label className="checkbox import-confirm">
                        <input type="checkbox" checked={confirmWarningImport} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setConfirmWarningImport(event.target.checked)} />
                        Ich habe Warnungen und mögliche Dubletten geprüft und möchte den Import trotzdem ausführen.
                      </label>
                    )}
                    {importPreview.hasBlockingIssues && <p className="error">Blockierende Probleme müssen vor dem Import behoben werden.</p>}
                    <div className="table-scroll compact import-preview-table">
'@ `
    -Description 'Warnungsbestätigung im Preview-Block'

# CSS ergänzen
$css = Get-Content -LiteralPath $styles -Raw
if (-not $css.Contains('.import-confirm')) {
    $css += @'

.import-confirm {
  margin-top: 0.75rem;
  padding: 0.75rem;
  border: 1px solid rgba(245, 158, 11, 0.45);
  border-radius: 0.75rem;
  background: rgba(245, 158, 11, 0.08);
}

.preview-summary.ready + .import-confirm {
  display: none;
}
'@
    Set-Content -LiteralPath $styles -Value $css -Encoding utf8NoBOM
}

# Verifikation
$verifyMain = Get-Content -LiteralPath $mainTsx -Raw
foreach ($needle in @(
    'const sampleCsvTemplate',
    'confirmWarningImport',
    'CSV-Vorlage einsetzen',
    'Ich habe Warnungen und mögliche Dubletten geprüft'
)) {
    if (-not $verifyMain.Contains($needle)) {
        throw "v0.16.0 UI-Patch unvollständig: $needle fehlt in main.tsx"
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

Write-Host '[v0.16.0] Nachkontrolle abgeschlossen. Bitte danach git status prüfen und committen.' -ForegroundColor Green
git status --short
