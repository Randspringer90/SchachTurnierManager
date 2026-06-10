$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $Root

$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Write-Step {
    param([string]$Message)
    Write-Host "[v0.29.0] $Message"
}

function Read-Text {
    param([string]$Path)
    return [System.IO.File]::ReadAllText((Resolve-Path $Path))
}

function Write-Text {
    param(
        [string]$Path,
        [string]$Text
    )
    [System.IO.File]::WriteAllText((Resolve-Path $Path), $Text, $Utf8NoBom)
}

function Set-Version {
    param([string]$Path)

    $text = Read-Text $Path
    $next = $text.Replace('0.28.0', '0.29.0')
    if ($next -eq $text) {
        Write-Step "$Path ist bereits auf 0.29.0 oder enthielt keine 0.28.0-Version mehr"
        return
    }

    Write-Text $Path $next
    Write-Step "$Path auf 0.29.0 gesetzt"
}

function Insert-BeforeRenderReturn {
    param(
        [string]$Text,
        [string]$Block
    )

    $marker = "`r`n  return (`r`n"
    $index = $Text.LastIndexOf($marker)
    if ($index -lt 0) {
        $marker = "`n  return (`n"
        $index = $Text.LastIndexOf($marker)
    }

    if ($index -lt 0) {
        throw 'Render-return-Anker nicht gefunden.'
    }

    return $Text.Insert($index, $Block)
}

function Insert-PanelBeforeHeading {
    param(
        [string]$Text,
        [string[]]$Headings,
        [string]$Panel
    )

    foreach ($heading in $Headings) {
        $headingIndex = $Text.IndexOf($heading)
        if ($headingIndex -ge 0) {
            $articleIndex = $Text.LastIndexOf('<article', $headingIndex)
            if ($articleIndex -lt 0) {
                throw "Artikel-Anker fuer $heading nicht gefunden."
            }

            return $Text.Insert($articleIndex, $Panel)
        }
    }

    throw "Kein passender Einfuegeanker fuer Korrekturjournal gefunden."
}

function Append-IfMissing {
    param(
        [string]$Path,
        [string]$Needle,
        [string]$Block,
        [string]$Description
    )

    $text = Read-Text $Path
    if ($text.Contains($Needle)) {
        Write-Step "$Description bereits vorhanden"
        return
    }

    Write-Text $Path ($text.TrimEnd() + "`r`n`r`n" + $Block.Trim() + "`r`n")
    Write-Step "$Description ergänzt"
}

Set-Version 'src/SchachTurnierManager.WebApi/Program.cs'
Set-Version 'src/SchachTurnierManager.WebApp/package.json'
Set-Version 'src/SchachTurnierManager.WebApp/package-lock.json'
Set-Version 'src/SchachTurnierManager.WebApp/src/main.tsx'

$mainPath = 'src/SchachTurnierManager.WebApp/src/main.tsx'
$main = Read-Text $mainPath

