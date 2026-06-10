Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Write-Step {
    param([string]$Message)
    Write-Host "[v0.34.1] $Message"
}

function Read-Text {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $path = Join-Path $Root $RelativePath
    if (-not (Test-Path -LiteralPath $path)) { throw "Datei nicht gefunden: $RelativePath" }
    return [System.IO.File]::ReadAllText($path)
}

function Write-Text {
    param([Parameter(Mandatory = $true)][string]$RelativePath, [Parameter(Mandatory = $true)][string]$Content)
    $path = Join-Path $Root $RelativePath
    [System.IO.File]::WriteAllText($path, $Content, $Utf8NoBom)
}

function Set-TextFileUtf8NoBom {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $path = Join-Path $Root $RelativePath
    if (Test-Path -LiteralPath $path) {
        $content = [System.IO.File]::ReadAllText($path)
        [System.IO.File]::WriteAllText($path, $content, $Utf8NoBom)
        Write-Step "$RelativePath als UTF-8 ohne BOM gespeichert"
    }
}

function Replace-Version {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $text = Read-Text $RelativePath
    $updated = $text.Replace('0.34.0', '0.34.1')
    if ($updated -eq $text) {
        if ($text.Contains('0.34.1')) { Write-Step "$RelativePath ist bereits auf 0.34.1" }
        else { Write-Step "$RelativePath enthielt keine 0.34.0-Version mehr" }
    } else {
        Write-Text $RelativePath $updated
        Write-Step "$RelativePath auf 0.34.1 gesetzt"
    }
}

function Get-MethodSpan {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Signature
    )

    $start = $Text.IndexOf($Signature, [StringComparison]::Ordinal)
    if ($start -lt 0) { throw "Methodensignatur nicht gefunden: $Signature" }
    $braceStart = $Text.IndexOf('{', $start)
    if ($braceStart -lt 0) { throw "Oeffnende Klammer nicht gefunden: $Signature" }

    $depth = 0
    for ($i = $braceStart; $i -lt $Text.Length; $i++) {
        $ch = $Text[$i]
        if ($ch -eq '{') { $depth++ }
        elseif ($ch -eq '}') {
            $depth--
            if ($depth -eq 0) {
                return [pscustomobject]@{ Start = $start; End = $i + 1 }
            }
        }
    }

    throw "Schliessende Klammer nicht gefunden: $Signature"
}

function Ensure-AuditEntryBeforeStoreSave {
    param(
        [Parameter(Mandatory = $true)][string]$Signature,
        [Parameter(Mandatory = $true)][string]$Marker,
        [Parameter(Mandatory = $true)][string]$AuditLine,
        [Parameter(Mandatory = $true)][string]$Description
    )

    $relativePath = 'src/SchachTurnierManager.Application/TournamentService.cs'
    $text = Read-Text $relativePath
    $span = Get-MethodSpan -Text $text -Signature $Signature
    $method = $text.Substring($span.Start, $span.End - $span.Start)

    if ($method.Contains($Marker)) {
        Write-Step "$Description bereits vorhanden"
        return
    }

    $saveLine = '        _store.Save(tournament);'
    $saveIndex = $method.LastIndexOf($saveLine, [StringComparison]::Ordinal)
    if ($saveIndex -lt 0) { throw "_store.Save(tournament) nicht gefunden fuer $Description" }

    $lineEnding = if ($method.Contains("`r`n")) { "`r`n" } else { "`n" }
    $replacement = $AuditLine + $lineEnding + $saveLine
    $patchedMethod = $method.Substring(0, $saveIndex) + $replacement + $method.Substring($saveIndex + $saveLine.Length)
    $updated = $text.Substring(0, $span.Start) + $patchedMethod + $text.Substring($span.End)
    Write-Text $relativePath $updated
    Write-Step "$Description ergänzt"
}

function Ensure-ChangelogEntry {
    $relativePath = 'CHANGELOG.md'
    $text = Read-Text $relativePath
    if ($text.Contains('## 0.34.1')) {
        Write-Step 'CHANGELOG.md enthält 0.34.1 bereits'
        return
    }

    $entry = @'
## 0.34.1 - Audit Journal Round Review Fix

- Auditjournal-Einträge für `SetRoundLock` und `SetRoundVerified` ergänzt.
- Runden-Sperren, Entsperren, Prüfen und Zurücksetzen werden nun dauerhaft im Auditjournal protokolliert.
- Behebt den roten `AuditJournal_TracksManualCorrectionsAndRoundReview`-Regressionstest aus 0.34.0.
- Keine Änderung an Auslosungslogik, Wertungsberechnung oder UI.

'@

    $updated = if ($text.StartsWith("# Changelog")) {
        $text -replace '(^# Changelog\s*)', ("# Changelog`r`n`r`n" + $entry)
    } else {
        $entry + $text
    }
    Write-Text $relativePath $updated
    Write-Step 'CHANGELOG.md ergänzt'
}

