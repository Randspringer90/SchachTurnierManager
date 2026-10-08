# Shared helper for the readiness scripts.
#
# STM-FE-014 split the former src/main.tsx monolith into modules (app shell,
# lib helpers, feature components). Readiness checks care that a capability is
# present in the WebApp, not which file holds it, so they assert against a
# concatenated snapshot of the whole source tree instead of a single file.

function New-WebAppSourceSnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$WebAppRoot,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    $sourceRoot = Join-Path $WebAppRoot 'src'
    if (-not (Test-Path -LiteralPath $sourceRoot)) {
        throw "WebApp-Quellverzeichnis fehlt: $sourceRoot"
    }

    $files = @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -Include '*.ts', '*.tsx' |
        Sort-Object -Property FullName)
    if ($files.Count -eq 0) {
        throw "Keine TypeScript-Quellen unter $sourceRoot gefunden."
    }

    $builder = [System.Text.StringBuilder]::new()
    foreach ($file in $files) {
        $relative = $file.FullName.Substring($sourceRoot.Length).TrimStart('\', '/')
        [void]$builder.AppendLine("// ---- $relative ----")
        [void]$builder.AppendLine((Get-Content -Raw -LiteralPath $file.FullName))
    }

    $destinationDirectory = Split-Path -Parent $Destination
    if ($destinationDirectory -and -not (Test-Path -LiteralPath $destinationDirectory)) {
        New-Item -ItemType Directory -Force -Path $destinationDirectory | Out-Null
    }

    Set-Content -LiteralPath $Destination -Value $builder.ToString() -Encoding UTF8
    return $Destination
}
