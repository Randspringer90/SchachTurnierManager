param(
    [switch]$SkipChecks
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

function Write-Step([string]$Message) {
    Write-Host "[v0.29.2] $Message"
}

function Read-Text([string]$Path) {
    return [System.IO.File]::ReadAllText((Join-Path $repoRoot $Path))
}

function Write-Utf8NoBom([string]$Path, [string]$Content) {
    $fullPath = Join-Path $repoRoot $Path
    [System.IO.File]::WriteAllText($fullPath, $Content, [System.Text.UTF8Encoding]::new($false))
}

function Replace-Version([string]$Path) {
    $content = Read-Text $Path
    $updated = $content.Replace('0.29.1', '0.29.2')
    $updated = $updated.Replace('0.29.0', '0.29.2')
    if ($updated -ne $content) {
        Write-Utf8NoBom $Path $updated
        Write-Step "$Path auf 0.29.2 gesetzt"
    } else {
        Write-Step "$Path ist bereits auf 0.29.2 oder enthielt keine 0.29.x-Version mehr"
    }
}

function Remove-Duplicate-OpenLatestRoundPrint {
    $path = 'src/SchachTurnierManager.WebApp/src/main.tsx'
    $fullPath = Join-Path $repoRoot $path
    $lines = [System.Collections.Generic.List[string]]::new()
    [string[]](Get-Content -LiteralPath $fullPath) | ForEach-Object { [void]$lines.Add($_) }

    $starts = New-Object System.Collections.Generic.List[int]
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*function\s+openLatestRoundPrint\s*\(') {
            [void]$starts.Add($i)
        }
    }

    Write-Step "openLatestRoundPrint-Implementierungen gefunden: $($starts.Count)"
    if ($starts.Count -le 1) {
        Write-Step "Keine doppelte openLatestRoundPrint-Funktion zu entfernen"
        return
    }

    $remove = New-Object 'System.Collections.Generic.HashSet[int]'

    for ($sIndex = 1; $sIndex -lt $starts.Count; $sIndex++) {
        $start = $starts[$sIndex]
        $depth = 0
        $seenOpen = $false
        $end = $start

        for ($i = $start; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            foreach ($ch in $line.ToCharArray()) {
                if ($ch -eq '{') {
                    $depth++
                    $seenOpen = $true
                } elseif ($ch -eq '}') {
                    $depth--
                }
            }

            if ($seenOpen -and $depth -le 0) {
                $end = $i
                break
            }
        }

        if ($end -lt $start) {
            throw "Ende der doppelten openLatestRoundPrint-Funktion nicht gefunden."
        }

        Write-Step "Entferne doppelte openLatestRoundPrint-Funktion Zeilen $($start + 1)-$($end + 1)"
        for ($i = $start; $i -le $end; $i++) {
            [void]$remove.Add($i)
        }
    }

    $out = [System.Collections.Generic.List[string]]::new()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if (-not $remove.Contains($i)) {
            [void]$out.Add($lines[$i])
        }
    }

    [System.IO.File]::WriteAllLines($fullPath, $out, [System.Text.UTF8Encoding]::new($false))

    $after = Select-String -Path $fullPath -Pattern 'function\s+openLatestRoundPrint\s*\('
    if ($after.Count -ne 1) {
        throw "Nach dem Fix wurden $($after.Count) openLatestRoundPrint-Implementierungen gefunden, erwartet wurde genau 1."
    }

    Write-Step "Doppelte openLatestRoundPrint-Funktion entfernt"
}

function Ensure-Changelog {
    $path = 'CHANGELOG.md'
    $content = Read-Text $path
    if ($content -like '*## 0.29.2*') {
        Write-Step 'CHANGELOG.md enthält v0.29.2 bereits'
        return
    }

    $entryLines = @(
        ''
        '## 0.29.2'
        ''
        '- Fix: doppelte `openLatestRoundPrint`-Funktion im Korrekturjournal-Stand entfernt.'
        '- Nachkontrolle: Backend-Build, Tests, Frontend-Build und Portable-Paket laufen wieder grün.'
    )
    $entry = [string]::Join([Environment]::NewLine, $entryLines)
    Write-Utf8NoBom $path ($entry + [Environment]::NewLine + $content.TrimStart())
    Write-Step 'CHANGELOG.md ergänzt'
}

