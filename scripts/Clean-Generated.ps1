$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot\.."
$fixedPaths = @(
    "src\SchachTurnierManager.WebApp\dist",
    "src\SchachTurnierManager.WebApp\node_modules",
    "src\SchachTurnierManager.WebApp\tsconfig.tsbuildinfo",
    "logs",
    "output",
    "tmp"
)

$legacyBuildDirs = @()
foreach ($base in @('src', 'tests')) {
    $basePath = Join-Path $root $base
    if (Test-Path -LiteralPath $basePath) {
        $legacyBuildDirs += Get-ChildItem -LiteralPath $basePath -Directory -Recurse -Force |
            Where-Object { $_.Name -in @('bin', 'obj') } |
            ForEach-Object { $_.FullName }
    }
}

$removed = 0
foreach ($relative in $fixedPaths) {
    $path = Join-Path $root $relative
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Recurse -Force
        Write-Host "Entfernt: $path"
        $removed++
    }
}

foreach ($path in ($legacyBuildDirs | Sort-Object -Unique)) {
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Recurse -Force
        Write-Host "Entfernt: $path"
        $removed++
    }
}

Write-Host "Clean-Generated abgeschlossen. Entfernte Pfade: $removed"
