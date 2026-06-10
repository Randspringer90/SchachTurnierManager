Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Write-Step {
    param([string]$Message)
    Write-Host "[v0.35.2] $Message"
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

function Set-TextFileUtf8NoBom {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $path = Join-Path $Root $RelativePath
    if (Test-Path -LiteralPath $path) {
        $content = [System.IO.File]::ReadAllText($path)
        [System.IO.File]::WriteAllText($path, $content, $Utf8NoBom)
        Write-Step "$RelativePath als UTF-8 ohne BOM gespeichert"
    }
}

function Replace-Version {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $text = Read-Text $RelativePath
    $updated = $text.Replace('0.35.1', '0.35.2').Replace('0.35.0', '0.35.2').Replace('0.34.1', '0.35.2')
    if ($updated -eq $text) {
        if ($text.Contains('0.35.2')) { Write-Step "$RelativePath ist bereits auf 0.35.2" }
        else { Write-Step "$RelativePath enthielt keine bekannte Vorversion mehr" }
    } else {
        Write-Text $RelativePath $updated
        Write-Step "$RelativePath auf 0.35.2 gesetzt"
    }
}

function Insert-BeforeLineMatching {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string[]]$Patterns,
        [Parameter(Mandatory = $true)][string]$InsertText,
        [Parameter(Mandatory = $true)][string]$Marker,
        [Parameter(Mandatory = $true)][string]$Description
    )

    $text = Read-Text $RelativePath
    if ($text.Contains($Marker)) {
        Write-Step "$Description bereits vorhanden"
        return
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    $text -split "`r?`n", -1 | ForEach-Object { [void]$lines.Add($_) }

    for ($p = 0; $p -lt $Patterns.Count; $p++) {
        $pattern = $Patterns[$p]
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match $pattern) {
                $insertLines = $InsertText.TrimEnd() -split "`r?`n", -1
                for ($j = $insertLines.Length - 1; $j -ge 0; $j--) {
                    $lines.Insert($i, $insertLines[$j])
                }
                Write-Text $RelativePath (($lines -join "`r`n").TrimEnd() + "`r`n")
                Write-Step "$Description ergänzt"
                return
            }
        }
    }

    throw "Kein stabiler Einfügepunkt für $Description in $RelativePath gefunden."
}

function Insert-AuditJournalCard {
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

    # Korrektur: Im PowerShell-Here-String stehen die Quotes absichtlich erst escaped,
    # damit alte Editors/Formatter nicht eingreifen. Vor dem Schreiben ins TSX müssen die Backslashes weg.
    $card = $card.Replace('\"', '"')

    $lines = [System.Collections.Generic.List[string]]::new()
    $text -split "`r?`n", -1 | ForEach-Object { [void]$lines.Add($_) }

    $headingIndex = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Contains('<h3>Import / Export</h3>')) {
            $headingIndex = $i
            break
        }
    }

    if ($headingIndex -lt 0) {
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i].Contains('Import / Export')) {
                $headingIndex = $i
                break
            }
        }
    }

    if ($headingIndex -lt 0) {
        throw 'Anker für Auditjournal-Dashboardkarte nicht gefunden: Import / Export fehlt.'
    }

    $articleIndex = $headingIndex
    for ($i = $headingIndex; $i -ge 0; $i--) {
        if ($lines[$i].Contains('<article ')) {
            $articleIndex = $i
            break
        }
    }

    $insertLines = $card.TrimEnd() -split "`r?`n", -1
    for ($j = $insertLines.Length - 1; $j -ge 0; $j--) {
        $lines.Insert($articleIndex, $insertLines[$j])
    }

    Write-Text $relativePath (($lines -join "`r`n").TrimEnd() + "`r`n")
    Write-Step 'Auditjournal-Dashboardkarte ergänzt'
}

