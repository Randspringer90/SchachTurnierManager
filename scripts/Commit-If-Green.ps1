param(
    [Parameter(Mandatory = $true)]
    [string]$Message,

    [switch]$Push,

    [switch]$SkipReleaseGate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

function Invoke-Step([string]$Name, [scriptblock]$Action) {
    Write-Host "[CommitGuard] $Name..."
    & $Action
    if ($LASTEXITCODE -ne 0) {
        throw "$Name ist fehlgeschlagen mit Exitcode $LASTEXITCODE."
    }
}

if (-not $SkipReleaseGate) {
    Invoke-Step 'Release-Gate' { pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Invoke-ReleaseGate.ps1') }
}

Invoke-Step 'Git-Sicherheitspruefung vor Stage' { pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Test-GitCommitSafety.ps1') }

Invoke-Step 'git status vor add' { git status --short }

Invoke-Step 'git add --all' { git add --all }

Invoke-Step 'Git-Sicherheitspruefung nach Stage' { pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Test-GitCommitSafety.ps1') }

$Cached = @(git diff --cached --name-status)
if ($Cached.Count -eq 0) {
    Write-Host '[CommitGuard] Nichts zu committen.'
    exit 0
}

Write-Host '[CommitGuard] Dateien im Commit:'
foreach ($Line in $Cached) {
    Write-Host "  $Line"
}

Invoke-Step 'git commit' { git commit -m $Message }

if ($Push) {
    Invoke-Step 'git push' { git push }
}

Write-Host '[CommitGuard] Fertig.'