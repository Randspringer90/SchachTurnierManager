$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Root = Split-Path -Parent $PSScriptRoot

function Read-ProjectFile {
    param([Parameter(Mandatory)][string]$Path)
    $fullPath = Join-Path $Root $Path
    return [System.IO.File]::ReadAllText($fullPath, [System.Text.Encoding]::UTF8)
}

function Write-ProjectFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content
    )
    $fullPath = Join-Path $Root $Path
    $directory = Split-Path -Parent $fullPath
    if ($directory -and -not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($fullPath, $Content, $utf8NoBom)
}

function Set-VersionRegex {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][string]$Replacement,
        [Parameter(Mandatory)][string]$Description
    )
    $content = Read-ProjectFile -Path $Path
    if ($content.Contains($Replacement)) {
        return
    }
    $updated = [regex]::Replace($content, $Pattern, $Replacement)
    if ($updated -eq $content) {
        throw "Version konnte nicht gesetzt werden in ${Path}: ${Description}"
    }
    Write-ProjectFile -Path $Path -Content $updated
    Write-Host "[v0.18.1] $Description"
}

function Ensure-ProjectText {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$UniqueMarker,
        [Parameter(Mandatory)][string]$Search,
        [Parameter(Mandatory)][string]$Replacement,
        [Parameter(Mandatory)][string]$Description
    )
    $content = Read-ProjectFile -Path $Path
    if ($content.Contains($UniqueMarker)) {
        return
    }
    if (-not $content.Contains($Search)) {
        throw "Erwartete Stelle nicht gefunden in ${Path}: ${Description}"
    }
    Write-ProjectFile -Path $Path -Content ($content.Replace($Search, $Replacement))
    Write-Host "[v0.18.1] $Description"
}

function Ensure-InsertBefore {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$UniqueMarker,
        [Parameter(Mandatory)][string]$Before,
        [Parameter(Mandatory)][string]$Insert,
        [Parameter(Mandatory)][string]$Description
    )
    $content = Read-ProjectFile -Path $Path
    if ($content.Contains($UniqueMarker)) {
        return
    }
    $index = $content.IndexOf($Before, [StringComparison]::Ordinal)
    if ($index -lt 0) {
        throw "Einfügemarke nicht gefunden in ${Path}: ${Description}"
    }
    $updated = $content.Substring(0, $index) + $Insert + $content.Substring($index)
    Write-ProjectFile -Path $Path -Content $updated
    Write-Host "[v0.18.1] $Description"
}

function Ensure-InsertBeforeAfter {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$UniqueMarker,
        [Parameter(Mandatory)][string]$AfterAnchor,
        [Parameter(Mandatory)][string]$Before,
        [Parameter(Mandatory)][string]$Insert,
        [Parameter(Mandatory)][string]$Description
    )
    $content = Read-ProjectFile -Path $Path
    if ($content.Contains($UniqueMarker)) {
        return
    }
    $afterIndex = $content.IndexOf($AfterAnchor, [StringComparison]::Ordinal)
    if ($afterIndex -lt 0) {
        throw "Startanker nicht gefunden in ${Path}: ${Description}"
    }
    $beforeIndex = $content.IndexOf($Before, $afterIndex, [StringComparison]::Ordinal)
    if ($beforeIndex -lt 0) {
        throw "Einfügemarke nach Startanker nicht gefunden in ${Path}: ${Description}"
    }
    $updated = $content.Substring(0, $beforeIndex) + $Insert + $content.Substring($beforeIndex)
    Write-ProjectFile -Path $Path -Content $updated
    Write-Host "[v0.18.1] $Description"
}

function Run-Step {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Action
    )
    Write-Host "[v0.18.1] $Name..."
    & $Action
    if ($LASTEXITCODE -ne 0) {
        throw "Schritt fehlgeschlagen: $Name (ExitCode=$LASTEXITCODE)"
    }
}

# Alte, defekte v0.18.0-Nachkontrolle nicht mitcommitten.
Remove-Item -LiteralPath (Join-Path $Root 'scripts/After-Apply-V0.18.ps1') -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $Root 'docs/HANDOFF_0_18_0.md') -Force -ErrorAction SilentlyContinue

