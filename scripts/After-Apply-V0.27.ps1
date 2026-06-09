$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-Step([string]$Message) { Write-Host "[v0.27.0] $Message" }

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
    $updated = $text -replace '0\.26\.0', '0.27.0'
    $updated = $updated -replace 'v0\.26\.0', 'v0.27.0'
    if ($updated -ne $text) {
        Write-Text $Path $updated
        Write-Step "$Path auf 0.27.0 gesetzt"
    } else {
        Write-Step "$Path ist bereits auf 0.27.0 oder enthielt keine 0.26.0-Version mehr"
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

$byeForfeitHelpers = @'
  function totalByeBoardCount(): number {
    return roundDiagnostics.reduce((sum, item) => sum + item.byeBoards, 0);
  }

  function byeForfeitAffectedRoundCount(): number {
    return new Set(roundDiagnostics
      .filter(item => item.byeBoards > 0 || item.forfeitBoards > 0)
      .map(item => item.roundNumber)).size;
  }

  function byeForfeitRows() {
    return roundDiagnostics
      .flatMap(round => round.boards
        .filter(board => board.isForfeit
          || board.note.toLowerCase().includes('bye')
          || board.note.toLowerCase().includes('spielfrei')
          || board.black.toLowerCase().includes('spielfrei'))
        .map(board => ({
          roundNumber: round.roundNumber,
          boardNumber: board.boardNumber,
          white: board.white,
          black: board.black,
          resultLabel: board.resultLabel,
          note: board.note,
          isForfeit: board.isForfeit,
          countsForBuchholz: board.countsForBuchholz,
          countsForDirectAndSonneborn: board.countsForDirectAndSonneborn,
          countsForPerformance: board.countsForPerformance,
          kind: board.note.toLowerCase().includes('bye') || board.note.toLowerCase().includes('spielfrei') || board.black.toLowerCase().includes('spielfrei') ? 'Bye/spielfrei' : 'kampflos'
        })))
      .slice(0, 20);
  }

  function byeForfeitAuditStatusLabel(): string {
    if (!selectedTournament || selectedTournament.rounds.length === 0) {
      return 'noch keine Runde';
    }
    if (totalForfeitBoardCount() > 0) {
      return 'kampflos prüfen';
    }
    if (totalByeBoardCount() > 0) {
      return 'Bye sichtbar';
    }
    return 'keine Fälle';
  }

  function byeForfeitAuditStatusClass(): string {
    const label = byeForfeitAuditStatusLabel();
    if (label === 'keine Fälle') {
      return 'bye-forfeit-status ok';
    }
    if (label === 'kampflos prüfen') {
      return 'bye-forfeit-status warn';
    }
    return 'bye-forfeit-status info';
  }

'@
Ensure-Contains $mainPath 'function byeForfeitRows' {
    param($text)
    $anchor = '  return ('
    if (-not $text.Contains($anchor)) { throw 'Anker fuer Bye-/Kampflos-Helfer nicht gefunden.' }
    return $text.Replace($anchor, $byeForfeitHelpers + $anchor)
} 'Bye-/Kampflos-Helfer ergänzt'

$byeForfeitCard = @'
            <article className="card bye-forfeit-card">
              <div className="bye-forfeit-header">
                <div>
                  <h3>Bye- und Kampflos-Audit</h3>
                  <p className="muted">Macht spielfreie und kampflose Bretter inklusive Wertungswirkung sichtbar. Das hilft vor Tabelle, Export und nächster Auslosung.</p>
                </div>
                <span className={byeForfeitAuditStatusClass()}>{byeForfeitAuditStatusLabel()}</span>
              </div>

              <div className="bye-forfeit-metrics">
                <div><strong>{totalByeBoardCount()}</strong><span>Bye/spielfrei</span></div>
                <div><strong>{totalForfeitBoardCount()}</strong><span>kampflos</span></div>
                <div><strong>{byeForfeitAffectedRoundCount()}</strong><span>betroffene Runden</span></div>
                <div><strong>{byeForfeitRows().length}</strong><span>sichtbare Fälle</span></div>
              </div>

              {!selectedTournament && <p className="muted">Bitte zuerst ein Turnier auswählen.</p>}
              {selectedTournament && selectedTournament.rounds.length === 0 && <div className="bye-forfeit-empty">Noch keine Runde vorhanden. Bye- und Kampflos-Fälle werden nach der ersten Auslosung angezeigt.</div>}
              {selectedTournament && selectedTournament.rounds.length > 0 && byeForfeitRows().length === 0 && <div className="bye-forfeit-ok">Keine Bye- oder kampflosen Bretter in den aktuellen Diagnosen gefunden.</div>}
              {totalForfeitBoardCount() > 0 && <div className="bye-forfeit-warning"><strong>Kampflos-Fälle prüfen:</strong> Bitte vor Veröffentlichung kontrollieren, ob Buchholz, Sonneborn-Berger, Direktwertung und Performance korrekt behandelt werden.</div>}
              {totalByeBoardCount() > 0 && <div className="bye-forfeit-warning info"><strong>Bye/spielfrei vorhanden:</strong> Aushänge und Exporte sollten eindeutig zeigen, wer spielfrei war und wie dies gewertet wurde.</div>}

              {byeForfeitRows().length > 0 && (
                <div className="table-wrap bye-forfeit-table-wrap">
                  <table>
                    <thead>
                      <tr><th>Runde</th><th>Brett</th><th>Weiß</th><th>Schwarz</th><th>Art</th><th>Ergebnis</th><th>BH</th><th>Direkt/SB</th><th>Perf.</th><th>Hinweis</th></tr>
                    </thead>
                    <tbody>
                      {byeForfeitRows().map(row => (
                        <tr key={`${row.roundNumber}-${row.boardNumber}-${row.kind}`}>
                          <td>{row.roundNumber}</td>
                          <td>{row.boardNumber}</td>
                          <td>{row.white}</td>
                          <td>{row.black}</td>
                          <td><span className={`bye-forfeit-chip ${row.isForfeit ? 'warn' : 'info'}`}>{row.kind}</span></td>
                          <td>{row.resultLabel}</td>
                          <td>{row.countsForBuchholz ? 'ja' : 'nein'}</td>
                          <td>{row.countsForDirectAndSonneborn ? 'ja' : 'nein'}</td>
                          <td>{row.countsForPerformance ? 'ja' : 'nein'}</td>
                          <td>{row.note || '—'}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}

              <div className="bye-forfeit-actions">
                <button type="button" onClick={openLatestRoundPrint} disabled={!selectedTournament || selectedTournament.rounds.length === 0}>Aktuelle Runde drucken</button>
                <button type="button" className="secondary" onClick={() => openTournamentExport('pairings/export.csv')} disabled={!selectedTournament}>Paarungen CSV</button>
                <button type="button" className="secondary" onClick={() => openTournamentExport('print/html')} disabled={!selectedTournament}>Turnierbericht öffnen</button>
              </div>
            </article>
'@
Ensure-Contains $mainPath 'Bye- und Kampflos-Audit' {
    param($text)

    $normalized = $text -replace "`r`n", "`n"
    $marker = '<h3>Rundenabschluss-Checkliste</h3>'
    $markerIndex = $normalized.IndexOf($marker, [System.StringComparison]::Ordinal)
    if ($markerIndex -lt 0) {
        throw 'Anker fuer Bye- und Kampflos-Audit nicht gefunden: Rundenabschluss-Checkliste fehlt.'
    }

    $beforeMarker = $normalized.Substring(0, $markerIndex)
    $articleIndex = $beforeMarker.LastIndexOf('<article className="card result-review-card"', [System.StringComparison]::Ordinal)
    if ($articleIndex -lt 0) {
        $articleIndex = $beforeMarker.LastIndexOf('<article className="card"', [System.StringComparison]::Ordinal)
    }
    if ($articleIndex -lt 0) {
        throw 'Anker fuer Bye- und Kampflos-Audit nicht gefunden: Article konnte nicht bestimmt werden.'
    }

    return $normalized.Substring(0, $articleIndex) + $byeForfeitCard.TrimEnd() + "`n`n" + $normalized.Substring($articleIndex)
} 'Bye- und Kampflos-Audit ergänzt'

$cssPath = 'src/SchachTurnierManager.WebApp/src/styles.css'
$byeForfeitCss = @'
.bye-forfeit-card {
  border-color: rgba(245, 158, 11, 0.32);
  background: linear-gradient(180deg, rgba(120, 53, 15, 0.18), rgba(15, 23, 42, 0.78));
}

.bye-forfeit-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  margin-bottom: 1rem;
}

.bye-forfeit-status {
  border-radius: 999px;
  padding: 0.3rem 0.7rem;
  font-size: 0.82rem;
  font-weight: 700;
  white-space: nowrap;
  border: 1px solid rgba(148, 163, 184, 0.35);
  color: #e5e7eb;
  background: rgba(71, 85, 105, 0.35);
}

.bye-forfeit-status.ok {
  color: #bbf7d0;
  background: rgba(22, 101, 52, 0.28);
  border-color: rgba(34, 197, 94, 0.4);
}

.bye-forfeit-status.info {
  color: #bfdbfe;
  background: rgba(30, 64, 175, 0.26);
  border-color: rgba(96, 165, 250, 0.42);
}

.bye-forfeit-status.warn {
  color: #fde68a;
  background: rgba(120, 53, 15, 0.32);
  border-color: rgba(245, 158, 11, 0.45);
}

.bye-forfeit-metrics {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
  gap: 0.65rem;
  margin: 1rem 0;
}

.bye-forfeit-metrics div {
  border: 1px solid rgba(148, 163, 184, 0.22);
  border-radius: 0.85rem;
  padding: 0.7rem;
  background: rgba(15, 23, 42, 0.46);
}

.bye-forfeit-metrics strong {
  display: block;
  font-size: 1.35rem;
}

.bye-forfeit-metrics span {
  display: block;
  color: #94a3b8;
  font-size: 0.82rem;
  margin-top: 0.15rem;
}

.bye-forfeit-empty,
.bye-forfeit-ok,
.bye-forfeit-warning {
  border-radius: 0.9rem;
  padding: 0.75rem 0.9rem;
  margin: 0.8rem 0;
  border: 1px solid rgba(148, 163, 184, 0.24);
  background: rgba(15, 23, 42, 0.42);
}

.bye-forfeit-ok {
  color: #bbf7d0;
  border-color: rgba(34, 197, 94, 0.35);
  background: rgba(22, 101, 52, 0.2);
}

.bye-forfeit-warning {
  color: #fde68a;
  border-color: rgba(245, 158, 11, 0.36);
  background: rgba(120, 53, 15, 0.22);
}

.bye-forfeit-warning.info {
  color: #bfdbfe;
  border-color: rgba(96, 165, 250, 0.38);
  background: rgba(30, 64, 175, 0.18);
}

.bye-forfeit-table-wrap {
  margin-top: 0.8rem;
}

.bye-forfeit-chip {
  display: inline-flex;
  align-items: center;
  border-radius: 999px;
  border: 1px solid rgba(148, 163, 184, 0.28);
  padding: 0.15rem 0.45rem;
  font-size: 0.78rem;
  color: #cbd5e1;
  background: rgba(51, 65, 85, 0.4);
}

.bye-forfeit-chip.warn {
  color: #fde68a;
  border-color: rgba(245, 158, 11, 0.35);
  background: rgba(120, 53, 15, 0.24);
}

.bye-forfeit-chip.info {
  color: #bfdbfe;
  border-color: rgba(96, 165, 250, 0.38);
  background: rgba(30, 64, 175, 0.18);
}

.bye-forfeit-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.55rem;
  margin-top: 1rem;
}
'@
Ensure-Contains $cssPath '.bye-forfeit-card' {
    param($text)
    return $text.TrimEnd() + "`n`n" + $byeForfeitCss.Trim() + "`n"
} 'CSS für Bye- und Kampflos-Audit ergänzt'

$changelogPath = 'CHANGELOG.md'
Ensure-Contains $changelogPath '## v0.27.0' {
    param($text)
    $entry = @'
## v0.27.0

- Dashboard um ein Bye- und Kampflos-Audit erweitert.
- Spielfreie und kampflose Bretter werden inklusive Wertungswirkung sichtbar gemacht.
- Anzeige für Buchholz-, Direkt-/Sonneborn-Berger- und Performance-Wertung ergänzt.
- Schnellaktionen für aktuelle Runde, Paarungen-CSV und Turnierbericht ergänzt.
- Version auf 0.27.0 angehoben.

'@
    return $entry + $text.TrimStart()
} 'CHANGELOG.md ergänzt'

$handoff = @'
# Handoff v0.27.0 – Bye- und Kampflos-Audit

## Ziel

v0.27.0 ergänzt ein Dashboard-Panel für spielfreie und kampflose Bretter. Turnierleiter sehen dadurch schneller, welche Runden betroffen sind und wie diese Bretter in Wertungen und Exporte eingehen.

## Enthalten

- Versionen auf 0.27.0 gesetzt.
- Neue Helfer für Bye-/Kampflos-Zählung und Auditzeilen.
- Neues Dashboard-Panel „Bye- und Kampflos-Audit“.
- Kennzahlen: Bye/spielfrei, kampflos, betroffene Runden, sichtbare Fälle.
- Tabelle mit Runde, Brett, Spielern, Ergebnis, Art und Wertungswirkung.
- Schnellaktionen: aktuelle Runde drucken, Paarungen CSV, Turnierbericht öffnen.
- CSS für Status-Badges, Warnungen und Audit-Tabelle.

## Nicht geändert

- Keine Änderung an Auslosungslogik.
- Keine Änderung an Wertungsberechnung.
- Keine Änderung an Persistenz oder Datenmodell.

## Erwartete Checks

- dotnet restore
- dotnet build
- dotnet test
- npm install
- npm run build
- scripts/Pack-Portable.ps1
'@
Write-Text 'docs/HANDOFF_0_27_0.md' $handoff
Write-Step 'Handoff ergänzt'

$normalizeFiles = @(
    'src/SchachTurnierManager.WebApi/Program.cs',
    'src/SchachTurnierManager.WebApp/package.json',
    'src/SchachTurnierManager.WebApp/package-lock.json',
    'src/SchachTurnierManager.WebApp/src/main.tsx',
    'src/SchachTurnierManager.WebApp/src/styles.css',
    'CHANGELOG.md',
    'docs/HANDOFF_0_27_0.md',
    'scripts/After-Apply-V0.27.ps1'
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
