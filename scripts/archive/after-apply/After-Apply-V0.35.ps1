Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Write-Step {
    param([string]$Message)
    Write-Host "[v0.35.0] $Message"
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
    $updated = $text.Replace('0.34.1', '0.35.0')
    if ($updated -eq $text) {
        if ($text.Contains('0.35.0')) { Write-Step "$RelativePath ist bereits auf 0.35.0" }
        else { Write-Step "$RelativePath enthielt keine 0.34.1-Version mehr" }
    } else {
        Write-Text $RelativePath $updated
        Write-Step "$RelativePath auf 0.35.0 gesetzt"
    }
}

function Replace-Once {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Old,
        [Parameter(Mandatory = $true)][string]$New,
        [Parameter(Mandatory = $true)][string]$Description,
        [string]$AlreadyMarker = ''
    )
    $text = Read-Text $RelativePath
    if ($AlreadyMarker -and $text.Contains($AlreadyMarker)) {
        Write-Step "$Description bereits vorhanden"
        return
    }

    $oldVariants = @($Old, $Old.Replace("`r`n", "`n"), $Old.Replace("`n", "`r`n")) | Select-Object -Unique
    foreach ($candidate in $oldVariants) {
        if ($text.Contains($candidate)) {
            $newCandidate = if ($candidate.Contains("`r`n")) { $New.Replace("`n", "`r`n") } else { $New.Replace("`r`n", "`n") }
            Write-Text $RelativePath ($text.Replace($candidate, $newCandidate))
            Write-Step "$Description ergänzt"
            return
        }
    }

    throw "Anker fuer $Description nicht gefunden in $RelativePath."
}

function Append-Once {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Content,
        [Parameter(Mandatory = $true)][string]$Marker,
        [Parameter(Mandatory = $true)][string]$Description
    )
    $text = Read-Text $RelativePath
    if ($text.Contains($Marker)) {
        Write-Step "$Description bereits vorhanden"
        return
    }
    Write-Text $RelativePath ($text.TrimEnd() + "`r`n`r`n" + $Content.Trim() + "`r`n")
    Write-Step "$Description ergänzt"
}

function Ensure-ChangelogEntry {
    $relativePath = 'CHANGELOG.md'
    $text = Read-Text $relativePath
    if ($text.Contains('## 0.35.0')) {
        Write-Step 'CHANGELOG.md enthält 0.35.0 bereits'
        return
    }

    $entry = @'
## 0.35.0 - Audit Journal Dashboard

- Auditjournal im Dashboard sichtbar gemacht.
- Persistente Audit-Einträge werden über den bestehenden Endpunkt `/api/tournaments/{id}/audit-journal` geladen.
- Neue Kennzahlen für Info-/Warn-/kritische Journal-Einträge ergänzt.
- Letzte Audit-Einträge werden mit Zeitpunkt, Aktion, Bezug, Zusammenfassung, Details und Grund angezeigt.
- Clientseitiger CSV- und JSON-Export des Auditjournals ergänzt.
- Keine Änderung an Auslosungslogik, Wertungsberechnung oder Speicherformat.

'@

    $updated = if ($text.StartsWith("# Changelog")) {
        $text -replace '(^# Changelog\s*)', ("# Changelog`r`n`r`n" + $entry)
    } else {
        $entry + $text
    }
    Write-Text $relativePath $updated
    Write-Step 'CHANGELOG.md ergänzt'
}

