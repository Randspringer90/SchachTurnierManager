#requires -Version 7.0
[CmdletBinding()]
param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$RunName = 'STM_RUN54_RuntimeLoggingReadiness',
    [string]$BaseDirectory = 'D:\Temp',
    [switch]$BuildDesktop,
    [int]$Port = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/BackgroundProcess.ps1')

$bundleScript = Join-Path $PSScriptRoot 'New-RunLogBundle.ps1'
$loggedCommandScript = Join-Path $PSScriptRoot 'Invoke-LoggedCommand.ps1'

function ConvertTo-SafeFileName([string]$Value) {
    $safe = $Value -replace '[^a-zA-Z0-9_.-]+', '_'
    if ([string]::IsNullOrWhiteSpace($safe)) { return 'run' }
    return $safe.Trim('_')
}

function New-LoggingRunDirectory {
    param([string]$RunName, [string]$BaseDirectory)
    $safeRunName = ConvertTo-SafeFileName $RunName
    $directory = Join-Path $BaseDirectory ("${safeRunName}_$(Get-Date -Format yyyyMMdd_HHmmss)")
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    return (Resolve-Path -LiteralPath $directory).Path
}

function Resolve-UploadZipPath([string]$RunDirectory) {
    return (Join-Path (Split-Path -Parent $RunDirectory) ("$(Split-Path -Leaf $RunDirectory).zip"))
}

function Complete-RunBundle {
    $expectedUploadZip = Resolve-UploadZipPath -RunDirectory $runDirectory
    pwsh.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $bundleScript -RunDirectory $runDirectory -RunName $RunName -RepositoryRoot $Root | Out-Null
    if (-not (Test-Path -LiteralPath $expectedUploadZip -PathType Leaf)) {
        throw "Upload-ZIP wurde nicht erzeugt: $expectedUploadZip"
    }
    Write-Host "UPLOAD_ZIP=$expectedUploadZip"
}

function Invoke-Logged {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$CommandLine
    )

    pwsh.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $loggedCommandScript `
        -RunDirectory $runDirectory `
        -Name $Name `
        -WorkingDirectory $Root `
        -CommandLine $CommandLine
    if ($LASTEXITCODE -ne 0) {
        throw "$Name ist fehlgeschlagen (ExitCode=$LASTEXITCODE). Details im Run-ZIP."
    }
}

function Get-AvailableLoopbackPort {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $listener.Start()
    try { return ([int]$listener.LocalEndpoint.Port) }
    finally { $listener.Stop() }
}

function Wait-HttpOk {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [int]$TimeoutSeconds = 45,
        [psobject]$BackgroundHandle
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        if ($null -ne $BackgroundHandle -and $BackgroundHandle.Process.HasExited) {
            throw "Logging smoke exited with $($BackgroundHandle.Process.ExitCode). See $($BackgroundHandle.StderrPath)."
        }
        try {
            $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 2
            if ($response.StatusCode -eq 200) { return $response }
        }
        catch {
            Start-Sleep -Milliseconds 750
        }
    } while ((Get-Date) -lt $deadline)

    throw "HTTP-Endpunkt war nicht rechtzeitig erreichbar: $Url"
}

$runDirectory = New-LoggingRunDirectory -RunName $RunName -BaseDirectory $BaseDirectory
Write-Host "RUN_DIR=$runDirectory"

