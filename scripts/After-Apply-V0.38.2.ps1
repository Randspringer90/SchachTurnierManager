param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Version = '0.38.2'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function Step([string]$Message) { Write-Host "[v$Version] $Message" }

function Save-Utf8NoBom([string]$Path, [string]$Text) {
    $encoding = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($Path, $Text, $encoding)
}

function Read-Text([string]$RelativePath) {
    $path = Join-Path $Root $RelativePath
    return [System.IO.File]::ReadAllText($path)
}

function Write-Text([string]$RelativePath, [string]$Text) {
    $path = Join-Path $Root $RelativePath
    $dir = Split-Path -Parent $path
    if ($dir) { New-Item -ItemType Directory -Force $dir | Out-Null }
    Save-Utf8NoBom $path $Text
    Step "$RelativePath als UTF-8 ohne BOM gespeichert"
}

function Update-JsonRootVersion([string]$RelativePath) {
    $path = Join-Path $Root $RelativePath
    if (-not (Test-Path -LiteralPath $path)) { throw "$RelativePath nicht gefunden." }
    $json = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    $json.version = $Version
    $text = $json | ConvertTo-Json -Depth 100
    Save-Utf8NoBom $path ($text + [Environment]::NewLine)
    Step "$RelativePath root-Version auf $Version gesetzt"
}

function Update-SourceVersion([string]$RelativePath) {
    $path = Join-Path $Root $RelativePath
    if (-not (Test-Path -LiteralPath $path)) { return }
    $text = [System.IO.File]::ReadAllText($path)
    $text = [regex]::Replace($text, '0\.(?:2[0-9]|3[0-9])\.\d+', $Version)
    Save-Utf8NoBom $path $text
    Step "$RelativePath auf $Version gesetzt"
}

function Append-UniqueLines([string]$RelativePath, [string[]]$Lines) {
    $path = Join-Path $Root $RelativePath
    $existing = if (Test-Path -LiteralPath $path) { [System.IO.File]::ReadAllText($path) } else { '' }
    $normalized = $existing -replace "`r`n", "`n"
    $add = New-Object System.Collections.Generic.List[string]
    foreach ($line in $Lines) {
        if ($normalized -notmatch [regex]::Escape($line)) { [void]$add.Add($line) }
    }
    if ($add.Count -gt 0) {
        if ($existing.Length -gt 0 -and -not $existing.EndsWith("`n")) { $existing += [Environment]::NewLine }
        $existing += [Environment]::NewLine + '# Local/security/build artifacts' + [Environment]::NewLine + (($add | ForEach-Object { $_ }) -join [Environment]::NewLine) + [Environment]::NewLine
        Save-Utf8NoBom $path $existing
        Step "$RelativePath um Sicherheits-/Artefaktregeln ergaenzt"
    } else {
        Step "$RelativePath Sicherheits-/Artefaktregeln bereits vorhanden"
    }
}

function Run-Step([string]$Name, [scriptblock]$Action) {
    Step $Name
    & $Action
    if ($LASTEXITCODE -ne 0) { throw "$Name ist fehlgeschlagen mit Exitcode $LASTEXITCODE." }
}

# Remove failed/intermediate patch files from the accidentally committed v0.37 repair attempts.
$cleanup = @(
    'docs/HANDOFF_0_37_0.md','docs/HANDOFF_0_37_1.md','docs/HANDOFF_0_37_2.md','docs/HANDOFF_0_37_3.md','docs/HANDOFF_0_37_4.md','docs/HANDOFF_0_37_5.md',
    'scripts/After-Apply-V0.37.ps1','scripts/After-Apply-V0.37.1.ps1','scripts/After-Apply-V0.37.2.ps1','scripts/After-Apply-V0.37.3.ps1','scripts/After-Apply-V0.37.4.ps1','scripts/After-Apply-V0.37.5.ps1',
    'scripts/After-Apply-V0.38.ps1','scripts/After-Apply-V0.38.1.ps1'
)
foreach ($relative in $cleanup) {
    $path = Join-Path $Root $relative
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Force
        Step "Ungueltigen Zwischenstand entfernt: $relative"
    }
}

