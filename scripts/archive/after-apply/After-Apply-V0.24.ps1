$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-Step([string]$Message) { Write-Host "[v0.24.0] $Message" }

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
    $updated = $text -replace '0\.23\.0', '0.24.0'
    $updated = $updated -replace 'v0\.23\.0', 'v0.24.0'
    if ($updated -ne $text) {
        Write-Text $Path $updated
        Write-Step "$Path auf 0.24.0 gesetzt"
    } else {
        Write-Step "$Path enthielt keine 0.23.0-Version mehr"
    }
}

function Insert-Before([string]$Path, [string]$Anchor, [string]$Insert, [string]$Sentinel, [string]$Description) {
    $text = Read-Text $Path
    if ($text.Contains($Sentinel)) {
        Write-Step "$Description bereits vorhanden"
        return
    }
    if (-not $text.Contains($Anchor)) { throw "Anker nicht gefunden in ${Path}: ${Description}" }
    $updated = $text.Replace($Anchor, $Insert.TrimEnd() + "`n`n" + $Anchor)
    Write-Text $Path $updated
    Write-Step $Description
}

function Insert-After([string]$Path, [string]$Anchor, [string]$Insert, [string]$Sentinel, [string]$Description) {
    $text = Read-Text $Path
    if ($text.Contains($Sentinel)) {
        Write-Step "$Description bereits vorhanden"
        return
    }
    if (-not $text.Contains($Anchor)) { throw "Anker nicht gefunden in ${Path}: ${Description}" }
    $updated = $text.Replace($Anchor, $Anchor + "`n`n" + $Insert.TrimEnd())
    Write-Text $Path $updated
    Write-Step $Description
}

function Replace-Once([string]$Path, [string]$Old, [string]$New, [string]$Sentinel, [string]$Description) {
    $text = Read-Text $Path
    if ($text.Contains($Sentinel)) {
        Write-Step "$Description bereits vorhanden"
        return
    }
    if (-not $text.Contains($Old)) { throw "Anker nicht gefunden in ${Path}: ${Description}" }
    $updated = $text.Replace($Old, $New.TrimEnd())
    Write-Text $Path $updated
    Write-Step $Description
}

function Append-IfMissing([string]$Path, [string]$Content, [string]$Sentinel, [string]$Description) {
    $text = Read-Text $Path
    if ($text.Contains($Sentinel)) {
        Write-Step "$Description bereits vorhanden"
        return
    }
    Write-Text $Path ($text.TrimEnd() + "`n`n" + $Content.TrimEnd() + "`n")
    Write-Step $Description
}

function Run-Step([string]$Name, [scriptblock]$Action) {
    Write-Step "$Name..."
    & $Action
    if ($LASTEXITCODE -ne 0) { throw "$Name ist fehlgeschlagen mit Exitcode $LASTEXITCODE." }
}

Replace-Version 'src/SchachTurnierManager.WebApi/Program.cs'
Replace-Version 'src/SchachTurnierManager.WebApp/package.json'
Replace-Version 'src/SchachTurnierManager.WebApp/package-lock.json'
Replace-Version 'src/SchachTurnierManager.WebApp/src/main.tsx'

$programPath = 'src/SchachTurnierManager.WebApi/Program.cs'
$previewExportEndpoints = @'
app.MapGet("/api/tournaments/{id:guid}/pairings/preview-next-round/export.csv", (Guid id, TournamentService service) =>
{
    try
    {
        return ToDownload(service.ExportNextRoundPreviewCsv(id));
    }
    catch (Exception ex) when (ex is InvalidOperationException or NotSupportedException)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
});

app.MapGet("/api/tournaments/{id:guid}/pairings/preview-next-round/print/html", (Guid id, TournamentService service) =>
{
    try
    {
        return ToDownload(service.ExportPrintableNextRoundPreviewHtml(id));
    }
    catch (Exception ex) when (ex is InvalidOperationException or NotSupportedException)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
});
'@
Insert-Before $programPath 'app.MapPost("/api/tournaments/{id:guid}/pairings/next-round", (Guid id, TournamentService service) =>' $previewExportEndpoints 'preview-next-round/export.csv' 'API-Endpunkte für Vorschau-CSV und Vorschau-Druckansicht ergänzt'

