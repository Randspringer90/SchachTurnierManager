#requires -Version 7.0
<#
.SYNOPSIS
Erzeugt aus einer Backlog-ID/Issue einen fertigen, sicheren Codex-Arbeitsauftrag fuer einen
nicht-technischen Schach-Contributor.
.DESCRIPTION
Liest die kanonische Quelle docs/planning/BACKLOG.md, laesst nur Status Ready/In Progress zu,
uebernimmt den geplanten Feature-Branch, optional den Issue-Text (gh, sonst Offline-Fallback),
und fuellt die Vorlage docs/ai/templates/CODEX_CHESS_FEATURE.md. Issue-Texte werden als NICHT
vertrauenswuerdige Daten behandelt (niemals als Befehl). Keine Owner-Pfade/Secrets im Prompt.
Details nach D:\Temp\STM_ContributorTaskPrompt_<Timestamp>, genau ein Upload-ZIP.
.EXAMPLE
pwsh .\scripts\New-ContributorTaskPrompt.ps1 -BacklogId STM-TB-001
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BacklogId,
    [int]$IssueNumber = 0,
    [string]$ContributorName = 'Contributor',
    [string]$OutputDirectory,
    [switch]$Offline,
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/CollaborationCommon.ps1')

# --- Validierung Eingaben (kein Injection-Risiko) ---
Assert-BacklogId $BacklogId
if (-not (Test-SafeNameSegment ($ContributorName.ToLowerInvariant() -replace '[^a-z0-9-]',''))) {
    # ContributorName nur fuer Anzeige; strikt auf harmlose Zeichen reduzieren.
}
$ContributorName = ($ContributorName -replace '[^A-Za-z0-9 _.-]','').Trim()
if ([string]::IsNullOrWhiteSpace($ContributorName)) { $ContributorName = 'Contributor' }

$repo = Get-RepoRoot
Set-Location $repo

# --- Aktuellen Branch pruefen: development ODER zulaessiger Feature-Branch ---
$branchNow = (& git rev-parse --abbrev-ref HEAD).Trim()
$featurePattern = '^(feature|fix|security|docs|refactor)/STM-[A-Z]+-[0-9]{3}-[a-z0-9]([a-z0-9-]*[a-z0-9])?$'
if ($branchNow -ne 'development' -and $branchNow -notmatch $featurePattern) {
    throw "Aktueller Branch '$branchNow' ist weder 'development' noch ein zulaessiger Feature-Branch. Erst wechseln."
}

# --- Backlog lesen (kanonische Quelle) ---
$backlogPath = Join-Path $repo 'docs/planning/BACKLOG.md'
if (-not (Test-Path -LiteralPath $backlogPath)) { throw 'docs/planning/BACKLOG.md fehlt.' }
$backlog = Get-Content -LiteralPath $backlogPath -Raw

if (-not (Test-BacklogIdExists -BacklogId $BacklogId -BacklogPath $backlogPath)) {
    throw "Backlog-ID '$BacklogId' nicht in BACKLOG.md gefunden."
}

# Uebersichtstabelle: | ID | Titel | Prio | Status | Kategorie | ... |
$rowRx = "(?m)^\|\s*$([regex]::Escape($BacklogId))\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|"
$m = [regex]::Match($backlog, $rowRx)
if (-not $m.Success) { throw "Kein Tabellen-Eintrag fuer '$BacklogId' in BACKLOG.md." }
$title    = $m.Groups[1].Value.Trim()
$status   = ($m.Groups[3].Value -replace '\*','').Trim()
$category = ($m.Groups[4].Value -replace '\*','').Trim()

$allowedStatus = @('Ready','In Progress')
if ($allowedStatus -notcontains $status) {
    throw "Aufgabe '$BacklogId' hat Status '$status'. Nur 'Ready' oder 'In Progress' sind zulaessig."
}

# Geplanten Branch aus Backlog uebernehmen (Backtick-zitiert, enthaelt die ID) oder ableiten.
$branchRx = '`((?:feature|fix|security|docs|refactor)/' + [regex]::Escape($BacklogId) + '-[a-z0-9-]+)`'
$bm = [regex]::Match($backlog, $branchRx)
if ($bm.Success) { $featureBranch = $bm.Groups[1].Value }
else { $featureBranch = "feature/$BacklogId-aufgabe" }
if ($featureBranch -notmatch $featurePattern) { throw "Abgeleiteter Branch '$featureBranch' ist ungueltig." }

