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
function Normalize-GitPath([string]$Path) { return (($Path ?? '').Trim().Trim('"') -replace '\\', '/') }

$blockedPathRegex = '(?i)(^|/)(\.codex|\.vs|security-audit|\.local-audits|\.local-backups|output|bin|obj|dist|node_modules|logs|tmp|reports)(/|$)|\.(zip|7z|rar|exe|dll|pdb|nupkg|db|sqlite|sqlite3|log|dmp|dump|key|pem|pfx|p12)$|(^|/)\.env(\.|$)|backup_before_|before-v[0-9].*\.json$|package-lock\.json\.backup'
$internalPattern = @((('tfs') + '\.fwdev'), (('eckd') + 'service'), ('_' + 'packaging'), (('ITM') + '_KFM')) -join '|'
$contentPattern = @(
    (('github') + '_pat_'),
    ('g' + 'hp_'),
    'glpat-',
    'sk-[A-Za-z0-9]{20,}',
    (('BEGIN ') + '[A-Z ]*' + ('PRIVATE ') + 'KEY'),
    (('pass' + 'word') + '\s*[:=]\s*[''\"][^''\"]{4,}'),
    (('api' + '[_-]?key') + '\s*[:=]\s*[''\"][^''\"]{8,}'),
    (('client' + '[_-]?' + 'secret') + '\s*[:=]\s*[''\"][^''\"]{8,}'),
    (('access' + '[_-]?' + 'token') + '\s*[:=]\s*[''\"][^''\"]{8,}'),
    (('refresh' + '[_-]?' + 'token') + '\s*[:=]\s*[''\"][^''\"]{8,}'),
    ('(_auth' + 'Token|npm[_-]?token)' + '\s*=\s*[^\s]+')
) -join '|'
$patternSourceRegex = '(?i)(^|/)scripts/(Test-GitCommitSafety|Test-RepositoryOpenSourceSafety|After-Apply-V0\.38\.5)\.ps1$'

function Test-RepositoryKind {
    $remoteText = (git remote -v 2>$null | Out-String)
    if ($remoteText -match $internalPattern) {
        Stop-GitSafety 'Arbeits-/TFS-Remote erkannt. Dieses Commit-/Push-Skript ist fuer private oder lokale Repositories gedacht und bricht hier hart ab.'
    }
    if ($remoteText -match '(?i)github\.com[:/].+/.+\.git|github\.com[:/].+/.+$') {
        Info 'Repository-Art: GitHub-Remote erkannt. Private Repos sind ok; Public Release nur als Clean Snapshot.'
    }
    elseif ([string]::IsNullOrWhiteSpace($remoteText)) {
        Info 'Repository-Art: kein Remote erkannt.'
    }
    else {
        Info 'Repository-Art: unbekannter Remote. Kein Push ohne bewusste Pruefung.'
    }
}

function Get-StatusPaths {
    $lines = git -c core.quotepath=false status --porcelain=v1 --untracked-files=all
    foreach ($line in $lines) {
        if ($line.Length -lt 4) { continue }
        $status = $line.Substring(0,2)
        $payload = $line.Substring(3)
        if ($payload -like '* -> *') {
            $parts = $payload -split ' -> ', 2
            [pscustomobject]@{ Status = $status; Path = (Normalize-GitPath $parts[0]) }
            [pscustomobject]@{ Status = $status; Path = (Normalize-GitPath $parts[1]) }
        }
        else {
            [pscustomobject]@{ Status = $status; Path = (Normalize-GitPath $payload) }
        }
    }
}

function Test-PathList([object[]]$Items, [switch]$AllowDeletes) {
    foreach ($item in $Items) {
        $status = [string]$item.Status
        $path = Normalize-GitPath ([string]$item.Path)
        if ([string]::IsNullOrWhiteSpace($path)) { continue }
        $isDelete = ($status.Trim() -eq 'D') -or ($status -eq 'D ' -or $status -eq ' D')
        if ($AllowDeletes -and $isDelete) { continue }
        if ($path -match $blockedPathRegex) { Stop-GitSafety "Verbotener Pfad: $path" }
    }
}

function Test-ContentText([string]$Text, [string]$Context) {
    if ([string]::IsNullOrEmpty($Text)) { return }
    if ($Text -match $internalPattern) { Stop-GitSafety "Interne URL/Registry-/Projekt-Referenz gefunden: $Context" }
    if ($Text -match $contentPattern) { Stop-GitSafety "Kritisches Zugangsdaten-Muster gefunden: $Context" }
}