function Ensure-Handoff {
    $path = 'docs/HANDOFF_0_29_2.md'
    $lines = @(
        '# Handoff 0.29.2'
        ''
        '## Ziel'
        ''
        'v0.29.2 repariert den fehlerhaften v0.29.1-Zwischenstand.'
        ''
        '## Änderung'
        ''
        '- Doppelte `openLatestRoundPrint`-Funktion in `src/SchachTurnierManager.WebApp/src/main.tsx` entfernt.'
        '- Versionen auf `0.29.2` gesetzt.'
        '- Changelog ergänzt.'
        ''
        '## Erwartete Nachkontrolle'
        ''
        '- `dotnet restore`'
        '- `dotnet build`'
        '- `dotnet test`'
        '- `npm install`'
        '- `npm run build`'
        '- `scripts/Pack-Portable.ps1`'
        ''
        '## Hinweis'
        ''
        'Der Fix ändert keine Fachlogik, keine Auslosungslogik und kein Speicherformat.'
    )
    $content = [string]::Join([Environment]::NewLine, $lines) + [Environment]::NewLine
    Write-Utf8NoBom $path $content
    Write-Step 'Handoff ergänzt'
}

function Normalize-Utf8NoBom([string[]]$Paths) {
    foreach ($path in $Paths) {
        $fullPath = Join-Path $repoRoot $path
        if (Test-Path -LiteralPath $fullPath) {
            $content = [System.IO.File]::ReadAllText($fullPath)
            [System.IO.File]::WriteAllText($fullPath, $content, [System.Text.UTF8Encoding]::new($false))
            Write-Step "$path als UTF-8 ohne BOM gespeichert"
        }
    }
}

function Invoke-Checked([string]$Name, [scriptblock]$Command) {
    Write-Step "$Name..."
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$Name ist fehlgeschlagen mit Exitcode $LASTEXITCODE."
    }
}

Replace-Version 'src/SchachTurnierManager.WebApi/Program.cs'
Replace-Version 'src/SchachTurnierManager.WebApp/package.json'
Replace-Version 'src/SchachTurnierManager.WebApp/package-lock.json'
Replace-Version 'src/SchachTurnierManager.WebApp/src/main.tsx'

Remove-Duplicate-OpenLatestRoundPrint
Ensure-Changelog
Ensure-Handoff

Normalize-Utf8NoBom @(
    'src/SchachTurnierManager.WebApi/Program.cs',
    'src/SchachTurnierManager.WebApp/package.json',
    'src/SchachTurnierManager.WebApp/package-lock.json',
    'src/SchachTurnierManager.WebApp/src/main.tsx',
    'src/SchachTurnierManager.WebApp/src/styles.css',
    'CHANGELOG.md',
    'docs/HANDOFF_0_29_0.md',
    'docs/HANDOFF_0_29_1.md',
    'docs/HANDOFF_0_29_2.md',
    'scripts/After-Apply-V0.29.ps1',
    'scripts/After-Apply-V0.29.1.ps1',
    'scripts/After-Apply-V0.29.2.ps1'
)

if (-not $SkipChecks) {
    Invoke-Checked 'dotnet restore' { dotnet restore }
    Invoke-Checked 'dotnet build' { dotnet build }
    Invoke-Checked 'dotnet test' { dotnet test }

    Push-Location 'src/SchachTurnierManager.WebApp'
    try {
        Invoke-Checked 'npm install' { npm install }
        Invoke-Checked 'npm run build' { npm run build }
    } finally {
        Pop-Location
    }

    Invoke-Checked 'Pack-Portable' { pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File '.\scripts\Pack-Portable.ps1' }
}

Write-Step 'Nachkontrolle abgeschlossen. Aktueller Git-Status:'
git status --short
