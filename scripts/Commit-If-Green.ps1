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
function Normalize-GitPath([string]$Path) { return (($Path ?? '').Trim().Trim('"') -replace '\\', '/') }
function Get-WorktreeStatusItems {
    $lines = git -c core.quotepath=false status --porcelain=v1 --untracked-files=all
    foreach ($line in $lines) {
        if ($line.Length -lt 4) { continue }
        $status = $line.Substring(0,2)
        $payload = $line.Substring(3)
        if ($payload -like '* -> *') {
            $parts = $payload -split ' -> ', 2
            [pscustomobject]@{ Status = $status; Path = (Normalize-GitPath $parts[0]) }
            [pscustomobject]@{ Status = $status; Path = (Normalize-GitPath $parts[1]) }
        }
        else {
            [pscustomobject]@{ Status = $status; Path = (Normalize-GitPath $payload) }
        }
    }
}
function Add-SafeChangedFiles {
    $items = @(Get-WorktreeStatusItems)
    if ($items.Count -eq 0) { Write-Host '[CommitGuard] Keine geaenderten Dateien.'; return }

    Write-Host '[CommitGuard] Dateien vor Stage:'
    $items | ForEach-Object { Write-Host ("  {0} {1}" -f $_.Status, $_.Path) }

    $paths = @($items | ForEach-Object { $_.Path } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    if ($paths.Count -eq 0) { Write-Host '[CommitGuard] Keine stagebaren Pfade gefunden.'; return }

    Write-Host '[CommitGuard] Stage explizit gepruefter Pfade, kein git add --all:'
    $paths | ForEach-Object { Write-Host "  $_" }
    & git add -- @paths
    if ($LASTEXITCODE -ne 0) { throw "git add fuer gepruefte Pfade ist fehlgeschlagen mit Exitcode $LASTEXITCODE." }
}

Run-Step 'Release-Gate' { pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File '.\scripts\Invoke-ReleaseGate.ps1' }
Run-Step 'Git-Sicherheitspruefung vor Stage' { pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File '.\scripts\Test-GitCommitSafety.ps1' }

Write-Host '[CommitGuard] git status vor Stage...'
git status --short

Run-Step 'Explizites Staging gepruefter Dateien' { Add-SafeChangedFiles }
Run-Step 'Git-Sicherheitspruefung nach Stage' { pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File '.\scripts\Test-GitCommitSafety.ps1' -Staged }

Write-Host '[CommitGuard] Dateien im Commit:'
git diff --cached --name-status

$pending = git diff --cached --name-only
if (-not $pending) { Write-Host '[CommitGuard] Nichts zu committen.'; exit 0 }

Run-Step 'git commit' { git commit -m $Message }
if ($Push) { Run-Step 'git push' { git push } }
Write-Host '[CommitGuard] Fertig.'