function Invoke-Checked {
    param([Parameter(Mandatory = $true)][string]$Name, [Parameter(Mandatory = $true)][scriptblock]$Command)
    Write-Step "$Name..."
    & $Command
    if ($LASTEXITCODE -ne 0) { throw "$Name ist fehlgeschlagen mit Exitcode $LASTEXITCODE." }
}

try {
    Replace-Version 'src/SchachTurnierManager.WebApi/Program.cs'
    Replace-Version 'src/SchachTurnierManager.WebApp/package.json'
    Replace-Version 'src/SchachTurnierManager.WebApp/package-lock.json'
    Replace-Version 'src/SchachTurnierManager.WebApp/src/main.tsx'

    Ensure-AuditEntryBeforeStoreSave `
        -Signature 'public TournamentRound SetRoundLock(Guid tournamentId, int roundNumber, bool isLocked)' `
        -Marker 'AuditJournalAction.RoundLocked' `
        -AuditLine '        AddAuditEntry(tournament, isLocked ? AuditJournalAction.RoundLocked : AuditJournalAction.RoundUnlocked, AuditJournalSeverity.Warning, isLocked ? $"Runde {roundNumber} gesperrt." : $"Runde {roundNumber} entsperrt.", null, roundNumber: roundNumber);' `
        -Description 'Auditjournal: Runde sperren/entsperren'

    Ensure-AuditEntryBeforeStoreSave `
        -Signature 'public TournamentRound SetRoundVerified(Guid tournamentId, int roundNumber, bool isVerified)' `
        -Marker 'AuditJournalAction.RoundVerified' `
        -AuditLine '        AddAuditEntry(tournament, isVerified ? AuditJournalAction.RoundVerified : AuditJournalAction.RoundUnverified, AuditJournalSeverity.Warning, isVerified ? $"Runde {roundNumber} geprüft." : $"Runde {roundNumber} als ungeprüft markiert.", null, roundNumber: roundNumber);' `
        -Description 'Auditjournal: Runde prüfen/ungeprüft markieren'

    Ensure-ChangelogEntry

    $handoff = @'
# Handoff 0.34.1 - Audit Journal Round Review Fix

## Ziel

0.34.1 ist ein Fix-Forward für 0.34.0. Der Domain-/Application-Build war grün, aber der neue Auditjournal-Regressionstest `AuditJournal_TracksManualCorrectionsAndRoundReview` scheiterte, weil Sperren/Entsperren/Prüfen einer Runde zwar im bestehenden Rundenaudit landeten, aber nicht im neuen persistenten `TournamentState.AuditJournal`.

## Änderung

- `SetRoundLock(...)` schreibt jetzt `RoundLocked` bzw. `RoundUnlocked` in das persistente Auditjournal.
- `SetRoundVerified(...)` schreibt jetzt `RoundVerified` bzw. `RoundUnverified` in das persistente Auditjournal.
- Keine Änderung an Auslosungslogik, Wertungsberechnung, Speicherformat über das bereits in 0.34.0 eingeführte Auditjournal hinaus oder UI.

## Erwartung

- `dotnet test`: 81/81 grün.
- `npm run build`: grün.
- `Pack-Portable`: `SchachTurnierManager_Portable_0.34.1.zip`.
'@
    Write-Text 'docs/HANDOFF_0_34_1.md' $handoff
    Write-Step 'Handoff ergänzt'

    @(
        'CHANGELOG.md',
        'src/SchachTurnierManager.WebApi/Program.cs',
        'src/SchachTurnierManager.WebApp/package.json',
        'src/SchachTurnierManager.WebApp/package-lock.json',
        'src/SchachTurnierManager.WebApp/src/main.tsx',
        'src/SchachTurnierManager.Application/TournamentService.cs',
        'docs/HANDOFF_0_34_1.md',
        'scripts/After-Apply-V0.34.1.ps1'
    ) | ForEach-Object { Set-TextFileUtf8NoBom $_ }

    Invoke-Checked 'Release-Gate' { pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'scripts/Invoke-ReleaseGate.ps1') }
    Write-Step 'Nachkontrolle abgeschlossen. Aktueller Git-Status:'
    git -C $Root status --short
}
catch {
    Write-Error $_
    exit 1
}
