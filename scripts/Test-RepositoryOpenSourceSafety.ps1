param(
    [string]$ReportDir = 'output\repo-open-source-safety',
    [switch]$AllHistory
)
$ErrorActionPreference = 'Stop'
$repoRoot = (git rev-parse --show-toplevel).Trim()
Set-Location $repoRoot

function Stop-Safety([string]$Message) { Write-Error "[OpenSourceSafety] $Message"; exit 1 }
function Info([string]$Message) { Write-Host "[OpenSourceSafety] $Message" }
function Normalize-GitPath([string]$Path) { return (($Path ?? '').Trim().Trim('"') -replace '\\', '/') }

# SECURITY-PATTERN-FILE: Diese Datei enthaelt bewusst Detection-/Blocklist-Regexe, keine echten Secrets.
# Diese Pruefung ist fuer Public-Snapshot-Kandidaten strenger als der private Commit-Guard:
# Sie scannt immer alle getrackten Dateien und markiert zusaetzlich public-unsichere Artefakte.
$blockedPathRegex = '(?i)(^|/)(\.codex|\.vs|security-audit|\.local-audits|\.local-backups|output|bin|obj|dist|node_modules|logs|tmp|reports)(/|$)|\.(zip|7z|rar|exe|dll|pdb|nupkg|db|sqlite|sqlite3|log|dmp|dump|key|pem|pfx|p12)$|(^|/)\.env(\.|$)|(^|/)\.npmrc$|backup_before_|before-v[0-9].*\.json$|package-lock\.json\.backup'
# Artefakte, die im privaten Repo erlaubt sind, aber NIE in einen Public Snapshot gehoeren.
$snapshotExcludeRegex = '(?i)(^|/)scripts/(archive/after-apply/)?After-Apply-.*\.ps1$|(^|/)scripts/archive(/|$)|(^|/)docs/(handoffs/)?HANDOFF_.*\.md$|(^|/)docs/handoffs(/|$)|(^|/)files/|\.(patch|diff|diffstat)$'
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
$patternSourceRegex = '(?i)(^|/)(scripts/(Test-GitCommitSafety|Test-RepositoryOpenSourceSafety|New-OpenSourceSnapshot)\.ps1|scripts/(archive/after-apply/)?After-Apply-V0\.38\.5\.ps1|\.agents/skills/repository-security\.md)$'
$patternSourceMarker = 'SECURITY-' + 'PATTERN-FILE'
$patternSourceDirRegex = '(?i)^(scripts|\.agents/skills)/'

function Test-IsPatternSource([string]$NormalizedPath, [string]$Content) {
    if ([string]::IsNullOrWhiteSpace($NormalizedPath)) { return $false }
    if ($NormalizedPath -match $patternSourceRegex) { return $true }
    if (($NormalizedPath -match $patternSourceDirRegex) -and $Content -and ($Content -match $patternSourceMarker)) { return $true }
    return $false
}

function Test-RepositoryKind {
    $remoteText = (git remote -v 2>$null | Out-String)
    if ($remoteText -match $internalPattern) {
        Stop-Safety 'Arbeits-/TFS-Remote erkannt. Public-Snapshot-Pruefung ist nur fuer das private/oeffentliche Schach-Repo gedacht.'
    }
}

Test-RepositoryKind

$findings = New-Object System.Collections.Generic.List[object]
function Add-Finding([string]$Severity, [string]$Kind, [string]$Path, [string]$Detail) {
    $findings.Add([pscustomobject]@{ severity = $Severity; kind = $Kind; path = $Path; detail = $Detail })
}

# Public-Snapshot-Kandidaten = alle getrackten Dateien.
$tracked = @(git ls-files | ForEach-Object { Normalize-GitPath $_ })
Info "Pruefe $($tracked.Count) getrackte Public-Snapshot-Kandidaten."