$servicePath = 'src/SchachTurnierManager.Application/TournamentService.cs'
$serviceExportMethods = @'
    public ExportDocument ExportNextRoundPreviewCsv(Guid tournamentId)
    {
        var tournament = RequireTournament(tournamentId);
        var preview = PreviewNextRound(tournamentId);
        return _exports.ExportNextRoundPreviewCsv(tournament, preview);
    }

    public ExportDocument ExportPrintableNextRoundPreviewHtml(Guid tournamentId)
    {
        var tournament = RequireTournament(tournamentId);
        var preview = PreviewNextRound(tournamentId);
        return _exports.ExportPrintableNextRoundPreviewHtml(tournament, preview);
    }
'@
Insert-Before $servicePath '    public TournamentRound GenerateNextRound(Guid tournamentId)' $serviceExportMethods 'ExportNextRoundPreviewCsv' 'Application-Exports für Auslosungsvorschau ergänzt'

$formatterPath = 'src/SchachTurnierManager.Domain/Services/TournamentExportFormatter.cs'
$formatterMethods = @'
    public ExportDocument ExportNextRoundPreviewCsv(TournamentState tournament, NextRoundPreview preview)
    {
        var builder = new StringBuilder();
        builder.AppendLine("Runde;Brett;Weiß;Schwarz;Weiß Punkte vorher;Schwarz Punkte vorher;Score-Differenz;Bye;Rematch;Scoregruppen-Abweichung;Farbfolge-Risiko;Hinweise");
        foreach (var board in preview.PairingQuality.Boards.OrderBy(b => b.BoardNumber))
        {
            var hasColorRisk = board.WouldGiveWhiteThirdSameColor || board.WouldGiveBlackThirdSameColor;
            var values = new[]
            {
                preview.RoundNumber.ToString(CultureInfo.InvariantCulture),
                board.BoardNumber.ToString(CultureInfo.InvariantCulture),
                board.WhiteName,
                board.IsBye ? "spielfrei" : board.BlackName,
                FormatDecimal(board.WhiteScoreBeforeRound),
                board.IsBye ? string.Empty : FormatDecimal(board.BlackScoreBeforeRound),
                board.IsBye ? string.Empty : FormatDecimal(board.ScoreDifference),
                board.IsBye ? "ja" : "nein",
                board.IsRematch ? "ja" : "nein",
                board.IsCrossScoreGroupPairing ? "ja" : "nein",
                hasColorRisk ? "ja" : "nein",
                string.Join(" | ", board.Findings)
            };
            builder.AppendLine(string.Join(';', values.Select(EscapeCsv)));
        }

        return CsvDocument($"{SafeFileName(tournament.Name)}_Vorschau_Runde_{preview.RoundNumber:D2}.csv", builder.ToString());
    }

    public ExportDocument ExportPrintableNextRoundPreviewHtml(TournamentState tournament, NextRoundPreview preview)
    {
        var builder = new StringBuilder();
        AppendHtmlStart(builder, tournament.Name, $"Auslosungsvorschau Runde {preview.RoundNumber}");
        builder.AppendLine($"<h1>{Html(tournament.Name)} · Auslosungsvorschau Runde {preview.RoundNumber}</h1>");
        builder.AppendLine("<p class=\"muted\">Diese Vorschau wurde nicht gespeichert. Erst die echte Auslosung übernimmt die Paarungen ins Turnier.</p>");
        AppendPreviewSummary(builder, preview);
        AppendPreviewPairings(builder, preview);
        AppendPreviewAudit(builder, preview);
        AppendHtmlEnd(builder);
        return HtmlDocument($"{SafeFileName(tournament.Name)}_Vorschau_Runde_{preview.RoundNumber:D2}.html", builder.ToString());
    }

    private static void AppendPreviewSummary(StringBuilder builder, NextRoundPreview preview)
    {
        builder.AppendLine("<section><h2>Qualität</h2>");
        builder.AppendLine("<dl>");
        builder.AppendLine($"<dt>Zusammenfassung</dt><dd>{Html(preview.Summary)}</dd>");
        builder.AppendLine($"<dt>Speicherbar</dt><dd>{(preview.IsSavable ? "ja" : "nein")}</dd>");
        builder.AppendLine($"<dt>Qualitätswert</dt><dd>{preview.PairingQuality.QualityScore}/100 · {Html(preview.PairingQuality.Severity.ToString())}</dd>");
        builder.AppendLine($"<dt>Bretter</dt><dd>{preview.BoardCount}</dd>");
        builder.AppendLine($"<dt>Rematches</dt><dd>{preview.PairingQuality.RematchCount}</dd>");
        builder.AppendLine($"<dt>Scoregruppen-Abweichungen</dt><dd>{preview.PairingQuality.CrossScoreGroupPairingCount}</dd>");
        builder.AppendLine($"<dt>Farbfolge-Risiken</dt><dd>{preview.PairingQuality.ThirdSameColorRiskCount}</dd>");
        builder.AppendLine($"<dt>Byes</dt><dd>{preview.PairingQuality.ByeCount}</dd>");
        builder.AppendLine("</dl>");
        if (preview.Messages.Count > 0 || preview.PairingQuality.Findings.Count > 0)
        {
            builder.AppendLine("<div class=\"diagnostics\"><strong>Hinweise:</strong><ul>");
            foreach (var message in preview.Messages.Concat(preview.PairingQuality.Findings).Distinct())
            {
                builder.AppendLine($"<li>{Html(message)}</li>");
            }
            builder.AppendLine("</ul></div>");
        }
        builder.AppendLine("</section>");
    }

    private static void AppendPreviewPairings(StringBuilder builder, NextRoundPreview preview)
    {
        builder.AppendLine("<section><h2>Paarungen</h2><table><thead><tr><th>Brett</th><th>Weiß</th><th>Schwarz</th><th>Score vor Runde</th><th>Hinweise</th></tr></thead><tbody>");
        foreach (var board in preview.PairingQuality.Boards.OrderBy(b => b.BoardNumber))
        {
            var score = board.IsBye ? "Bye" : $"{FormatDecimal(board.WhiteScoreBeforeRound)} : {FormatDecimal(board.BlackScoreBeforeRound)}";
            var notes = board.Findings.Count == 0 ? "ok" : string.Join(" | ", board.Findings);
            builder.Append("<tr>");
            builder.Append($"<td>{board.BoardNumber}</td>");
            builder.Append($"<td>{Html(board.WhiteName)}</td>");
            builder.Append($"<td>{Html(board.IsBye ? "spielfrei" : board.BlackName)}</td>");
            builder.Append($"<td>{Html(score)}</td>");
            builder.Append($"<td>{Html(notes)}</td>");
            builder.AppendLine("</tr>");
        }
        builder.AppendLine("</tbody></table></section>");
    }

    private static void AppendPreviewAudit(StringBuilder builder, NextRoundPreview preview)
    {
        builder.AppendLine("<section><h2>Audit</h2>");
        builder.AppendLine($"<p class=\"muted\">Algorithmus: {Html(preview.Round.Audit.Algorithm)} · Ruleset: {Html(preview.Round.Audit.RulesetVersion)}</p>");
        AppendAuditList(builder, "Hinweise", preview.Round.Audit.Messages);
        AppendAuditList(builder, "Scoregruppen", preview.Round.Audit.ScoreGroups);
        AppendAuditList(builder, "Floater", preview.Round.Audit.Floaters);
        AppendAuditList(builder, "Farben", preview.Round.Audit.ColorNotes);
        builder.AppendLine("</section>");
    }

    private static void AppendAuditList(StringBuilder builder, string title, IReadOnlyList<string> items)
    {
        builder.AppendLine($"<h3>{Html(title)}</h3><ul>");
        if (items.Count == 0)
        {
            builder.AppendLine("<li>keine</li>");
        }
        else
        {
            foreach (var item in items)
            {
                builder.AppendLine($"<li>{Html(item)}</li>");
            }
        }
        builder.AppendLine("</ul>");
    }