# Versions: avoid touching dependency versions in package-lock.json.
Update-SourceVersion 'src/SchachTurnierManager.WebApi/Program.cs'
Update-SourceVersion 'src/SchachTurnierManager.WebApp/src/main.tsx'
Update-JsonRootVersion 'src/SchachTurnierManager.WebApp/package.json'

# Force public npm config for this project, including scoped dependencies that may otherwise inherit a user-level registry.
$npmrc = @'
registry=https://registry.npmjs.org/
@emnapi:registry=https://registry.npmjs.org/
@napi-rs:registry=https://registry.npmjs.org/
@oxc-project:registry=https://registry.npmjs.org/
@rolldown:registry=https://registry.npmjs.org/
@tybys:registry=https://registry.npmjs.org/
always-auth=false
'@
Write-Text 'src/SchachTurnierManager.WebApp/.npmrc' ($npmrc.TrimEnd() + [Environment]::NewLine)

$webApp = Join-Path $Root 'src/SchachTurnierManager.WebApp'
$lockPath = Join-Path $webApp 'package-lock.json'
if (Test-Path -LiteralPath $lockPath) {
    $backupDir = Join-Path $Root '.local-backups'
    New-Item -ItemType Directory -Force $backupDir | Out-Null
    $backup = Join-Path $backupDir ("package-lock.before-v$Version.{0}.json" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
    Copy-Item -LiteralPath $lockPath -Destination $backup -Force
    Remove-Item -LiteralPath $lockPath -Force
    Step "Altes package-lock.json entfernt; Backup lokal unter .local-backups erstellt"
}

Push-Location $webApp
try {
    $npmArgs = @(
        'install',
        '--package-lock-only',
        '--ignore-scripts',
        '--registry=https://registry.npmjs.org/',
        '--userconfig', (Join-Path $webApp '.npmrc'),
        '--@emnapi:registry=https://registry.npmjs.org/',
        '--@napi-rs:registry=https://registry.npmjs.org/',
        '--@oxc-project:registry=https://registry.npmjs.org/',
        '--@rolldown:registry=https://registry.npmjs.org/',
        '--@tybys:registry=https://registry.npmjs.org/'
    )
    Run-Step 'package-lock.json mit public npm Registry neu erzeugen' { & npm.cmd @npmArgs }
} finally {
    Pop-Location
}

if (-not (Test-Path -LiteralPath $lockPath)) { throw 'package-lock.json wurde nicht neu erzeugt.' }

# Set only the lockfile root package version, never dependency versions.
$nodeScript = @'
const fs = require('fs');
const path = process.argv[1];
const version = process.argv[2];
const lock = JSON.parse(fs.readFileSync(path, 'utf8'));
lock.version = version;
if (lock.packages && lock.packages['']) {
  lock.packages[''].version = version;
}
fs.writeFileSync(path, JSON.stringify(lock, null, 2) + '\n', 'utf8');
'@
$nodeScriptPath = Join-Path $Root '.local-backups\set-lock-version-v0382.js'
New-Item -ItemType Directory -Force (Split-Path -Parent $nodeScriptPath) | Out-Null
Save-Utf8NoBom $nodeScriptPath $nodeScript
Run-Step 'package-lock root-Version setzen' { & node.exe $nodeScriptPath $lockPath $Version }

$lockText = [System.IO.File]::ReadAllText($lockPath)
$blocked = @('tfs.fwdev', 'eckdservice', '_packaging', 'ITM_KFM', 'scheduler-0.37.0', '"scheduler": "^0.37.0"')
foreach ($needle in $blocked) {
    if ($lockText -like "*$needle*") { throw "package-lock.json enthaelt weiterhin blockierten Open-Source-Treffer: $needle" }
}
Step 'package-lock.json enthaelt keine internen Registry-URLs oder scheduler@0.37.0 mehr'

Append-UniqueLines '.gitignore' @(
    'output/',
    '**/bin/',
    '**/obj/',
    '**/dist/',
    '**/node_modules/',
    'security-audit/',
    '.local-backups/',
    '*.zip',
    '*.7z',
    '*.rar',
    '*.log',
    '*.dmp',
    '*.dump',
    '*.db',
    '*.sqlite',
    '*.sqlite3',
    '*.nupkg',
    '*.snupkg',
    '.env',
    '.env.*',
    '*.key',
    '*.pem',
    '*.pfx',
    '*.p12'
)

$readme = @'
# SchachTurnierManager

Privater Turniermanager fuer Schweizer-System-, Schnellschach- und Vereinsturniere.

## Aktueller Stand

Stand: v0.38.2

Wichtige Funktionen:

- Turniere anlegen, importieren und als portable Version paketieren.
- Spieler verwalten, externe FIDE-Spielerdaten nachschlagen und Dubletten pruefen.
- Runden auslosen, Ergebnisse erfassen und Paarungen manuell korrigieren.
- Export-Center fuer JSON/CSV/HTML/PGN/Print-Workflows.
- Dashboard mit Ergebnispruefung, Bye-/kampflos-Audit, Auslosungsbereitschaft und Audit-Journal.
- Persistentes Audit-Journal fuer Turnierleitungsaktionen.
- Query-Grundlage und API fuer gefilterte Audit-Journal-Auswertungen.
- Release-Gate fuer Restore, Build, Tests, Frontend-Build und Portable-Paket.
- Safe Commit Guard gegen Build-Artefakte, interne Registry-URLs und typische Secret-Muster.

## Entwicklung

```powershell
pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-ReleaseGate.ps1
```

Commit und Push nur ueber:

```powershell
pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Commit-If-Green.ps1 -Message "<Commit-Message>" -Push
```

## Open-Source-Hinweis

Dieses private Entwicklungsrepository enthaelt eine Git-Historie. Vor einer oeffentlichen Veroeffentlichung muss die gesamte Historie auf Secrets, interne URLs und Artefakte geprueft werden. Fuer eine oeffentliche Version ist ein separates Clean-Snapshot-Repository ohne private Historie empfohlen.
'@
Write-Text 'README.md' ($readme.TrimEnd() + [Environment]::NewLine)

$safetyScript = @'
param(
    [switch]$StagedOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $Root

function Fail([string]$Message) { throw "[GitSafety] $Message" }
function Info([string]$Message) { Write-Host "[GitSafety] $Message" }

$artifactPathPattern = '(?i)(^|/)(bin|obj|output|dist|node_modules|security-audit|logs|reports|tmp|\.local-backups)(/|$)|\.(zip|7z|rar|exe|dll|pdb|nupkg|snupkg|db|sqlite|sqlite3|log|dmp|dump|key|pem|pfx|p12)$|(^|/)\.env(\.|$)'
$internalTextPattern = '(?i)tfs\.fwdev|eckdservice|_packaging|ITM_KFM|github_pat_|ghp_|glpat-|sk-[A-Za-z0-9]{20,}|BEGIN [A-Z ]*PRIVATE KEY|_authToken\s*=|//.*:_authToken\s*=|client[_-]?secret\s*[:=]|access[_-]?token\s*[:=]|refresh[_-]?token\s*[:=]|api[_-]?key\s*[:=]|password\s*[:=]'

if ($StagedOnly) {
    $files = git diff --cached --name-only --diff-filter=ACMRT
} else {
    $files = @()
    $files += git diff --name-only --diff-filter=ACMRT
    $files += git ls-files --others --exclude-standard
    $files = $files | Sort-Object -Unique
}

foreach ($file in $files) {
    $norm = $file -replace '\\', '/'
    if ($norm -match $artifactPathPattern) { Fail "Blockierter Artefakt-/Secret-Pfad: $file" }
}

foreach ($file in $files) {
    $path = Join-Path $Root $file
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
    $item = Get-Item -LiteralPath $path
    if ($item.Length -gt 2MB) { Fail "Datei ist fuer Commit ungewoehnlich gross: $file ($($item.Length) Bytes)" }
    $text = [System.IO.File]::ReadAllText($path)
    if ($text -match $internalTextPattern) { Fail "Blockierter Secret-/Interne-URL-Treffer in Datei: $file" }
}

Info "OK: Keine blockierten Artefaktpfade oder Secret-/interne-URL-Treffer in $($files.Count) Datei(en)."
'@
Write-Text 'scripts/Test-GitCommitSafety.ps1' ($safetyScript.TrimEnd() + [Environment]::NewLine)

$commitGuard = @'
param(
    [Parameter(Mandatory = $true)][string]$Message,
    [switch]$Push
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $Root

function Run-Step([string]$Name, [scriptblock]$Action) {
    Write-Host "[CommitGuard] $Name..."
    & $Action
    if ($LASTEXITCODE -ne 0) { throw "$Name ist fehlgeschlagen mit Exitcode $LASTEXITCODE." }
}

Run-Step 'Release-Gate' { & pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Invoke-ReleaseGate.ps1') }
Run-Step 'Safety-Check vor Stage' { & pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Test-GitCommitSafety.ps1') }

Run-Step 'git add -A' { git add -A }

Write-Host '[CommitGuard] Zu commitende Dateien:'
git diff --cached --name-status

Run-Step 'Safety-Check nach Stage' { & pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Test-GitCommitSafety.ps1') -StagedOnly }

$hasChanges = git diff --cached --quiet; $exit = $LASTEXITCODE
if ($exit -eq 0) {
    Write-Host '[CommitGuard] Keine staged changes. Commit wird uebersprungen.'
    exit 0
}

Run-Step 'git commit' { git commit -m $Message }
if ($Push) { Run-Step 'git push' { git push } }
'@
Write-Text 'scripts/Commit-If-Green.ps1' ($commitGuard.TrimEnd() + [Environment]::NewLine)

$changelogPath = Join-Path $Root 'CHANGELOG.md'
$entry = @"

## v$Version - Open-Source-Safety-Fix

- package-lock.json aus oeffentlicher npm Registry neu erzeugt; interne TFS/ECKD/_packaging/ITM_KFM-URLs werden blockiert.
- package-lock-Versionierung korrigiert: Nur Root-Version wird gesetzt, Dependency-Versionen bleiben unveraendert.
- Safe Commit Guard gegen Artefakte, lokale Backups, Security-Audit-Dateien, interne Registry-URLs und typische Secret-Muster ergaenzt.
- README auf aktuellen Projektstand gebracht und Open-Source-Hinweis ergaenzt.
- Ungueltige v0.37-Zwischenpatch-Dateien entfernt; v0.37.6 bleibt als gueltiger Handoff erhalten.
"@
$changelog = if (Test-Path $changelogPath) { [System.IO.File]::ReadAllText($changelogPath) } else { '# Changelog' + [Environment]::NewLine }
if ($changelog -notmatch [regex]::Escape("## v$Version - Open-Source-Safety-Fix")) {
    $changelog = $changelog.TrimEnd() + $entry + [Environment]::NewLine
    Save-Utf8NoBom $changelogPath $changelog
    Step 'CHANGELOG.md ergaenzt'
}

$handoff = @"
# Handoff v$Version - Open-Source-Safety-Fix

## Ziel

Aktuellen Arbeitsstand fuer ein spaeteres oeffentliches Clean-Snapshot-Repository vorbereiten.

## Inhalt

- package-lock.json wird mit public npm Registry neu erzeugt.
- Interne Registry-URLs wie tfs.fwdev/eckdservice/_packaging/ITM_KFM werden blockiert.
- Dependency-Versionen im Lockfile werden nicht mehr durch App-Versionierung ueberschrieben.
- Commit-If-Green enthaelt Safety-Checks vor und nach dem Staging.
- README ist auf aktuellen Stand gebracht.

## Wichtig

Dieses private Entwicklungsrepo darf nicht automatisch oeffentlich geschaltet werden, solange die alte Git-Historie interne URLs enthaelt. Fuer Open Source wird ein Clean-Snapshot-Repo ohne alte Historie empfohlen.
"@
Write-Text 'docs/HANDOFF_0_38_2.md' ($handoff.TrimEnd() + [Environment]::NewLine)
Write-Text 'scripts/After-Apply-V0.38.2.ps1' ([System.IO.File]::ReadAllText($PSCommandPath))

Run-Step 'Release-Gate' { & pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'scripts/Invoke-ReleaseGate.ps1') }

Step 'Open-Source-Safety-Nachkontrolle aktuelle Dateien'
& pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'scripts/Test-GitCommitSafety.ps1')

git status --short
Step 'Nachkontrolle abgeschlossen. Bitte Commit-If-Green.ps1 zum Commit/Push verwenden.'
