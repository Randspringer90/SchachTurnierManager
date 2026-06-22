param()
$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir
Set-Location $repoRoot

function Step([string]$Message) { Write-Host "[v0.38.5] $Message" }
function Read-Text([string]$Path) { [System.IO.File]::ReadAllText((Join-Path $repoRoot $Path), [System.Text.UTF8Encoding]::new($false)) }
function Write-Text([string]$Path, [string]$Text) {
    $full = Join-Path $repoRoot $Path
    $dir = Split-Path -Parent $full
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    [System.IO.File]::WriteAllText($full, $Text, [System.Text.UTF8Encoding]::new($false))
    Step "$Path als UTF-8 ohne BOM gespeichert"
}
function Replace-Version([string]$Path, [string]$Version) {
    if (-not (Test-Path (Join-Path $repoRoot $Path))) { return }
    $text = Read-Text $Path
    $text = $text -replace '0\.38\.[0-9]+', $Version
    $text = $text -replace '0\.37\.[0-9]+', $Version
    Write-Text $Path $text
    Step "$Path auf $Version gesetzt"
}
function Ensure-Line([string]$Path, [string]$Line) {
    $full = Join-Path $repoRoot $Path
    $text = if (Test-Path $full) { [System.IO.File]::ReadAllText($full, [System.Text.UTF8Encoding]::new($false)) } else { '' }
    if ($text -notmatch [regex]::Escape($Line)) {
        if ($text.Length -gt 0 -and -not $text.EndsWith("`n")) { $text += "`n" }
        $text += $Line + "`n"
        Write-Text $Path $text
    }
}
function Run-Step([string]$Name, [scriptblock]$Block) {
    Step $Name
    & $Block
    if ($LASTEXITCODE -ne 0) { throw "$Name ist fehlgeschlagen mit Exitcode $LASTEXITCODE." }
}

$version = '0.38.5'

# Failed/intermediate patch leftovers are not part of the clean current development baseline.
$removePaths = @(
    'docs/HANDOFF_0_38_0.md',
    'docs/HANDOFF_0_38_2.md',
    'docs/HANDOFF_0_38_4.md',
    'scripts/After-Apply-V0.38.2.ps1',
    'scripts/After-Apply-V0.38.3.ps1',
    'scripts/After-Apply-V0.38.4.ps1',
    'security-audit',
    '.local-audits',
    '.local-backups',
    'src/SchachTurnierManager.WebApp/package-lock.json.backup_before_v0.38.1'
)
foreach ($rel in $removePaths) {
    $full = Join-Path $repoRoot $rel
    if (Test-Path $full) {
        Remove-Item -LiteralPath $full -Recurse -Force -ErrorAction SilentlyContinue
        Step "Zwischen-/Lokaldatei entfernt: $rel"
    }
}

Replace-Version 'src/SchachTurnierManager.WebApi/Program.cs' $version
Replace-Version 'src/SchachTurnierManager.WebApp/src/main.tsx' $version

# package.json root version only.
$packageJsonPath = 'src/SchachTurnierManager.WebApp/package.json'
$packageJsonFull = Join-Path $repoRoot $packageJsonPath
if (Test-Path $packageJsonFull) {
    $packageJson = Get-Content -Raw -LiteralPath $packageJsonFull | ConvertFrom-Json
    $packageJson.version = $version
    [System.IO.File]::WriteAllText($packageJsonFull, ($packageJson | ConvertTo-Json -Depth 100) + "`n", [System.Text.UTF8Encoding]::new($false))
    Step "$packageJsonPath root-Version auf $version gesetzt"
}

# Force public npm registry for this project and selected package scopes.
$npmrc = @'
registry=https://registry.npmjs.org/
@emnapi:registry=https://registry.npmjs.org/
@napi-rs:registry=https://registry.npmjs.org/
@oxc-project:registry=https://registry.npmjs.org/
@rolldown:registry=https://registry.npmjs.org/
@tybys:registry=https://registry.npmjs.org/
'@
Write-Text 'src/SchachTurnierManager.WebApp/.npmrc' $npmrc

