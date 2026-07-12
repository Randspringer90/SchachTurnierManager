#requires -Version 7.0
<#
.SYNOPSIS
Bereitet einen Hotfix-Branch hotfix/<semver>-<name> von main vor.
.DESCRIPTION
Validiert SemVer und Namenssegment, zweigt von origin/main ab. Kein Tag, ohne -Push nur lokal.
Details nach D:\Temp\<RunName>_<Timestamp>, genau ein Upload-ZIP.
.EXAMPLE
pwsh scripts/Prepare-HotfixBranch.ps1 -Version 1.0.1 -Name crash-import
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Version,
    [Parameter(Mandatory)][string]$Name,
    [switch]$Push,
    [switch]$SkipFetch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/CollaborationCommon.ps1')

$run = New-RunContext -RunName 'prepare-hotfix-branch'
try {
    Assert-SemVer $Version
    Assert-SafeNameSegment $Name 'Name'
    $branch = "hotfix/$Version-$Name"
    Write-RunLog $run "Hotfix-Branch: $branch (von main; danach PR nach main UND Rueckmerge nach development)."

    $repo = Get-RepoRoot; Set-Location $repo
    Assert-CleanWorktree
    if (-not $SkipFetch) {
        & git fetch --no-tags origin main | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'git fetch fehlgeschlagen.' }
    }
    if (& git rev-parse --verify --quiet "refs/heads/$branch") { throw "Branch '$branch' existiert bereits." }

    & git switch -c $branch origin/main
    if ($LASTEXITCODE -ne 0) { throw "git switch -c '$branch' fehlgeschlagen." }
    Write-RunLog $run "Branch '$branch' von origin/main erstellt."

    if ($Push) {
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
