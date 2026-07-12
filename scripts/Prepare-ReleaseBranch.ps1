#requires -Version 7.0
<#
.SYNOPSIS
Bereitet einen Release-Branch release/<semver> von development vor (kein Tag, kein Push per Default).
.DESCRIPTION
Validiert die SemVer, zweigt von origin/development ab. Erstellt KEINEN Tag und KEIN Release.
Details nach D:\Temp\<RunName>_<Timestamp>, genau ein Upload-ZIP. Ohne -Push nur lokal.
.EXAMPLE
pwsh scripts/Prepare-ReleaseBranch.ps1 -Version 1.0.0
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Version,
    [switch]$Push,
    [switch]$SkipFetch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/CollaborationCommon.ps1')

$run = New-RunContext -RunName 'prepare-release-branch'
try {
    Assert-SemVer $Version
    $branch = "release/$Version"
    Write-RunLog $run "Release-Branch: $branch (nur Stabilisierung, keine neuen Features; kein Tag)."

    $repo = Get-RepoRoot; Set-Location $repo
    Assert-CleanWorktree
    if (-not $SkipFetch) {
        & git fetch --no-tags origin development | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'git fetch fehlgeschlagen.' }
    }
    if (& git rev-parse --verify --quiet "refs/heads/$branch") { throw "Branch '$branch' existiert bereits." }

    & git switch -c $branch origin/development
    if ($LASTEXITCODE -ne 0) { throw "git switch -c '$branch' fehlgeschlagen." }
    Write-RunLog $run "Branch '$branch' erstellt. Jetzt: Version anpassen, CHANGELOG finalisieren, Gates gruen."

    if ($Push) {
        Write-RunLog $run 'Push (explizit angefordert) ...'
        & git push --set-upstream origin $branch
        if ($LASTEXITCODE -ne 0) { throw 'git push fehlgeschlagen.' }
    } else {
        Write-RunLog $run 'Kein Push (Default). Mit -Push explizit pushen.'
    }
    $zip = Complete-RunZip $run
    Write-Host "OK: $branch"; Write-Host "Upload-ZIP: $zip"
    exit 0
}
catch {
    Write-RunLog $run ("FEHLER: " + $_.Exception.Message)
    [void](Complete-RunZip $run)
    Write-Error $_.Exception.Message
    exit 1
}