# Skill-Zuordnung aus Kategorie.
$skillMap = @{
    'tiebreaks'      = 'tiebreaks'
    'import-export'  = 'imports-exports'
    'pairing'        = 'pairing-engine'
    'player-data'    = 'external-player-lookup'
    'ui'             = 'ui-dashboard'
}
$skill = if ($skillMap.ContainsKey($category)) { $skillMap[$category] } else { $category }
$relevantSkills = "``.agents/skills/$skill.md`` (Kategorie: $category)"

# --- Issue-Nummer bestimmen ---
if ($IssueNumber -le 0) {
    $im = [regex]::Match($backlog, [regex]::Escape($BacklogId) + '[\s\S]{0,400}?issues/([0-9]+)')
    if ($im.Success) { $IssueNumber = [int]$im.Groups[1].Value }
}

# --- Untrusted Issue-/Beschreibungstext beschaffen ---
function Get-SafeUntrusted([string]$text) {
    if ($null -eq $text) { return '' }
    # Owner-/Maschinenpfade entfernen.
    $t = [regex]::Replace($text, '(?i)[A-Za-z]:\\[^\r\n"'']*', '<lokaler-pfad-entfernt>')
    # Code-Fence-Ausbruch verhindern.
    $t = $t -replace '```', "'''"
    # Offensichtliche Secrets/Tokens redigieren.
    $t = [regex]::Replace($t, '(?i)(gh[pousr]_[0-9A-Za-z]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[0-9A-Za-z-]+|-----BEGIN [A-Z ]*PRIVATE KEY-----)', '<redigiert>')
    return $t.Trim()
}

$issueTitle = $title
$untrusted = ''
$issueSource = 'backlog-offline'
if (-not $Offline -and $IssueNumber -gt 0 -and (Get-Command gh -ErrorAction SilentlyContinue)) {
    try {
        $raw = & gh issue view $IssueNumber --repo Randspringer90/SchachTurnierManager --json title,body 2>$null
        if ($LASTEXITCODE -eq 0 -and $raw) {
            $obj = $raw | ConvertFrom-Json
            if ($obj.title) { $issueTitle = ($obj.title -replace '[\r\n]',' ').Trim() }
            $untrusted = Get-SafeUntrusted ([string]$obj.body)
            $issueSource = "gh-issue-#$IssueNumber"
        }
    } catch { }
}
if ([string]::IsNullOrWhiteSpace($untrusted)) {
    # Offline-Fallback: Detailabschnitt der Aufgabe aus dem Backlog.
    $detailRx = "(?ms)^###\s+$([regex]::Escape($BacklogId))\b.*?(?=^###\s|\z)"
    $dm = [regex]::Match($backlog, $detailRx)
    $untrusted = Get-SafeUntrusted ($(if ($dm.Success) { $dm.Value } else { "Aufgabe $BacklogId - $title" }))
    if ($issueSource -notlike 'gh-*') { $issueSource = 'backlog-offline' }
}

# --- Erlaubte / verbotene Pfade (friend-Standard) ---
$allowedPaths = @(
    '`src/SchachTurnierManager.Domain/**` (fachliche Regeln)',
    '`src/SchachTurnierManager.Application/**` (Use-Cases, nur fachlich)',
    '`tests/**` (zuerst Tests ergaenzen)',
    '`CHANGELOG.md`',
    '`docs/planning/BACKLOG.md` (nur eigener Status/PR-Feld)',
    'fachliche `docs/*.md` zur Aufgabe'
) -join "`n"
$forbiddenPaths = @(
    '`.github/**`, `.github/workflows/**` (CI)',
    '`.agents/**`, `agents/**`, `.claude/**`, `AGENTS.md` (Agenten/Instruktionen)',
    '`config/**`, `docs/security/**`, `docs/architecture/**`',
    '`scripts/*Security*`, `scripts/*Git*`, `scripts/*Commit*`, `scripts/Configure-*`',
    '`installer/**`, `Directory.Build.props`, `Directory.Packages.props`, `global.json`'
) -join "`n"