'@
Insert-Before $formatterPath '    private static void AppendTournamentMeta(StringBuilder builder, TournamentState tournament)' $formatterMethods 'ExportNextRoundPreviewCsv' 'Domain-Formatter für Vorschau-CSV und Vorschau-Druckansicht ergänzt'

$testPath = 'tests/SchachTurnierManager.Domain.Tests/TournamentExportFormatterTests.cs'
$tests = @'
    [Fact]
    public void ExportNextRoundPreviewCsv_ContainsQualityFields()
    {
        var tournament = CreateTournament();
        var preview = CreatePreview(tournament);
        var document = new TournamentExportFormatter().ExportNextRoundPreviewCsv(tournament, preview);

        Assert.EndsWith("_Vorschau_Runde_02.csv", document.FileName);
        Assert.Contains("Runde;Brett;Weiß;Schwarz;Weiß Punkte vorher;Schwarz Punkte vorher;Score-Differenz", document.Content);
        Assert.Contains("Alpha", document.Content);
        Assert.Contains("Beta", document.Content);
        Assert.Contains("Scoregruppen-Test", document.Content);
    }

    [Fact]
    public void ExportPrintableNextRoundPreviewHtml_ContainsAuditAndEscapesContent()
    {
        var tournament = CreateTournament();
        tournament.Name = "Vorschau <Finale>";
        var preview = CreatePreview(tournament);
        var document = new TournamentExportFormatter().ExportPrintableNextRoundPreviewHtml(tournament, preview);

        Assert.Equal("text/html; charset=utf-8", document.ContentType);
        Assert.Contains("Vorschau &lt;Finale&gt;", document.Content);
        Assert.Contains("Auslosungsvorschau Runde 2", document.Content);
        Assert.Contains("Scoregruppen-Test", document.Content);
        Assert.Contains("Algorithmus", document.Content);
    }

    private static NextRoundPreview CreatePreview(TournamentState tournament)
    {
        var alpha = tournament.Players[0];
        var beta = tournament.Players[1];
        var round = new TournamentRound
        {
            RoundNumber = 2,
            Pairings = new[]
            {
                Pairing.Game(1, beta.Id, alpha.Id)
            },
            Audit = new PairingAudit
            {
                Algorithm = "Test",
                RulesetVersion = "Test-1",
                Messages = new[] { "Audit-Test" },
                ScoreGroups = new[] { "Scoregruppen-Test" },
                Floaters = Array.Empty<string>(),
                ColorNotes = new[] { "Farb-Test" }
            }
        };

        return new NextRoundPreview
        {
            RoundNumber = 2,
            BoardCount = 1,
            IsSavable = true,
            Summary = "Testvorschau",
            Round = round,
            PairingQuality = new PairingQualityReport
            {
                RoundNumber = 2,
                BoardCount = 1,
                GameCount = 1,
                QualityScore = 88,
                Severity = PairingQualitySeverity.Notice,
                Findings = new[] { "Scoregruppen-Test" },
                Boards = new[]
                {
                    new PairingQualityBoard
                    {
                        BoardNumber = 1,
                        WhitePlayerId = beta.Id,
                        BlackPlayerId = alpha.Id,
                        WhiteName = beta.Name,
                        BlackName = alpha.Name,
                        WhiteScoreBeforeRound = 0,
                        BlackScoreBeforeRound = 1,
                        ScoreDifference = 1,
                        IsCrossScoreGroupPairing = true,
                        Findings = new[] { "Scoregruppen-Test" }
                    }
                }
            },
            Messages = new[] { "Audit-Test" }
        };
    }