$webAppDir = Join-Path $repoRoot 'src/SchachTurnierManager.WebApp'
$lockPath = Join-Path $webAppDir 'package-lock.json'
$blockedLockPattern = ('(?i)' + ('tfs' + '\.fwdev') + '|' + ('eckd' + 'service') + '|_' + 'packaging|' + ('ITM' + '_KFM') + '|scheduler-0\.37\.0|"scheduler"\s*:\s*"\^0\.37\.0"')
if ((Test-Path $lockPath) -and ((Get-Content -Raw -LiteralPath $lockPath) -match $blockedLockPattern)) {
    Step 'package-lock.json enthaelt interne/falsche Registry-Daten; Lockfile wird neu erzeugt'
    Remove-Item -Force $lockPath
}
if (-not (Test-Path $lockPath)) {
    Push-Location $webAppDir
    try { Run-Step 'npm install --package-lock-only mit public registry' { npm.cmd install --package-lock-only --ignore-scripts --registry=https://registry.npmjs.org/ } }
    finally { Pop-Location }
}

# Set lock root version with Node. JSON packages[""] is intentional and avoids PowerShell empty-name issues.
$lockSetter = Join-Path $repoRoot '.tmp-set-lock-version-v0385.js'
$lockSetterJs = @'
const fs = require('fs');
const lockPath = process.argv[2];
const version = process.argv[3];
const json = JSON.parse(fs.readFileSync(lockPath, 'utf8'));
json.version = version;
if (json.packages && json.packages['']) {
  json.packages[''].version = version;
}
fs.writeFileSync(lockPath, JSON.stringify(json, null, 2) + '\n', 'utf8');
'@
Set-Content -LiteralPath $lockSetter -Value $lockSetterJs -Encoding UTF8
try { Run-Step 'package-lock root-Version setzen' { node $lockSetter $lockPath $version } }
finally { Remove-Item -Force $lockSetter -ErrorAction SilentlyContinue }

$lockText = Get-Content -Raw -LiteralPath $lockPath
if ($lockText -match $blockedLockPattern) { throw 'package-lock.json enthaelt weiterhin interne Registry- oder falsche scheduler-0.37.0-Daten.' }
Step 'package-lock.json public/open-source-sicherer Lockfile-Check OK'

# Harden gitignore.
$ignoreLines = @(
    '# Local/private audit and backup files',
    'security-audit/',
    '.local-audits/',
    '.local-backups/',
    '*.backup_before_*',
    '*.before-v*.json',
    'src/SchachTurnierManager.WebApp/package-lock.json.backup*',
    '.tmp-*',
    '# Generated build artifacts',
    'output/',
    '**/bin/',
    '**/obj/',
    '**/dist/',
    '**/node_modules/',
    '*.zip',
    '*.log',
    '*.dmp',
    '*.dump',
    '*.db',
    '*.sqlite',
    '*.sqlite3',
    '.env',
    '.env.*',
    '*.key',
    '*.pem',
    '*.pfx',
    '*.p12'
)
foreach ($line in $ignoreLines) { Ensure-Line '.gitignore' $line }

$testGitSafety = @'
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

$blockedPathRegex = '(?i)(^|/)(security-audit|\.local-audits|\.local-backups|output|bin|obj|dist|node_modules)(/|$)|\.(zip|7z|rar|exe|dll|pdb|nupkg|db|sqlite|sqlite3|log|dmp|dump|key|pem|pfx|p12)$|(^|/)\.env(\.|$)|backup_before_|before-v[0-9].*\.json$|package-lock\.json\.backup'
$internalPattern = @(('tfs' + '\.fwdev'), ('eckd' + 'service'), ('_' + 'packaging'), ('ITM' + '_KFM')) -join '|'
$contentPattern = @(
    ('github' + '_pat_'),
    ('gh' + 'p_'),
    ('gl' + 'pat-'),
    ('sk-' + '[A-Za-z0-9]{20,}'),
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

$trackedFiles = git ls-files
$hits = New-Object System.Collections.Generic.List[string]
foreach ($file in $trackedFiles) {
    if ($file -match $blockedPathRegex) { Stop-GitSafety "Verbotener getrackter Pfad im Repository: $file" }
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { continue }
    $content = Get-Content -Raw -LiteralPath $file -ErrorAction SilentlyContinue
    if ($null -eq $content) { continue }
    if ($content -match $internalPattern) { $hits.Add("internal:$file") }
    if ($content -match $contentPattern) { $hits.Add("credential-pattern:$file") }
}
if ($hits.Count -gt 0) { Stop-GitSafety ("Treffer in getrackten Dateien: " + ($hits -join ', ')) }
Info 'OK: Aktueller Arbeitsbaum ist frei von verbotenen getrackten Pfaden, internen Referenzen und kritischen Zugangsdaten-Mustern.'

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
'@
Write-Text 'scripts/Test-GitCommitSafety.ps1' $testGitSafety
Write-Text 'scripts/Test-RepositoryOpenSourceSafety.ps1' $testGitSafety

$commitGuard = @'
param(
    [Parameter(Mandatory = $true)][string]$Message,
    [switch]$Push
)
$ErrorActionPreference = 'Stop'
$repoRoot = (git rev-parse --show-toplevel).Trim()
Set-Location $repoRoot

function Run-Step([string]$Name, [scriptblock]$Block) {
    Write-Host "[CommitGuard] $Name..."
    & $Block
    if ($LASTEXITCODE -ne 0) { throw "$Name ist fehlgeschlagen mit Exitcode $LASTEXITCODE." }
}

Run-Step 'Release-Gate' { pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File '.\scripts\Invoke-ReleaseGate.ps1' }
Run-Step 'Git-Sicherheitspruefung vor Stage' { pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File '.\scripts\Test-GitCommitSafety.ps1' }

Write-Host '[CommitGuard] git status vor add...'
git status --short

Run-Step 'git add --all' { git add --all }
Run-Step 'Git-Sicherheitspruefung nach Stage' { pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File '.\scripts\Test-GitCommitSafety.ps1' -Staged }

Write-Host '[CommitGuard] Dateien im Commit:'
git diff --cached --name-status

$pending = git diff --cached --name-only
if (-not $pending) { Write-Host '[CommitGuard] Nichts zu committen.'; exit 0 }

Run-Step 'git commit' { git commit -m $Message }
if ($Push) { Run-Step 'git push' { git push } }
Write-Host '[CommitGuard] Fertig.'
'@
Write-Text 'scripts/Commit-If-Green.ps1' $commitGuard

$readmePath = Join-Path $repoRoot 'README.md'
if (Test-Path $readmePath) {
    $readme = Read-Text 'README.md'
    if ($readme -notmatch '0\.38\.5') {
        $readme = $readme -replace '0\.38\.[0-9]+', $version
        if ($readme -notmatch 'Commit-Sicherheitscheck') {
            $readme += "`n## Commit-Sicherheitscheck`n`nCommits laufen ueber `scripts/Commit-If-Green.ps1`. Der Guard prueft Build, Tests, Frontend, Paketierung und blockiert lokale Audit-/Backup-Dateien, Artefakte, interne Registry-Referenzen und kritische Zugangsdaten-Muster. Fuer eine spaetere Open-Source-Veröffentlichung wird ein Clean Snapshot ohne private Historie verwendet.`n"
        }
        Write-Text 'README.md' $readme
    }
}

$changelogPath = Join-Path $repoRoot 'CHANGELOG.md'
$entry = @"

## 0.38.5 - Commit-Guard-Fix und Clean-Current-Baseline

- Entfernt fehlgeschlagene v0.38-Zwischenpatch-Dateien aus dem aktuellen Arbeitsstand.
- Repariert den Git-Sicherheitscheck, damit er eigene Prüfpattern nicht mehr selbst als Treffer blockiert.
- Prüft staged Diffs nur auf neu hinzugefügte Zeilen, damit Löschungen alter belasteter Dateien möglich bleiben.
- Hält lokale Audit-/Backup-Verzeichnisse und Paket-Backups konsequent aus künftigen Commits heraus.
- Bestätigt weiterhin: Das private Repo wird wegen der Historie nicht direkt öffentlich geschaltet; Open Source erfolgt später als Clean Snapshot.
"@
$changelog = if (Test-Path $changelogPath) { Read-Text 'CHANGELOG.md' } else { '# Changelog' }
if ($changelog -notmatch '## 0\.38\.5') { Write-Text 'CHANGELOG.md' ($entry.TrimStart() + "`n" + $changelog) }

$handoff = @"
# Handoff 0.38.5 - Commit-Guard-Fix und Clean-Current-Baseline

## Ziel

v0.38.5 repariert den in v0.38.4 ausgelösten Selbsttreffer des Git-Sicherheitschecks und entfernt fehlgeschlagene Zwischenpatch-Dateien aus dem aktuellen Arbeitsstand.

## Wichtig

Das private Repository bleibt wegen historischer Altlasten privat. Für eine spätere öffentliche Veröffentlichung wird ein Clean Snapshot ohne alte Git-Historie erzeugt.

## Erwartete Prüfung

- `scripts/Test-GitCommitSafety.ps1` läuft ohne Treffer im aktuellen Arbeitsbaum.
- Release-Gate bleibt grün.
- Der Commit enthält keine `.local-*`, `security-audit`, Paket-Backups, Build-Artefakte oder internen Registry-Referenzen.
"@
Write-Text 'docs/HANDOFF_0_38_5.md' $handoff

Run-Step 'Git-Sicherheitspruefung aktueller Stand' { pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File '.\scripts\Test-GitCommitSafety.ps1' }
Run-Step 'Release-Gate' { pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File '.\scripts\Invoke-ReleaseGate.ps1' }

Step 'Fertig. Wenn Gate gruen ist: scripts/Commit-If-Green.ps1 -Message "Fix commit guard open source safety" -Push ausfuehren.'
