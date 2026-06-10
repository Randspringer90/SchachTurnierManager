$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-Step([string]$Message) { Write-Host "[v0.23.0] $Message" }

function Read-Text([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { throw "Datei nicht gefunden: $Path" }
    return [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path), [System.Text.Encoding]::UTF8)
}

function Write-Text([string]$Path, [string]$Content) {
    $parent = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText((Join-Path (Get-Location) $Path), $Content, $utf8NoBom)
}

function Normalize-Utf8NoBom([string[]]$Paths) {
    foreach ($path in $Paths) {
        if (Test-Path -LiteralPath $path) {
            $text = Read-Text $path
            Write-Text $path $text
            Write-Step "$path als UTF-8 ohne BOM gespeichert"
        }
    }
}

function Ensure-Contains([string]$Path, [string]$Needle, [string]$Description) {
    $text = Read-Text $Path
    if (-not $text.Contains($Needle)) {
        throw "Erwartete Stelle nicht gefunden in ${Path}: ${Description}"
    }
}

function Replace-Text([string]$Path, [string]$Old, [string]$New, [string]$Description) {
    $text = Read-Text $Path
    if ($text.Contains($New)) {
        Write-Step "$Description bereits vorhanden"
        return
    }
    if (-not $text.Contains($Old)) {
        throw "Erwartete Stelle nicht gefunden in ${Path}: ${Description}"
    }
    Write-Text $Path ($text.Replace($Old, $New))
    Write-Step $Description
}

function Replace-Version([string]$Path) {
    $text = Read-Text $Path
    $updated = $text -replace '0\.22\.2', '0.23.0'
    $updated = $updated -replace 'v0\.22\.2', 'v0.23.0'
    if ($updated -ne $text) {
        Write-Text $Path $updated
        Write-Step "$Path auf 0.23.0 gesetzt"
    } else {
        Write-Step "$Path enthielt keine 0.22.2-Version mehr"
    }
}

function Run-Step([string]$Name, [scriptblock]$Action) {
    Write-Step "$Name..."
    & $Action
    if ($LASTEXITCODE -ne 0) { throw "$Name ist fehlgeschlagen mit Exitcode $LASTEXITCODE." }
}

foreach ($stale in @('scripts/After-Apply-V0.22.ps1', 'scripts/After-Apply-V0.22.1.ps1', 'docs/HANDOFF_0_22_0.md', 'docs/HANDOFF_0_22_1.md')) {
    if (Test-Path -LiteralPath $stale) {
        Remove-Item -LiteralPath $stale -Force
        Write-Step "Entfernt alten Zwischenstand: $stale"
    }
}

Replace-Version 'src/SchachTurnierManager.WebApi/Program.cs'
Replace-Version 'src/SchachTurnierManager.WebApp/package.json'
Replace-Version 'src/SchachTurnierManager.WebApp/package-lock.json'
Replace-Version 'src/SchachTurnierManager.WebApp/src/main.tsx'

$mainPath = 'src/SchachTurnierManager.WebApp/src/main.tsx'
$main = Read-Text $mainPath

$nextRoundPreviewType = @'
type NextRoundPreview = {
  roundNumber: number;
  boardCount: number;
  isSavable: boolean;
  summary: string;
  round: TournamentRound;
  pairingQuality: PairingQualityReport;
  messages: string[];
};

'@
if (-not $main.Contains('type NextRoundPreview =')) {
    $anchor = "type ExternalPlayerProviderInfo = {"
    if (-not $main.Contains($anchor)) { throw "Anker fuer NextRoundPreview-Typ nicht gefunden." }
    $main = $main.Replace($anchor, $nextRoundPreviewType + $anchor)
    Write-Step 'React-Typ NextRoundPreview ergänzt'
} else {
    Write-Step 'React-Typ NextRoundPreview bereits vorhanden'
}