$helperBlock = @'

  function correctionJournalItems() {
    if (!selectedTournament) {
      return [];
    }

    const items: Array<{
      key: string;
      scope: string;
      severity: 'info' | 'warning' | 'critical';
      title: string;
      detail: string;
      action: string;
    }> = [];

    for (const player of selectedTournament.players.filter(player => player.status !== 0)) {
      items.push({
        key: `player-status-${player.id}`,
        scope: 'Teilnehmer',
        severity: 'warning',
        title: `${player.name} ist ${statusLabel(player.status).toLowerCase()}`,
        detail: `${player.name}${player.club ? ` · ${player.club}` : ''}${player.notes ? ` · ${player.notes}` : ''}`,
        action: 'Teilnehmerstatus vor der nächsten Auslosung und vor Aushängen bewusst prüfen.'
      });
    }

    for (const round of selectedTournament.rounds) {
      const diagnostics = diagnosticsFor(round.roundNumber);
      const openBoards = diagnostics?.openBoards ?? 0;
      const roundStatus = roundStatusLabel(round.resultStatus);

      if (round.isLocked) {
        items.push({
          key: `round-locked-${round.roundNumber}`,
          scope: 'Runde',
          severity: 'info',
          title: `Runde ${round.roundNumber} ist gesperrt`,
          detail: `${roundStatus} · ${round.pairings.length} Brett(er)`,
          action: 'Gesperrte Runde nur für bewusste Turnierleiter-Korrekturen wieder öffnen.'
        });
      }

      if (round.isVerified) {
        items.push({
          key: `round-verified-${round.roundNumber}`,
          scope: 'Runde',
          severity: 'info',
          title: `Runde ${round.roundNumber} ist geprüft`,
          detail: `${roundStatus} · ${round.pairings.length} Brett(er)`,
          action: 'Geprüfte Runde vor Änderungen nur nach Rücksprache/Turnierleiterentscheidung öffnen.'
        });
      } else if (round.pairings.length > 0 && openBoards === 0) {
        items.push({
          key: `round-unverified-${round.roundNumber}`,
          scope: 'Runde',
          severity: 'warning',
          title: `Runde ${round.roundNumber} ist vollständig, aber nicht geprüft`,
          detail: `${roundStatus} · keine offenen Bretter laut Diagnose`,
          action: 'Vor nächster Auslosung Ergebniszettel prüfen und Runde als geprüft markieren.'
        });
      }

      for (const pairing of round.pairings) {
        const resultText = resultLabel(pairing.result.kind);
        const lowerResult = resultText.toLowerCase();
        const whiteName = playerNameById(pairing.whitePlayerId);
        const blackName = pairing.isBye ? 'spielfrei' : playerNameById(pairing.blackPlayerId);
        const hasSpecialResult = pairing.isBye || lowerResult.includes('kampflos') || lowerResult.includes('bye') || lowerResult.includes('spielfrei');

        if (pairing.isManualOverride) {
          items.push({
            key: `manual-pairing-${round.roundNumber}-${pairing.boardNumber}`,
            scope: 'Paarung',
            severity: 'critical',
            title: `Manuelle Paarung R${round.roundNumber}/B${pairing.boardNumber}`,
            detail: `${whiteName} – ${blackName}${pairing.notes ? ` · ${pairing.notes}` : ''}`,
            action: 'Manuelle Paarung vor Veröffentlichung, Auslosung und Export gegen Turnierleiterentscheidung prüfen.'
          });
        }

        if (hasSpecialResult) {
          items.push({
            key: `special-result-${round.roundNumber}-${pairing.boardNumber}`,
            scope: 'Ergebnis',
            severity: pairing.isBye ? 'info' : 'warning',
            title: `${pairing.isBye ? 'Bye/spielfrei' : 'Sonderergebnis'} R${round.roundNumber}/B${pairing.boardNumber}`,
            detail: `${whiteName} – ${blackName} · ${resultText}`,
            action: 'Wertungsauswirkung in Bye-/Kampflos-Audit und Tabelle kontrollieren.'
          });
        }
      }
    }

    return items.slice(0, 60);
  }

  const correctionJournal = correctionJournalItems();
  const correctionJournalCriticalCount = correctionJournal.filter(item => item.severity === 'critical').length;
  const correctionJournalWarningCount = correctionJournal.filter(item => item.severity === 'warning').length;
  const correctionJournalInfoCount = correctionJournal.filter(item => item.severity === 'info').length;
  const correctionJournalStatusClass = !selectedTournament
    ? 'blocked'
    : correctionJournalCriticalCount > 0
      ? 'blocked'
      : correctionJournalWarningCount > 0
        ? 'warning'
        : 'ready';
  const correctionJournalStatusLabel = !selectedTournament
    ? 'kein Turnier'
    : correctionJournalCriticalCount > 0
      ? 'kritisch'
      : correctionJournalWarningCount > 0
        ? 'prüfen'
        : 'unauffällig';

  function openLatestRoundPrint(): void {
    const rounds = selectedTournament?.rounds ?? [];
    if (rounds.length === 0) {
      setStatus('Noch keine Runde zum Drucken vorhanden.');
      return;
    }

    openRoundPrint(rounds[rounds.length - 1].roundNumber);
  }
'@

if ($main.Contains('function correctionJournalItems()')) {
    Write-Step 'Korrekturjournal-Helfer bereits vorhanden'
} else {
    $main = Insert-BeforeRenderReturn -Text $main -Block $helperBlock
    Write-Step 'Korrekturjournal-Helfer ergänzt'
}

