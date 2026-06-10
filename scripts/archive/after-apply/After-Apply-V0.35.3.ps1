Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$Version = '0.35.3'

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
    foreach ($old in @('0.35.2','0.35.1','0.35.0','0.34.1')) {
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

function Insert-TextBeforeFirstToken {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string[]]$Tokens,
        [Parameter(Mandatory = $true)][string]$InsertText,
        [Parameter(Mandatory = $true)][string]$Marker,
        [Parameter(Mandatory = $true)][string]$Description
    )

    $text = Read-Text $RelativePath
    if ($text.Contains($Marker)) {
        Write-Step "$Description bereits vorhanden"
        return
    }

    $bestIndex = -1
    $bestToken = $null
    foreach ($token in $Tokens) {
        $idx = $text.IndexOf($token, [System.StringComparison]::Ordinal)
        if ($idx -ge 0 -and ($bestIndex -lt 0 -or $idx -lt $bestIndex)) {
            $bestIndex = $idx
            $bestToken = $token
        }
    }

    if ($bestIndex -lt 0) {
        throw "Kein stabiler Einfügepunkt für $Description in $RelativePath gefunden. Gesuchte Tokens: $($Tokens -join ', ')"
    }

    $prefix = $text.Substring(0, $bestIndex).TrimEnd()
    $suffix = $text.Substring($bestIndex)
    $insert = $InsertText.TrimEnd() + "`r`n`r`n"
    Write-Text $RelativePath ($prefix + "`r`n`r`n" + $insert + $suffix)
    Write-Step "$Description ergänzt vor Token '$bestToken'"
}

function Ensure-AuditExportFunctions {
    $relativePath = 'src/SchachTurnierManager.WebApp/src/main.tsx'
    $block = @'
  function exportAuditJournalCsv(): void {
    if (!selectedTournament) {
      return;
    }

    const header = ['Zeitpunkt', 'Schweregrad', 'Aktion', 'Akteur', 'Runde', 'Brett', 'Spieler', 'Zusammenfassung', 'Details', 'Grund'];
    const rows = auditJournal.map(entry => [
      auditDateLabel(entry.createdAt),
      auditSeverityLabel(entry.severity),
      auditActionLabel(entry.action),
      entry.actor,
      entry.roundNumber ?? '',
      entry.boardNumber ?? '',
      entry.playerName ?? entry.playerId ?? '',
      entry.summary,
      entry.details ?? '',
      entry.reason ?? ''
    ].map(auditCsvCell).join(';'));

    downloadText(`${selectedTournament.name}-auditjournal.csv`, [header.join(';'), ...rows].join('\r\n'), 'text/csv;charset=utf-8');
  }

  function exportAuditJournalJson(): void {
    if (!selectedTournament) {
      return;
    }

    downloadText(`${selectedTournament.name}-auditjournal.json`, JSON.stringify(auditJournal, null, 2), 'application/json;charset=utf-8');
  }
'@

    Insert-TextBeforeFirstToken $relativePath @(
        'function openRoundPrint(',
        'async function exportTournamentJson(',
        'function playerNameById(',
        'return ('
    ) $block 'function exportAuditJournalCsv' 'Auditjournal-Exportfunktionen'
}

