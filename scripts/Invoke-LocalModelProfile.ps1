#requires -Version 7.0
<#
.SYNOPSIS
Fuehrt eine delegierte read-only Teilaufgabe nichtinteraktiv ueber ein lokal installiertes
Ollama-Modell aus (STM-AI-008).

.DESCRIPTION
Spricht ausschliesslich die Loopback-REST-API des lokalen Ollama-Dienstes an:
`/api/tags` bestaetigt, dass das Katalogmodell mit lokal gespeicherten Gewichten vorhanden
ist (Cloud-/Remote-Modelle werden abgewiesen), `/api/generate` mit `stream:false` fuehrt
den Prompt aus. Dieser Endpunkt laedt nie Modelle herunter; `/api/pull` wird nie
aufgerufen. Das Modell hat keine Werkzeuge; die Antwort ist T3-Daten und wird nie als
Limit-/Fehlersignal gelesen. Modell-ID ausschliesslich aus config/model-catalog.json.
Exitcodes wie die uebrigen Adapter: 0=ok, 2=rate-limit, 3=auth/Policy, 4=timeout,
5=fehler oder HOLD.
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

$decision = [ordered]@{
    adapter        = 'ollama'
    profile        = $ProfileId
    model          = $model
    transport      = 'loopback-rest'
    timeoutSeconds = $TimeoutSeconds
    dryRun         = [bool]$DryRun
}

function Complete-Decision([string]$Status, [int]$ExitCode, [string]$Reason) {
    $decision.status = $Status
    if ($Reason) { $decision.reason = $Reason }
    $decision | ConvertTo-Json -Depth 6 -Compress
    exit $ExitCode
}

# Aufgabeninhalte duerfen den Rechner nicht verlassen: nur Loopback-Endpunkte.
$endpoint = Get-LocalModelEndpoint -HostSetting ([Environment]::GetEnvironmentVariable('OLLAMA_HOST'))
if ($null -eq $endpoint) {
    Complete-Decision 'HOLD_NON_LOOPBACK_HOST' 3 'OLLAMA_HOST zeigt nicht auf 127.0.0.1/localhost/[::1] (nur http/https).'
}

function Invoke-LocalModelRequest([string]$Method, [string]$Path, [string]$Body, [int]$Seconds) {
    $request = @{ Uri = "$endpoint$Path"; Method = $Method; NoProxy = $true; SkipHttpErrorCheck = $true; TimeoutSec = $Seconds }
    if ($Body) { $request.Body = [Text.Encoding]::UTF8.GetBytes($Body); $request.ContentType = 'application/json; charset=utf-8' }
    return Invoke-WebRequest @request
}

try { $tags = Invoke-LocalModelRequest -Method Get -Path '/api/tags' -Seconds 15 }
catch { Complete-Decision 'HOLD_RUNTIME_UNAVAILABLE' 5 'Lokaler Ollama-Dienst antwortet nicht.' }
if ([int]$tags.StatusCode -ne 200) { Complete-Decision 'HOLD_RUNTIME_UNAVAILABLE' 5 "Ollama /api/tags antwortete $([int]$tags.StatusCode)." }
$inventory = @((($tags.Content | ConvertFrom-Json).models) | Where-Object { [string]$_.name -ceq $model })
if ($inventory.Count -eq 0) {
    Complete-Decision 'HOLD_MODEL_NOT_INSTALLED' 5 'Katalogmodell ist lokal nicht installiert; kein automatischer Download.'
}
if ((Test-LocalModelInventoryEntry -Entry $inventory[0]) -ne 'LOCAL') {
    Complete-Decision 'HOLD_REMOTE_MODEL' 3 'Katalogmodell ist kein lokal gespeichertes Modell (Cloud/Remote); Inhalte wuerden den Rechner verlassen.'
}
$decision.availabilityVerification = 'LOCAL_WEIGHTS_LISTED'

if ($DryRun) { Complete-Decision 'DRY_RUN_OK' 0 $null }

if (-not (Test-Path -LiteralPath $PromptFile -PathType Leaf)) {
    Write-Error "Promptdatei fehlt: $PromptFile"
    exit 5
}
$promptText = Get-Content -LiteralPath $PromptFile -Raw
$outputPath = [IO.Path]::GetFullPath($OutputFile)
$outputDir = Split-Path -Parent $outputPath
if ($outputDir -and -not (Test-Path -LiteralPath $outputDir)) { New-Item -ItemType Directory -Force -Path $outputDir | Out-Null }

$body = [ordered]@{ model = $model; prompt = $promptText; stream = $false } | ConvertTo-Json -Compress
$started = Get-Date
$classification = 'error'
$answer = ''
$httpStatus = 0
try {
    $response = Invoke-LocalModelRequest -Method Post -Path '/api/generate' -Body $body -Seconds $TimeoutSeconds
    $httpStatus = [int]$response.StatusCode
    # Nur der HTTP-Status klassifiziert; die Modellantwort ist T3-Inhalt, nie ein Signal.
    $classification = switch ($httpStatus) { 200 { 'ok' } 429 { 'rate-limit' } 401 { 'auth-error' } 403 { 'auth-error' } default { 'error' } }
    if ($classification -eq 'ok') {
        $result = $response.Content | ConvertFrom-Json
        $answer = [string]$result.response
        if (-not [bool]$result.done -or [string]::IsNullOrWhiteSpace($answer)) { $classification = 'error' }
        # Gemessene, nicht geschaetzte Tokenzahlen des lokalen Dienstes.
        foreach ($field in 'prompt_eval_count', 'eval_count') {
            if ($result.PSObject.Properties.Name -contains $field) { $decision[$field] = [int]$result.$field }
        }
    }
}
catch [System.Threading.Tasks.TaskCanceledException], [System.TimeoutException] { $classification = 'timeout' }
catch {
    $classification = if ($_.Exception.Message -match '(?i)timeout|timed out') { 'timeout' } else { 'error' }
}
$duration = [int]((Get-Date) - $started).TotalSeconds
Set-Content -LiteralPath $outputPath -Value $answer -Encoding utf8NoBOM

if ($LogFile) {
    $logDir = Split-Path -Parent ([IO.Path]::GetFullPath($LogFile))
    if ($logDir -and -not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
    $redacted = Get-RedactedText -Text $answer -RuntimePolicy $runtimePolicy
    Add-Content -LiteralPath $LogFile -Encoding utf8NoBOM -Value (
        "=== ollama/$ProfileId $([DateTime]::UtcNow.ToString('o')) http=$httpStatus class=$classification ===`n$redacted")
}

$decision.httpStatus = $httpStatus
$decision.durationSeconds = $duration
$decision.outputFile = $outputPath
$decision.outputChars = (Get-Item -LiteralPath $outputPath).Length
$exit = switch ($classification) { 'ok' { 0 } 'rate-limit' { 2 } 'auth-error' { 3 } 'timeout' { 4 } default { 5 } }
Complete-Decision $classification $exit $null