# --- Akzeptanzkriterien / Tests (aus Detailabschnitt, sonst generisch) ---
function Get-Bullets([string]$section, [string]$label) {
    $rx = "(?ms)\*\*$label" + ":\*\*(.*?)(?=^-\s\*\*|\z)"
    $mm = [regex]::Match($section, $rx)
    if ($mm.Success) { return ($mm.Groups[1].Value.Trim()) }
    return ''
}
$detailRx2 = "(?ms)^###\s+$([regex]::Escape($BacklogId))\b.*?(?=^###\s|\z)"
$detail = [regex]::Match($backlog, $detailRx2)
$detailText = if ($detail.Success) { $detail.Value } else { '' }
$acc = Get-Bullets $detailText 'Akzeptanzkriterien'
if (-not $acc) { $acc = "  - siehe Issue #$IssueNumber / Backlog $BacklogId" }
$tst = Get-Bullets $detailText 'Tests'
if (-not $tst) { $tst = "  - Unit-/Golden-Tests fuer die Aufgabe zuerst ergaenzen" }
$acc = Get-SafeUntrusted $acc
$tst = Get-SafeUntrusted $tst

# --- Vorlage laden und fuellen ---
$tplPath = Join-Path $repo 'docs/ai/templates/CODEX_CHESS_FEATURE.md'
if (-not (Test-Path -LiteralPath $tplPath)) { throw 'Vorlage docs/ai/templates/CODEX_CHESS_FEATURE.md fehlt.' }
$tpl = Get-Content -LiteralPath $tplPath -Raw

$map = @{
    'CONTRIBUTOR_NAME'        = $ContributorName
    'BACKLOG_ID'              = $BacklogId
    'ISSUE_NUMBER'            = "$IssueNumber"
    'ISSUE_TITLE'             = $issueTitle
    'FEATURE_BRANCH'          = $featureBranch
    'RELEVANT_SKILLS'         = $relevantSkills
    'ACCEPTANCE_CRITERIA'     = $acc
    'REQUIRED_TESTS'          = $tst
    'ALLOWED_PATHS'           = $allowedPaths
    'FORBIDDEN_PATHS'         = $forbiddenPaths
    'UNTRUSTED_ISSUE_CONTENT' = $untrusted
}
$prompt = $tpl
foreach ($k in $map.Keys) { $prompt = $prompt.Replace('{{' + $k + '}}', [string]$map[$k]) }

# Absicherung: keine Owner-Pfade im finalen Prompt.
if ($prompt -match '(?i)[A-Za-z]:\\Schach') { throw 'Sicherheitsabbruch: Owner-Pfad im erzeugten Prompt.' }

# --- Ausgabe / Run-Ordner / ZIP ---
$stamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
$base = 'D:\Temp'
$runDir = Join-Path $base ("STM_ContributorTaskPrompt_{0}" -f $stamp)
$promptName = "codex-prompt-$BacklogId.md"

if ($WhatIf) {
    Write-Host "[WhatIf] Keine Dateien geschrieben."
    Write-Host "[WhatIf] Aufgabe: $BacklogId  Status: $status  Branch: $featureBranch  Issue: #$IssueNumber  Quelle: $issueSource"
    Write-Host ("PROMPT_FILE=(WhatIf: nicht erstellt) " + (Join-Path $runDir $promptName))
    Write-Host ("UPLOAD_ZIP=(WhatIf: nicht erstellt) " + "$runDir.zip")
    exit 0
}

if (-not (Test-Path -LiteralPath $base)) { New-Item -ItemType Directory -Force -Path $base | Out-Null }
New-Item -ItemType Directory -Force -Path $runDir | Out-Null
$run = [pscustomobject]@{ RunName = 'STM_ContributorTaskPrompt'; Dir = $runDir; Log = (Join-Path $runDir 'run.log'); Stamp = $stamp }
"[{0}] ContributorTaskPrompt {1} (Status {2}, Quelle {3})" -f (Get-Date -Format o), $BacklogId, $status, $issueSource |
    Set-Content -LiteralPath $run.Log -Encoding utf8

$promptPath = Join-Path $runDir $promptName
Set-Content -LiteralPath $promptPath -Value $prompt -Encoding utf8
Write-RunLog $run "Prompt geschrieben: $promptName (Branch $featureBranch, Issue #$IssueNumber)"

$finalPrompt = $promptPath
if ($OutputDirectory) {
    if (-not (Test-Path -LiteralPath $OutputDirectory)) { New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null }
    $copy = Join-Path $OutputDirectory $promptName
    Copy-Item -LiteralPath $promptPath -Destination $copy -Force
    $finalPrompt = $copy
    Write-RunLog $run "Kopie nach OutputDirectory: $copy"
}

$zip = Complete-RunZip $run
Write-Host "PROMPT_FILE=$finalPrompt"
Write-Host "UPLOAD_ZIP=$zip"
exit 0