function Ensure-AuditDashboardCard {
    $relativePath = 'src/SchachTurnierManager.WebApp/src/main.tsx'
    $text = Read-Text $relativePath
    if ($text.Contains('audit-journal-card')) {
        Write-Step 'Auditjournal-Dashboardkarte bereits vorhanden'
        return
    }

    $card = @'
          <article className="card audit-journal-card">
            <div className="audit-journal-heading">
              <div>
                <h3>Audit-Journal</h3>
                <p>Persistentes Protokoll wichtiger Turnierleiter-Aktionen. Hilft bei Ergebnis-Korrekturen, Rundenprüfung und späteren Nachfragen.</p>
              </div>
              <span className={`status-pill ${auditJournalCriticalCount > 0 ? 'audit-critical' : auditJournalWarningCount > 0 ? 'audit-warning' : 'audit-info'}`}>
                {auditJournal.length} Einträge
              </span>
            </div>
            <div className="audit-journal-summary">
              <div><strong>{auditJournalInfoCount}</strong><span>Info</span></div>
              <div><strong>{auditJournalWarningCount}</strong><span>Warnung</span></div>
              <div><strong>{auditJournalCriticalCount}</strong><span>kritisch</span></div>
              <div><strong>{auditJournalRoundEntryCount}</strong><span>Rundenbezug</span></div>
              <div><strong>{auditJournalPlayerEntryCount}</strong><span>Spielerbezug</span></div>
            </div>
            {!selectedTournament && <p>Bitte zuerst ein Turnier auswählen.</p>}
            {selectedTournament && auditJournal.length === 0 && <p className="ok">Noch keine Audit-Einträge vorhanden.</p>}
            {auditJournalCriticalCount > 0 && <p className="warning-text">Kritische Audit-Einträge vorhanden: Bitte vor Veröffentlichung oder nächster Auslosung prüfen.</p>}
            {selectedTournament && auditJournal.length > 0 && (
              <>
                <div className="table-scroll compact audit-journal-table">
                  <table>
                    <thead><tr><th>Zeit</th><th>Stufe</th><th>Aktion</th><th>Bezug</th><th>Zusammenfassung</th><th>Details</th><th>Grund</th></tr></thead>
                    <tbody>
                      {auditJournalRecentEntries.map(entry => (
                        <tr key={entry.id} className={auditSeverityClass(entry.severity)}>
                          <td>{auditDateLabel(entry.createdAt)}</td>
                          <td><span className={`audit-pill ${auditSeverityClass(entry.severity)}`}>{auditSeverityLabel(entry.severity)}</span></td>
                          <td>{auditActionLabel(entry.action)}<small>{entry.actor}</small></td>
                          <td>{entry.roundNumber ? `R${entry.roundNumber}` : '—'}{entry.boardNumber ? ` · Brett ${entry.boardNumber}` : ''}{entry.playerName ? <small>{entry.playerName}</small> : null}</td>
                          <td>{entry.summary}</td>
                          <td>{entry.details || '—'}</td>
                          <td>{entry.reason || '—'}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
                {auditJournal.length > auditJournalRecentEntries.length && <p className="muted">Anzeige begrenzt auf die letzten {auditJournalRecentEntries.length} von {auditJournal.length} Einträgen. Für vollständige Auswertung bitte CSV/JSON exportieren.</p>}
              </>
            )}
            <div className="actions">
              <button type="button" onClick={() => exportAuditJournalCsv()} disabled={!selectedTournament || auditJournal.length === 0}>Audit CSV</button>
              <button type="button" className="secondary" onClick={() => exportAuditJournalJson()} disabled={!selectedTournament || auditJournal.length === 0}>Audit JSON</button>
            </div>
          </article>

'@
    $card = $card.Replace('\"', '"')

    $headingIndex = $text.IndexOf('<h3>Import / Export</h3>', [System.StringComparison]::Ordinal)
    if ($headingIndex -lt 0) {
        $headingIndex = $text.IndexOf('Import / Export', [System.StringComparison]::Ordinal)
    }
    if ($headingIndex -lt 0) {
        $headingIndex = $text.LastIndexOf('</main>', [System.StringComparison]::Ordinal)
    }
    if ($headingIndex -lt 0) {
        throw 'Kein stabiler Einfügepunkt für Auditjournal-Dashboardkarte gefunden.'
    }

    $insertIndex = $headingIndex
    $articleIndex = $text.LastIndexOf('<article', $headingIndex, [System.StringComparison]::Ordinal)
    if ($articleIndex -ge 0) {
        $insertIndex = $articleIndex
    }

    $prefix = $text.Substring(0, $insertIndex).TrimEnd()
    $suffix = $text.Substring($insertIndex)
    Write-Text $relativePath ($prefix + "`r`n" + $card + $suffix)
    Write-Step 'Auditjournal-Dashboardkarte ergänzt'
}

function Ensure-AuditStyles {
    $relativePath = 'src/SchachTurnierManager.WebApp/src/styles.css'
    $text = Read-Text $relativePath
    if ($text.Contains('.audit-journal-card')) {
        Write-Step 'CSS für Audit-Journal-Dashboard bereits vorhanden'
        return
    }

    $css = @'
.audit-journal-card {
  border-color: rgba(96, 165, 250, 0.28);
}

.audit-journal-heading {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  align-items: flex-start;
}

.audit-journal-heading p {
  margin: 0.25rem 0 0;
  color: var(--muted);
}

.audit-journal-summary {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(110px, 1fr));
  gap: 0.75rem;
  margin: 1rem 0;
}

.audit-journal-summary div {
  border: 1px solid var(--border);
  border-radius: 0.75rem;
  padding: 0.75rem;
  background: rgba(15, 23, 42, 0.45);
}

.audit-journal-summary strong {
  display: block;
  font-size: 1.35rem;
}

.audit-journal-summary span {
  color: var(--muted);
  font-size: 0.85rem;
}

.audit-pill {
  display: inline-block;
  border-radius: 999px;
  padding: 0.15rem 0.45rem;
  font-size: 0.78rem;
  font-weight: 700;
}

.audit-info {
  background: rgba(59, 130, 246, 0.14);
  color: #bfdbfe;
}

.audit-warning {
  background: rgba(245, 158, 11, 0.18);
  color: #fde68a;
}

.audit-critical {
  background: rgba(239, 68, 68, 0.16);
  color: #fecaca;
}

.audit-journal-table td {
  vertical-align: top;
}

.audit-journal-table small {
  display: block;
  color: var(--muted);
  margin-top: 0.15rem;
}

.warning-text {
  border: 1px solid rgba(245, 158, 11, 0.35);
  background: rgba(245, 158, 11, 0.12);
  border-radius: 0.75rem;
  padding: 0.75rem;
}
'@
    Write-Text $relativePath ($text.TrimEnd() + "`r`n`r`n" + $css.Trim() + "`r`n")
    Write-Step 'CSS für Audit-Journal-Dashboard ergänzt'
}

function Ensure-Changelog {
    $relativePath = 'CHANGELOG.md'
    $text = Read-Text $relativePath
    if ($text.Contains('## 0.35.3')) {
        Write-Step 'CHANGELOG.md enthält 0.35.3 bereits'
        return
    }
    $entry = @'
## 0.35.3 - Audit Journal Dashboard Fix 2

- Repariert den teilweise angewendeten Audit-Journal-Dashboard-Stand nach 0.35.0 bis 0.35.2.
- Fügt Audit-Exportfunktionen über tokenbasierte Einfügepunkte ein statt über zeilenbasierte Spezialanker.
- Ergänzt Audit-Journal-Dashboardkarte und Styles idempotent.
- Keine Änderung an Auslosungslogik, Wertungsberechnung oder Speicherformat.

'@
    if ($text.StartsWith('# Changelog')) {
        $updated = $text -replace '(^# Changelog\s*)', ("# Changelog`r`n`r`n" + $entry)
    } else {
        $updated = $entry + $text
    }
    Write-Text $relativePath $updated
    Write-Step 'CHANGELOG.md ergänzt'
}

function Invoke-Checked {
    param([Parameter(Mandatory = $true)][string]$Name, [Parameter(Mandatory = $true)][scriptblock]$Command)
    Write-Step "$Name..."
    & $Command
    if ($LASTEXITCODE -ne 0) { throw "$Name ist fehlgeschlagen mit Exitcode $LASTEXITCODE." }
}

try {
    Set-VersionInFile 'src/SchachTurnierManager.WebApi/Program.cs'
    Set-VersionInFile 'src/SchachTurnierManager.WebApp/package.json'
    Set-VersionInFile 'src/SchachTurnierManager.WebApp/package-lock.json'
    Set-VersionInFile 'src/SchachTurnierManager.WebApp/src/main.tsx'

    Ensure-AuditExportFunctions
    Ensure-AuditDashboardCard
    Ensure-AuditStyles
    Ensure-Changelog

    $handoff = @'
# Handoff 0.35.3 - Audit Journal Dashboard Fix 2

## Ziel

0.35.3 repariert den teilweise angewendeten Audit-Journal-Dashboard-Stand nach 0.35.0 bis 0.35.2.

## Änderungen

- Version auf 0.35.3 gesetzt.
- Fehlende Auditjournal-Exportfunktionen tokenbasiert ergänzt.
- Audit-Journal-Dashboardkarte eingefügt.
- CSS für Auditjournal-Karte, Kennzahlen, Severity-Pills und Tabelle ergänzt.
- Changelog/Handoff ergänzt.

## Erwartung

- `dotnet test`: 81/81 grün.
- `npm run build`: grün.
- `Pack-Portable`: `SchachTurnierManager_Portable_0.35.3.zip`.

## Wichtig

Erst nach grünem Release-Gate committen und pushen.
'@
    Write-Text 'docs/HANDOFF_0_35_3.md' $handoff
    Write-Step 'Handoff ergänzt'

    @(
        'CHANGELOG.md',
        'src/SchachTurnierManager.WebApi/Program.cs',
        'src/SchachTurnierManager.WebApp/package.json',
        'src/SchachTurnierManager.WebApp/package-lock.json',
        'src/SchachTurnierManager.WebApp/src/main.tsx',
        'src/SchachTurnierManager.WebApp/src/styles.css',
        'docs/HANDOFF_0_35_3.md',
        'scripts/After-Apply-V0.35.ps1',
        'scripts/After-Apply-V0.35.1.ps1',
        'scripts/After-Apply-V0.35.2.ps1',
        'scripts/After-Apply-V0.35.3.ps1'
    ) | ForEach-Object { Normalize-TextFile $_ }

    Invoke-Checked 'Release-Gate' { pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'scripts/Invoke-ReleaseGate.ps1') }
    Write-Step 'Nachkontrolle abgeschlossen. Aktueller Git-Status:'
    git -C $Root status --short
}
catch {
    Write-Error $_
    exit 1
}