'@
Insert-Before $testPath '    private static TournamentState CreateTournament()' $tests 'ExportNextRoundPreviewCsv_ContainsQualityFields' 'Tests für Vorschau-Exports ergänzt'

$mainPath = 'src/SchachTurnierManager.WebApp/src/main.tsx'
$previewFunctions = @'
  function openNextRoundPreviewCsv() {
    if (!selectedTournament) {
      return;
    }
    window.open(`/api/tournaments/${selectedTournament.id}/pairings/preview-next-round/export.csv`, '_blank', 'noopener,noreferrer');
  }

  function openNextRoundPreviewPrint() {
    if (!selectedTournament) {
      return;
    }
    window.open(`/api/tournaments/${selectedTournament.id}/pairings/preview-next-round/print/html`, '_blank', 'noopener,noreferrer');
  }
'@
Insert-Before $mainPath '  function openTournamentExport(path: string) {' $previewFunctions 'openNextRoundPreviewCsv' 'Frontend-Funktionen für Vorschau-CSV und Druckansicht ergänzt'

$oldWarningsAnchor = @'
              <div className="preview-metrics">
                <span>{nextRoundPreview.boardCount} Bretter</span>
                <span>{nextRoundPreview.pairingQuality.rematchCount} Rematches</span>
                <span>{nextRoundPreview.pairingQuality.crossScoreGroupPairingCount} Scoregruppen-Abweichungen</span>
                <span>{nextRoundPreview.pairingQuality.thirdSameColorRiskCount} Farbfolge-Risiken</span>
                <span>{nextRoundPreview.pairingQuality.byeCount} Bye</span>
              </div>
