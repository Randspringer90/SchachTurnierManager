#requires -Version 7.0
<#
.SYNOPSIS
Fuehrt eine delegierte Teilaufgabe nichtinteraktiv ueber die lokale OpenAI-Codex-CLI aus.

.DESCRIPTION
Verwendet ausschliesslich den vorhandenen lokalen Login (Auth-Probe optional).
Sandbox read-only: der Child darf weder schreiben noch committen noch pushen.
Prompt via stdin; Antwort als T3-Daten in die Ausgabedatei; Logs redigiert.
Exitcodes: 0=ok, 2=rate-/usage-limit, 3=auth, 4=timeout, 5=fehler.
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

    [switch]$SkipAuthProbe,

    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib/RoutedExecutionCommon.ps1')

$runtimePolicy = Get-ProviderRuntimePolicy -PolicyPath $RuntimePolicyPath
$provider = $runtimePolicy.providers.openai
if ($provider.profiles.PSObject.Properties.Name -notcontains $ProfileId) {
    Write-Error "Profil '$ProfileId' ist kein OpenAI-Profil dieser Policy."
    exit 5
}
$model = [string]$provider.profiles.$ProfileId.model
if (-not $ProjectPath) { $ProjectPath = Get-RoutedRepoRoot }
$ProjectPath = [IO.Path]::GetFullPath($ProjectPath)

$lastMessageFile = [IO.Path]::GetFullPath($OutputFile)
$arguments = @($provider.invocation.argumentTemplate | ForEach-Object {
        $_ -replace '\{model\}', $model `
            -replace '\{projectPath\}', $ProjectPath `
            -replace '\{lastMessageFile\}', $lastMessageFile
    })

$decision = [ordered]@{
    adapter        = 'openai'
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

if (-not $SkipAuthProbe -and ($provider.PSObject.Properties.Name -contains 'authProbeArgs')) {
    $probe = Invoke-ExternalRunner -Executable $provider.executable `
        -Arguments @($provider.authProbeArgs) -PromptText '' -TimeoutSeconds 60
    $probeClass = Get-RunnerOutputClassification -Text "$($probe.StdOut)`n$($probe.StdErr)" `
        -ExitCode $probe.ExitCode -RuntimePolicy $runtimePolicy -TimedOut:$probe.TimedOut
    if ($probe.ExitCode -ne 0 -or $probeClass -eq 'auth-error') {
        $decision.status = 'auth-error'
        $decision.reason = 'Auth-Probe fehlgeschlagen; vorhandener Login erforderlich (kein Token-Handling durch dieses Skript).'
        $decision | ConvertTo-Json -Depth 6 -Compress
        exit 3
    }
}

$promptText = Get-Content -LiteralPath $PromptFile -Raw

$outputDir = Split-Path -Parent $lastMessageFile
if ($outputDir -and -not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
}

$started = Get-Date
$result = Invoke-ExternalRunner -Executable $provider.executable -Arguments $arguments `
    -PromptText $promptText -TimeoutSeconds $TimeoutSeconds
$duration = [int]((Get-Date) - $started).TotalSeconds

$combined = "$($result.StdOut)`n$($result.StdErr)"
$classification = Get-RunnerOutputClassification -Text $combined -ExitCode $result.ExitCode `
    -RuntimePolicy $runtimePolicy -TimedOut:$result.TimedOut

# codex schreibt die letzte Nachricht selbst nach {lastMessageFile}; Fallback: stdout.
if (-not (Test-Path -LiteralPath $lastMessageFile -PathType Leaf) -or
    (Get-Item -LiteralPath $lastMessageFile).Length -eq 0) {
    Set-Content -LiteralPath $lastMessageFile -Value $result.StdOut -Encoding utf8NoBOM
}

if ($LogFile) {
    $logDir = Split-Path -Parent ([IO.Path]::GetFullPath($LogFile))
    if ($logDir -and -not (Test-Path -LiteralPath $logDir)) {
        New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    }
    $redacted = Get-RedactedText -Text $combined -RuntimePolicy $runtimePolicy
    Add-Content -LiteralPath $LogFile -Encoding utf8NoBOM -Value (
        "=== openai/$ProfileId $([DateTime]::UtcNow.ToString('o')) exit=$($result.ExitCode) class=$classification ===`n$redacted")
}

$decision.status = $classification
$decision.exitCode = $result.ExitCode
$decision.durationSeconds = $duration
$decision.outputFile = $lastMessageFile
$decision.outputChars = if (Test-Path -LiteralPath $lastMessageFile) { (Get-Item -LiteralPath $lastMessageFile).Length } else { 0 }
$decision | ConvertTo-Json -Depth 6 -Compress

switch ($classification) {
    'ok' { exit 0 }
    'usage-limit' { exit 2 }
    'rate-limit' { exit 2 }
    'auth-error' { exit 3 }
    'timeout' { exit 4 }
    default { exit 5 }
}
