$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-Step([string]$Message) { Write-Host "[v0.28.0] $Message" }

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
    $updated = $text -replace '0\.27\.0', '0.28.0'
    $updated = $updated -replace 'v0\.27\.0', 'v0.28.0'
    if ($updated -ne $text) {
        Write-Text $Path $updated
        Write-Step "$Path auf 0.28.0 gesetzt"
    } else {
        Write-Step "$Path ist bereits auf 0.28.0 oder enthielt keine 0.27.0-Version mehr"
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

$readinessHelpers = @'
  function pairingReadinessOpenResultCount(): number {
    return totalOpenBoardCount();
  }

  function pairingReadinessUnverifiedRoundCount(): number {
    if (!selectedTournament) {
      return 0;
    }

    return selectedTournament.rounds.filter(round => {
      const diagnostics = diagnosticsFor(round.roundNumber);
      return diagnostics !== undefined && diagnostics.openBoards === 0 && !round.isVerified;
    }).length;
  }

  function pairingReadinessIssues(): string[] {
    const issues: string[] = [];

    if (!selectedTournament) {
      issues.push('Kein Turnier ausgewählt.');
      return issues;
    }

    const activePlayers = selectedTournament.players.filter(player => player.status === 0).length;
    if (activePlayers < 2) {
      issues.push('Für eine Auslosung werden mindestens zwei aktive Spieler benötigt.');
    }

    const openResults = pairingReadinessOpenResultCount();
    if (openResults > 0) {
      issues.push(`${openResults} offene Ergebnis(se) müssen vor der nächsten Auslosung geklärt werden.`);
    }

    const unverifiedRounds = pairingReadinessUnverifiedRoundCount();
    if (unverifiedRounds > 0) {
      issues.push(`${unverifiedRounds} vollständige Runde(n) sind noch nicht als geprüft markiert.`);
    }

    if (nextRoundPreview?.pairingQuality.hasCriticalIssues) {
      issues.push('Die aktuelle Auslosungsvorschau enthält kritische Hinweise. Bitte vor dem Speichern prüfen.');
    }

    return issues;
  }

  function pairingReadinessStatusLabel(): string {
    if (!selectedTournament) {
      return 'kein Turnier';
    }

    if (pairingReadinessOpenResultCount() > 0 || selectedTournament.players.filter(player => player.status === 0).length < 2) {
      return 'blockiert';
    }

    if (pairingReadinessUnverifiedRoundCount() > 0 || nextRoundPreview?.pairingQuality.hasCriticalIssues) {
      return 'prüfen';
    }

    return 'bereit';
  }

  function pairingReadinessStatusClass(): string {
    const label = pairingReadinessStatusLabel();
    if (label === 'bereit') {
      return 'pairing-readiness-status ok';
    }
    if (label === 'prüfen') {
      return 'pairing-readiness-status warn';
    }
    if (label === 'blockiert') {
      return 'pairing-readiness-status danger';
    }
    return 'pairing-readiness-status neutral';
  }

  function pairingReadinessCanCreatePreview(): boolean {
    if (!selectedTournament) {
      return false;
    }

    return selectedTournament.players.filter(player => player.status === 0).length >= 2 && pairingReadinessOpenResultCount() === 0;
  }

  function pairingReadinessCanGenerateRound(): boolean {
    return pairingReadinessCanCreatePreview() && pairingReadinessUnverifiedRoundCount() === 0 && !nextRoundPreview?.pairingQuality.hasCriticalIssues;
  }

'@
Ensure-Contains $mainPath 'function pairingReadinessIssues' {
    param($text)
    $anchor = '  return ('
    if (-not $text.Contains($anchor)) { throw 'Anker fuer Auslosungsfreigabe-Helfer nicht gefunden.' }
    return $text.Replace($anchor, $readinessHelpers + $anchor)
} 'Auslosungsfreigabe-Helfer ergänzt'

$readinessCard = @'
            <article className="card pairing-readiness-card">
              <div className="pairing-readiness-header">
                <div>
                  <h3>Auslosungsfreigabe</h3>
                  <p className="muted">Prüft vor der nächsten Auslosung, ob Ergebnisse, Rundenprüfung und Vorschauqualität zusammenpassen.</p>
                </div>
                <span className={pairingReadinessStatusClass()}>{pairingReadinessStatusLabel()}</span>
              </div>

              <div className="pairing-readiness-metrics">
                <div><strong>{pairingReadinessOpenResultCount()}</strong><span>offene Ergebnisse</span></div>
                <div><strong>{pairingReadinessUnverifiedRoundCount()}</strong><span>ungeprüfte Runden</span></div>
                <div><strong>{selectedTournament?.players.filter(player => player.status === 0).length ?? 0}</strong><span>aktive Spieler</span></div>
                <div><strong>{nextRoundPreview ? nextRoundPreview.pairingQuality.qualityScore : '—'}</strong><span>Vorschauqualität</span></div>
              </div>

              {pairingReadinessIssues().length === 0 ? (
                <div className="pairing-readiness-ok"><strong>Bereit:</strong> Es sind keine blockierenden Punkte für die nächste Auslosung sichtbar.</div>
              ) : (
                <div className="pairing-readiness-warning">
                  <strong>Vor der nächsten Auslosung prüfen:</strong>
                  <ul>
                    {pairingReadinessIssues().map((issue, index) => <li key={index}>{issue}</li>)}
                  </ul>
                </div>
              )}

              <div className="pairing-readiness-actions">
                <button type="button" onClick={() => void previewNextRound()} disabled={!pairingReadinessCanCreatePreview()}>Auslosungsvorschau erzeugen</button>
                <button type="button" onClick={() => void generateRound()} disabled={!pairingReadinessCanGenerateRound()}>Nächste Runde auslosen</button>
                <button type="button" className="secondary" onClick={openLatestRoundPrint} disabled={!selectedTournament || selectedTournament.rounds.length === 0}>Aktuelle Runde drucken</button>
                <button type="button" className="secondary" onClick={() => openTournamentExport('print/html')} disabled={!selectedTournament}>Turnierbericht öffnen</button>
              </div>

              <p className="muted small">Hinweis: Diese Freigabe ergänzt die bestehenden Aktionen im Kopfbereich. Sie ist als bewusster Turnierleiter-Check vor der nächsten Runde gedacht.</p>
            </article>
'@
Ensure-Contains $mainPath 'Auslosungsfreigabe' {
    param($text)

    $normalized = $text -replace "`r`n", "`n"
    $markers = @(
        '<h3>Bye- und Kampflos-Audit</h3>',
        '<h3>Rundenabschluss-Checkliste</h3>',
        '<h3>Turnierleiter-Exportcenter</h3>',
        '<h3>Auslosungsvorschau Runde {nextRoundPreview.roundNumber}</h3>'
    )

    foreach ($marker in $markers) {
        $markerIndex = $normalized.IndexOf($marker, [System.StringComparison]::Ordinal)
        if ($markerIndex -lt 0) { continue }

        $beforeMarker = $normalized.Substring(0, $markerIndex)
        $articleIndex = $beforeMarker.LastIndexOf('<article className="card', [System.StringComparison]::Ordinal)
        if ($articleIndex -lt 0) { continue }

        return $normalized.Substring(0, $articleIndex) + $readinessCard.TrimEnd() + "`n`n" + $normalized.Substring($articleIndex)
    }

    throw 'Anker fuer Auslosungsfreigabe nicht gefunden.'
} 'Auslosungsfreigabe ergänzt'

$cssPath = 'src/SchachTurnierManager.WebApp/src/styles.css'
$readinessCss = @'
.pairing-readiness-card {
  border-color: rgba(59, 130, 246, 0.35);
  background: linear-gradient(180deg, rgba(30, 64, 175, 0.18), rgba(15, 23, 42, 0.78));
}

.pairing-readiness-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  margin-bottom: 1rem;
}

