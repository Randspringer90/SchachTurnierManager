$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot\.."
$fixedPaths = @(
    "src\SchachTurnierManager.WebApp\dist",
    "src\SchachTurnierManager.WebApp\node_modules",
    "src\SchachTurnierManager.WebApp\tsconfig.tsbuildinfo",
    "output",
    "tmp",
    "System.Object[]"
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

$logDirectory = Join-Path $root 'logs'
if (Test-Path -LiteralPath $logDirectory -PathType Container) {
    Get-ChildItem -LiteralPath $logDirectory -File -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin @('README.md', '.gitkeep') } |
        ForEach-Object {
            Remove-Item -LiteralPath $_.FullName -Force
            Write-Host "Entfernt: $($_.FullName)"
            $script:removed++
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