# Versionsnummern robust von 0.17.0/0.18.0 auf 0.18.1 anheben.
Set-VersionRegex -Path 'src/SchachTurnierManager.WebApp/package.json' -Pattern '"version"\s*:\s*"0\.(17\.0|18\.0)"' -Replacement '"version": "0.18.1"' -Description 'package.json auf 0.18.1 gesetzt'
Set-VersionRegex -Path 'src/SchachTurnierManager.WebApp/package-lock.json' -Pattern '"version"\s*:\s*"0\.(17\.0|18\.0)"' -Replacement '"version": "0.18.1"' -Description 'package-lock.json auf 0.18.1 gesetzt'
Set-VersionRegex -Path 'src/SchachTurnierManager.WebApi/Program.cs' -Pattern 'version = "0\.(17\.0|18\.0)"' -Replacement 'version = "0.18.1"' -Description 'API-Version auf 0.18.1 gesetzt'
Set-VersionRegex -Path 'src/SchachTurnierManager.WebApp/src/main.tsx' -Pattern 'Lokaler Turnierleiter · v0\.(17\.0|18\.0)' -Replacement 'Lokaler Turnierleiter · v0.18.1' -Description 'Dashboard-Version auf 0.18.1 gesetzt'

# TournamentService: PairingQualityAnalyzer einbinden.
Ensure-ProjectText -Path 'src/SchachTurnierManager.Application/TournamentService.cs' -UniqueMarker 'private readonly PairingQualityAnalyzer _pairingQuality = new();' -Search @'
    private readonly RoundDiagnosticsCalculator _roundDiagnostics = new();
    private readonly TournamentExportFormatter _exports = new();
'@ -Replacement @'
    private readonly RoundDiagnosticsCalculator _roundDiagnostics = new();
    private readonly PairingQualityAnalyzer _pairingQuality = new();
    private readonly TournamentExportFormatter _exports = new();
'@ -Description 'PairingQualityAnalyzer-Feld ergänzt'

Ensure-ProjectText -Path 'src/SchachTurnierManager.Application/TournamentService.cs' -UniqueMarker 'public PairingQualityReport GetPairingQuality' -Search @'
    public RoundDiagnostics GetRoundDiagnostics(Guid tournamentId, int roundNumber)
    {
        var tournament = RequireTournament(tournamentId);
        var roundIndex = RequireRoundIndex(tournament, roundNumber);
        return _roundDiagnostics.Calculate(tournament, tournament.Rounds[roundIndex]);
    }

    public TournamentState RequireTournament(Guid tournamentId)
'@ -Replacement @'
    public RoundDiagnostics GetRoundDiagnostics(Guid tournamentId, int roundNumber)
    {
        var tournament = RequireTournament(tournamentId);
        var roundIndex = RequireRoundIndex(tournament, roundNumber);
        return _roundDiagnostics.Calculate(tournament, tournament.Rounds[roundIndex]);
    }

    public PairingQualityReport GetPairingQuality(Guid tournamentId, int roundNumber)
    {
        var tournament = RequireTournament(tournamentId);
        var roundIndex = RequireRoundIndex(tournament, roundNumber);
        return _pairingQuality.Analyze(tournament, tournament.Rounds[roundIndex]);
    }

    public TournamentState RequireTournament(Guid tournamentId)
'@ -Description 'Application-Methode GetPairingQuality ergänzt'

# WebApi: Endpoint ergänzen.
Ensure-ProjectText -Path 'src/SchachTurnierManager.WebApi/Program.cs' -UniqueMarker '/pairing-quality' -Search @'
app.MapGet("/api/tournaments/{id:guid}/rounds/{roundNumber:int}/diagnostics", (Guid id, int roundNumber, TournamentService service) =>
{
    try
    {
        return Results.Ok(service.GetRoundDiagnostics(id, roundNumber));
    }
    catch (InvalidOperationException ex)
    {
        return Results.NotFound(new { error = ex.Message });
    }
});