.pairing-readiness-status {
  border-radius: 999px;
  padding: 0.3rem 0.75rem;
  font-size: 0.82rem;
  font-weight: 700;
  white-space: nowrap;
  border: 1px solid rgba(148, 163, 184, 0.35);
  color: #e5e7eb;
  background: rgba(71, 85, 105, 0.35);
}

.pairing-readiness-status.ok {
  color: #bbf7d0;
  background: rgba(22, 101, 52, 0.28);
  border-color: rgba(34, 197, 94, 0.45);
}

.pairing-readiness-status.warn {
  color: #fde68a;
  background: rgba(120, 53, 15, 0.32);
  border-color: rgba(245, 158, 11, 0.45);
}

.pairing-readiness-status.danger {
  color: #fecaca;
  background: rgba(127, 29, 29, 0.32);
  border-color: rgba(248, 113, 113, 0.45);
}

.pairing-readiness-status.neutral {
  color: #cbd5e1;
  background: rgba(51, 65, 85, 0.42);
}

.pairing-readiness-metrics {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(135px, 1fr));
  gap: 0.65rem;
  margin: 1rem 0;
}

.pairing-readiness-metrics div {
  border: 1px solid rgba(148, 163, 184, 0.22);
  border-radius: 0.85rem;
  padding: 0.75rem;
  background: rgba(15, 23, 42, 0.45);
}

