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