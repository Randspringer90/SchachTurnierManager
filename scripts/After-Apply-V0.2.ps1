$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot\.."
Set-Location $root
$tsBuildInfo = "src\SchachTurnierManager.WebApp\tsconfig.tsbuildinfo"
if (Test-Path $tsBuildInfo) {
    Remove-Item -LiteralPath $tsBuildInfo -Force
    Write-Host "Entfernt: $tsBuildInfo"
}
if (git ls-files --error-unmatch $tsBuildInfo 2>$null) {
    git rm --cached --ignore-unmatch $tsBuildInfo | Out-Host
    Write-Host "Aus Git-Index entfernt: $tsBuildInfo"
}
.\scripts\Test-All.ps1
Write-Host "v0.2-Nachkontrolle abgeschlossen. Bitte danach git status prüfen und committen."
