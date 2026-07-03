param(
    [switch]$Staged,
    [switch]$AllHistory,
    [string]$ReportDir = '.local-audits'
)
$ErrorActionPreference = 'Stop'
$repoRoot = (git rev-parse --show-toplevel).Trim()
Set-Location $repoRoot

function Stop-GitSafety([string]$Message) { Write-Error "[GitSafety] $Message"; exit 1 }
function Info([string]$Message) { Write-Host "[GitSafety] $Message" }

$blockedPathRegex = '(?i)(^|/)(security-audit|\.local-audits|\.local-backups|output|bin|obj|dist|node_modules)(/|$)|\.(zip|7z|rar|exe|dll|pdb|nupkg|db|sqlite|sqlite3|log|dmp|dump|key|pem|pfx|p12)$|(^|/)\.env$|(^|/)\.env\.(?!example$)|backup_before_|before-v[0-9].*\.json$|package-lock\.json\.backup'
$internalPattern = @(('tfs' + '\.fwdev'), ('eckd' + 'service'), ('_' + 'packaging'), ('ITM' + '_KFM')) -join '|'
$contentPattern = @(
    ('github' + '_pat_'),
    'ghp_',
    'glpat-',
    'sk-[A-Za-z0-9]{20,}',
    ('BEGIN ' + '[A-Z ]*' + 'PRIVATE ' + 'KEY'),
    (('pass' + 'word') + '\s*[:=]\s*[''\"][^''\"]{4,}'),
    (('api' + '[_-]?key') + '\s*[:=]\s*[''\"][^''\"]{8,}'),
    (('client' + '[_-]?' + 'secret') + '\s*[:=]\s*[''\"][^''\"]{8,}'),
    (('access' + '[_-]?' + 'token') + '\s*[:=]\s*[''\"][^''\"]{8,}'),
    (('refresh' + '[_-]?' + 'token') + '\s*[:=]\s*[''\"][^''\"]{8,}')
) -join '|'

function Get-StatusPaths {
    $lines = git status --porcelain=v1 --untracked-files=all
    foreach ($line in $lines) {
        if ($line.Length -lt 4) { continue }
        [pscustomobject]@{ Status = $line.Substring(0,2); Path = $line.Substring(3) }
    }
}

function Test-PathList([object[]]$Items, [switch]$AllowDeletes) {
    foreach ($item in $Items) {
        $status = [string]$item.Status
        $path = [string]$item.Path
        $isDelete = $status.Trim() -eq 'D'
        if ($AllowDeletes -and $isDelete) { continue }
        if ($path -match $blockedPathRegex) { Stop-GitSafety "Verbotener Pfad: $path" }
    }
}

if ($Staged) {
    $entries = git diff --cached --name-status
    Info 'Dateien im Staging:'
    if (-not $entries) { Info '  <leer>'; exit 0 }
    $items = @()
    foreach ($entry in $entries) {
        Info "  $entry"
        $parts = $entry -split "`t"
        $status = $parts[0]
        foreach ($path in $parts[1..($parts.Length-1)]) { $items += [pscustomobject]@{ Status = $status; Path = $path } }
    }
    Test-PathList $items -AllowDeletes

    $diffLines = git diff --cached --unified=0 -- . ':(exclude).local-audits/**' ':(exclude)security-audit/**' ':(exclude).local-backups/**'
    $addedText = ($diffLines | Where-Object { $_ -like '+*' -and $_ -notlike '+++ *' }) -join "`n"
    if ($addedText -match $internalPattern) { Stop-GitSafety 'Interne URL/Registry-Referenz in neu hinzugefuegten staged Zeilen gefunden.' }
    if ($addedText -match $contentPattern) { Stop-GitSafety 'Kritisches Zugangsdaten-Muster in neu hinzugefuegten staged Zeilen gefunden.' }
    Info 'OK: Staging ist frei von verbotenen Pfaden, internen Referenzen und kritischen Zugangsdaten-Mustern.'
    exit 0
}

$statusItems = @(Get-StatusPaths)
Info 'Geaenderte Dateien:'
if ($statusItems.Count -eq 0) { Info '  <leer>'; exit 0 }
$statusItems | ForEach-Object { Info ("  {0} {1}" -f $_.Status, $_.Path) }
Test-PathList $statusItems -AllowDeletes

$hits = New-Object System.Collections.Generic.List[string]
function Test-ContentPatterns([string]$Label, [string]$Text) {
    if ([string]::IsNullOrEmpty($Text)) { return }
    if ($Text -match $internalPattern) { $hits.Add("internal:$Label") }
    if ($Text -match $contentPattern) { $hits.Add("credential-pattern:$Label") }
}

$diffLines = git diff --unified=0 -- . ':(exclude).local-audits/**' ':(exclude)security-audit/**' ':(exclude).local-backups/**'
$addedText = ($diffLines | Where-Object { $_ -like '+*' -and $_ -notlike '+++ *' }) -join "`n"
Test-ContentPatterns 'working-tree-added-lines' $addedText

foreach ($item in ($statusItems | Where-Object { $_.Status -eq '??' })) {
    $path = [string]$item.Path
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
    $content = Get-Content -Raw -LiteralPath $path -ErrorAction SilentlyContinue
    Test-ContentPatterns $path $content
}

if ($hits.Count -gt 0) { Stop-GitSafety ("Treffer in aktuellen Aenderungen: " + ($hits -join ', ')) }
Info 'OK: Aktuelle Aenderungen sind frei von verbotenen Pfaden, internen Referenzen und kritischen Zugangsdaten-Mustern.'

if ($AllHistory) {
    New-Item -ItemType Directory -Force $ReportDir | Out-Null
    git rev-list --objects --all | Set-Content (Join-Path $ReportDir 'git-objects-all.txt') -Encoding UTF8
    $artifactHits = Select-String -Path (Join-Path $ReportDir 'git-objects-all.txt') -Pattern $blockedPathRegex -ErrorAction SilentlyContinue
    $historyPattern = "($internalPattern)|($contentPattern)"
    $historyPath = Join-Path $ReportDir 'history-sensitive-patches.txt'
    git log --all -p --regexp-ignore-case -G $historyPattern -- . ":(exclude)$ReportDir/**" | Set-Content $historyPath -Encoding UTF8
    if ($artifactHits) { $artifactHits | Set-Content (Join-Path $ReportDir 'history-artifact-paths.txt') -Encoding UTF8 }
    if ($artifactHits -or ((Test-Path $historyPath) -and ((Get-Item $historyPath).Length -gt 0))) {
        Stop-GitSafety "Historie enthaelt potenzielle Altlasten. Details lokal unter $ReportDir. Dieses Repo nicht direkt public schalten; Clean Snapshot verwenden."
    }
    Info 'OK: Historie ohne Treffer in diesem Basisscan.'
}
