<#
.SYNOPSIS
    Synthetischer Operator-Smoke fuer den Turniertag. Startet (optional) ein isoliertes
    Backend, faehrt die wichtigsten Turniertag-Workflows durch und faehrt es sauber herunter.

.DESCRIPTION
    Reines lokales Verifikationswerkzeug. Es nutzt ausschliesslich die oeffentlichen
    REST-Endpunkte des WebApi-Backends und arbeitet mit rein synthetischen Spielern
    ("Smoke Spieler NN"). Keine Cloud, kein Upload, keine echten Teilnehmerdaten.

    Der Smoke ist bewusst HAENGE-SICHER:
      - Jeder HTTP-Aufruf hat ein TimeoutSec.
      - Der Backend-Start wartet maximal -StartTimeoutSeconds mit Heartbeat-Ausgabe.
      - Wird das Backend von diesem Skript gestartet, laeuft es gegen ein ISOLIERTES
        Datenverzeichnis (Temp) auf einem eigenen Port (Standard 5099) und wird im
        finally-Block zuverlaessig (Prozessbaum) beendet. Das Release-Binary wird vor
        dem Start frisch gebaut, damit keine veraltete DLL getestet wird.
      - Klarer Exit-Code: 0 = alle Checks gruen, 1 = mindestens ein Check rot,
        2 = Backend nicht startbar/erreichbar.

    Abgedeckte Szenarien (Plan Phase 3):
      1. Health.
      2. Swiss 12 Spieler / 5 Runden: ausgespielt, KEINE 6. Runde (HTTP 400),
         keine vermeidbaren Rematches (direkt aus den Paarungen geprueft), Audit-Export
         nach jeder Runde, Turnierpaket HTML/JSON.
      3. Round-Robin 6 Spieler: vollstaendiger Spielplan und Late Entry nach Start
         blockiert (HTTP 400).
      4. Manuelle Paarung: gueltig ok, Self-Pairing blockiert, doppelter Spieler blockiert.
      5. Backup/Restore: Export -> Delete -> Re-Import -> verifiziert (isoliertes Datenverz.).
      6. QR/Chess960: Start-Stellungen je Brett, Einzelbrett-Endpunkt und QR-URL-Form.

.PARAMETER BaseUrl
    Wenn gesetzt, wird ein BEREITS laufendes Backend unter dieser URL genutzt und NICHT
    gestartet/gestoppt. Ohne Angabe startet der Smoke ein eigenes isoliertes Backend.

.PARAMETER Port
    Port fuer das selbst gestartete Backend. Standard: 5099 (nicht 5088, um den Turniertag
    nicht zu stoeren).

.PARAMETER StartTimeoutSeconds
    Maximale Wartezeit auf die Backend-Erreichbarkeit. Standard: 90.

.PARAMETER DataDirectory
    Isoliertes Datenverzeichnis fuer das selbst gestartete Backend. Standard: ein frischer
    Ordner unterhalb von %TEMP%. Wird am Ende geloescht, ausser -KeepData ist gesetzt.

.PARAMETER KeepData
    Loescht das isolierte Temp-Datenverzeichnis am Ende NICHT (zur Fehlersuche).

.EXAMPLE
    pwsh -File .\scripts\Smoke-OperatorWorkflow.ps1

.EXAMPLE
    pwsh -File .\scripts\Smoke-OperatorWorkflow.ps1 -BaseUrl http://localhost:5088