'@
$warningsReplacement = @'
              <div className="preview-metrics">
                <span>{nextRoundPreview.boardCount} Bretter</span>
                <span>{nextRoundPreview.pairingQuality.rematchCount} Rematches</span>
                <span>{nextRoundPreview.pairingQuality.crossScoreGroupPairingCount} Scoregruppen-Abweichungen</span>
                <span>{nextRoundPreview.pairingQuality.thirdSameColorRiskCount} Farbfolge-Risiken</span>
                <span>{nextRoundPreview.pairingQuality.byeCount} Bye</span>
              </div>
              {nextRoundPreview.pairingQuality.hasCriticalIssues && <div className="preview-warning critical"><strong>Kritische Vorschau:</strong> Bitte Paarungen, Rematches und Farbfolge prüfen, bevor die Runde wirklich ausgelost wird.</div>}
              {!nextRoundPreview.isSavable && <div className="preview-warning critical"><strong>Nicht speicherbar:</strong> Diese Vorschau darf nicht übernommen werden. Bitte Hinweise prüfen.</div>}
'@
Replace-Once $mainPath $oldWarningsAnchor $warningsReplacement 'Kritische Vorschau:' 'Warnboxen in der Vorschaukarte ergänzt'

$oldActions = @'
              <div className="actions preview-actions">
                <button type="button" onClick={() => void generateRound()} disabled={!nextRoundPreview.isSavable}>Diese Runde jetzt auslosen</button>
                <button type="button" className="secondary" onClick={() => setNextRoundPreview(null)}>Vorschau schließen</button>
              </div>
'@
$newActions = @'
              <div className="actions preview-actions">
                <button type="button" onClick={() => void generateRound()} disabled={!nextRoundPreview.isSavable}>Diese Runde jetzt auslosen</button>
                <button type="button" className="secondary" onClick={openNextRoundPreviewPrint}>Druckansicht öffnen</button>
                <button type="button" className="secondary" onClick={openNextRoundPreviewCsv}>CSV exportieren</button>
                <button type="button" className="secondary" onClick={() => setNextRoundPreview(null)}>Vorschau schließen</button>
              </div>
