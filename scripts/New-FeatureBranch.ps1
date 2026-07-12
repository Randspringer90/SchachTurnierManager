#requires -Version 7.0
<#
.SYNOPSIS
Erzeugt sicher einen Feature-/Fix-/Security-/Docs-/Refactor-Branch von aktuellem development.
.DESCRIPTION
Validiert Backlog-ID und Namenssegment (kein Injection-Risiko), zweigt vom aktuellen
origin/development ab. Details werden nach D:\Temp\<RunName>_<Timestamp> geschrieben und am
Ende zu genau einem Upload-ZIP gepackt. Oeffnet keine neuen Terminalfenster.
.EXAMPLE
pwsh scripts/New-FeatureBranch.ps1 -BacklogId STM-IE-001 -Name trf-export
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BacklogId,
    [Parameter(Mandatory)][string]$Name,
    [ValidateSet('feature','fix','security','docs','refactor')][string]$Type = 'feature',
    [switch]$SkipFetch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/CollaborationCommon.ps1')

$run = New-RunContext -RunName 'new-feature-branch'
try {
    Assert-BacklogId $BacklogId
    Assert-SafeNameSegment $Name 'Name'
    Write-RunLog $run "Backlog-ID/Name validiert: $BacklogId / $Name (Typ $Type)"

    $repo = Get-RepoRoot
    Set-Location $repo
    if (-not (Test-BacklogIdExists -BacklogId $BacklogId)) {
        throw "Backlog-ID '$BacklogId' nicht in docs/planning/BACKLOG.md gefunden. Erst Backlog-Eintrag anlegen."
    }
    Assert-CleanWorktree

    $branch = "$Type/$BacklogId-$Name"
    Write-RunLog $run "Zielbranch: $branch"

    if (-not $SkipFetch) {
        Write-RunLog $run 'Fetch origin ...'
        & git fetch --no-tags origin development | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'git fetch fehlgeschlagen.' }
    }

    $exists = (& git rev-parse --verify --quiet "refs/heads/$branch")
    if ($exists) { throw "Branch '$branch' existiert bereits lokal." }

    # Branchname ist strikt validiert -> sichere Uebergabe als einzelnes Argument.
    & git switch -c $branch origin/development
    if ($LASTEXITCODE -ne 0) { throw "git switch -c '$branch' fehlgeschlagen." }

    Write-RunLog $run "Branch '$branch' von origin/development erstellt."
    Write-RunLog $run "Naechste Schritte: umsetzen, Tests gruen, PR nach 'development' (Backlog-Status -> In Progress)."
    $zip = Complete-RunZip $run
    Write-Host "OK: $branch"
    Write-Host "Upload-ZIP: $zip"
    exit 0
}
catch {
    Write-RunLog $run ("FEHLER: " + $_.Exception.Message)
    [void](Complete-RunZip $run)
    Write-Error $_.Exception.Message
    exit 1
}
