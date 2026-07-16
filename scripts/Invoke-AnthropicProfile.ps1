#requires -Version 7.0
<#
.SYNOPSIS
Fuehrt eine delegierte Teilaufgabe nichtinteraktiv ueber die lokale Anthropic-CLI aus.

.DESCRIPTION
Verwendet ausschliesslich den vorhandenen lokalen Login. Persistiert keine Tokens,
gibt keine Secrets aus, startet kein neues Terminalfenster. Der Prompt kommt aus
einer Datei; die Antwort wird als T3-Daten in eine Ausgabedatei geschrieben und
redigiert geloggt. Exitcodes: 0=ok, 2=rate-/usage-limit, 3=auth, 4=timeout, 5=fehler.
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

    [string]$ProjectPath,

    [string]$RuntimePolicyPath,

    [string]$LogFile,

    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib/RoutedExecutionCommon.ps1')

$runtimePolicy = Get-ProviderRuntimePolicy -PolicyPath $RuntimePolicyPath
$provider = $runtimePolicy.providers.anthropic
if ($provider.profiles.PSObject.Properties.Name -notcontains $ProfileId) {
    Write-Error "Profil '$ProfileId' ist kein Anthropic-Profil dieser Policy."
    exit 5
}
$model = [string]$provider.profiles.$ProfileId.model
if (-not $ProjectPath) { $ProjectPath = Get-RoutedRepoRoot }
$ProjectPath = [IO.Path]::GetFullPath($ProjectPath)

$arguments = @($provider.invocation.argumentTemplate | ForEach-Object {
        $_ -replace '\{model\}', $model -replace '\{projectPath\}', $ProjectPath
    })

$decision = [ordered]@{
    adapter        = 'anthropic'
    profile        = $ProfileId
    model          = $model
    executable     = [string]$provider.executable
    timeoutSeconds = $TimeoutSeconds
    dryRun         = [bool]$DryRun
}

if ($DryRun) {
    $available = $null -ne (Get-Command $provider.executable -ErrorAction SilentlyContinue)
    $decision.status = if ($available) { 'DRY_RUN_OK' } else { 'DRY_RUN_RUNNER_MISSING' }
    $decision.arguments = $arguments
    $decision | ConvertTo-Json -Depth 6 -Compress
    exit ([int](-not $available) * 5)
}

if (-not (Test-Path -LiteralPath $PromptFile -PathType Leaf)) {
    Write-Error "Promptdatei fehlt: $PromptFile"
    exit 5
}
$promptText = Get-Content -LiteralPath $PromptFile -Raw

$started = Get-Date
$result = Invoke-ExternalRunner -Executable $provider.executable -Arguments $arguments `
    -PromptText $promptText -TimeoutSeconds $TimeoutSeconds
$duration = [int]((Get-Date) - $started).TotalSeconds

$combined = "$($result.StdOut)`n$($result.StdErr)"
$classification = Get-RunnerOutputClassification -Text $combined -ExitCode $result.ExitCode `
    -RuntimePolicy $runtimePolicy -TimedOut:$result.TimedOut

$outputDir = Split-Path -Parent ([IO.Path]::GetFullPath($OutputFile))
if ($outputDir -and -not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
}
Set-Content -LiteralPath $OutputFile -Value $result.StdOut -Encoding utf8NoBOM

if ($LogFile) {
    $logDir = Split-Path -Parent ([IO.Path]::GetFullPath($LogFile))
    if ($logDir -and -not (Test-Path -LiteralPath $logDir)) {
        New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    }
    $redacted = Get-RedactedText -Text $combined -RuntimePolicy $runtimePolicy
    Add-Content -LiteralPath $LogFile -Encoding utf8NoBOM -Value (
        "=== anthropic/$ProfileId $([DateTime]::UtcNow.ToString('o')) exit=$($result.ExitCode) class=$classification ===`n$redacted")
}

$decision.status = $classification
$decision.exitCode = $result.ExitCode
$decision.durationSeconds = $duration
$decision.outputFile = [IO.Path]::GetFullPath($OutputFile)
$decision.outputChars = ([string]$result.StdOut).Length
$decision | ConvertTo-Json -Depth 6 -Compress

switch ($classification) {
    'ok' { exit 0 }
    'usage-limit' { exit 2 }
    'rate-limit' { exit 2 }
    'auth-error' { exit 3 }
    'timeout' { exit 4 }
    default { exit 5 }
}
