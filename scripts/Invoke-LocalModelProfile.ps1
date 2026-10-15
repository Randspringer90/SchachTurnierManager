#requires -Version 7.0
<#
.SYNOPSIS
Fuehrt eine delegierte read-only Teilaufgabe nichtinteraktiv ueber ein lokal installiertes
Ollama-Modell aus (STM-AI-008).

.DESCRIPTION
Das Modell erhaelt nur den Prompt via stdin und hat keine Werkzeuge: es kann weder lesen,
schreiben, committen noch pushen. Die Antwort ist T3-Daten. Es wird nichts heruntergeladen
(`ollama pull` ist nie Teil dieses Adapters) und nur ein Loopback-Ollama-Host akzeptiert,
damit Aufgabeninhalte den Rechner nicht verlassen. Modell-ID ausschliesslich aus
config/model-catalog.json. Exitcodes wie die uebrigen Adapter: 0=ok, 2=rate-/usage-limit,
3=auth/Policy, 4=timeout, 5=fehler oder HOLD.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z][a-z0-9-]*$')]
    [string]$ProfileId,

    [Parameter(Mandatory)]
    [string]$PromptFile,

    [Parameter(Mandatory)]
    [string]$OutputFile,

    [int]$TimeoutSeconds = 900,

    [string]$RuntimePolicyPath,

    [string]$LogFile,

    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib/RoutedExecutionCommon.ps1')

$runtimePolicy = Get-ProviderRuntimePolicy -PolicyPath $RuntimePolicyPath
if ($runtimePolicy.providers.PSObject.Properties.Name -notcontains 'ollama') {
    Write-Error 'Provider-Runtime-Policy enthaelt keinen lokalen Provider (ollama).'
    exit 5
}
$provider = $runtimePolicy.providers.ollama
if ($provider.profiles.PSObject.Properties.Name -notcontains $ProfileId) {
    Write-Error "Profil '$ProfileId' ist kein lokales Profil dieser Policy."
    exit 5
}
$model = [string]$provider.profiles.$ProfileId.model
$arguments = @($provider.invocation.argumentTemplate | ForEach-Object { $_ -replace '\{model\}', $model })

$decision = [ordered]@{
    adapter        = 'ollama'
    profile        = $ProfileId
    model          = $model
    executable     = [string]$provider.executable
    timeoutSeconds = $TimeoutSeconds
    dryRun         = [bool]$DryRun
}

function Complete-Decision([string]$Status, [int]$ExitCode, [string]$Reason) {
    $decision.status = $Status
    if ($Reason) { $decision.reason = $Reason }
    $decision | ConvertTo-Json -Depth 6 -Compress
    exit $ExitCode
}

# Aufgabeninhalte duerfen den Rechner nicht verlassen: nur Loopback-Hosts.
$hostSetting = [Environment]::GetEnvironmentVariable('OLLAMA_HOST')
if (-not (Test-LocalModelLoopbackHost -HostSetting $hostSetting)) {
    Complete-Decision 'HOLD_NON_LOOPBACK_HOST' 3 'OLLAMA_HOST zeigt nicht auf 127.0.0.1/localhost/::1.'
}

try { $null = Resolve-RoutedRunnerInvocation -Executable $provider.executable }
catch { Complete-Decision 'HOLD_RUNNER_MISSING' 5 'Lokale Ollama-CLI ist nicht installiert oder nicht im PATH.' }

# Verfuegbarkeit bestaetigen statt still herunterzuladen oder auszuweichen.
$list = Invoke-ExternalRunner -Executable $provider.executable -Arguments @('list') -PromptText '' -TimeoutSeconds 60
if ($list.TimedOut -or $list.ExitCode -ne 0) {
    Complete-Decision 'HOLD_RUNTIME_UNAVAILABLE' 5 'Ollama-Dienst antwortet nicht.'
}
$installed = @($list.StdOut -split "`r?`n" | Select-Object -Skip 1 | ForEach-Object { ($_ -split '\s+')[0] } |
    Where-Object { $_ })
if ($installed -cnotcontains $model) {
    Complete-Decision 'HOLD_MODEL_NOT_INSTALLED' 5 'Katalogmodell ist lokal nicht installiert; kein automatischer Download.'
}
$decision.availabilityVerification = 'LOCAL_MODEL_LISTED'

if ($DryRun) {
    $decision.arguments = $arguments
    Complete-Decision 'DRY_RUN_OK' 0 $null
}

if (-not (Test-Path -LiteralPath $PromptFile -PathType Leaf)) {
    Write-Error "Promptdatei fehlt: $PromptFile"
    exit 5
}
$promptText = Get-Content -LiteralPath $PromptFile -Raw
$outputPath = [IO.Path]::GetFullPath($OutputFile)
$outputDir = Split-Path -Parent $outputPath
if ($outputDir -and -not (Test-Path -LiteralPath $outputDir)) { New-Item -ItemType Directory -Force -Path $outputDir | Out-Null }

$started = Get-Date
$result = Invoke-ExternalRunner -Executable $provider.executable -Arguments $arguments `
    -PromptText $promptText -TimeoutSeconds $TimeoutSeconds
$duration = [int]((Get-Date) - $started).TotalSeconds

# stdout ist Modellinhalt (T3) und darf nicht als Limit-/Authsignal gelesen werden:
# eine Antwort, die "503" erwaehnt, ist kein Kapazitaetsfehler. Nur stderr/Exitcode zaehlen.
$classification = Get-RunnerOutputClassification -Text $result.StdErr -ExitCode $result.ExitCode `
    -RuntimePolicy $runtimePolicy -TimedOut:$result.TimedOut
if ($classification -eq 'ok' -and [string]::IsNullOrWhiteSpace($result.StdOut)) { $classification = 'error' }
Set-Content -LiteralPath $outputPath -Value $result.StdOut -Encoding utf8NoBOM

if ($LogFile) {
    $logDir = Split-Path -Parent ([IO.Path]::GetFullPath($LogFile))
    if ($logDir -and -not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
    $redacted = Get-RedactedText -Text "$($result.StdOut)`n$($result.StdErr)" -RuntimePolicy $runtimePolicy
    Add-Content -LiteralPath $LogFile -Encoding utf8NoBOM -Value (
        "=== ollama/$ProfileId $([DateTime]::UtcNow.ToString('o')) exit=$($result.ExitCode) class=$classification ===`n$redacted")
}

$decision.exitCode = $result.ExitCode
$decision.durationSeconds = $duration
$decision.outputFile = $outputPath
$decision.outputChars = (Get-Item -LiteralPath $outputPath).Length
$exit = switch ($classification) { 'ok' { 0 } 'usage-limit' { 2 } 'rate-limit' { 2 } 'auth-error' { 3 } 'timeout' { 4 } default { 5 } }
Complete-Decision $classification $exit $null
