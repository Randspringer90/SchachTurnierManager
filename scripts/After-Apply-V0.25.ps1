$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-Step([string]$Message) { Write-Host "[v0.25.0] $Message" }

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
    $updated = $text -replace '0\.24\.1', '0.25.0'
    $updated = $updated -replace 'v0\.24\.1', 'v0.25.0'
    if ($updated -ne $text) {
        Write-Text $Path $updated
        Write-Step "$Path auf 0.25.0 gesetzt"
    } else {
        Write-Step "$Path enthielt keine 0.24.1-Version mehr"
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

$exportCenterHelpers = @'
  function latestRoundNumber(): number | null {
    if (!selectedTournament || selectedTournament.rounds.length === 0) {
      return null;
    }
    return selectedTournament.rounds.reduce((max, round) => Math.max(max, round.roundNumber), 0);
  }

  function activePlayerCount(): number {
    return selectedTournament?.players.filter(player => player.status === 0).length ?? 0;
  }

  function inactivePlayerCount(): number {
    return selectedTournament?.players.filter(player => player.status !== 0).length ?? 0;
  }

  function totalOpenBoardCount(): number {
    return roundDiagnostics.reduce((sum, item) => sum + item.openBoards, 0);
  }

  function totalForfeitBoardCount(): number {
    return roundDiagnostics.reduce((sum, item) => sum + item.forfeitBoards, 0);
  }

  function openLatestRoundPrint() {
    const roundNumber = latestRoundNumber();
    if (roundNumber === null) {
      setError('Es gibt noch keine Runde für den Rundenaushang.');
      return;
    }
    openRoundPrint(roundNumber);
  }

  function openLatestPairingsCsv() {
    const roundNumber = latestRoundNumber();
    if (!selectedTournament || roundNumber === null) {
      setError('Es gibt noch keine Runde für den Paarungsexport.');
      return;
    }
    window.open(`/api/tournaments/${selectedTournament.id}/pairings/export.csv?roundNumber=${roundNumber}`, '_blank', 'noopener,noreferrer');
  }

'@
Ensure-Contains $mainPath 'function openLatestRoundPrint' {
    param($text)
    $anchor = '  function openRoundPrint(roundNumber: number) {'
    if (-not $text.Contains($anchor)) { throw 'Anker fuer Exportcenter-Helfer nicht gefunden.' }
    return $text.Replace($anchor, $exportCenterHelpers + $anchor)
} 'Exportcenter-Helfer ergänzt'

$exportCenterCard = @'
            <article className="card export-center-card">
              <div className="export-center-header">
                <div>
                  <h3>Turnierleiter-Exportcenter</h3>
                  <p className="muted">Schnellzugriff auf Aushänge, Tabellen, Paarungen, Vorschau und Backup. Ideal vor, während und nach einer Runde.</p>
                </div>
                <span className="export-center-badge">v0.25</span>
              </div>

              <div className="export-center-metrics">
                <div><strong>{selectedTournament?.players.length ?? 0}</strong><span>Teilnehmer</span></div>
                <div><strong>{activePlayerCount()}</strong><span>aktiv</span></div>
                <div><strong>{inactivePlayerCount()}</strong><span>inaktiv</span></div>
                <div><strong>{selectedTournament?.rounds.length ?? 0}</strong><span>Runden</span></div>
                <div><strong>{totalOpenBoardCount()}</strong><span>offene Bretter</span></div>
                <div><strong>{totalForfeitBoardCount()}</strong><span>kampflos</span></div>
              </div>

              {totalOpenBoardCount() > 0 && <div className="export-center-warning"><strong>Offene Ergebnisse:</strong> Vor Finaltabellen oder Veröffentlichungen bitte offene Bretter prüfen.</div>}
              {nextRoundPreview?.pairingQuality.hasCriticalIssues && <div className="export-center-warning critical"><strong>Kritische Vorschau:</strong> Pairing-Hinweise vor Aushang oder Auslosung prüfen.</div>}

              <div className="export-center-grid">
                <section>
                  <h4>Aushänge</h4>
                  <div className="export-center-actions">
                    <button type="button" onClick={() => openTournamentExport('print/html')} disabled={!selectedTournament}>Gesamt-Druckansicht</button>
                    <button type="button" onClick={openLatestRoundPrint} disabled={!selectedTournament || selectedTournament.rounds.length === 0}>Aktuelle Runde drucken</button>
                    <button type="button" onClick={openNextRoundPreviewPrint} disabled={!selectedTournament || activePlayerCount() < 2}>Vorschau drucken</button>
                  </div>
                </section>
                <section>
                  <h4>CSV / Daten</h4>
                  <div className="export-center-actions">
                    <button type="button" className="secondary" onClick={() => void exportPlayers()} disabled={!selectedTournament}>Teilnehmer CSV</button>
                    <button type="button" className="secondary" onClick={() => openTournamentExport('standings/export.csv')} disabled={!selectedTournament}>Tabelle CSV</button>
                    <button type="button" className="secondary" onClick={() => openTournamentExport('pairings/export.csv')} disabled={!selectedTournament}>Alle Paarungen CSV</button>
                    <button type="button" className="secondary" onClick={openLatestPairingsCsv} disabled={!selectedTournament || selectedTournament.rounds.length === 0}>Aktuelle Paarungen CSV</button>
                    <button type="button" className="secondary" onClick={openNextRoundPreviewCsv} disabled={!selectedTournament || activePlayerCount() < 2}>Vorschau CSV</button>
                    <button type="button" className="secondary" onClick={() => void exportTournamentJson()} disabled={!selectedTournament}>Backup JSON</button>
                  </div>
                </section>
              </div>

              <p className="muted export-center-note">Hinweis: Vorschau-Exports speichern keine Runde. Erst „Diese Runde jetzt auslosen“ übernimmt die Paarungen ins Turnier.</p>
            </article>
'@
Ensure-Contains $mainPath 'Turnierleiter-Exportcenter' {
    param($text)
    $anchor = '            <article className="card">`n              <h3>Import / Export</h3>'
    if (-not $text.Contains($anchor)) {
        $anchor = "            <article className=`"card`">`r`n              <h3>Import / Export</h3>"
    }
    if (-not $text.Contains($anchor)) { throw 'Anker fuer Turnierleiter-Exportcenter nicht gefunden.' }
    return $text.Replace($anchor, $exportCenterCard.TrimEnd() + "`n`n" + $anchor)
} 'Turnierleiter-Exportcenter ergänzt'

$cssPath = 'src/SchachTurnierManager.WebApp/src/styles.css'
$exportCenterCss = @'
.export-center-card {
  border-color: rgba(96, 165, 250, 0.35);
  background: linear-gradient(180deg, rgba(15, 23, 42, 0.92), rgba(15, 23, 42, 0.78));
}

.export-center-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  margin-bottom: 1rem;
}

.export-center-badge {
  border: 1px solid rgba(96, 165, 250, 0.55);
  border-radius: 999px;
  padding: 0.25rem 0.55rem;
  font-size: 0.8rem;
  color: #bfdbfe;
  background: rgba(30, 64, 175, 0.28);
}

.export-center-metrics {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(110px, 1fr));
  gap: 0.65rem;
  margin: 1rem 0;
}

.export-center-metrics div {
  border: 1px solid rgba(148, 163, 184, 0.22);
  border-radius: 0.8rem;
  padding: 0.7rem;
  background: rgba(15, 23, 42, 0.45);
}

.export-center-metrics strong {
  display: block;
  font-size: 1.3rem;
}

.export-center-metrics span {
  color: #94a3b8;
  font-size: 0.85rem;
}

.export-center-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
  gap: 1rem;
}

.export-center-grid section {
  border: 1px solid rgba(148, 163, 184, 0.18);
  border-radius: 0.9rem;
  padding: 0.85rem;
  background: rgba(2, 6, 23, 0.22);
}

.export-center-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.export-center-warning {
  margin: 0.75rem 0;
  padding: 0.75rem 0.85rem;
  border-radius: 0.75rem;
  border: 1px solid rgba(245, 158, 11, 0.55);
  background: rgba(146, 64, 14, 0.18);
  color: #fde68a;
}

.export-center-warning.critical {
  border-color: rgba(248, 113, 113, 0.72);
  background: rgba(127, 29, 29, 0.24);
  color: #fecaca;
}

.export-center-note {
  margin-top: 0.85rem;
}
'@
Ensure-Contains $cssPath '.export-center-card' {
    param($text)
    return $text.TrimEnd() + "`n`n" + $exportCenterCss.TrimEnd() + "`n"
} 'CSS für Turnierleiter-Exportcenter ergänzt'

$changelogPath = 'CHANGELOG.md'
$changelog = Read-Text $changelogPath
if (-not $changelog.Contains('## 0.25.0')) {
    $entry = @'
## 0.25.0

- Ergänzt ein Turnierleiter-Exportcenter im Dashboard.
- Bündelt Aushänge, Tabellen-, Paarungs-, Vorschau- und Backup-Exporte an einer Stelle.
- Zeigt Schnellkennzahlen zu Teilnehmern, aktiven Spielern, Runden, offenen Brettern und kampflosen Partien.
- Ergänzt Warnhinweise für offene Ergebnisse und kritische Auslosungsvorschauen.
- Baut das Portable-Paket als `SchachTurnierManager_Portable_0.25.0.zip`.

'@
    Write-Text $changelogPath ($entry + $changelog.TrimStart())
    Write-Step 'CHANGELOG.md ergänzt'
} else {
    Write-Step 'CHANGELOG.md enthält v0.25.0 bereits'
}

$handoffPath = 'docs/HANDOFF_0_25_0.md'
$handoff = @'
# Handoff 0.25.0 – Turnierleiter-Exportcenter

## Ziel

v0.25.0 bündelt die inzwischen vorhandenen Export- und Druckfunktionen an einer zentralen Stelle im Dashboard. Das Feature ist bewusst UI-/Workflow-orientiert und nutzt vorhandene geprüfte Backend-Endpunkte, statt die Pairing-Engine erneut anzufassen.

## Inhalt

- Version auf 0.25.0 angehoben
- neues Dashboard-Panel „Turnierleiter-Exportcenter“
- Kennzahlen:
  - Teilnehmer
  - aktive Spieler
  - inaktive/zurückgezogene Spieler
  - Runden
  - offene Bretter
  - kampflose Bretter
- Schnellaktionen:
  - Gesamt-Druckansicht
  - aktuelle Runde drucken
  - Vorschau drucken
  - Teilnehmer CSV
  - Tabelle CSV
  - alle Paarungen CSV
  - aktuelle Paarungen CSV
  - Vorschau CSV
  - Backup JSON
- Warnhinweise für offene Ergebnisse und kritische Vorschauen
- CSS für Exportcenter ergänzt

## Nachkontrolle

Das Apply-Script führt aus:

- `dotnet restore`
- `dotnet build --no-restore`
- `dotnet test --no-build`
- `npm install`
- `npm run build`
- `scripts\Pack-Portable.ps1`
- `git status --short`

## Nächste sinnvolle Schritte

- bestehende alte Import-/Export-Karte ggf. in v0.25.1 verschlanken oder in das Exportcenter integrieren
- danach fachlicher Block: kampflos/Bye/Buchholz-Feinheiten oder weitere Härtung der FIDE-Dutch-Auslosung
'@
Write-Text $handoffPath $handoff
Write-Step 'Handoff ergänzt'

foreach ($path in @(
    'src/SchachTurnierManager.WebApi/Program.cs',
    'src/SchachTurnierManager.WebApp/package.json',
    'src/SchachTurnierManager.WebApp/package-lock.json',
    'src/SchachTurnierManager.WebApp/src/main.tsx',
    'src/SchachTurnierManager.WebApp/src/styles.css',
    'CHANGELOG.md',
    'docs/HANDOFF_0_25_0.md',
    'scripts/After-Apply-V0.25.ps1'
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