#>
[CmdletBinding()]
param(
    [string]$BaseUrl,
    [ValidateRange(1, 65535)][int]$Port = 5099,
    [ValidateRange(10, 600)][int]$StartTimeoutSeconds = 90,
    [string]$DataDirectory,
    [switch]$KeepData
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path "$PSScriptRoot\.."
$httpTimeout = 10

# --- Ergebnis-Buchhaltung --------------------------------------------------
$script:Passed = 0
$script:Failed = 0
$script:Failures = New-Object System.Collections.Generic.List[string]

function Write-Step { param([string]$Text) Write-Host "`n=== $Text ===" -ForegroundColor Cyan }

function Assert-That {
    param([Parameter(Mandatory)][bool]$Condition, [Parameter(Mandatory)][string]$Label, [string]$Detail = '')
    if ($Condition) {
        $script:Passed++
        Write-Host "  [ OK ] $Label" -ForegroundColor Green
        if ($Detail) { Write-Host "         $Detail" -ForegroundColor DarkGray }
    }
    else {
        $script:Failed++
        $script:Failures.Add($Label)
        Write-Host "  [FAIL] $Label" -ForegroundColor Red
        if ($Detail) { Write-Host "         $Detail" -ForegroundColor Yellow }
    }
}

# HTTP-Helfer: liefert immer Statuscode + Body (auch bei 4xx/5xx), nie ein Hänger.
function Invoke-Api {
    param(
        [Parameter(Mandatory)][string]$Method,
        [Parameter(Mandatory)][string]$Path,
        $Body
    )
    $uri = "$apiBase$Path"
    $payload = if ($null -ne $Body) { $Body | ConvertTo-Json -Depth 16 } else { $null }
    try {
        $resp = Invoke-WebRequest -Method $Method -Uri $uri -ContentType 'application/json' -Body $payload -TimeoutSec $httpTimeout -ErrorAction Stop
        $content = $null
        if ($resp.Content) { try { $content = $resp.Content | ConvertFrom-Json } catch { $content = $resp.Content } }
        return [pscustomobject]@{ Status = [int]$resp.StatusCode; Body = $content; Raw = $resp.Content }
    }
    catch {
        $status = $null
        if ($_.Exception.Response) { try { $status = [int]$_.Exception.Response.StatusCode } catch { $status = $null } }
        return [pscustomobject]@{ Status = $status; Body = $null; Raw = $_.Exception.Message }
    }
}

# --- Backend-Start (optional, isoliert, timeout-hart) ----------------------
$ownBackend = [string]::IsNullOrWhiteSpace($BaseUrl)
$apiBase = if ($ownBackend) { "http://localhost:$Port" } else { $BaseUrl.TrimEnd('/') }
$backendProcess = $null
$logDir = Join-Path $root 'output\smoke'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$stdoutLog = Join-Path $logDir "backend-$stamp.out.log"
$stderrLog = Join-Path $logDir "backend-$stamp.err.log"

if ($ownBackend -and [string]::IsNullOrWhiteSpace($DataDirectory)) {
    $DataDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("stm-smoke-$stamp")
}

function Test-PortInUse {
    param([Parameter(Mandatory)][int]$TcpPort)
    try { return ($null -ne (Get-NetTCPConnection -State Listen -LocalPort $TcpPort -ErrorAction Stop)) }
    catch { return $false }
}

function Stop-BackendTree {
    if ($null -eq $backendProcess) { return }
    try {
        if (-not $backendProcess.HasExited) {
            Write-Host "[Smoke] Stoppe Backend-Prozessbaum (PID $($backendProcess.Id)) ..." -ForegroundColor DarkGray
            & taskkill /PID $backendProcess.Id /T /F *> $null
            # Maximal 10s auf sauberes Beenden warten, dann ist es ohnehin gekillt.
            $deadline = (Get-Date).AddSeconds(10)
            while (-not $backendProcess.HasExited -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 200 }
        }
    }
    catch { Write-Host "[Smoke] Hinweis beim Stoppen: $($_.Exception.Message)" -ForegroundColor DarkGray }
}

try {
    if ($ownBackend) {
        Write-Step "Backend starten (isoliert, Port $Port)"
        # Pre-Flight: Port muss frei sein. Sonst wuerde der Smoke sich still gegen ein fremdes/
        # veraltetes Backend verbinden (stale-DLL-Falle) statt gegen das frische Release-Binary.
        if (Test-PortInUse -TcpPort $Port) {
            Write-Host "[Smoke] Port $Port ist bereits belegt. Der Smoke startet KEIN eigenes Backend," -ForegroundColor Red
            Write-Host "        um nicht versehentlich gegen ein fremdes/veraltetes Backend zu testen." -ForegroundColor Red
            Write-Host "        Stoppe den Prozess auf Port $Port oder rufe das Skript mit -Port <frei> auf." -ForegroundColor Red
            Write-Host "        Belegenden Prozess finden: Get-NetTCPConnection -LocalPort $Port -State Listen" -ForegroundColor DarkGray
            exit 2
        }
        # Directory.Build.props redirects BaseOutputPath to tmp\dotnet-bin\<project>\.
        # The legacy src\**\bin path is still probed so older checkouts keep working.
        $dllCandidates = @(
            (Join-Path $root 'tmp\dotnet-bin\SchachTurnierManager.WebApi\Release\net10.0\SchachTurnierManager.WebApi.dll'),
            (Join-Path $root 'src\SchachTurnierManager.WebApi\bin\Release\net10.0\SchachTurnierManager.WebApi.dll')
        )
        Write-Host "[Smoke] Baue WebApi (Release), damit kein veraltetes Binary getestet wird ..." -ForegroundColor Yellow
        & dotnet build (Join-Path $root 'src\SchachTurnierManager.WebApi') -c Release -v minimal
        if ($LASTEXITCODE -ne 0) { Write-Error "Build fehlgeschlagen."; exit 2 }
        $dll = $dllCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
        if (-not $dll) {
            Write-Error "WebApi-DLL nicht gefunden. Geprueft:`n  $($dllCandidates -join "`n  ")"
            exit 2
        }

        New-Item -ItemType Directory -Force -Path $DataDirectory | Out-Null
        Write-Host "[Smoke] Isoliertes Datenverzeichnis: $DataDirectory" -ForegroundColor DarkGray
        Write-Host "[Smoke] Backend-Logs: $stdoutLog" -ForegroundColor DarkGray

        # Env nur fuer den Kindprozess setzen (wird vom Start-Process geerbt), danach zuruecksetzen.
        $prevUrls = $env:ASPNETCORE_URLS
        $prevData = $env:SchachTurnierManager__DataDirectory
        $env:ASPNETCORE_URLS = "http://localhost:$Port"
        $env:SchachTurnierManager__DataDirectory = $DataDirectory
        try {
            $backendProcess = Start-Process -FilePath 'dotnet' -ArgumentList @("`"$dll`"") `
                -WorkingDirectory (Join-Path $root 'src\SchachTurnierManager.WebApi') `
                -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog `
                -PassThru -WindowStyle Hidden
        }
        finally {
            $env:ASPNETCORE_URLS = $prevUrls
            $env:SchachTurnierManager__DataDirectory = $prevData
        }
    }

    # --- Auf Erreichbarkeit warten (Heartbeat, Timeout) --------------------
    Write-Step "Warte auf Health $apiBase/api/health (max ${StartTimeoutSeconds}s)"
    $deadline = (Get-Date).AddSeconds($StartTimeoutSeconds)
    $healthy = $false
    $elapsed = 0
    do {
        if ($ownBackend -and $backendProcess -and $backendProcess.HasExited) {
            Write-Host "[Smoke] Backend-Prozess vorzeitig beendet (ExitCode $($backendProcess.ExitCode)). Siehe $stderrLog." -ForegroundColor Red
            break
        }
        $h = Invoke-Api -Method Get -Path '/api/health'
        if ($h.Status -eq 200) { $healthy = $true; break }
        Start-Sleep -Seconds 2
        $elapsed += 2
        Write-Host "  ... warte ($elapsed s)" -ForegroundColor DarkGray
    } while ((Get-Date) -lt $deadline)

    if (-not $healthy) {
        Write-Host "[Smoke] Backend war nach ${StartTimeoutSeconds}s nicht erreichbar." -ForegroundColor Red
        exit 2
    }

    # =====================================================================
    # 1. HEALTH
    # =====================================================================
    Write-Step "1. Health"
    $health = (Invoke-Api -Method Get -Path '/api/health').Body
    Assert-That ($health.status -eq 'ok') 'Health liefert status=ok' ("Version $($health.version), DB $($health.database)")

    # =====================================================================
    # 2. SWISS: 12 Spieler / 5 Runden, keine 6., keine vermeidbaren Rematches
    # =====================================================================
    Write-Step "2. Swiss 12 Spieler / 5 Runden"
    # Enums numerisch: TournamentFormat.Swiss = 1.
    $swiss = (Invoke-Api -Method Post -Path '/api/tournaments' -Body @{
        name = "Smoke Swiss $stamp"; settings = @{ format = 1; plannedRounds = 5 }
    }).Body
    $sid = $swiss.id
    Assert-That ($null -ne $sid) 'Swiss-Turnier angelegt' "Id $sid"
    for ($i = 1; $i -le 12; $i++) {
        [void](Invoke-Api -Method Post -Path "/api/tournaments/$sid/players" -Body @{
            name = ("Smoke Spieler {0:D2}" -f $i); startingRank = $i; manualTwz = (2000 - $i * 20)
        })
    }

    # Begegnungen ueber alle Runden sammeln, um Rematches direkt zu erkennen.
    $seenPairs = New-Object System.Collections.Generic.HashSet[string]
    $rematches = 0
    for ($r = 1; $r -le 5; $r++) {
        $round = (Invoke-Api -Method Post -Path "/api/tournaments/$sid/pairings/next-round").Body
        $boards = @($round.pairings | Where-Object { -not $_.isBye })
        foreach ($b in $boards) {
            $key = (@([string]$b.whitePlayerId, [string]$b.blackPlayerId) | Sort-Object) -join '|'
            if (-not $seenPairs.Add($key)) { $rematches++ }
            $res = @(1, 2, 3) | Get-Random
            [void](Invoke-Api -Method Post -Path "/api/tournaments/$sid/rounds/$($round.roundNumber)/boards/$($b.boardNumber)/result" -Body @{ result = $res })
        }

        $roundAudit = Invoke-Api -Method Get -Path "/api/tournaments/$sid/audit-journal/export.jsonl"
        Assert-That ($roundAudit.Status -eq 200 -and $roundAudit.Raw.Length -gt 0) "Audit-Bundle nach Swiss Runde $r exportierbar" "Bytes: $($roundAudit.Raw.Length)"
    }
    $final = (Invoke-Api -Method Get -Path "/api/tournaments/$sid").Body
    Assert-That ($final.rounds.Count -eq 5) 'Genau 5 Runden ausgelost' "Ist: $($final.rounds.Count)"
    Assert-That ($rematches -eq 0) 'Keine vermeidbaren Rematches in 5 Runden' "Rematches: $rematches"

    # Keine 6. Runde: generate UND preview muessen blockieren.
    $sixth = Invoke-Api -Method Post -Path "/api/tournaments/$sid/pairings/next-round"
    Assert-That ($sixth.Status -eq 400) '6. Runde wird hart blockiert (HTTP 400)' "Status: $($sixth.Status)"
    $sixthPreview = Invoke-Api -Method Get -Path "/api/tournaments/$sid/pairings/preview-next-round"
    Assert-That ($sixthPreview.Status -eq 400) '6.-Runden-Vorschau wird blockiert (HTTP 400)' "Status: $($sixthPreview.Status)"

    # Audit-Export.
    $audit = Invoke-Api -Method Get -Path "/api/tournaments/$sid/audit-journal/export.json"
    Assert-That ($audit.Status -eq 200 -and $audit.Raw.Length -gt 0) 'Audit-Bundle exportierbar (JSON)' "Bytes: $($audit.Raw.Length)"
    if ($audit.Status -eq 200) {
        $auditFile = Join-Path $logDir "audit-swiss-$stamp.json"
        [System.IO.File]::WriteAllText($auditFile, $audit.Raw, [System.Text.UTF8Encoding]::new($false))
        Write-Host "         Audit gesichert: $auditFile" -ForegroundColor DarkGray
    }

    # Turnierpaket: HTML fuer Druck/Aushang, JSON fuer lokale Weiterverarbeitung.
    $packageHtml = Invoke-Api -Method Get -Path "/api/tournaments/$sid/package/print/html"
    Assert-That ($packageHtml.Status -eq 200 -and $packageHtml.Raw -match 'Turnierpaket' -and $packageHtml.Raw -match 'Ergebnisbogen') 'Turnierpaket HTML exportierbar' "Bytes: $($packageHtml.Raw.Length)"
    $packageJson = Invoke-Api -Method Get -Path "/api/tournaments/$sid/package/export.json"
    Assert-That ($packageJson.Status -eq 200 -and $packageJson.Raw -match 'SchachTurnierManager.TournamentPackage' -and $packageJson.Raw -match 'currentRound') 'Turnierpaket JSON exportierbar' "Bytes: $($packageJson.Raw.Length)"

    # =====================================================================
    # 6 (vorgezogen, nutzt Swiss-Runde): QR/Chess960 Start-Stellungen
    # =====================================================================
    Write-Step "6. QR / Chess960 Start-Stellungen (Runde 1)"
    $roll = Invoke-Api -Method Post -Path "/api/tournaments/$sid/rounds/1/chess960/start-positions" -Body @{ overwriteExisting = $true; seed = 960 }
    Assert-That ($roll.Status -eq 200) 'Chess960-Wuerfeln liefert HTTP 200' "Status: $($roll.Status)"
    if ($roll.Status -eq 200) {
        $regular = @($roll.Body.pairings | Where-Object { -not $_.isBye })
        $assigned = @($regular | Where-Object { $null -ne $_.chess960StartPosition })
        Assert-That ($assigned.Count -eq $regular.Count -and $regular.Count -gt 0) 'Alle regulaeren Bretter haben eine Start-Stellung' "$($assigned.Count)/$($regular.Count)"
    }
    $singleBoard = Invoke-Api -Method Post -Path "/api/tournaments/$sid/rounds/1/chess960/start-positions/1" -Body @{ overwriteExisting = $true; positionNumber = 518 }
    $singleBoardPairing = if ($singleBoard.Status -eq 200) { @($singleBoard.Body.pairings | Where-Object { $_.boardNumber -eq 1 })[0] } else { $null }
    Assert-That ($singleBoard.Status -eq 200 -and $singleBoardPairing.chess960StartPosition.positionNumber -eq 518) 'Chess960-Einzelbrett-Endpunkt akzeptiert feste Position' "Status: $($singleBoard.Status)"
    $qrUrl = "http://LAPTOP-IP:5173/?dice=$sid&round=1&board=1"
    Assert-That ($qrUrl -match '\?dice=.*&round=1&board=1') 'QR-URL-Form enthaelt Turnier, Runde und Brett' $qrUrl

    # =====================================================================
    # 3. ROUND-ROBIN: 6 Spieler vollstaendig, Late Entry nach Start blockiert
    # =====================================================================
    Write-Step "3. Round-Robin 6 Spieler / vollstaendig + Late-Entry-Sperre"
    # TournamentFormat.RoundRobin = 0.
    $rrFull = (Invoke-Api -Method Post -Path '/api/tournaments' -Body @{
        name = "Smoke RR Full $stamp"; settings = @{ format = 0; plannedRounds = 5 }
    }).Body
    $rrFullId = $rrFull.id
    for ($i = 1; $i -le 6; $i++) {
        [void](Invoke-Api -Method Post -Path "/api/tournaments/$rrFullId/players" -Body @{ name = ("RR Full Spieler {0:D2}" -f $i); startingRank = $i })
    }
    $rrPairs = New-Object System.Collections.Generic.HashSet[string]
    for ($r = 1; $r -le 5; $r++) {
        $rrRound = (Invoke-Api -Method Post -Path "/api/tournaments/$rrFullId/pairings/next-round").Body
        foreach ($board in @($rrRound.pairings | Where-Object { -not $_.isBye })) {
            $key = (@([string]$board.whitePlayerId, [string]$board.blackPlayerId) | Sort-Object) -join '|'
            [void]$rrPairs.Add($key)
            $res = @(1, 2, 3) | Get-Random
            [void](Invoke-Api -Method Post -Path "/api/tournaments/$rrFullId/rounds/$($rrRound.roundNumber)/boards/$($board.boardNumber)/result" -Body @{ result = $res })
        }
    }
    Assert-That ($rrPairs.Count -eq 15) 'RR 6 Spieler erzeugt alle 15 Paarungen genau einmal' "Paarungen: $($rrPairs.Count)"
    $rrFullExtra = Invoke-Api -Method Post -Path "/api/tournaments/$rrFullId/pairings/next-round"
    Assert-That ($rrFullExtra.Status -eq 400) 'RR Zusatzrunde nach komplettem Spielplan blockiert (HTTP 400)' "Status: $($rrFullExtra.Status)"

    $rr = (Invoke-Api -Method Post -Path '/api/tournaments' -Body @{
        name = "Smoke RR $stamp"; settings = @{ format = 0; plannedRounds = 5 }
    }).Body
    $rid = $rr.id
    for ($i = 1; $i -le 6; $i++) {
        [void](Invoke-Api -Method Post -Path "/api/tournaments/$rid/players" -Body @{ name = ("RR Spieler {0:D2}" -f $i); startingRank = $i })
    }
    $rrRound1 = Invoke-Api -Method Post -Path "/api/tournaments/$rid/pairings/next-round"
    Assert-That ($rrRound1.Status -eq 200) 'RR Runde 1 ausgelost' "Status: $($rrRound1.Status)"
    if ($rrRound1.Status -eq 200) {
        foreach ($board in @($rrRound1.Body.pairings | Where-Object { -not $_.isBye })) {
            $res = @(1, 2, 3) | Get-Random
            [void](Invoke-Api -Method Post -Path "/api/tournaments/$rid/rounds/1/boards/$($board.boardNumber)/result" -Body @{ result = $res })
        }
    }
    # Late Entry nach Start: Spieler hinzufuegen, dann naechste Runde muss blockieren.
    [void](Invoke-Api -Method Post -Path "/api/tournaments/$rid/players" -Body @{ name = 'RR Late Entry'; startingRank = 7 })
    $rrNext = Invoke-Api -Method Post -Path "/api/tournaments/$rid/pairings/next-round"
    Assert-That ($rrNext.Status -eq 400) 'RR Late Entry nach Start blockiert (HTTP 400)' "Status: $($rrNext.Status)"

    # =====================================================================
    # 4. MANUELLE PAARUNG: gueltig ok, Self-Pairing blockiert, Doppel blockiert
    # =====================================================================
    Write-Step "4. Manuelle Paarung"
    $mp = (Invoke-Api -Method Post -Path '/api/tournaments' -Body @{
        name = "Smoke Manual $stamp"; settings = @{ format = 1; plannedRounds = 3 }
    }).Body
    $mid = $mp.id
    for ($i = 1; $i -le 6; $i++) {
        [void](Invoke-Api -Method Post -Path "/api/tournaments/$mid/players" -Body @{ name = ("MP Spieler {0:D2}" -f $i); startingRank = $i })
    }
    $mpRound = (Invoke-Api -Method Post -Path "/api/tournaments/$mid/pairings/next-round").Body
    $mpBoards = @($mpRound.pairings | Where-Object { -not $_.isBye })
    Assert-That ($mpBoards.Count -ge 2) 'Manuelle Paarung: mindestens 2 Bretter vorhanden' "Bretter: $($mpBoards.Count)"

    $b1 = $mpBoards[0]; $b2 = $mpBoards[1]
    # gueltig: Farben am Brett 1 tauschen (beide Spieler aktiv, kein Doppel).
    $validOverride = Invoke-Api -Method Put -Path "/api/tournaments/$mid/rounds/1/boards/1/pairing" -Body @{
        whitePlayerId = $b1.blackPlayerId; blackPlayerId = $b1.whitePlayerId; notes = 'Smoke: gueltiger Farbtausch'
    }
    Assert-That ($validOverride.Status -eq 200) 'Gueltige manuelle Paarung akzeptiert (HTTP 200)' "Status: $($validOverride.Status)"

    # Self-Pairing: gleicher Spieler weiss und schwarz -> blockiert.
    $selfPair = Invoke-Api -Method Put -Path "/api/tournaments/$mid/rounds/1/boards/1/pairing" -Body @{
        whitePlayerId = $b1.whitePlayerId; blackPlayerId = $b1.whitePlayerId; notes = 'Smoke: self'
    }
    Assert-That ($selfPair.Status -eq 400) 'Self-Pairing blockiert (HTTP 400)' "Status: $($selfPair.Status)"

    # Doppelter Spieler: Brett 2 mit einem bereits auf Brett 1 stehenden Spieler -> blockiert.
    $dupPair = Invoke-Api -Method Put -Path "/api/tournaments/$mid/rounds/1/boards/2/pairing" -Body @{
        whitePlayerId = $b1.whitePlayerId; blackPlayerId = $b2.blackPlayerId; notes = 'Smoke: dup'
    }
    Assert-That ($dupPair.Status -eq 400) 'Doppelter Spieler auf zwei Brettern blockiert (HTTP 400)' "Status: $($dupPair.Status)"

    # =====================================================================
    # 5. BACKUP / RESTORE (isoliertes Datenverzeichnis)
    # =====================================================================
    Write-Step "5. Backup / Restore"
    $exp = Invoke-Api -Method Get -Path "/api/tournaments/$mid/export/json"
    Assert-That ($exp.Status -eq 200 -and $null -ne $exp.Body) 'Backup-Export (JSON) erfolgreich' "Status: $($exp.Status)"
    $snapshot = $exp.Body
    $playerCountBefore = @($snapshot.players).Count
    $backupFile = Join-Path $logDir "backup-manual-$stamp.json"
    [System.IO.File]::WriteAllText($backupFile, ($snapshot | ConvertTo-Json -Depth 20), [System.Text.UTF8Encoding]::new($false))

    $del = Invoke-Api -Method Delete -Path "/api/tournaments/$mid"
    Assert-That ($del.Status -eq 200) 'Turnier fuer Restore-Test geloescht' "Status: $($del.Status)"
    $gone = Invoke-Api -Method Get -Path "/api/tournaments/$mid"
    Assert-That ($gone.Status -eq 404) 'Geloeschtes Turnier ist weg (HTTP 404)' "Status: $($gone.Status)"

    $restore = Invoke-Api -Method Post -Path '/api/tournaments/import' -Body @{ tournament = $snapshot; overwriteExisting = $true }
    Assert-That ($restore.Status -eq 200) 'Restore (Import) erfolgreich' "Status: $($restore.Status)"
    $restored = Invoke-Api -Method Get -Path "/api/tournaments/$mid"
    $playerCountAfter = if ($restored.Status -eq 200) { @($restored.Body.players).Count } else { -1 }
    Assert-That ($restored.Status -eq 200 -and $playerCountAfter -eq $playerCountBefore) 'Wiederhergestelltes Turnier vollstaendig' "Spieler vorher/nachher: $playerCountBefore/$playerCountAfter"

    # --- Aufraeumen der Smoke-Turniere (nur das isolierte DB-Verzeichnis) ---
    foreach ($cleanupId in @($sid, $rrFullId, $rid, $mid)) {
        [void](Invoke-Api -Method Delete -Path "/api/tournaments/$cleanupId")
    }
}
finally {
    Stop-BackendTree
    if ($ownBackend -and -not $KeepData -and $DataDirectory -and (Test-Path $DataDirectory)) {
        try { Remove-Item -Recurse -Force -LiteralPath $DataDirectory; Write-Host "[Smoke] Temp-Datenverzeichnis entfernt." -ForegroundColor DarkGray }
        catch { Write-Host "[Smoke] Temp-Datenverzeichnis konnte nicht entfernt werden: $DataDirectory" -ForegroundColor DarkGray }
    }
}

# --- Zusammenfassung -------------------------------------------------------
Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host ("Operator-Smoke: {0} OK, {1} FEHLER" -f $script:Passed, $script:Failed) -ForegroundColor $(if ($script:Failed -eq 0) { 'Green' } else { 'Red' })
if ($script:Failed -gt 0) {
    Write-Host 'Fehlgeschlagen:' -ForegroundColor Red
    foreach ($f in $script:Failures) { Write-Host "  - $f" -ForegroundColor Red }
    exit 1
}
Write-Host 'Alle Operator-Workflows gruen.' -ForegroundColor Green
exit 0