if (-not $main.Contains('const [nextRoundPreview, setNextRoundPreview]')) {
    $old = "  const [pairingQualityReports, setPairingQualityReports] = React.useState<Record<number, PairingQualityReport>>({});`r`n"
    if (-not $main.Contains($old)) { $old = "  const [pairingQualityReports, setPairingQualityReports] = React.useState<Record<number, PairingQualityReport>>({});`n" }
    if (-not $main.Contains($old)) { throw "Anker fuer NextRoundPreview-State nicht gefunden." }
    $new = $old + "  const [nextRoundPreview, setNextRoundPreview] = React.useState<NextRoundPreview | null>(null);`n"
    $main = $main.Replace($old, $new)
    Write-Step 'React-State für Auslosungsvorschau ergänzt'
} else {
    Write-Step 'React-State für Auslosungsvorschau bereits vorhanden'
}

if (-not $main.Contains("setNextRoundPreview(null);`n      return;") -and -not $main.Contains("setNextRoundPreview(null);`r`n      return;")) {
    $old = "      setPairingQualityReports({});`r`n      return;"
    if (-not $main.Contains($old)) { $old = "      setPairingQualityReports({});`n      return;" }
    if (-not $main.Contains($old)) { throw "Anker fuer Leerlauf-Reset nicht gefunden." }
    $main = $main.Replace($old, "      setPairingQualityReports({});`n      setNextRoundPreview(null);`n      return;")
    Write-Step 'Auslosungsvorschau bei leerem Turnier zurückgesetzt'
} else {
    Write-Step 'Leerlauf-Reset für Auslosungsvorschau bereits vorhanden'
}

if (-not $main.Contains("setNextRoundPreview(null);`n  }, [selectedTournament?.id]);") -and -not $main.Contains("setNextRoundPreview(null);`r`n  }, [selectedTournament?.id]);")) {
    $old = "  React.useEffect(() => {`r`n    setPairingQualityReports({});`r`n  }, [selectedTournament?.id]);"
    if (-not $main.Contains($old)) { $old = "  React.useEffect(() => {`n    setPairingQualityReports({});`n  }, [selectedTournament?.id]);" }
    if (-not $main.Contains($old)) { throw "Anker fuer Turnierwechsel-Reset nicht gefunden." }
    $new = "  React.useEffect(() => {`n    setPairingQualityReports({});`n    setNextRoundPreview(null);`n  }, [selectedTournament?.id]);"
    $main = $main.Replace($old, $new)
    Write-Step 'Auslosungsvorschau bei Turnierwechsel zurückgesetzt'
} else {
    Write-Step 'Turnierwechsel-Reset für Auslosungsvorschau bereits vorhanden'
}

$previewFunction = @'
  async function previewNextRound() {
    if (!selectedTournament) {
      return;
    }

    setError(null);
    const preview = await requestJson<NextRoundPreview>(`/api/tournaments/${selectedTournament.id}/pairings/preview-next-round`);
    setNextRoundPreview(preview);
    setStatus(`Auslosungsvorschau Runde ${preview.roundNumber}: ${preview.pairingQuality.qualityScore}/100 · ${pairingQualitySeverityLabel(preview.pairingQuality.severity)}.`);
  }

'@
if (-not $main.Contains('async function previewNextRound()')) {
    $anchor = "  async function generateRound() {"
    if (-not $main.Contains($anchor)) { throw "Anker fuer previewNextRound nicht gefunden." }
    $main = $main.Replace($anchor, $previewFunction + $anchor)
    Write-Step 'Funktion previewNextRound ergänzt'
} else {
    Write-Step 'Funktion previewNextRound bereits vorhanden'
}

