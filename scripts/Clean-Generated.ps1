$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot\.."
$paths = @(
    "src\SchachTurnierManager.WebApp\dist",
    "src\SchachTurnierManager.WebApp\node_modules",
    "src\SchachTurnierManager.WebApp\tsconfig.tsbuildinfo",
    "logs",
    "output",
    "tmp"
)
foreach ($relative in $paths) {
    $path = Join-Path $root $relative
    if (Test-Path $path) {
        Remove-Item -LiteralPath $path -Recurse -Force
        Write-Host "Entfernt: $path"
    }
}
