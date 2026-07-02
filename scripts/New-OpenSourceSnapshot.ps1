param(
    [string]$OutputRoot = 'output\open-source-snapshot',
    [switch]$NoZip
)
$ErrorActionPreference = 'Stop'
$repoRoot = (git rev-parse --show-toplevel).Trim()
Set-Location $repoRoot

function Stop-Snapshot([string]$Message) { Write-Error "[OpenSourceSnapshot] $Message"; exit 1 }
function Info([string]$Message) { Write-Host "[OpenSourceSnapshot] $Message" }
function Normalize-GitPath([string]$Path) { return (($Path ?? '').Trim().Trim('"') -replace '\\', '/') }

# SECURITY-PATTERN-FILE: Die folgenden Regexe sind Detection-/Blocklist-Patterns zum Aufspueren
# von internen Referenzen und Zugangsdaten im Snapshot - es sind bewusst KEINE echten Secrets.
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
$excludePathRegex = '(?i)(^|/)(\.git|\.codex|\.vs|security-audit|\.local-audits|\.local-backups|output|bin|obj|dist|node_modules|logs|tmp|reports)(/|$)|\.(zip|7z|rar|exe|dll|pdb|nupkg|db|sqlite|sqlite3|log|dmp|dump|key|pem|pfx|p12)$|(^|/)\.env(\.|$)|(^|/)scripts/(archive/after-apply/)?After-Apply-.*\.ps1$|(^|/)scripts/archive(/|$)|(^|/)docs/(handoffs/)?HANDOFF_.*\.md$|(^|/)docs/handoffs(/|$)|backup_before_|before-v[0-9].*\.json$|package-lock\.json\.backup'

$status = git status --porcelain=v1 --untracked-files=all
if ($status) {
    Info 'Arbeitsbaum ist nicht clean. Bitte erst committen oder verwerfen:'
    $status | ForEach-Object { Write-Host "  $_" }
    Stop-Snapshot 'Clean Snapshot wird nur aus einem sauberen Arbeitsbaum erzeugt.'
}

$commit = (git rev-parse --short HEAD).Trim()
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$snapshotName = "SchachTurnierManager_OpenSourceSnapshot_${commit}_$stamp"
$target = Join-Path $OutputRoot $snapshotName
if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
New-Item -ItemType Directory -Force $target | Out-Null

$tracked = @(git ls-files | ForEach-Object { Normalize-GitPath $_ })
$included = New-Object System.Collections.Generic.List[string]
$excluded = New-Object System.Collections.Generic.List[string]
foreach ($file in $tracked) {
    if ($file -match $excludePathRegex) { $excluded.Add($file); continue }
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { continue }
    $destination = Join-Path $target $file
    $destinationDir = Split-Path -Parent $destination
    if (-not [string]::IsNullOrWhiteSpace($destinationDir)) { New-Item -ItemType Directory -Force $destinationDir | Out-Null }
    Copy-Item -LiteralPath $file -Destination $destination -Force
    $included.Add($file)
}

$hitReport = Join-Path $target 'OPEN_SOURCE_SNAPSHOT_SECURITY_FINDINGS.txt'
$hits = New-Object System.Collections.Generic.List[string]
foreach ($file in $included) {
    $full = Join-Path $target $file
    $item = Get-Item -LiteralPath $full -ErrorAction SilentlyContinue
    if ($null -eq $item -or $item.Length -gt 5MB) { continue }
    $content = Get-Content -Raw -LiteralPath $full -ErrorAction SilentlyContinue
    if ($null -eq $content) { continue }
    if ($content -match $internalPattern) { $hits.Add("internal:$file") }
    if ($content -match $contentPattern) { $hits.Add("credential-pattern:$file") }
}

$reportPath = Join-Path $target 'OPEN_SOURCE_SNAPSHOT_REPORT.md'
$report = @(
    '# Open Source Snapshot Report',
    '',
    ('- Commit: `{0}`' -f $commit),
    "- Erzeugt: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    "- Enthaltene Dateien: $($included.Count)",
    "- Ausgeschlossene Dateien: $($excluded.Count)",
    '',
    '## Sicherheitsmodell',
    '',
    '- Snapshot wird aus getrackten Dateien eines cleanen Arbeitsbaums erzeugt.',
    '- Git-Historie wird nicht übernommen.',
    '- Lokale/temporäre Artefakte und historische Handoff-/After-Apply-Dateien werden ausgeschlossen.',
    '- Danach wird der Snapshot erneut auf interne Referenzen und typische Zugangsdaten-Muster geprüft.',
    '',
    '## Ausgeschlossene Dateien',
    ''
)
$report += ($excluded | Sort-Object | ForEach-Object { '- `{0}`' -f $_ })
$report | Set-Content -LiteralPath $reportPath -Encoding UTF8

if ($hits.Count -gt 0) {
    $hits | Sort-Object -Unique | Set-Content -LiteralPath $hitReport -Encoding UTF8
    Stop-Snapshot "Snapshot enthaelt potenzielle Sicherheitsfunde. Details: $hitReport"
}

if (-not $NoZip) {
    $zipPath = "$target.zip"
    if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
    Compress-Archive -LiteralPath $target -DestinationPath $zipPath -Force
    Info "ZIP: $zipPath"
}
Info "Snapshot: $target"
Info 'OK: Clean Snapshot ohne Sicherheitsfunde erzeugt.'