try {
    Invoke-Logged -Name 'releasegate-skip-pack' -CommandLine 'pwsh -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\scripts\Invoke-ReleaseGate.ps1 -SkipPack'

    if ($BuildDesktop -or -not (Test-Path -LiteralPath (Join-Path $Root 'output\desktop\app\SchachTurnierManager.WebApi.exe') -PathType Leaf)) {
        Invoke-Logged -Name 'publish-desktop' -CommandLine 'pwsh -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\scripts\Publish-DesktopApp.ps1 -NoZip'
    }

    $exe = Join-Path $Root 'output\desktop\app\SchachTurnierManager.WebApi.exe'
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw "Desktop-WebApi-EXE fehlt: $exe" }

    $dataDirectory = Join-Path $runDirectory 'app-data'
    $logDirectory = Join-Path $runDirectory 'app-logs'
    New-Item -ItemType Directory -Force -Path $dataDirectory, $logDirectory | Out-Null

    $effectivePort = $Port
    if ($effectivePort -le 0) { $effectivePort = Get-AvailableLoopbackPort }
    Write-Host "PORT=$effectivePort"

    $background = $null
    try {
        $background = Start-StmBackgroundProcess -FilePath $exe -WorkingDirectory (Split-Path -Parent $exe) `
            -LogDirectory $runDirectory -Name logging-smoke `
            -Environment @{
                ASPNETCORE_URLS = "http://127.0.0.1:$effectivePort"
                SchachTurnierManager__DataDirectory = $dataDirectory
                SchachTurnierManager__LogDirectory = $logDirectory
            }
        $healthResponse = Wait-HttpOk -Url "http://127.0.0.1:$effectivePort/api/health" -TimeoutSeconds 45 -BackgroundHandle $background
        $health = $healthResponse.Content | ConvertFrom-Json
        if ($health.logging.file -ne 'enabled') { throw "File-Logging ist laut Health nicht aktiv: $($health.logging.file)" }
        # The public health endpoint no longer exposes absolute paths (Public-Health-Haertung).
        # The configured log folder is proven below by the log file actually written there.
        if ([string]$health.logging.storage -ne 'local') { throw "Health meldet keine lokale Logablage: $($health.logging.storage)" }
        foreach ($privatePath in @($logDirectory, $dataDirectory)) {
            if ($healthResponse.Content -match [regex]::Escape($privatePath) -or $healthResponse.Content -match [regex]::Escape($privatePath.Replace('\', '\\'))) {
                throw 'Health gibt einen absoluten lokalen Pfad preis.'
            }
        }

        Wait-HttpOk -Url "http://127.0.0.1:$effectivePort/" -TimeoutSeconds 10 -BackgroundHandle $background | Out-Null
        Wait-HttpOk -Url "http://127.0.0.1:$effectivePort/api/tournaments" -TimeoutSeconds 10 -BackgroundHandle $background | Out-Null
        Wait-HttpOk -Url "http://127.0.0.1:$effectivePort/api/health?token=should-not-appear" -TimeoutSeconds 10 -BackgroundHandle $background | Out-Null
        Start-Sleep -Milliseconds 500
    }
    finally {
        if ($null -ne $background) {
            Stop-StmBackgroundProcess -Handle $background | Out-Null
        }
    }

    $logFiles = @(Get-ChildItem -LiteralPath $logDirectory -Filter '*.log' -File -ErrorAction SilentlyContinue)
    if ($logFiles.Count -eq 0) { throw "Es wurde keine Logdatei erzeugt unter: $logDirectory" }

    $logText = ($logFiles | ForEach-Object { Get-Content -Raw -LiteralPath $_.FullName }) -join "`n"
    if ($logText -notmatch 'HTTP GET /api/tournaments') { throw 'HTTP-Request wurde nicht in die Logdatei geschrieben.' }
    if ($logText -match 'should-not-appear' -or $logText -match '\?token=') { throw 'Querystring/Token wurde in die Logdatei geschrieben.' }

    @(
        'LOGGING_READINESS=OK',
        "LogDirectory=$logDirectory",
        "LogFiles=$($logFiles.Count)",
        "Port=$effectivePort"
    ) | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $runDirectory 'logging-readiness-summary.txt')

    Write-Host 'LOGGING_READINESS=OK'
    Complete-RunBundle
}
catch {
    $_.Exception.ToString() | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $runDirectory 'FAILED.txt')
    Complete-RunBundle
    throw
}