'@
Replace-Once $mainPath $oldActions $newActions 'Druckansicht öffnen' 'Preview-Aktionsbuttons um Druck/CSV ergänzt'

$previewCss = @'
.preview-warning {
  padding: 0.75rem 0.85rem;
  border-radius: 0.75rem;
  border: 1px solid rgba(245, 158, 11, 0.55);
  background: rgba(146, 64, 14, 0.18);
  color: #fde68a;
}

.preview-warning.critical {
  border-color: rgba(248, 113, 113, 0.72);
  background: rgba(127, 29, 29, 0.24);
  color: #fecaca;
}

.preview-actions {
  flex-wrap: wrap;
}
'@
Append-IfMissing 'src/SchachTurnierManager.WebApp/src/styles.css' $previewCss '.preview-warning' 'CSS für Vorschau-Warnungen ergänzt'

$changelogPath = 'CHANGELOG.md'
$changelog = Read-Text $changelogPath
if (-not $changelog.Contains('## 0.24.0')) {
    $entry = @'
## 0.24.0

- Auslosungsvorschau kann jetzt als CSV exportiert werden.
- Auslosungsvorschau kann jetzt als HTML-Druckansicht geöffnet werden.
- Vorschaukarte im Dashboard zeigt kritische Warnungen deutlicher.
- API-Endpunkte für temporäre Vorschau-Exports ergänzt, ohne die Runde zu speichern.

'@
    Write-Text $changelogPath ($entry + $changelog.TrimStart())
    Write-Step 'CHANGELOG.md ergänzt'
} else {
    Write-Step 'CHANGELOG.md enthält v0.24.0 bereits'
}

$handoffPath = 'docs/HANDOFF_0_24_0.md'
$handoff = @'
# Handoff 0.24.0 – Auslosungsvorschau drucken und exportieren

## Ziel

v0.24.0 erweitert die in v0.23.0 sichtbare Auslosungsvorschau um turnierpraktische Ausgabewege:

- CSV-Export der nächsten Auslosungsvorschau
- HTML-Druckansicht der nächsten Auslosungsvorschau
- zusätzliche Dashboard-Aktionen in der Vorschaukarte
- deutliche Warnbox bei kritischer Paarungsqualität oder nicht speicherbarer Vorschau

## Fachlicher Nutzen

Turnierleiter können vor dem echten Auslosen eine Vorschau für Aushang, Kontrolle oder Abstimmung öffnen/exportieren, ohne die Runde zu speichern. Das passt zum Ziel: erst prüfen, dann bewusst auslosen.

## Neue API-Endpunkte

- `GET /api/tournaments/{id}/pairings/preview-next-round/export.csv`
- `GET /api/tournaments/{id}/pairings/preview-next-round/print/html`

Beide Endpunkte erzeugen die Vorschau nur temporär. Es wird keine Runde gespeichert.

## Nachkontrolle

- `dotnet restore`
- `dotnet build`
- `dotnet test`
- `npm install`
- `npm run build`
- `scripts\Pack-Portable.ps1`
- `git status --short`
'@
Write-Text $handoffPath $handoff
Write-Step 'Handoff ergänzt'

foreach ($path in @(
    'src/SchachTurnierManager.WebApi/Program.cs',
    'src/SchachTurnierManager.Application/TournamentService.cs',
    'src/SchachTurnierManager.Domain/Services/TournamentExportFormatter.cs',
    'tests/SchachTurnierManager.Domain.Tests/TournamentExportFormatterTests.cs',
    'src/SchachTurnierManager.WebApp/package.json',
    'src/SchachTurnierManager.WebApp/package-lock.json',
    'src/SchachTurnierManager.WebApp/src/main.tsx',
    'src/SchachTurnierManager.WebApp/src/styles.css',
    'CHANGELOG.md',
    'docs/HANDOFF_0_24_0.md',
    'scripts/After-Apply-V0.24.ps1'
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
