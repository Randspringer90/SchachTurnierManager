param(
    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

function Write-Info([string]$Message) {
    if (-not $Quiet) {
        Write-Host "[GitSafety] $Message"
    }
}

function Get-ChangedPathFromStatusLine([string]$Line) {
    if ([string]::IsNullOrWhiteSpace($Line) -or $Line.Length -lt 4) {
        return $null
    }
    $Path = $Line.Substring(3).Trim()
    if ($Path -match ' -> ') {
        $Path = ($Path -split ' -> ')[-1].Trim()
    }
    return $Path.Trim('"')
}

function Test-TextFile([string]$Path) {
    $Extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    $TextExtensions = @('.cs','.csproj','.sln','.props','.targets','.json','.md','.txt','.ps1','.psm1','.psd1','.tsx','.ts','.js','.jsx','.css','.html','.yml','.yaml','.xml','.gitignore','.editorconfig')
    if ($TextExtensions -contains $Extension) { return $true }
    $FileName = [System.IO.Path]::GetFileName($Path).ToLowerInvariant()
    return $FileName -in @('readme','license','changelog','.gitignore','.editorconfig')
}

$StatusLines = @(git status --porcelain=v1)
$ChangedPaths = @()
foreach ($Line in $StatusLines) {
    $Path = Get-ChangedPathFromStatusLine $Line
    if ($Path) { $ChangedPaths += $Path }
}
$ChangedPaths = @($ChangedPaths | Sort-Object -Unique)

if ($ChangedPaths.Count -eq 0) {
    Write-Info 'Keine geaenderten Dateien gefunden.'
    exit 0
}

Write-Info 'Geaenderte Dateien:'
foreach ($Path in $ChangedPaths) {
    Write-Info "  $Path"
}

$ForbiddenPathPatterns = @(
    '(^|[\\/])output([\\/]|$)',
    '(^|[\\/])bin([\\/]|$)',
    '(^|[\\/])obj([\\/]|$)',
    '(^|[\\/])dist([\\/]|$)',
    '(^|[\\/])node_modules([\\/]|$)',
    '(^|[\\/])logs?([\\/]|$)',
    '(^|[\\/])reports?([\\/]|$)',
    '(^|[\\/])tmp([\\/]|$)',
    '(^|[\\/])\.env(\.|$)',
    '(^|[\\/])secrets?\.',
    '(^|[\\/]).*password.*',
    '(^|[\\/]).*passwd.*',
    '(^|[\\/]).*credential.*'
)

$ForbiddenExtensions = @('.zip','.7z','.rar','.nupkg','.dll','.exe','.pdb','.dmp','.dump','.log','.db','.sqlite','.sqlite3','.key','.pem','.pfx','.p12')
$Violations = New-Object System.Collections.Generic.List[string]

foreach ($Path in $ChangedPaths) {
    $Normalized = $Path -replace '\\','/'
    foreach ($Pattern in $ForbiddenPathPatterns) {
        if ($Normalized -match $Pattern) {
            $Violations.Add("Verbotener Pfad: $Path")
            break
        }
    }
    $Extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    if ($ForbiddenExtensions -contains $Extension) {
        $Violations.Add("Verbotene Dateiendung: $Path")
    }
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        $Item = Get-Item -LiteralPath $Path
        if ($Item.Length -gt 2MB) {
            $Violations.Add("Datei groesser als 2 MB: $Path ($($Item.Length) Bytes)")
        }
    }
}

$SecretPatterns = @(
    'ghp_[A-Za-z0-9_]{20,}',
    'github_pat_[A-Za-z0-9_]{20,}',
    'sk-[A-Za-z0-9]{20,}',
    'xox[baprs]-[A-Za-z0-9-]{20,}',
    '(?i)(password|passwd|pwd|api[_-]?key|client[_-]?secret|access[_-]?token|refresh[_-]?token)\s*[:=]\s*["'']?[^"''\s]{8,}',
    '-----BEGIN [^-]{0,40}PRIVATE KEY-----'
)

foreach ($Path in $ChangedPaths) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { continue }
    if (-not (Test-TextFile $Path)) { continue }
    $Item = Get-Item -LiteralPath $Path
    if ($Item.Length -gt 1MB) { continue }
    $Text = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    foreach ($Pattern in $SecretPatterns) {
        if ($Text -match $Pattern) {
            $Violations.Add("Moegliches Secret-Muster in: $Path")
            break
        }
    }
}

if ($Violations.Count -gt 0) {
    Write-Host '[GitSafety] Commit-Sicherheitspruefung FEHLGESCHLAGEN:' -ForegroundColor Red
    foreach ($Violation in $Violations) {
        Write-Host "  - $Violation" -ForegroundColor Red
    }
    Write-Host '[GitSafety] Bitte bereinigen oder gezielt begruenden, bevor committed wird.' -ForegroundColor Red
    exit 1
}

Write-Info 'OK: Keine verbotenen Artefakte oder typischen Secret-Muster gefunden.'
exit 0