if (-not $main.Contains("setNextRoundPreview(null);`n    await refresh(selectedTournament.id);") -and -not $main.Contains("setNextRoundPreview(null);`r`n    await refresh(selectedTournament.id);")) {
    $old = "    setStatus('Neue Runde ausgelost.');`r`n    await refresh(selectedTournament.id);"
    if (-not $main.Contains($old)) { $old = "    setStatus('Neue Runde ausgelost.');`n    await refresh(selectedTournament.id);" }
    if (-not $main.Contains($old)) { throw "Anker fuer generateRound-Reset nicht gefunden." }
    $new = "    setStatus('Neue Runde ausgelost.');`n    setNextRoundPreview(null);`n    await refresh(selectedTournament.id);"
    $main = $main.Replace($old, $new)
    Write-Step 'Auslosungsvorschau nach echter Auslosung zurückgesetzt'
} else {
    Write-Step 'generateRound-Reset bereits vorhanden'
}

$oldHeaderButton = '            <button type="button" onClick={() => void generateRound()} disabled={!selectedTournament || selectedTournament.players.filter(player => player.status === 0).length < 2}>Nächste Runde auslosen</button>'
$newHeaderButtons = @'
            <div className="actions">
              <button type="button" className="secondary" onClick={() => void previewNextRound()} disabled={!selectedTournament || selectedTournament.players.filter(player => player.status === 0).length < 2}>Auslosungsvorschau</button>
              <button type="button" onClick={() => void generateRound()} disabled={!selectedTournament || selectedTournament.players.filter(player => player.status === 0).length < 2}>Nächste Runde auslosen</button>
            </div>
'@.TrimEnd()
if ($main.Contains($oldHeaderButton)) {
    $main = $main.Replace($oldHeaderButton, $newHeaderButtons)
    Write-Step 'Header-Aktionen um Auslosungsvorschau ergänzt'
} elseif ($main.Contains('void previewNextRound()')) {
    Write-Step 'Header-Aktionen für Auslosungsvorschau bereits vorhanden'
} else {
    throw 'Header-Button-Anker für Auslosungsvorschau nicht gefunden.'
}

