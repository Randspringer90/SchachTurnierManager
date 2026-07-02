<#
.SYNOPSIS
    Erzeugt einen PUBLIC-Safety-Snapshot fuer SchachTurnierManager ohne Push.
#>
[CmdletBinding()]
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$ReportRoot = 'D:\KFM\_handoff'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$outDir = Join-Path $ReportRoot ("SchachTurnierManager_PublicSafety_{0}" -f $stamp)
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function Run-Step {
    param([string]$Name, [scriptblock]$Script)
    $path = Join-Path $outDir ("{0}.txt" -f $Name)
    try {
        & $Script *>&1 | Tee-Object -FilePath $path
        [pscustomobject]@{ name=$Name; exitCode=$LASTEXITCODE; ok=($LASTEXITCODE -eq 0); log=$path }
    } catch {
        $_ | Out-String | Set-Content -LiteralPath $path -Encoding UTF8
        [pscustomobject]@{ name=$Name; exitCode=99; ok=$false; log=$path }
    }
}

$results = [System.Collections.Generic.List[object]]::new()
$results.Add((Run-Step 'git_status' { git -C $ProjectRoot status --short --branch --untracked-files=all })) | Out-Null
$results.Add((Run-Step 'git_remote' { git -C $ProjectRoot remote -v })) | Out-Null
$results.Add((Run-Step 'git_diff_check' { git -C $ProjectRoot diff --check })) | Out-Null

foreach ($script in @('scripts\Test-RepositoryOpenSourceSafety.ps1','scripts\Test-GitCommitSafety.ps1','scripts\Invoke-ReleaseGate.ps1')) {
    $full = Join-Path $ProjectRoot $script
    if (Test-Path -LiteralPath $full) {
        $safeName = ($script -replace '[\\/.]','_')
        $results.Add((Run-Step $safeName { pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File $full })) | Out-Null
    }
}

$result = [pscustomobject]([ordered]@{
    generatedAt=(Get-Date).ToString('o')
    projectRoot=$ProjectRoot
    publicRepo=$true
    pushAllowed=$false
    reason='PUBLIC-Push nur nach expliziter Freigabe.'
    results=@($results)
})
$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $outDir 'public_safety_snapshot.json') -Encoding UTF8
@(
    '# SchachTurnierManager Public Safety Snapshot',
    '',
    '- Push erlaubt: **Nein**',
    ('- Report: `' + $outDir + '`'),
    '',
    '| Check | OK | Log |',
    '|---|---:|---|'
) + ($results | ForEach-Object { '| ' + $_.name + ' | ' + $_.ok + ' | `' + $_.log + '` |' }) | Set-Content -LiteralPath (Join-Path $outDir 'public_safety_snapshot.md') -Encoding UTF8
Write-Host "Report: $outDir"
Write-Host 'Kein Push ausgefuehrt.'