function Get-StagedAddedText([string[]]$Files) {
    $chunks = New-Object System.Collections.Generic.List[string]
    foreach ($file in $Files) {
        $normalized = Normalize-GitPath $file
        if ([string]::IsNullOrWhiteSpace($normalized)) { continue }
        if ($normalized -match $patternSourceRegex) { continue }
        $diffLines = git diff --cached --unified=0 -- $normalized
        $addedText = ($diffLines | Where-Object { $_ -like '+*' -and $_ -notlike '+++ *' }) -join "`n"
        if (-not [string]::IsNullOrEmpty($addedText)) { $chunks.Add($addedText) }
    }
    return ($chunks -join "`n")
}

Test-RepositoryKind

if ($Staged) {
    $entries = git diff --cached --name-status
    Info 'Dateien im Staging:'
    if (-not $entries) { Info '  <leer>'; exit 0 }
    $items = @()
    foreach ($entry in $entries) {
        Info "  $entry"
        $parts = $entry -split "`t"
        $status = $parts[0]
        if ($parts.Length -gt 1) {
            foreach ($path in $parts[1..($parts.Length-1)]) { $items += [pscustomobject]@{ Status = $status; Path = (Normalize-GitPath $path) } }
        }
    }
    Test-PathList $items -AllowDeletes

    $stagedFiles = @(git diff --cached --name-only)
    $addedText = Get-StagedAddedText $stagedFiles
    Test-ContentText $addedText 'neu hinzugefuegte staged Zeilen'
    Info 'OK: Staging ist frei von verbotenen Pfaden, internen Referenzen und kritischen Zugangsdaten-Mustern.'
    exit 0
}

$statusItems = @(Get-StatusPaths)
Info 'Geaenderte Dateien:'
if ($statusItems.Count -eq 0) { Info '  <leer>'; exit 0 }
$statusItems | ForEach-Object { Info ("  {0} {1}" -f $_.Status, $_.Path) }
Test-PathList $statusItems -AllowDeletes

$trackedFiles = git ls-files
$hits = New-Object System.Collections.Generic.List[string]
foreach ($file in $trackedFiles) {
    $normalized = Normalize-GitPath $file
    if ($normalized -match $blockedPathRegex) { Stop-GitSafety "Verbotener getrackter Pfad im Repository: $normalized" }
    if ($normalized -match $patternSourceRegex) { continue }
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { continue }
    $content = Get-Content -Raw -LiteralPath $file -ErrorAction SilentlyContinue
    if ($null -eq $content) { continue }
    if ($content -match $internalPattern) { $hits.Add("internal:$normalized") }
    if ($content -match $contentPattern) { $hits.Add("credential-pattern:$normalized") }
}
if ($hits.Count -gt 0) { Stop-GitSafety ("Treffer in getrackten Dateien: " + ($hits -join ', ')) }
Info 'OK: Aktueller Arbeitsbaum ist frei von verbotenen getrackten Pfaden, internen Referenzen und kritischen Zugangsdaten-Mustern.'

if ($AllHistory) {
    New-Item -ItemType Directory -Force $ReportDir | Out-Null
    git rev-list --objects --all | Set-Content (Join-Path $ReportDir 'git-objects-all.txt') -Encoding UTF8
    $artifactHits = Select-String -Path (Join-Path $ReportDir 'git-objects-all.txt') -Pattern $blockedPathRegex -ErrorAction SilentlyContinue
    $historyPattern = "($internalPattern)|($contentPattern)"
    $historyPath = Join-Path $ReportDir 'history-sensitive-patches.txt'
    git log --all -p --regexp-ignore-case -G $historyPattern -- . ":(exclude)$ReportDir/**" ':(exclude)scripts/Test-GitCommitSafety.ps1' ':(exclude)scripts/Test-RepositoryOpenSourceSafety.ps1' | Set-Content $historyPath -Encoding UTF8
    if ($artifactHits) { $artifactHits | Set-Content (Join-Path $ReportDir 'history-artifact-paths.txt') -Encoding UTF8 }
    if ($artifactHits -or ((Test-Path $historyPath) -and ((Get-Item $historyPath).Length -gt 0))) {
        Stop-GitSafety "Historie enthaelt potenzielle Altlasten. Details lokal unter $ReportDir. Dieses Repo nicht direkt public schalten; Clean Snapshot verwenden."
    }
    Info 'OK: Historie ohne Treffer in diesem Basisscan.'
}