function Patch-MainTsx {
    $relativePath = 'src/SchachTurnierManager.WebApp/src/main.tsx'

    Replace-Once $relativePath @'
type Tournament = {
  id: string;
  name: string;
  createdOn: string;
  settings: {
    format: number;
    scoringSystem: number;
    twzSource: number;
    plannedRounds: number;
    seniorBirthYearOrEarlier?: number | null;
    heroCupMinimumRatedGames: number;
    forfeitTiebreakPolicy: number;
    countByeAsWin: boolean;
    allowManualPairingOverrides: boolean;
    tiebreaks: number[];
  };
  players: Player[];
  rounds: TournamentRound[];
};
'@ @'
type Tournament = {
  id: string;
  name: string;
  createdOn: string;
  settings: {
    format: number;
    scoringSystem: number;
    twzSource: number;
    plannedRounds: number;
    seniorBirthYearOrEarlier?: number | null;
    heroCupMinimumRatedGames: number;
    forfeitTiebreakPolicy: number;
    countByeAsWin: boolean;
    allowManualPairingOverrides: boolean;
    tiebreaks: number[];
  };
  players: Player[];
  rounds: TournamentRound[];
};

type AuditJournalEntry = {
  id: string;
  createdAt: string;
  action: number | string;
  severity: number | string;
  actor: string;
  summary: string;
  details?: string | null;
  reason?: string | null;
  roundNumber?: number | null;
  boardNumber?: number | null;
  playerId?: string | null;
  playerName?: string | null;
};
'@ 'AuditJournalEntry-Type' 'type AuditJournalEntry ='

    Replace-Once $relativePath @'
function pairingQualitySeverityClass(severity: number): string {
  switch (severity) {
    case 0: return 'quality-good';
    case 1: return 'quality-notice';
    case 2: return 'quality-warning';
    case 3: return 'quality-critical';
    default: return '';
  }
}
function settingsToForm(tournament?: Tournament): SettingsForm {
'@ @'
function pairingQualitySeverityClass(severity: number): string {
  switch (severity) {
    case 0: return 'quality-good';
    case 1: return 'quality-notice';
    case 2: return 'quality-warning';
    case 3: return 'quality-critical';
    default: return '';
  }
}

function auditSeverityKey(severity: number | string): 'info' | 'warning' | 'critical' {
  switch (String(severity)) {
    case '1':
    case 'Warning':
      return 'warning';
    case '2':
    case 'Critical':
      return 'critical';
    default:
      return 'info';
  }
}

function auditSeverityLabel(severity: number | string): string {
  switch (auditSeverityKey(severity)) {
    case 'warning': return 'Warnung';
    case 'critical': return 'kritisch';
    default: return 'Info';
  }
}

function auditSeverityClass(severity: number | string): string {
  return `audit-${auditSeverityKey(severity)}`;
}

function auditActionLabel(action: number | string): string {
  switch (String(action)) {
    case '0':
    case 'TournamentCreated': return 'Turnier angelegt';
    case '1':
    case 'SettingsUpdated': return 'Einstellungen geändert';
    case '2':
    case 'TournamentImported': return 'Turnier importiert';
    case '3':
    case 'ExternalPlayerApplied': return 'Externe Spielerdaten';
    case '10':
    case 'PlayerAdded': return 'Spieler hinzugefügt';
    case '11':
    case 'PlayerUpdated': return 'Spieler geändert';
    case '12':
    case 'PlayerStatusChanged': return 'Spielerstatus geändert';
    case '13':
    case 'PlayerRemoved': return 'Spieler entfernt';
    case '14':
    case 'PlayerWithdrawn': return 'Spieler zurückgezogen';
    case '20':
    case 'RoundGenerated': return 'Runde ausgelost';
    case '21':
    case 'ResultRecorded': return 'Ergebnis erfasst';
    case '22':
    case 'PairingOverridden': return 'Paarung korrigiert';
    case '23':
    case 'RoundLocked': return 'Runde gesperrt';
    case '24':
    case 'RoundUnlocked': return 'Runde entsperrt';
    case '25':
    case 'RoundVerified': return 'Runde geprüft';
    case '26':
    case 'RoundUnverified': return 'Prüfung zurückgenommen';
    default: return String(action);
  }
}

function auditDateLabel(value: string): string {
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    return value || '—';
  }

  return parsed.toLocaleString('de-DE', { dateStyle: 'short', timeStyle: 'short' });
}

function auditCsvCell(value: unknown): string {
  const text = value === null || value === undefined ? '' : String(value);
  return /[;"\r\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
}

function settingsToForm(tournament?: Tournament): SettingsForm {
'@ 'Auditjournal-Helfer im Frontend' 'function auditActionLabel'

    Replace-Once $relativePath @'
  const [roundDiagnostics, setRoundDiagnostics] = React.useState<RoundDiagnostics[]>([]);
  const [pairingQualityReports, setPairingQualityReports] = React.useState<Record<number, PairingQualityReport>>({});
'@ @'
  const [roundDiagnostics, setRoundDiagnostics] = React.useState<RoundDiagnostics[]>([]);
  const [auditJournal, setAuditJournal] = React.useState<AuditJournalEntry[]>([]);
  const [pairingQualityReports, setPairingQualityReports] = React.useState<Record<number, PairingQualityReport>>({});
'@ 'Auditjournal-State' 'setAuditJournal'

    Replace-Once $relativePath @'
  const selectedTournament = tournaments.find(tournament => tournament.id === selectedId) ?? tournaments[0];

  const loadTournaments = React.useCallback(async (): Promise<Tournament[]> => {
'@ @'
  const selectedTournament = tournaments.find(tournament => tournament.id === selectedId) ?? tournaments[0];
  const auditJournalRecentEntries = auditJournal.slice(0, 15);
  const auditJournalWarningCount = auditJournal.filter(entry => auditSeverityKey(entry.severity) === 'warning').length;
  const auditJournalCriticalCount = auditJournal.filter(entry => auditSeverityKey(entry.severity) === 'critical').length;
  const auditJournalInfoCount = auditJournal.length - auditJournalWarningCount - auditJournalCriticalCount;
  const auditJournalRoundEntryCount = auditJournal.filter(entry => entry.roundNumber !== null && entry.roundNumber !== undefined).length;
  const auditJournalPlayerEntryCount = auditJournal.filter(entry => Boolean(entry.playerId || entry.playerName)).length;

  const loadTournaments = React.useCallback(async (): Promise<Tournament[]> => {
'@ 'Auditjournal-Kennzahlen' 'auditJournalRecentEntries'

    Replace-Once $relativePath @'
      setHeroCup([]);
      setRoundDiagnostics([]);
      setPairingQualityReports({});
      return;
    }

    const [standingData, categoryData, crossTableData, heroCupData, diagnosticsData] = await Promise.all([
      requestJson<StandingRow[]>(`/api/tournaments/${id}/standings`),
      requestJson<CategoryStandingTable[]>(`/api/tournaments/${id}/categories`),
      requestJson<CrossTable>(`/api/tournaments/${id}/cross-table`),
      requestJson<HeroCupRow[]>(`/api/tournaments/${id}/hero-cup`),
      requestJson<RoundDiagnostics[]>(`/api/tournaments/${id}/round-diagnostics`)
    ]);
    setStandings(standingData);
    setCategories(categoryData);
    setCrossTable(crossTableData);
    setHeroCup(heroCupData);
    setRoundDiagnostics(diagnosticsData);
  }, []);
'@ @'
      setHeroCup([]);
      setRoundDiagnostics([]);
      setAuditJournal([]);
      setPairingQualityReports({});
      return;
    }

    const [standingData, categoryData, crossTableData, heroCupData, diagnosticsData, auditJournalData] = await Promise.all([
      requestJson<StandingRow[]>(`/api/tournaments/${id}/standings`),
      requestJson<CategoryStandingTable[]>(`/api/tournaments/${id}/categories`),
      requestJson<CrossTable>(`/api/tournaments/${id}/cross-table`),
      requestJson<HeroCupRow[]>(`/api/tournaments/${id}/hero-cup`),
      requestJson<RoundDiagnostics[]>(`/api/tournaments/${id}/round-diagnostics`),
      requestJson<AuditJournalEntry[]>(`/api/tournaments/${id}/audit-journal`)
    ]);
    setStandings(standingData);
    setCategories(categoryData);
    setCrossTable(crossTableData);
    setHeroCup(heroCupData);
    setRoundDiagnostics(diagnosticsData);
    setAuditJournal(auditJournalData);
  }, []);
'@ 'Auditjournal-Ladevorgang' 'auditJournalData'

    Replace-Once $relativePath @'
  function openTournamentExport(path: string) {
    if (!selectedTournament) {
      return;
    }

    window.open(`/api/tournaments/${selectedTournament.id}/${path}`, '_blank', 'noopener,noreferrer');
  }

  function openRoundPrint(roundNumber: number) {
'@ @'
  function openTournamentExport(path: string) {
    if (!selectedTournament) {
      return;
    }

    window.open(`/api/tournaments/${selectedTournament.id}/${path}`, '_blank', 'noopener,noreferrer');
  }

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

  function openRoundPrint(roundNumber: number) {
'@ 'Auditjournal-Exportfunktionen' 'exportAuditJournalCsv'

    Replace-Once $relativePath @'
          <article className="card">
            <h3>Import / Export</h3>
'@ @'
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

          <article className="card">
            <h3>Import / Export</h3>
'@ 'Auditjournal-Dashboardkarte' 'audit-journal-card'
}

function Patch-Styles {
    $css = @'
.audit-journal-card {
  border-color: rgba(96, 165, 250, 0.35);
}

.audit-journal-heading {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  align-items: flex-start;
}

.audit-journal-heading p {
  margin-top: 0.35rem;
  color: var(--muted);
}

.audit-journal-summary {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
  gap: 0.75rem;
  margin: 1rem 0;
}

.audit-journal-summary div {
  border: 1px solid var(--border);
  border-radius: 0.8rem;
  padding: 0.75rem;
  background: rgba(15, 23, 42, 0.35);
}

.audit-journal-summary strong {
  display: block;
  font-size: 1.3rem;
}

.audit-journal-summary span {
  color: var(--muted);
  font-size: 0.85rem;
}

.audit-pill {
  display: inline-flex;
  border-radius: 999px;
  padding: 0.15rem 0.55rem;
  font-size: 0.78rem;
  font-weight: 700;
}

.audit-info {
  background: rgba(59, 130, 246, 0.12);
  color: #bfdbfe;
}

.audit-warning {
  background: rgba(245, 158, 11, 0.14);
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
    Append-Once 'src/SchachTurnierManager.WebApp/src/styles.css' $css '.audit-journal-card' 'CSS für Audit-Journal-Dashboard'
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

    Patch-MainTsx
    Patch-Styles
    Ensure-ChangelogEntry

    $handoff = @'
# Handoff 0.35.0 - Audit Journal Dashboard

## Ziel

0.35.0 macht das in 0.34.x eingeführte persistente Auditjournal im Dashboard sichtbar. Der Turnierleiter soll sofort sehen können, welche Aktionen protokolliert wurden und ob Warn-/kritische Einträge vorhanden sind.

## Änderungen

- Frontend-Typ `AuditJournalEntry` ergänzt.
- `loadDerived(...)` lädt zusätzlich `/api/tournaments/{id}/audit-journal`.
- Neue Dashboardkarte `Audit-Journal` mit Kennzahlen, letzten Einträgen und Warnhinweis.
- Clientseitiger CSV- und JSON-Export des Journals ergänzt.
- CSS für Journal-Karte, Severity-Pills und Tabelle ergänzt.

## Nicht geändert

- Keine Änderung an Auslosungslogik.
- Keine Änderung an Wertungsberechnung.
- Keine Änderung am Speicherformat über das bestehende Auditjournal aus 0.34.x hinaus.

## Erwartung

- `dotnet test`: 81/81 grün.
- `npm run build`: grün.
- `Pack-Portable`: `SchachTurnierManager_Portable_0.35.0.zip`.
'@
    Write-Text 'docs/HANDOFF_0_35_0.md' $handoff
    Write-Step 'Handoff ergänzt'

    @(
        'CHANGELOG.md',
        'src/SchachTurnierManager.WebApi/Program.cs',
        'src/SchachTurnierManager.WebApp/package.json',
        'src/SchachTurnierManager.WebApp/package-lock.json',
        'src/SchachTurnierManager.WebApp/src/main.tsx',
        'src/SchachTurnierManager.WebApp/src/styles.css',
        'docs/HANDOFF_0_35_0.md',
        'scripts/After-Apply-V0.35.ps1'
    ) | ForEach-Object { Set-TextFileUtf8NoBom $_ }

    Invoke-Checked 'Release-Gate' { pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'scripts/Invoke-ReleaseGate.ps1') }
    Write-Step 'Nachkontrolle abgeschlossen. Aktueller Git-Status:'
    git -C $Root status --short
}
catch {
    Write-Error $_
    exit 1
}