function Ensure-AuditJournalExportFunctions {
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

    Insert-BeforeLineMatching $relativePath @(
        '^\s*function openRoundPrint\(',
        '^\s*async function exportTournamentJson\(',
        '^\s*function playerNameById\(',
        '^\s*return \('
    ) $block 'function exportAuditJournalCsv' 'Auditjournal-Exportfunktionen'
}

function Ensure-Styles {
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

function Ensure-ChangelogEntry {
    $relativePath = 'CHANGELOG.md'
    $text = Read-Text $relativePath
    if ($text.Contains('## 0.35.2')) {
        Write-Step 'CHANGELOG.md enthält 0.35.2 bereits'
        return
    }

    $entry = @'
## 0.35.2 - Audit Journal Dashboard Fix

- Robuster Fix für den Auditjournal-Dashboard-Patch nach teilweise angewendetem 0.35.0/0.35.1-Stand.
- Exportfunktionen werden ohne zerbrechlichen Spezialanker eingefügt.
- Dashboardkarte wird anhand der bestehenden Import-/Export-Karte positioniert.
- Keine Änderung an Auslosungslogik, Wertungsberechnung oder Speicherformat.

'@

    $updated = if ($text.StartsWith('# Changelog')) {
        $text -replace '(^# Changelog\s*)', ("# Changelog`r`n`r`n" + $entry)
    } else {
        $entry + $text
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
    Replace-Version 'src/SchachTurnierManager.WebApi/Program.cs'
    Replace-Version 'src/SchachTurnierManager.WebApp/package.json'
    Replace-Version 'src/SchachTurnierManager.WebApp/package-lock.json'
    Replace-Version 'src/SchachTurnierManager.WebApp/src/main.tsx'

    Ensure-AuditJournalExportFunctions
    Insert-AuditJournalCard
    Ensure-Styles
    Ensure-ChangelogEntry

    $handoff = @'
# Handoff 0.35.2 - Audit Journal Dashboard Fix

## Ziel

0.35.2 repariert den teilweise angewendeten 0.35.0/0.35.1-Stand. Die Auditjournal-Basis aus 0.34.x bleibt unverändert; im Frontend werden die fehlenden Dashboard-/Export-Bausteine robust nachgezogen.

## Änderungen

- Version auf 0.35.2 gesetzt.
- Fehlende Auditjournal-Exportfunktionen ergänzt.
- Dashboardkarte `Audit-Journal` anhand der bestehenden Import-/Export-Karte eingefügt.
- CSS für Auditjournal-Karte, Kennzahlen, Severity-Pills und Tabelle ergänzt.
- Changelog/Handoff ergänzt.

## Erwartung

- `dotnet test`: 81/81 grün.
- `npm run build`: grün.
- `Pack-Portable`: `SchachTurnierManager_Portable_0.35.2.zip`.

## Nicht geändert

- Keine Änderung an Auslosungslogik.
- Keine Änderung an Wertungsberechnung.
- Keine Änderung am Speicherformat.
'@
    Write-Text 'docs/HANDOFF_0_35_2.md' $handoff
    Write-Step 'Handoff ergänzt'

    @(
        'CHANGELOG.md',
        'src/SchachTurnierManager.WebApi/Program.cs',
        'src/SchachTurnierManager.WebApp/package.json',
        'src/SchachTurnierManager.WebApp/package-lock.json',
        'src/SchachTurnierManager.WebApp/src/main.tsx',
        'src/SchachTurnierManager.WebApp/src/styles.css',
        'docs/HANDOFF_0_35_2.md',
        'scripts/After-Apply-V0.35.ps1',
        'scripts/After-Apply-V0.35.1.ps1',
        'scripts/After-Apply-V0.35.2.ps1'
    ) | ForEach-Object { Set-TextFileUtf8NoBom $_ }

    Invoke-Checked 'Release-Gate' { pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'scripts/Invoke-ReleaseGate.ps1') }
    Write-Step 'Nachkontrolle abgeschlossen. Aktueller Git-Status:'
    git -C $Root status --short
}
catch {
    Write-Error $_
    exit 1
}