$panelBlock = @'

          <article className="card correction-journal-card">
            <div className="card-heading-row">
              <div>
                <h3>Korrektur- und Eingriffsübersicht</h3>
                <p className="muted">Zeigt manuelle Paarungen, gesperrte/geprüfte Runden, inaktive Teilnehmer und Sonderergebnisse als Turnierleiter-Prüfliste.</p>
              </div>
              <span className={`status-pill ${correctionJournalStatusClass}`}>{correctionJournalStatusLabel}</span>
            </div>
            <div className="review-metrics correction-metrics">
              <div><strong>{correctionJournal.length}</strong><span>Einträge</span></div>
              <div><strong>{correctionJournalCriticalCount}</strong><span>kritisch</span></div>
              <div><strong>{correctionJournalWarningCount}</strong><span>prüfen</span></div>
              <div><strong>{correctionJournalInfoCount}</strong><span>Info</span></div>
            </div>
            {!selectedTournament && <p className="muted">Bitte zuerst ein Turnier auswählen.</p>}
            {selectedTournament && correctionJournal.length === 0 && (
              <div className="notice success">Keine manuellen Eingriffe, Sonderergebnisse oder offenen Prüfpunkte erkannt.</div>
            )}
            {selectedTournament && correctionJournalCriticalCount > 0 && (
              <div className="notice danger">Kritische Eingriffe erkannt: Manuelle Paarungen vor Aushang oder nächster Auslosung bewusst prüfen.</div>
            )}
            {selectedTournament && correctionJournalWarningCount > 0 && (
              <div className="notice warning">Prüfpunkte vorhanden: Teilnehmerstatus, ungeprüfte Runden oder Sonderergebnisse kontrollieren.</div>
            )}
            {selectedTournament && correctionJournal.length > 0 && (
              <div className="table-scroll compact correction-journal-table">
                <table>
                  <thead>
                    <tr>
                      <th>Bereich</th>
                      <th>Status</th>
                      <th>Eintrag</th>
                      <th>Details</th>
                      <th>Aktion</th>
                    </tr>
                  </thead>
                  <tbody>
                    {correctionJournal.map(item => (
                      <tr key={item.key} className={`journal-row ${item.severity}`}>
                        <td>{item.scope}</td>
                        <td><span className={`status-pill ${item.severity === 'critical' ? 'blocked' : item.severity === 'warning' ? 'warning' : 'ready'}`}>{item.severity === 'critical' ? 'kritisch' : item.severity === 'warning' ? 'prüfen' : 'Info'}</span></td>
                        <td>{item.title}</td>
                        <td>{item.detail}</td>
                        <td>{item.action}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
            <div className="actions">
              <button type="button" onClick={() => openLatestRoundPrint()} disabled={!selectedTournament || selectedTournament.rounds.length === 0}>Letzte Runde drucken</button>
              <button type="button" className="secondary" onClick={() => openTournamentExport('print/html')} disabled={!selectedTournament}>Turnierbericht öffnen</button>
              <button type="button" className="secondary" onClick={() => openTournamentExport('pairings/export.csv')} disabled={!selectedTournament}>Paarungen CSV</button>
            </div>
          </article>
'@

if ($main.Contains('Korrektur- und Eingriffsübersicht')) {
    Write-Step 'Korrektur- und Eingriffsübersicht bereits vorhanden'
} else {
    $main = Insert-PanelBeforeHeading -Text $main -Headings @('<h3>Turnierleiter-Exportcenter</h3>', '<h3>Import / Export</h3>') -Panel $panelBlock
    Write-Step 'Korrektur- und Eingriffsübersicht ergänzt'
}

Write-Text $mainPath $main

$cssBlock = @'
.correction-journal-card .card-heading-row {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
}

.correction-metrics {
  margin: 1rem 0;
}

.correction-journal-table td:nth-child(3),
.correction-journal-table td:nth-child(4),
.correction-journal-table td:nth-child(5) {
  min-width: 12rem;
}

.journal-row.critical {
  background: rgba(220, 38, 38, 0.08);
}

.journal-row.warning {
  background: rgba(245, 158, 11, 0.08);
}

.journal-row.info {
  background: rgba(59, 130, 246, 0.06);
}
'@

Append-IfMissing -Path 'src/SchachTurnierManager.WebApp/src/styles.css' -Needle '.correction-journal-card' -Block $cssBlock -Description 'CSS für Korrektur- und Eingriffsübersicht'

$changelogPath = 'CHANGELOG.md'
$changelog = Read-Text $changelogPath
if ($changelog.Contains('0.29.0')) {
    Write-Step 'CHANGELOG.md enthält v0.29.0 bereits'
} else {
    $entry = @'
## 0.29.0 - Korrektur- und Eingriffsübersicht

- Dashboard-Panel fuer Turnierleiter-Korrekturen ergaenzt.
- Manuelle Paarungen, gesperrte/gepruefte Runden, inaktive Teilnehmer und Sonderergebnisse werden zentral sichtbar.
- Status-Badges und Schnellzugriffe auf letzte Runde, Turnierbericht und Paarungs-CSV ergaenzt.
- Keine Aenderung an Auslosungslogik, Wertungsberechnung oder Speicherformat.

'@
    Write-Text $changelogPath ($entry + $changelog)
    Write-Step 'CHANGELOG.md ergänzt'
}

$handoffPath = 'docs/HANDOFF_0_29_0.md'
$handoff = @'
# Handoff 0.29.0 - Korrektur- und Eingriffsübersicht

## Ziel

v0.29.0 ergänzt ein Dashboard-Panel, das Turnierleiter vor Aushang, Veröffentlichung und nächster Auslosung auf manuelle Eingriffe und organisatorische Prüfpunkte hinweist.

## Enthalten

- Korrektur- und Eingriffsübersicht im Dashboard.
- Erkennung und Anzeige von:
  - manuellen Paarungen,
  - gesperrten Runden,
  - geprüften Runden,
  - vollständigen, aber ungeprüften Runden,
  - inaktiven/zurückgezogenen Teilnehmern,
  - Bye/spielfrei und kampflosen/Sonderergebnissen.
- Status-Badge: kein Turnier, unauffällig, prüfen, kritisch.
- Schnellzugriffe:
  - letzte Runde drucken,
  - Turnierbericht öffnen,
  - Paarungen CSV.

## Nicht geändert

- Keine Änderung der Auslosungslogik.
- Keine Änderung der Wertungsberechnung.
- Keine Änderung am Speicherformat.
- Noch kein persistentes Audit-Log; die Übersicht ist aus dem aktuellen Turnierzustand abgeleitet.

## Nachkontrolle

- dotnet restore
- dotnet build
- dotnet test
- npm install
- npm run build
- scripts/Pack-Portable.ps1
'@
[System.IO.File]::WriteAllText((Join-Path $Root $handoffPath), $handoff, $Utf8NoBom)
Write-Step 'Handoff ergänzt'

$filesToNormalize = @(
    'src/SchachTurnierManager.WebApi/Program.cs',
    'src/SchachTurnierManager.WebApp/package.json',
    'src/SchachTurnierManager.WebApp/package-lock.json',
    'src/SchachTurnierManager.WebApp/src/main.tsx',
    'src/SchachTurnierManager.WebApp/src/styles.css',
    'CHANGELOG.md',
    'docs/HANDOFF_0_29_0.md',
    'scripts/After-Apply-V0.29.ps1'
)

foreach ($file in $filesToNormalize) {
    if (Test-Path $file) {
        $text = Read-Text $file
        Write-Text $file $text
        Write-Step "$file als UTF-8 ohne BOM gespeichert"
    }
}

function Invoke-Step {
    param(
        [string]$Name,
        [scriptblock]$Command
    )

    Write-Step "$Name..."
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$Name ist fehlgeschlagen mit Exitcode $LASTEXITCODE."
    }
}

Invoke-Step 'dotnet restore' { dotnet restore }
Invoke-Step 'dotnet build' { dotnet build --no-restore }
Invoke-Step 'dotnet test' { dotnet test --no-build }
Push-Location 'src/SchachTurnierManager.WebApp'
try {
    Invoke-Step 'npm install' { npm install }
    Invoke-Step 'npm run build' { npm run build }
}
finally {
    Pop-Location
}
Invoke-Step 'Pack-Portable' { pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File '.\scripts\Pack-Portable.ps1' }

Write-Step 'Nachkontrolle abgeschlossen. Aktueller Git-Status:'
git status --short
