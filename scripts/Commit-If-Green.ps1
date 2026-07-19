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
function Test-IsCommitGuardLocalOnly([string]$Path) {
    $normalized = Normalize-GitPath $Path
    if ([string]::IsNullOrWhiteSpace($normalized)) { return $true }
    # NEXT_PROMPT.md ist ein lokales Handoff aus der externen Projekt-Registry und kann
    # Maschinenpfade/interne Blocker enthalten. Es wird nie automatisch committet.
    if ($normalized -match '^(?i:NEXT_PROMPT\.md)$') { return $true }
    return $false
}
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

    $paths = @($items | ForEach-Object { $_.Path } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and -not (Test-IsCommitGuardLocalOnly $_) } | Select-Object -Unique)
    if ($paths.Count -eq 0) { Write-Host '[CommitGuard] Keine stagebaren Pfade gefunden.'; return }

    $skipped = @($items | ForEach-Object { $_.Path } | Where-Object { Test-IsCommitGuardLocalOnly $_ } | Select-Object -Unique)
    if ($skipped.Count -gt 0) {
        Write-Host '[CommitGuard] Lokal-only/ignorierte Pfade werden nicht gestaged:'
        $skipped | ForEach-Object { Write-Host "  $_" }
    }

    # Bei einer Umbenennung liefert der Status alte und neue Seite. Ist die
    # Umbenennung bereits im Index (git mv), existiert die alte Seite weder im
    # Worktree noch im Index; git add bricht dann mit "pathspec did not match"
    # ab und es liesse sich ueberhaupt keine Umbenennung committen. Solche
    # bereits aufgeloesten Pfade werden hier verworfen, statt pauschal zu stagen.
    $addable = @($paths | Where-Object {
        if (Test-Path -LiteralPath $_) { return $true }
        & git ls-files --error-unmatch -- $_ 2>$null | Out-Null
        return ($LASTEXITCODE -eq 0)
    })
    $resolved = @($paths | Where-Object { $addable -notcontains $_ })
    if ($resolved.Count -gt 0) {
        Write-Host '[CommitGuard] Bereits im Index aufgeloeste Pfade (z. B. alte Seite einer Umbenennung):'
        $resolved | ForEach-Object { Write-Host "  $_" }
    }
    if ($addable.Count -eq 0) { Write-Host '[CommitGuard] Keine zusaetzlich stagebaren Pfade.'; return }

    Write-Host '[CommitGuard] Stage explizit gepruefter Pfade, kein git add --all:'
    $addable | ForEach-Object { Write-Host "  $_" }
    # -A gilt hier nur fuer die oben einzeln geprueften Pfade, nicht fuer den Baum,
    # erfasst aber auch Loeschungen (unstaged umbenannte Dateien).
    & git add -A -- @addable
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