foreach ($file in $tracked) {
    if ([string]::IsNullOrWhiteSpace($file)) { continue }
    if ($file -match $blockedPathRegex) {
        Add-Finding 'error' 'blocked-path' $file 'Lokaler/Build-/Artefaktpfad darf nicht im Repo getrackt sein.'
        continue
    }
    if ($file -match $snapshotExcludeRegex) {
        Add-Finding 'warning' 'snapshot-exclude' $file 'Privates Artefakt (After-Apply/Handoff/Patch/files): wird aus Public Snapshot ausgeschlossen.'
    }
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { continue }
    $item = Get-Item -LiteralPath $file -ErrorAction SilentlyContinue
    if ($null -eq $item -or $item.Length -gt 5MB) { continue }
    $content = Get-Content -Raw -LiteralPath $file -ErrorAction SilentlyContinue
    if ($null -eq $content) { continue }
    if (Test-IsPatternSource $file $content) { continue }
    if ($content -match $internalPattern) { Add-Finding 'error' 'internal-reference' $file 'Interne Registry-/TFS-/Projekt-Referenz im Inhalt.' }
    if ($content -match $contentPattern) { Add-Finding 'error' 'credential-pattern' $file 'Typisches Zugangsdaten-/Token-Muster im Inhalt.' }
}

if ($AllHistory) {
    $historyPattern = "($internalPattern)|($contentPattern)"
    $historyHits = git log --all -p --regexp-ignore-case -G $historyPattern -- . `
        ':(exclude)scripts/Test-GitCommitSafety.ps1' `
        ':(exclude)scripts/Test-RepositoryOpenSourceSafety.ps1' `
        ':(exclude)scripts/New-OpenSourceSnapshot.ps1'
    if ($historyHits) {
        Add-Finding 'error' 'history-leftover' '(git-history)' 'Historie enthaelt potenzielle Altlasten. Public Release nur als Clean Snapshot ohne .git.'
    }
    if (-not $historyHits) { Info 'OK: Historie ohne Treffer in diesem Basisscan.' }
}

New-Item -ItemType Directory -Force $ReportDir | Out-Null
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$commit = (git rev-parse --short HEAD).Trim()
$errors = @($findings | Where-Object { $_.severity -eq 'error' })
$warnings = @($findings | Where-Object { $_.severity -eq 'warning' })

# Maschinenlesbarer Report (JSON)
$jsonPath = Join-Path $ReportDir 'open-source-safety.json'
[pscustomobject]@{
    generatedAt = $stamp
    commit = $commit
    candidateCount = $tracked.Count
    errorCount = $errors.Count
    warningCount = $warnings.Count
    findings = $findings
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

# Menschenlesbarer Report (Markdown)
$mdPath = Join-Path $ReportDir 'open-source-safety.md'
$md = New-Object System.Collections.Generic.List[string]
$md.Add('# Open Source Safety Report')
$md.Add('')
$md.Add("- Erzeugt: $stamp")
$md.Add("- Commit: ``$commit``")
$md.Add("- Gepruefte Kandidaten: $($tracked.Count)")
$md.Add("- Fehler (blockierend): $($errors.Count)")
$md.Add("- Warnungen (Snapshot-Ausschluss): $($warnings.Count)")
$md.Add('')
$md.Add('## Fehler (muessen vor Public Release behoben werden)')
$md.Add('')
if ($errors.Count -eq 0) { $md.Add('- keine') }
else { foreach ($f in $errors) { $md.Add("- [$($f.kind)] $($f.path): $($f.detail)") } }
$md.Add('')
$md.Add('## Warnungen (werden aus Public Snapshot ausgeschlossen)')
$md.Add('')
if ($warnings.Count -eq 0) { $md.Add('- keine') }
else { foreach ($f in $warnings) { $md.Add("- [$($f.kind)] $($f.path): $($f.detail)") } }
($md -join "`n") | Set-Content -LiteralPath $mdPath -Encoding UTF8

Info "Report (JSON): $jsonPath"
Info "Report (Markdown): $mdPath"
Info "Warnungen (Snapshot-Ausschluss): $($warnings.Count)"

if ($errors.Count -gt 0) {
    Stop-Safety "Public-Snapshot-Kandidaten enthalten $($errors.Count) blockierende Funde. Details: $mdPath"
}
Info 'OK: Keine blockierenden Funde in den Public-Snapshot-Kandidaten. Public Release nur als Clean Snapshot ohne .git-Historie.'
