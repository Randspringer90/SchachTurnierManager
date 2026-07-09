[CmdletBinding()]
param(
    [string]$RunDirectory,
    [string]$RunName = 'SchachTurnierManager_Run',
    [string]$BaseDirectory = 'D:\Temp',
    [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [switch]$CreateOnly,
    [switch]$IncludeFullDiff
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-SafeFileName([string]$Value) {
    $safe = $Value -replace '[^a-zA-Z0-9_.-]+', '_'
    if ([string]::IsNullOrWhiteSpace($safe)) { return 'run' }
    return $safe.Trim('_')
}

if ([string]::IsNullOrWhiteSpace($RunDirectory)) {
    $safeRunName = ConvertTo-SafeFileName $RunName
    $RunDirectory = Join-Path $BaseDirectory ("${safeRunName}_$(Get-Date -Format yyyyMMdd_HHmmss)")
}

New-Item -ItemType Directory -Force -Path $RunDirectory | Out-Null
$resolvedRunDirectory = (Resolve-Path -LiteralPath $RunDirectory).Path

if ($CreateOnly) {
    Write-Output $resolvedRunDirectory
    return
}

$resolvedRepo = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$summaryPath = Join-Path $resolvedRunDirectory 'SUMMARY.txt'
$gitStatusPath = Join-Path $resolvedRunDirectory 'git-status.txt'
$gitDiffStatPath = Join-Path $resolvedRunDirectory 'git-diff-stat.txt'
$gitDiffPath = Join-Path $resolvedRunDirectory 'git-diff.patch'

@(
    "RunName: $RunName",
    "Created: $(Get-Date -Format o)",
    "RepositoryRoot: $resolvedRepo",
    "RunDirectory: $resolvedRunDirectory"
) | Set-Content -Encoding UTF8 -LiteralPath $summaryPath

Push-Location $resolvedRepo
try {
    git status --short --branch 2>&1 | Set-Content -Encoding UTF8 -LiteralPath $gitStatusPath
    git diff --stat 2>&1 | Set-Content -Encoding UTF8 -LiteralPath $gitDiffStatPath
    if ($IncludeFullDiff) {
        git diff -- 2>&1 | Set-Content -Encoding UTF8 -LiteralPath $gitDiffPath
    }
}
finally {
    Pop-Location
}

$zipPath = Join-Path (Split-Path -Parent $resolvedRunDirectory) ("$(Split-Path -Leaf $resolvedRunDirectory).zip")
Remove-Item -Force -LiteralPath $zipPath -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $resolvedRunDirectory '*') -DestinationPath $zipPath -Force
Write-Output $zipPath