app.MapGet("/api/tournaments/{id:guid}/standings/export.csv", (Guid id, TournamentService service) =>
'@ -Replacement @'
app.MapGet("/api/tournaments/{id:guid}/rounds/{roundNumber:int}/diagnostics", (Guid id, int roundNumber, TournamentService service) =>
{
    try
    {
        return Results.Ok(service.GetRoundDiagnostics(id, roundNumber));
    }
    catch (InvalidOperationException ex)
    {
        return Results.NotFound(new { error = ex.Message });
    }
});

app.MapGet("/api/tournaments/{id:guid}/rounds/{roundNumber:int}/pairing-quality", (Guid id, int roundNumber, TournamentService service) =>
{
    try
    {
        return Results.Ok(service.GetPairingQuality(id, roundNumber));
    }
    catch (InvalidOperationException ex)
    {
        return Results.NotFound(new { error = ex.Message });
    }
});

app.MapGet("/api/tournaments/{id:guid}/standings/export.csv", (Guid id, TournamentService service) =>
'@ -Description 'Pairing-Quality-Endpoint ergänzt'

# React: Typen ergänzen.
Ensure-ProjectText -Path 'src/SchachTurnierManager.WebApp/src/main.tsx' -UniqueMarker 'type PairingQualityReport = {' -Search @'
type RoundDiagnostics = {
  roundNumber: number;
  resultStatus: number;
  isComplete: boolean;
  isLocked: boolean;
  isVerified: boolean;
  openBoards: number;
  forfeitBoards: number;
  byeBoards: number;
  warnings: string[];
  boards: BoardDiagnostic[];
};

type ExternalPlayerProviderInfo = {
'@ -Replacement @'
type RoundDiagnostics = {
  roundNumber: number;
  resultStatus: number;
  isComplete: boolean;
  isLocked: boolean;
  isVerified: boolean;
  openBoards: number;
  forfeitBoards: number;
  byeBoards: number;
  warnings: string[];
  boards: BoardDiagnostic[];
};

type PairingQualityBoard = {
  boardNumber: number;
  whitePlayerId?: string | null;
  blackPlayerId?: string | null;
  whiteName: string;
  blackName: string;
  whiteScoreBeforeRound: number;
  blackScoreBeforeRound: number;
  scoreDifference: number;
  isBye: boolean;
  isRematch: boolean;
  isCrossScoreGroupPairing: boolean;
  wouldGiveWhiteThirdSameColor: boolean;
  wouldGiveBlackThirdSameColor: boolean;
  findings: string[];
};

type PairingQualityReport = {
  roundNumber: number;
  boardCount: number;
  gameCount: number;
  byeCount: number;
  rematchCount: number;
  crossScoreGroupPairingCount: number;
  thirdSameColorRiskCount: number;
  maxScoreDifference: number;
  averageScoreDifference: number;
  qualityScore: number;
  severity: number;
  findings: string[];
  boards: PairingQualityBoard[];
  hasCriticalIssues: boolean;
  hasWarnings: boolean;
  findingCount: number;
};

type ExternalPlayerProviderInfo = {
'@ -Description 'React-Typen für Pairing-Qualität ergänzt'

Ensure-ProjectText -Path 'src/SchachTurnierManager.WebApp/src/main.tsx' -UniqueMarker 'pairingQualityReports' -Search @'
  const [roundDiagnostics, setRoundDiagnostics] = React.useState<RoundDiagnostics[]>([]);
  const [newTournamentName, setNewTournamentName] = React.useState('Vereinsturnier');
'@ -Replacement @'
  const [roundDiagnostics, setRoundDiagnostics] = React.useState<RoundDiagnostics[]>([]);
  const [pairingQualityReports, setPairingQualityReports] = React.useState<Record<number, PairingQualityReport>>({});
  const [newTournamentName, setNewTournamentName] = React.useState('Vereinsturnier');
'@ -Description 'React-State für Pairing-Quality-Reports ergänzt'

Ensure-ProjectText -Path 'src/SchachTurnierManager.WebApp/src/main.tsx' -UniqueMarker 'setPairingQualityReports({});' -Search @'
      setHeroCup([]);
      setRoundDiagnostics([]);
      return;
'@ -Replacement @'
      setHeroCup([]);
      setRoundDiagnostics([]);
      setPairingQualityReports({});
      return;
'@ -Description 'Pairing-Quality-State beim Leerlauf zurückgesetzt'

Ensure-ProjectText -Path 'src/SchachTurnierManager.WebApp/src/main.tsx' -UniqueMarker 'setPairingQualityReports({});
  }, [selectedTournament?.id]);' -Search @'
  React.useEffect(() => {
    setSettingsForm(settingsToForm(selectedTournament));
  }, [selectedTournament?.id]);

  async function createTournament(event: React.FormEvent<HTMLFormElement>) {
'@ -Replacement @'
  React.useEffect(() => {
    setSettingsForm(settingsToForm(selectedTournament));
  }, [selectedTournament?.id]);

  React.useEffect(() => {
    setPairingQualityReports({});
  }, [selectedTournament?.id]);

  async function createTournament(event: React.FormEvent<HTMLFormElement>) {
'@ -Description 'Pairing-Quality-State bei Turnierwechsel zurückgesetzt'

# React: Hilfsfunktionen robust vor settingsToForm ergänzen.
Ensure-InsertBefore -Path 'src/SchachTurnierManager.WebApp/src/main.tsx' -UniqueMarker 'function pairingQualitySeverityLabel' -Before @'
function settingsToForm(tournament?: Tournament): SettingsForm {
'@ -Insert @'
function pairingQualitySeverityLabel(severity: number): string {
  switch (severity) {
    case 0: return 'gut';
    case 1: return 'Hinweis';
    case 2: return 'Warnung';
    case 3: return 'kritisch';
    default: return String(severity);
  }
}

function pairingQualitySeverityClass(severity: number): string {
  switch (severity) {
    case 0: return 'quality-good';
    case 1: return 'quality-notice';
    case 2: return 'quality-warning';
    case 3: return 'quality-critical';
    default: return '';
  }
}

'@ -Description 'Hilfsfunktionen für Pairing-Quality-Severity ergänzt'

# React: Ladefunktion ergänzen.
Ensure-InsertBefore -Path 'src/SchachTurnierManager.WebApp/src/main.tsx' -UniqueMarker 'function pairingQualityFor' -Before @'
  async function importPlayers() {
'@ -Insert @'
  function pairingQualityFor(roundNumber: number): PairingQualityReport | undefined {
    return pairingQualityReports[roundNumber];
  }

  async function loadPairingQuality(roundNumber: number) {
    if (!selectedTournament) {
      setError('Bitte zuerst ein Turnier auswählen.');
      return;
    }

    setError(null);
    const report = await requestJson<PairingQualityReport>(`/api/tournaments/${selectedTournament.id}/rounds/${roundNumber}/pairing-quality`);
    setPairingQualityReports(previous => ({ ...previous, [roundNumber]: report }));
    setStatus(`Pairing-Qualität Runde ${roundNumber}: ${report.qualityScore}/100 · ${pairingQualitySeverityLabel(report.severity)}.`);
  }

'@ -Description 'Pairing-Quality-Ladefunktion ergänzt'

# React: UI-Block in Rundenansicht ergänzen.
Ensure-InsertBeforeAfter -Path 'src/SchachTurnierManager.WebApp/src/main.tsx' -UniqueMarker 'quality-box' -AfterAnchor @'
{diagnosticsFor(round.roundNumber) && (
'@ -Before @'
                <div className="table-scroll">
'@ -Insert @'
                <div className={`quality-box ${pairingQualityFor(round.roundNumber) ? pairingQualitySeverityClass(pairingQualityFor(round.roundNumber)!.severity) : 'quality-empty'}`}>
                  <div className="quality-header">
                    <div>
                      <strong>Pairing-Qualität</strong>
                      {pairingQualityFor(round.roundNumber)
                        ? <span>{pairingQualityFor(round.roundNumber)!.qualityScore}/100 · {pairingQualitySeverityLabel(pairingQualityFor(round.roundNumber)!.severity)}</span>
                        : <span>noch nicht berechnet</span>}
                    </div>
                    <button type="button" className="small secondary" onClick={() => void loadPairingQuality(round.roundNumber)}>Qualität prüfen</button>
                  </div>
                  {pairingQualityFor(round.roundNumber) && (
                    <details open={pairingQualityFor(round.roundNumber)!.severity >= 2}>
                      <summary>{pairingQualityFor(round.roundNumber)!.findingCount} Hinweis(e) · {pairingQualityFor(round.roundNumber)!.rematchCount} Rematch · {pairingQualityFor(round.roundNumber)!.crossScoreGroupPairingCount} Scoregruppen-Abweichung(en) · {pairingQualityFor(round.roundNumber)!.thirdSameColorRiskCount} Farbfolge-Risiko/Risiken</summary>
                      <ul className="message-list">
                        {pairingQualityFor(round.roundNumber)!.findings.map((finding, index) => <li key={`quality-finding-${round.roundNumber}-${index}`}>{finding}</li>)}
                      </ul>
                      <div className="table-scroll compact">
                        <table>
                          <thead><tr><th>Brett</th><th>Paarung</th><th>Score vor Runde</th><th>Hinweise</th></tr></thead>
                          <tbody>
                            {pairingQualityFor(round.roundNumber)!.boards.map(board => (
                              <tr key={`quality-board-${round.roundNumber}-${board.boardNumber}`} className={board.isRematch ? 'quality-board-critical' : board.wouldGiveWhiteThirdSameColor || board.wouldGiveBlackThirdSameColor ? 'quality-board-warning' : board.isCrossScoreGroupPairing || board.isBye ? 'quality-board-notice' : ''}>
                                <td>{board.boardNumber}</td>
                                <td>{board.whiteName} – {board.blackName}</td>
                                <td>{board.isBye ? 'Bye' : `${board.whiteScoreBeforeRound} : ${board.blackScoreBeforeRound}`}</td>
                                <td>{board.findings.length === 0 ? <span className="ok">ok</span> : <ul className="message-list">{board.findings.map((finding, index) => <li key={`quality-board-finding-${round.roundNumber}-${board.boardNumber}-${index}`}>{finding}</li>)}</ul>}</td>
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>
                    </details>
                  )}
                </div>
'@ -Description 'Pairing-Quality-UI in Rundenansicht ergänzt'

# CSS ergänzen.
$stylesPath = 'src/SchachTurnierManager.WebApp/src/styles.css'
$styles = Read-ProjectFile -Path $stylesPath
if (-not $styles.Contains('.quality-box')) {
    $styles += @'

.quality-box {
  margin: 0.75rem 0;
  padding: 0.8rem;
  border: 1px solid rgba(148, 163, 184, 0.35);
  border-radius: 14px;
  background: rgba(15, 23, 42, 0.38);
}

.quality-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  margin-bottom: 0.45rem;
}

.quality-header div {
  display: flex;
  flex-direction: column;
  gap: 0.15rem;
}

.quality-header span {
  color: var(--muted);
  font-size: 0.9rem;
}

.quality-good {
  border-color: rgba(34, 197, 94, 0.55);
  background: rgba(22, 101, 52, 0.14);
}

.quality-notice,
.quality-empty {
  border-color: rgba(59, 130, 246, 0.45);
  background: rgba(30, 64, 175, 0.12);
}

.quality-warning {
  border-color: rgba(245, 158, 11, 0.65);
  background: rgba(146, 64, 14, 0.16);
}

.quality-critical {
  border-color: rgba(239, 68, 68, 0.7);
  background: rgba(127, 29, 29, 0.18);
}

.quality-board-critical {
  background: rgba(127, 29, 29, 0.22);
}

.quality-board-warning {
  background: rgba(146, 64, 14, 0.18);
}

.quality-board-notice {
  background: rgba(30, 64, 175, 0.16);
}
'@
    Write-ProjectFile -Path $stylesPath -Content $styles
    Write-Host "[v0.18.1] Pairing-Quality-CSS ergänzt"
}

# Changelog ergänzen.
$changelogPath = 'CHANGELOG.md'
$changelog = Read-ProjectFile -Path $changelogPath
if (-not $changelog.Contains('## 0.18.1 - Pairing-Qualität im Dashboard')) {
    $entry = @'
## 0.18.1 - Pairing-Qualität im Dashboard

- Fix-Forward für das v0.18.0-Nachkontrollskript.
- Application-Endpunkt für Pairing-Qualität pro Runde ergänzt.
- WebApi-Endpunkt `/api/tournaments/{id}/rounds/{roundNumber}/pairing-quality` ergänzt.
- Dashboard zeigt Pairing-Qualitätswert, Schweregrad, Rundenhinweise und brettweise Erklärungen.
- Tests für den Application-Workflow der Pairing-Qualitätsberichte ergänzt.

'@
    $changelog = $changelog -replace '# Changelog\s*', "# Changelog`r`n`r`n$entry"
    Write-ProjectFile -Path $changelogPath -Content $changelog
    Write-Host "[v0.18.1] CHANGELOG.md ergänzt"
}

# Application-Test ergänzen.
$testPath = 'tests/SchachTurnierManager.Application.Tests/PairingQualityWorkflowTests.cs'
if (-not (Test-Path -LiteralPath (Join-Path $Root $testPath))) {
    Write-ProjectFile -Path $testPath -Content @'
using SchachTurnierManager.Domain.Models;
using Xunit;

namespace SchachTurnierManager.Application.Tests;

public sealed class PairingQualityWorkflowTests
{
    [Fact]
    public void GetPairingQuality_ReturnsReportForGeneratedRound()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Pairing Quality", new TournamentSettings { Format = TournamentFormat.Swiss });
        AddPlayers(service, tournament.Id, 4);

        var round = service.GenerateNextRound(tournament.Id);
        var report = service.GetPairingQuality(tournament.Id, round.RoundNumber);

        Assert.Equal(round.RoundNumber, report.RoundNumber);
        Assert.Equal(round.Pairings.Count, report.BoardCount);
        Assert.Equal(100, report.QualityScore);
        Assert.Equal(PairingQualitySeverity.Good, report.Severity);
        Assert.NotEmpty(report.Findings);
        Assert.All(report.Boards, board => Assert.Equal(0, board.ScoreDifference));
    }

    [Fact]
    public void GetPairingQuality_RejectsUnknownRound()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Pairing Quality Missing Round", new TournamentSettings { Format = TournamentFormat.Swiss });
        AddPlayers(service, tournament.Id, 4);

        var ex = Assert.Throws<InvalidOperationException>(() => service.GetPairingQuality(tournament.Id, 99));

        Assert.Contains("Runde 99", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    private static void AddPlayers(TournamentService service, Guid tournamentId, int count)
    {
        for (var i = 1; i <= count; i++)
        {
            service.AddPlayer(tournamentId, new Player
            {
                Name = $"Spieler {i}",
                Rating = new RatingProfile { ManualTwz = 2100 - i * 10 }
            });
        }
    }
}
'@
    Write-Host "[v0.18.1] Application-Test PairingQualityWorkflowTests ergänzt"
}

# Handoff schreiben.
Write-ProjectFile -Path 'docs/HANDOFF_0_18_1.md' -Content @'
# Handoff 0.18.1 - Pairing-Qualität im Dashboard

## Inhalt

- Fix-Forward für das v0.18.0-Nachkontrollskript.
- `TournamentService.GetPairingQuality(...)` ergänzt.
- API-Endpunkt `GET /api/tournaments/{id}/rounds/{roundNumber}/pairing-quality` ergänzt.
- Dashboard kann pro Runde den Pairing-Qualitätsbericht laden und anzeigen.
- Anzeige enthält Qualitätswert, Schweregrad, Zusammenfassung und brettweise Hinweise.
- Application-Test für den neuen Service-Workflow ergänzt.

## Nachkontrolle

Ausführen:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\After-Apply-V0.18.1.ps1"
```

Danach committen:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; git status; git add .; git commit -m "Show pairing quality reports in dashboard"; git push
```

## Nächster Vorschlag

v0.19.0: Pairing-Qualitätsbericht direkt in den Swiss-Pairing-Audit integrieren und Golden Tests für komplette Turnierverläufe ergänzen.
'@

# Abschlussprüfungen vor Build.
$main = Read-ProjectFile -Path 'src/SchachTurnierManager.WebApp/src/main.tsx'
if ($main.Contains('v0.17.0') -or $main.Contains('v0.18.0')) {
    throw 'Dashboard enthält weiterhin eine alte v0.17.0/v0.18.0 Versionsanzeige.'
}
if (-not $main.Contains('Pairing-Qualität')) {
    throw 'Dashboard enthält den Pairing-Quality-Block nicht.'
}
if (-not (Read-ProjectFile -Path 'src/SchachTurnierManager.Application/TournamentService.cs').Contains('GetPairingQuality')) {
    throw 'TournamentService.GetPairingQuality wurde nicht gefunden.'
}
if (-not (Read-ProjectFile -Path 'src/SchachTurnierManager.WebApi/Program.cs').Contains('/pairing-quality')) {
    throw 'Pairing-Quality-Endpoint wurde nicht gefunden.'
}

Run-Step 'dotnet restore' { dotnet restore }
Run-Step 'dotnet build' { dotnet build }
Run-Step 'dotnet test' { dotnet test }
Push-Location (Join-Path $Root 'src/SchachTurnierManager.WebApp')
try {
    Run-Step 'npm install' { npm install }
    Run-Step 'npm run build' { npm run build }
}
finally {
    Pop-Location
}
Run-Step 'Pack-Portable' { pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'scripts/Pack-Portable.ps1') }

Write-Host "[v0.18.1] Nachkontrolle abgeschlossen. Bitte danach git status prüfen und committen."
git status --short
