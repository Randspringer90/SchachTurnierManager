$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-Step([string]$Message) { Write-Host "[v0.26.0] $Message" }

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
    $updated = $text -replace '0\.25\.0', '0.26.0'
    $updated = $updated -replace 'v0\.25\.0', 'v0.26.0'
    if ($updated -ne $text) {
        Write-Text $Path $updated
        Write-Step "$Path auf 0.26.0 gesetzt"
    } else {
        Write-Step "$Path ist bereits auf 0.26.0 oder enthielt keine 0.25.0-Version mehr"
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

Replace-Version 'src/SchachTurnierManager.WebApi/Program.cs'
Replace-Version 'src/SchachTurnierManager.WebApp/package.json'
Replace-Version 'src/SchachTurnierManager.WebApp/package-lock.json'
Replace-Version 'src/SchachTurnierManager.WebApp/src/main.tsx'

$mainPath = 'src/SchachTurnierManager.WebApp/src/main.tsx'

$resultReviewHelpers = @'
  function completedRoundCount(): number {
    return roundDiagnostics.filter(item => item.isComplete).length;
  }

  function unverifiedCompleteRoundCount(): number {
    return roundDiagnostics.filter(item => item.isComplete && !item.isVerified).length;
  }

  function lockedRoundCount(): number {
    return selectedTournament?.rounds.filter(round => round.isLocked).length ?? 0;
  }

  function diagnosticWarningCount(): number {
    return roundDiagnostics.reduce((sum, item) => sum + item.warnings.length, 0);
  }

  function resultReviewRows() {
    return roundDiagnostics
      .flatMap(round => round.boards
        .filter(board => board.isOpen || board.isForfeit || board.note.trim().length > 0)
        .map(board => ({
          roundNumber: round.roundNumber,
          boardNumber: board.boardNumber,
          white: board.white,
          black: board.black,
          resultLabel: board.resultLabel,
          note: board.note,
          kind: board.isOpen ? 'offen' : board.isForfeit ? 'kampflos' : 'Hinweis'
        })))
      .slice(0, 12);
  }

  function resultReviewStatusLabel(): string {
    if (!selectedTournament || selectedTournament.rounds.length === 0) {
      return 'noch keine Runde';
    }
    if (totalOpenBoardCount() > 0) {
      return 'offene Ergebnisse';
    }
    if (unverifiedCompleteRoundCount() > 0) {
      return 'Prüfung offen';
    }
    if (diagnosticWarningCount() > 0) {
      return 'Hinweise prüfen';
    }
    return 'bereit';
  }

  function resultReviewStatusClass(): string {
    const label = resultReviewStatusLabel();
    if (label === 'bereit') {
      return 'result-review-status ok';
    }
    if (label === 'offene Ergebnisse') {
      return 'result-review-status danger';
    }
    return 'result-review-status warn';
  }

'@
Ensure-Contains $mainPath 'function resultReviewRows' {
    param($text)
    $anchor = '  return ('
    if (-not $text.Contains($anchor)) { throw 'Anker fuer Rundenabschluss-Helfer nicht gefunden.' }
    return $text.Replace($anchor, $resultReviewHelpers + $anchor)
} 'Rundenabschluss-Helfer ergänzt'

$resultReviewCard = @'
            <article className="card result-review-card">
              <div className="result-review-header">
                <div>
                  <h3>Rundenabschluss-Checkliste</h3>
                  <p className="muted">Prüft offene Ergebnisse, kampflose Bretter, ungeprüfte Runden und Diagnosehinweise vor Aushang oder nächster Auslosung.</p>
                </div>
                <span className={resultReviewStatusClass()}>{resultReviewStatusLabel()}</span>
              </div>

              <div className="result-review-metrics">
                <div><strong>{selectedTournament?.rounds.length ?? 0}</strong><span>Runden</span></div>
                <div><strong>{completedRoundCount()}</strong><span>vollständig</span></div>
                <div><strong>{totalOpenBoardCount()}</strong><span>offen</span></div>
                <div><strong>{totalForfeitBoardCount()}</strong><span>kampflos</span></div>
                <div><strong>{unverifiedCompleteRoundCount()}</strong><span>ungeprüft</span></div>
                <div><strong>{lockedRoundCount()}</strong><span>gesperrt</span></div>
                <div><strong>{diagnosticWarningCount()}</strong><span>Hinweise</span></div>
              </div>

              {!selectedTournament && <p className="muted">Bitte zuerst ein Turnier auswählen.</p>}
              {selectedTournament && selectedTournament.rounds.length === 0 && <div className="result-review-empty">Noch keine Runde ausgelost. Die Checkliste wird aktiv, sobald Paarungen vorhanden sind.</div>}
              {selectedTournament && selectedTournament.rounds.length > 0 && totalOpenBoardCount() === 0 && unverifiedCompleteRoundCount() === 0 && diagnosticWarningCount() === 0 && <div className="result-review-ok">Alle bekannten Runden sind vollständig, geprüft oder ohne Diagnosewarnung. Der Turnierbericht kann veröffentlicht werden.</div>}
              {totalOpenBoardCount() > 0 && <div className="result-review-warning danger"><strong>Offene Ergebnisse:</strong> Vor Tabelle, Aushang oder nächster Auslosung bitte alle offenen Bretter erfassen.</div>}
              {unverifiedCompleteRoundCount() > 0 && totalOpenBoardCount() === 0 && <div className="result-review-warning"><strong>Prüfung offen:</strong> Mindestens eine vollständige Runde ist noch nicht als geprüft markiert.</div>}

              {resultReviewRows().length > 0 && (
                <div className="table-wrap result-review-table-wrap">
                  <table>
                    <thead>
                      <tr><th>Runde</th><th>Brett</th><th>Weiß</th><th>Schwarz</th><th>Status</th><th>Hinweis</th></tr>
                    </thead>
                    <tbody>
                      {resultReviewRows().map(row => (
                        <tr key={`${row.roundNumber}-${row.boardNumber}-${row.kind}`}>
                          <td>{row.roundNumber}</td>
                          <td>{row.boardNumber}</td>
                          <td>{row.white}</td>
                          <td>{row.black}</td>
                          <td><span className={`result-review-chip ${row.kind === 'offen' ? 'danger' : row.kind === 'kampflos' ? 'warn' : ''}`}>{row.kind}</span></td>
                          <td>{row.note || row.resultLabel}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}

              <div className="result-review-actions">
                <button type="button" onClick={openLatestRoundPrint} disabled={!selectedTournament || selectedTournament.rounds.length === 0}>Aktuelle Runde drucken</button>
                <button type="button" className="secondary" onClick={() => openTournamentExport('print/html')} disabled={!selectedTournament}>Turnierbericht öffnen</button>
                <button type="button" className="secondary" onClick={() => openTournamentExport('standings/export.csv')} disabled={!selectedTournament}>Tabelle CSV</button>
              </div>
            </article>
'@
Ensure-Contains $mainPath 'Rundenabschluss-Checkliste' {
    param($text)

    $normalized = $text -replace "`r`n", "`n"
    $marker = '<h3>Turnierleiter-Exportcenter</h3>'
    $markerIndex = $normalized.IndexOf($marker, [System.StringComparison]::Ordinal)
    if ($markerIndex -lt 0) {
        throw 'Anker fuer Rundenabschluss-Checkliste nicht gefunden: Turnierleiter-Exportcenter fehlt.'
    }

    $beforeMarker = $normalized.Substring(0, $markerIndex)
    $articleIndex = $beforeMarker.LastIndexOf('<article className="card export-center-card"', [System.StringComparison]::Ordinal)
    if ($articleIndex -lt 0) {
        $articleIndex = $beforeMarker.LastIndexOf('<article className="card"', [System.StringComparison]::Ordinal)
    }
    if ($articleIndex -lt 0) {
        throw 'Anker fuer Rundenabschluss-Checkliste nicht gefunden: Exportcenter-Article konnte nicht bestimmt werden.'
    }

    return $normalized.Substring(0, $articleIndex) + $resultReviewCard.TrimEnd() + "`n`n" + $normalized.Substring($articleIndex)
} 'Rundenabschluss-Checkliste ergänzt'

$cssPath = 'src/SchachTurnierManager.WebApp/src/styles.css'
$resultReviewCss = @'
.result-review-card {
  border-color: rgba(34, 197, 94, 0.28);
  background: linear-gradient(180deg, rgba(20, 83, 45, 0.2), rgba(15, 23, 42, 0.76));
}

.result-review-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  margin-bottom: 1rem;
}

.result-review-status {
  border-radius: 999px;
  padding: 0.3rem 0.7rem;
  font-size: 0.82rem;
  font-weight: 700;
  border: 1px solid rgba(148, 163, 184, 0.35);
  color: #e5e7eb;
  background: rgba(71, 85, 105, 0.35);
  white-space: nowrap;
}

.result-review-status.ok {
  color: #bbf7d0;
  background: rgba(22, 101, 52, 0.28);
  border-color: rgba(34, 197, 94, 0.4);
}

.result-review-status.warn {
  color: #fde68a;
  background: rgba(120, 53, 15, 0.32);
  border-color: rgba(245, 158, 11, 0.45);
}

.result-review-status.danger {
  color: #fecaca;
  background: rgba(127, 29, 29, 0.36);
  border-color: rgba(248, 113, 113, 0.45);
}

.result-review-metrics {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(105px, 1fr));
  gap: 0.65rem;
  margin: 1rem 0;
}

.result-review-metrics div {
  border: 1px solid rgba(148, 163, 184, 0.22);
  border-radius: 0.85rem;
  padding: 0.7rem;
  background: rgba(15, 23, 42, 0.46);
}

.result-review-metrics strong {
  display: block;
  font-size: 1.35rem;
}

.result-review-metrics span {
  display: block;
  color: #94a3b8;
  font-size: 0.82rem;
  margin-top: 0.15rem;
}

.result-review-empty,
.result-review-ok,
.result-review-warning {
  border-radius: 0.9rem;
  padding: 0.75rem 0.9rem;
  margin: 0.8rem 0;
  border: 1px solid rgba(148, 163, 184, 0.24);
  background: rgba(15, 23, 42, 0.42);
}

.result-review-ok {
  color: #bbf7d0;
  border-color: rgba(34, 197, 94, 0.35);
  background: rgba(22, 101, 52, 0.2);
}

.result-review-warning {
  color: #fde68a;
  border-color: rgba(245, 158, 11, 0.36);
  background: rgba(120, 53, 15, 0.22);
}

.result-review-warning.danger {
  color: #fecaca;
  border-color: rgba(248, 113, 113, 0.42);
  background: rgba(127, 29, 29, 0.24);
}

.result-review-table-wrap {
  margin-top: 0.8rem;
}

.result-review-chip {
  display: inline-flex;
  align-items: center;
  border-radius: 999px;
  border: 1px solid rgba(148, 163, 184, 0.28);
  padding: 0.15rem 0.45rem;
  font-size: 0.78rem;
  color: #cbd5e1;
  background: rgba(51, 65, 85, 0.4);
}

.result-review-chip.warn {
  color: #fde68a;
  border-color: rgba(245, 158, 11, 0.35);
  background: rgba(120, 53, 15, 0.24);
}

.result-review-chip.danger {
  color: #fecaca;
  border-color: rgba(248, 113, 113, 0.42);
  background: rgba(127, 29, 29, 0.24);
}

.result-review-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.55rem;
  margin-top: 1rem;
}
'@
Ensure-Contains $cssPath '.result-review-card' {
    param($text)
    return $text.TrimEnd() + "`n`n" + $resultReviewCss.Trim() + "`n"
} 'CSS für Rundenabschluss-Checkliste ergänzt'

$changelogPath = 'CHANGELOG.md'
Ensure-Contains $changelogPath '## v0.26.0' {
    param($text)
    $entry = @'
## v0.26.0

- Dashboard um eine Rundenabschluss-Checkliste erweitert.
- Offene Ergebnisse, kampflose Bretter, ungeprüfte vollständige Runden und Diagnosehinweise werden zentral sichtbar.
- Schnellaktionen für aktuelle Runde, Turnierbericht und Tabellen-CSV ergänzt.
- Version auf 0.26.0 angehoben.

'@
    return $entry + $text.TrimStart()
} 'CHANGELOG.md ergänzt'

$handoff = @'
# Handoff v0.26.0 – Rundenabschluss-Checkliste

## Ziel

v0.26.0 ergänzt ein Turnierleiter-Panel im Dashboard, das den Zustand vor Aushang, Veröffentlichung und nächster Auslosung sichtbar macht.

## Enthalten

- Versionen auf 0.26.0 gesetzt.
- Neue Rundenabschluss-Checkliste im Dashboard.
- Kennzahlen: Runden, vollständige Runden, offene Bretter, kampflose Bretter, ungeprüfte fertige Runden, gesperrte Runden und Diagnosehinweise.
- Kompakte Tabelle der wichtigsten offenen/kampflosen/auffälligen Bretter.
- Schnellaktionen für aktuelle Runde, Turnierbericht und Tabellen-CSV.
- CSS für Status-Badges, Warnungen und Review-Tabelle.

## Nicht geändert

- Keine Änderung an Swiss-/Round-Robin-Auslosungslogik.
- Keine Änderung an Wertungsberechnung.
- Keine Änderung an Speicherformaten.

## Erwartete Checks

- dotnet restore
- dotnet build
- dotnet test
- npm install
- npm run build
- scripts/Pack-Portable.ps1
'@
Write-Text 'docs/HANDOFF_0_26_0.md' $handoff
Write-Step 'Handoff ergänzt'

$normalizeFiles = @(
    'src/SchachTurnierManager.WebApi/Program.cs',
    'src/SchachTurnierManager.WebApp/package.json',
    'src/SchachTurnierManager.WebApp/package-lock.json',
    'src/SchachTurnierManager.WebApp/src/main.tsx',
    'src/SchachTurnierManager.WebApp/src/styles.css',
    'CHANGELOG.md',
    'docs/HANDOFF_0_26_0.md',
    'scripts/After-Apply-V0.26.ps1'
)
foreach ($file in $normalizeFiles) {
    if (Test-Path -LiteralPath $file) {
        Write-Text $file (Read-Text $file)
        Write-Step "$file als UTF-8 ohne BOM gespeichert"
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