$previewCard = @'
          {nextRoundPreview && (
            <article className={`card preview-card ${pairingQualitySeverityClass(nextRoundPreview.pairingQuality.severity)}`}>
              <div className="preview-card-header">
                <div>
                  <p className="eyebrow">Vorschau · noch nicht gespeichert</p>
                  <h3>Auslosungsvorschau Runde {nextRoundPreview.roundNumber}</h3>
                  <p className="muted">{nextRoundPreview.summary}</p>
                </div>
                <div className="preview-score">
                  <strong>{nextRoundPreview.pairingQuality.qualityScore}/100</strong>
                  <span>{pairingQualitySeverityLabel(nextRoundPreview.pairingQuality.severity)}</span>
                </div>
              </div>
              <div className="preview-metrics">
                <span>{nextRoundPreview.boardCount} Bretter</span>
                <span>{nextRoundPreview.pairingQuality.rematchCount} Rematches</span>
                <span>{nextRoundPreview.pairingQuality.crossScoreGroupPairingCount} Scoregruppen-Abweichungen</span>
                <span>{nextRoundPreview.pairingQuality.thirdSameColorRiskCount} Farbfolge-Risiken</span>
                <span>{nextRoundPreview.pairingQuality.byeCount} Bye</span>
              </div>
              {nextRoundPreview.messages.length > 0 && <ul className="message-list preview-message-list">{nextRoundPreview.messages.map((message, index) => <li key={`preview-message-${index}`}>{message}</li>)}</ul>}
              {nextRoundPreview.pairingQuality.findings.length > 0 && <ul className="message-list preview-message-list">{nextRoundPreview.pairingQuality.findings.map((finding, index) => <li key={`preview-quality-${index}`}>{finding}</li>)}</ul>}
              <div className="table-scroll compact preview-pairings">
                <table>
                  <thead><tr><th>Brett</th><th>Weiß</th><th>Schwarz</th><th>Score vor Runde</th><th>Hinweise</th></tr></thead>
                  <tbody>
                    {nextRoundPreview.pairingQuality.boards.map(board => (
                      <tr key={`preview-board-${board.boardNumber}`} className={board.isRematch ? 'quality-board-critical' : board.wouldGiveWhiteThirdSameColor || board.wouldGiveBlackThirdSameColor ? 'quality-board-warning' : board.isCrossScoreGroupPairing || board.isBye ? 'quality-board-notice' : ''}>
                        <td>{board.boardNumber}</td>
                        <td>{board.whiteName}</td>
                        <td>{board.isBye ? 'spielfrei' : board.blackName}</td>
                        <td>{board.isBye ? 'Bye' : `${board.whiteScoreBeforeRound} : ${board.blackScoreBeforeRound}`}</td>
                        <td>{board.findings.length === 0 ? <span className="ok">ok</span> : <ul className="message-list">{board.findings.map((finding, index) => <li key={`preview-board-${board.boardNumber}-${index}`}>{finding}</li>)}</ul>}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <details className="audit-box preview-audit">
                <summary>Audit der Vorschau anzeigen</summary>
                <div className="audit-grid">
                  <section><strong>Hinweise</strong><ul>{nextRoundPreview.round.audit.messages.map((message, index) => <li key={`preview-audit-message-${index}`}>{message}</li>)}</ul></section>
                  <section><strong>Scoregruppen</strong><ul>{nextRoundPreview.round.audit.scoreGroups.map((message, index) => <li key={`preview-audit-score-${index}`}>{message}</li>)}</ul></section>
                  <section><strong>Floater</strong><ul>{nextRoundPreview.round.audit.floaters.length === 0 ? <li>keine</li> : nextRoundPreview.round.audit.floaters.map((message, index) => <li key={`preview-audit-floater-${index}`}>{message}</li>)}</ul></section>
                  <section><strong>Farben</strong><ul>{nextRoundPreview.round.audit.colorNotes.map((message, index) => <li key={`preview-audit-color-${index}`}>{message}</li>)}</ul></section>
                </div>
              </details>
              <div className="actions preview-actions">
                <button type="button" onClick={() => void generateRound()} disabled={!nextRoundPreview.isSavable}>Diese Runde jetzt auslosen</button>
                <button type="button" className="secondary" onClick={() => setNextRoundPreview(null)}>Vorschau schließen</button>
              </div>
            </article>
          )}

'@
if (-not $main.Contains('Auslosungsvorschau Runde {nextRoundPreview.roundNumber}')) {
    $anchor = '          <article className="card settings-card">'
    if (-not $main.Contains($anchor)) { throw "Anker fuer Preview-Karte nicht gefunden." }
    $main = $main.Replace($anchor, $previewCard + $anchor)
    Write-Step 'Preview-Karte im Dashboard ergänzt'
} else {
    Write-Step 'Preview-Karte bereits vorhanden'
}

Write-Text $mainPath $main

$stylesPath = 'src/SchachTurnierManager.WebApp/src/styles.css'
$styles = Read-Text $stylesPath
$previewCss = @'

.preview-card {
  border-width: 1px;
  display: grid;
  gap: 0.85rem;
}

.preview-card-header {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  align-items: flex-start;
}

.preview-card-header h3 {
  margin-bottom: 0.25rem;
}

.preview-score {
  min-width: 8rem;
  padding: 0.75rem;
  border-radius: 0.85rem;
  background: rgba(2, 6, 23, 0.55);
  text-align: center;
  border: 1px solid rgba(148, 163, 184, 0.22);
}

.preview-score strong {
  display: block;
  font-size: 1.65rem;
}

.preview-score span {
  color: #cbd5e1;
}

.preview-metrics {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
  gap: 0.5rem;
}

.preview-metrics span {
  padding: 0.55rem 0.65rem;
  border-radius: 0.65rem;
  background: rgba(2, 6, 23, 0.45);
  border: 1px solid rgba(148, 163, 184, 0.16);
  color: #cbd5e1;
}

.preview-message-list {
  padding: 0.65rem 0.65rem 0.65rem 1.5rem;
  border-radius: 0.75rem;
  background: rgba(2, 6, 23, 0.36);
  border: 1px solid rgba(148, 163, 184, 0.16);
}

.preview-pairings table {
  min-width: 820px;
}

.preview-audit {
  margin: 0;
}

.preview-actions {
  justify-content: flex-end;
}

@media (max-width: 760px) {
  .preview-card-header {
    display: grid;
  }

  .preview-actions {
    justify-content: stretch;
  }
}
'@
if (-not $styles.Contains('.preview-card')) {
    Write-Text $stylesPath ($styles.TrimEnd() + $previewCss + "`n")
    Write-Step 'CSS für Auslosungsvorschau ergänzt'
} else {
    Write-Step 'CSS für Auslosungsvorschau bereits vorhanden'
}

$changelogPath = 'CHANGELOG.md'
$changelog = Read-Text $changelogPath
$entry = @'
## 0.23.0 - Auslosungsvorschau im Dashboard

- Die Next-Round-Auslosungsvorschau ist jetzt direkt im Dashboard sichtbar.
- Die Vorschau zeigt Pairing-Qualität, Warnungen, Bretter, Byes, Rematches, Scoregruppen-Abweichungen, Farbfolge-Risiken und Audit-Details.
- Turnierleiter können die Vorschau schließen oder danach bewusst die Runde wirklich auslosen.

'@
if (-not $changelog.Contains('## 0.23.0 - Auslosungsvorschau im Dashboard')) {
    Write-Text $changelogPath ($entry + $changelog)
    Write-Step 'CHANGELOG.md ergänzt'
} else {
    Write-Step 'CHANGELOG.md enthält v0.23.0 bereits'
}

$handoff023 = @'
# Handoff 0.23.0 - Auslosungsvorschau im Dashboard

## Inhalt

- UI-Typ `NextRoundPreview` ergänzt.
- Dashboard-State `nextRoundPreview` ergänzt.
- Button `Auslosungsvorschau` neben `Nächste Runde auslosen` ergänzt.
- Vorschaukarte zeigt:
  - Zusammenfassung,
  - Qualitätswert und Schweregrad,
  - Rematches,
  - Scoregruppen-Abweichungen,
  - Farbfolge-Risiken,
  - Bye-Anzahl,
  - brettweise Hinweise,
  - Audit mit Scoregruppen, Floatern und Farbnotizen.
- Button `Diese Runde jetzt auslosen` ruft weiterhin den echten Persistenz-Endpunkt auf.
- Vorschau wird bei Turnierwechsel, leerem Turnier und echter Auslosung zurückgesetzt.

## Nachkontrolle

Dieses Patch-Skript führt aus:

- dotnet restore
- dotnet build
- dotnet test
- npm install
- npm run build
- scripts/Pack-Portable.ps1

## Nächster sinnvoller Schritt

v0.24.0: Vorschau wirklich übernehmen statt neu generieren, oder tieferer Swiss-Pairing-Verbesserungsblock mit Kandidatenlisten/Penalties.
'@
Write-Text 'docs/HANDOFF_0_23_0.md' ($handoff023 + "`n")
Write-Step 'Handoff ergänzt'

Normalize-Utf8NoBom @(
    'src/SchachTurnierManager.WebApi/Program.cs',
    'src/SchachTurnierManager.WebApp/package.json',
    'src/SchachTurnierManager.WebApp/package-lock.json',
    'src/SchachTurnierManager.WebApp/src/main.tsx',
    'src/SchachTurnierManager.WebApp/src/styles.css',
    'CHANGELOG.md',
    'docs/HANDOFF_0_23_0.md'
)

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
Run-Step 'Pack-Portable' { pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File '.\scripts\Pack-Portable.ps1' -NoPause }

Write-Step 'Nachkontrolle abgeschlossen. Bitte danach git status prüfen und committen.'
git status --short