.pairing-readiness-metrics strong {
  display: block;
  font-size: 1.45rem;
  line-height: 1;
}

.pairing-readiness-metrics span {
  display: block;
  margin-top: 0.3rem;
  color: #cbd5e1;
  font-size: 0.82rem;
}

.pairing-readiness-ok,
.pairing-readiness-warning {
  border-radius: 0.85rem;
  padding: 0.85rem 1rem;
  margin: 0.8rem 0;
}

.pairing-readiness-ok {
  border: 1px solid rgba(34, 197, 94, 0.35);
  background: rgba(22, 101, 52, 0.2);
  color: #dcfce7;
}

.pairing-readiness-warning {
  border: 1px solid rgba(245, 158, 11, 0.42);
  background: rgba(120, 53, 15, 0.22);
  color: #fef3c7;
}

.pairing-readiness-warning ul {
  margin: 0.45rem 0 0;
  padding-left: 1.2rem;
}

.pairing-readiness-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.6rem;
  margin-top: 1rem;
}

.small {
  font-size: 0.82rem;
}
'@
Ensure-Contains $cssPath '.pairing-readiness-card' {
    param($text)
    return $text.TrimEnd() + "`n`n" + $readinessCss.Trim() + "`n"
} 'CSS für Auslosungsfreigabe ergänzt'

$changelogPath = 'CHANGELOG.md'
$changelogEntry = @'
## v0.28.0
- Dashboard um eine Auslosungsfreigabe erweitert.
- Offene Ergebnisse, ungeprüfte vollständige Runden, aktive Spielerzahl und kritische Vorschauhinweise werden vor der nächsten Auslosung zentral geprüft.
- Schnellaktionen für Auslosungsvorschau, nächste Runde, aktuelle Runde und Turnierbericht ergänzt.
- Version auf 0.28.0 angehoben.

'@
Ensure-Contains $changelogPath '## v0.28.0' {
    param($text)
    return $changelogEntry + $text
} 'CHANGELOG.md ergänzt'

if (Test-Path -LiteralPath '.\docs\HANDOFF_0_28_0.md') {
    $handoff = Read-Text 'docs/HANDOFF_0_28_0.md'
    Write-Text 'docs/HANDOFF_0_28_0.md' $handoff
    Write-Step 'Handoff ergänzt'
} else {
    throw 'docs/HANDOFF_0_28_0.md fehlt im Patch-ZIP.'
}

$utf8NoBomFiles = @(
    'src/SchachTurnierManager.WebApi/Program.cs',
    'src/SchachTurnierManager.WebApp/package.json',
    'src/SchachTurnierManager.WebApp/package-lock.json',
    'src/SchachTurnierManager.WebApp/src/main.tsx',
    'src/SchachTurnierManager.WebApp/src/styles.css',
    'CHANGELOG.md',
    'docs/HANDOFF_0_28_0.md',
    'scripts/After-Apply-V0.28.ps1'
)
foreach ($file in $utf8NoBomFiles) {
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
