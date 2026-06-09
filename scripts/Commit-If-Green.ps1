param(
    [Parameter(Mandatory = $true)][string]$Message,
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [switch]$Push,
    [switch]$SkipPack
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$gate = Join-Path $PSScriptRoot 'Invoke-ReleaseGate.ps1'
if (-not (Test-Path -LiteralPath $gate)) {
    throw "Release-Gate-Script nicht gefunden: $gate"
}

& pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $gate -Root $Root -SkipPack:$SkipPack
if ($LASTEXITCODE -ne 0) {
    throw "Release-Gate ist fehlgeschlagen mit Exitcode $LASTEXITCODE. Commit wird abgebrochen."
}

Push-Location $Root
try {
    $statusBefore = git status --short
    if (-not $statusBefore) {
        Write-Host '[Commit-If-Green] Keine Änderungen zum Committen.'
        return
    }

    git add .
    if ($LASTEXITCODE -ne 0) { throw "git add ist fehlgeschlagen mit Exitcode $LASTEXITCODE." }

    git commit -m $Message
    if ($LASTEXITCODE -ne 0) { throw "git commit ist fehlgeschlagen mit Exitcode $LASTEXITCODE." }

    if ($Push) {
        git push
        if ($LASTEXITCODE -ne 0) { throw "git push ist fehlgeschlagen mit Exitcode $LASTEXITCODE." }
    } else {
        Write-Host '[Commit-If-Green] Commit erstellt. Push wurde nicht ausgefuehrt. Fuer Push erneut mit -Push ausfuehren oder git push nutzen.'
    }
} finally {
    Pop-Location
}
