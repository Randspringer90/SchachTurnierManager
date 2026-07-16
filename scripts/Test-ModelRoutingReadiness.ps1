#requires -Version 7.0
# SECURITY-PATTERN-FILE: Diese Datei enthaelt bewusst Detection-Regexe und synthetische Testwerte.
<#
.SYNOPSIS
Prueft Policy, Profile, Fail-closed-Verhalten und reproduzierbare Routingentscheidungen.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$configPath = Join-Path $repo 'config/model-routing.json'
$schemaPath = Join-Path $repo 'config/model-routing.schema.json'
$resolverPath = Join-Path $repo 'scripts/Resolve-ModelRoute.ps1'
$failures = [Collections.Generic.List[string]]::new()
$caseCount = 0

function Check {
    param([bool]$Condition, [string]$Message)
    if ($Condition) {
        Write-Host "OK  : $Message"
    }
    else {
        $script:failures.Add($Message)
        Write-Host "FAIL: $Message"
    }
}

function Invoke-RouteCase {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$TaskCategory,
        [Parameter(Mandatory)][string]$WorkMode,
        [Parameter(Mandatory)][string]$Size,
        [Parameter(Mandatory)][string]$Risk,
        [bool]$Deterministic = $false,
        [string[]]$AvailableProfiles = @('fabel', 'sol', 'luna', 'terra', 'opus', 'sonnet'),
        [AllowNull()][string]$ExpectedProfile,
        [Parameter(Mandatory)][string]$ExpectedStatus,
        [Parameter(Mandatory)][int]$ExpectedExitCode
    )

    $script:caseCount++
    $arguments = @(
        '-NoLogo', '-NoProfile', '-File', $resolverPath,
        '-TaskCategory', $TaskCategory,
        '-WorkMode', $WorkMode,
        '-Size', $Size,
        '-Risk', $Risk
    )
    if ($Deterministic) { $arguments += '-Deterministic' }
    if ($AvailableProfiles.Count -gt 0) {
        $arguments += '-AvailableProfiles'
        $arguments += ($AvailableProfiles -join ',')
    }

    $output = @(& pwsh @arguments 2>&1)
    $exitCode = $LASTEXITCODE
    $decision = $null
    try {
        $decision = ($output | Select-Object -Last 1 | Out-String).Trim() | ConvertFrom-Json
    }
    catch {
        $script:failures.Add("$Name liefert kein gueltiges JSON: $($output -join ' | ')")
        return
    }

    Check ($exitCode -eq $ExpectedExitCode) "$Name Exitcode $ExpectedExitCode"
    Check ($decision.status -eq $ExpectedStatus) "$Name Status $ExpectedStatus"
    Check ([bool]$decision.silentSwitchPerformed -eq $false) "$Name fuehrt keinen stillen Wechsel aus"
    if (-not [string]::IsNullOrWhiteSpace($ExpectedProfile)) {
        Check ($decision.recommendedProfile -eq $ExpectedProfile) "$Name Profil $ExpectedProfile"
    }
}

Check (Test-Path -LiteralPath $configPath -PathType Leaf) 'Routing-Policy vorhanden'
Check (Test-Path -LiteralPath $schemaPath -PathType Leaf) 'Routing-Schema vorhanden'
Check (Test-Path -LiteralPath $resolverPath -PathType Leaf) 'Routing-Resolver vorhanden'

$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$schema = Get-Content -LiteralPath $schemaPath -Raw | ConvertFrom-Json
$configText = Get-Content -LiteralPath $configPath -Raw

Check ($config.schemaVersion -eq 2) 'Policy-SchemaVersion ist 2'
Check ($config.'$schema' -eq './model-routing.schema.json') 'Policy referenziert das lokale Schema'
Check ($schema.'$schema' -eq 'https://json-schema.org/draft/2020-12/schema') 'Schema ist Draft 2020-12'
Check ([bool]$config.policy.qualityOverCost) 'Qualitaet vor Kosten ist aktiv'
Check ([bool]$config.policy.noSilentModelSwitch) 'Stiller Modellwechsel ist verboten'
Check ([bool]$config.policy.noAutomaticDowngradeForCriticalWork) 'Kritischer Downgrade ist verboten'
Check ($config.policy.unavailableProfileAction -eq 'block-and-request-explicit-reroute') 'Nichtverfuegbarkeit blockiert fail-closed'
Check ($configText -notmatch '(?i)(claude|gpt|gemini|llama)[-_ ]?[0-9]') 'Keine konkreten Modellversionspins'
Check ($configText -notmatch '(?i)([A-Z]:\\|/home/|/Users/)') 'Keine lokalen oder fremden absoluten Pfade'

$profiles = @($config.profiles)
$profileIds = @($profiles | ForEach-Object { [string]$_.id })
$requiredProfiles = @('fabel', 'sol', 'luna', 'terra', 'opus', 'sonnet')
Check ($profileIds.Count -eq ($profileIds | Sort-Object -Unique).Count) 'Profil-IDs sind eindeutig'
foreach ($requiredProfile in $requiredProfiles) {
    Check ($profileIds -contains $requiredProfile) "Logisches Profil $requiredProfile vorhanden"
}

$priorities = @($config.selectionRules | ForEach-Object { [int]$_.priority })
Check ($priorities.Count -eq ($priorities | Sort-Object -Unique).Count) 'Regelprioritaeten sind eindeutig'
foreach ($rule in @($config.selectionRules)) {
    Check ($profileIds -contains $rule.profile) "Regel $($rule.id) referenziert bekanntes Profil"
    Check ($config.qualityClassRank.PSObject.Properties.Name -contains $rule.minimumQualityClass) "Regel $($rule.id) nutzt bekannte Qualitaetsklasse"
}

$terra = $profiles | Where-Object id -eq 'terra' | Select-Object -First 1
$terraRules = @($config.selectionRules | Where-Object profile -eq 'terra')
Check ([bool]$terra.deterministicOnly) 'Terra ist deterministisch begrenzt'
Check (@($terra.allowedRisk).Count -eq 1 -and $terra.allowedRisk[0] -eq 'low') 'Terra ist nur fuer niedriges Risiko erlaubt'
Check ($terraRules.Count -gt 0) 'Mindestens eine Terra-Regel vorhanden'
foreach ($terraRule in $terraRules) {
    Check ([bool]$terraRule.requiresDeterministic) "Terra-Regel $($terraRule.id) verlangt Determinismus"
    Check (@($terraRule.workModes) -contains 'bulk') "Terra-Regel $($terraRule.id) ist Massenarbeit"
    Check (@($terraRule.risks).Count -eq 1 -and $terraRule.risks[0] -eq 'low') "Terra-Regel $($terraRule.id) ist risikoarm"
}

foreach ($criticalCategory in @($config.policy.criticalTaskCategories)) {
    $criticalRules = @($config.selectionRules | Where-Object {
        $_.PSObject.Properties.Name -contains 'taskCategories' -and @($_.taskCategories) -contains $criticalCategory
    })
    Check ($criticalRules.Count -gt 0) "Kritische Kategorie $criticalCategory ist geroutet"
    Check (@($criticalRules | Where-Object profile -ne 'opus').Count -eq 0) "Kritische Kategorie $criticalCategory bleibt bei Opus"
}

$requiredAuditFields = @('schemaVersion', 'taskCategory', 'workMode', 'size', 'risk', 'deterministic', 'matchedRule', 'recommendedProfile', 'availabilityVerified', 'status', 'reason')
foreach ($auditField in $requiredAuditFields) {
    Check (@($config.auditFields) -contains $auditField) "Auditfeld $auditField vorhanden"
}

Invoke-RouteCase -Name 'Orchestrierung' -TaskCategory 'workflow' -WorkMode 'orchestration' -Size 'large' -Risk 'high' -ExpectedProfile 'fabel' -ExpectedStatus 'SELECTED' -ExpectedExitCode 0
Invoke-RouteCase -Name 'Architektur' -TaskCategory 'architecture' -WorkMode 'architecture' -Size 'large' -Risk 'high' -ExpectedProfile 'sol' -ExpectedStatus 'SELECTED' -ExpectedExitCode 0
Invoke-RouteCase -Name 'Finalintegration' -TaskCategory 'final-integration' -WorkMode 'final-integration' -Size 'large' -Risk 'critical' -ExpectedProfile 'sol' -ExpectedStatus 'SELECTED' -ExpectedExitCode 0
Invoke-RouteCase -Name 'Grosse Implementierung' -TaskCategory 'feature' -WorkMode 'implementation' -Size 'large' -Risk 'high' -ExpectedProfile 'luna' -ExpectedStatus 'SELECTED' -ExpectedExitCode 0
Invoke-RouteCase -Name 'Deterministische Massenarbeit' -TaskCategory 'metadata' -WorkMode 'bulk' -Size 'large' -Risk 'low' -Deterministic $true -ExpectedProfile 'terra' -ExpectedStatus 'SELECTED' -ExpectedExitCode 0
Invoke-RouteCase -Name 'Security' -TaskCategory 'security' -WorkMode 'review' -Size 'medium' -Risk 'critical' -ExpectedProfile 'opus' -ExpectedStatus 'SELECTED' -ExpectedExitCode 0
Invoke-RouteCase -Name 'Schachregeln' -TaskCategory 'chess-rules' -WorkMode 'review' -Size 'large' -Risk 'critical' -ExpectedProfile 'opus' -ExpectedStatus 'SELECTED' -ExpectedExitCode 0
Invoke-RouteCase -Name 'Begrenzte Implementierung' -TaskCategory 'feature' -WorkMode 'implementation' -Size 'medium' -Risk 'medium' -ExpectedProfile 'sonnet' -ExpectedStatus 'SELECTED' -ExpectedExitCode 0
Invoke-RouteCase -Name 'Opus nicht verfuegbar' -TaskCategory 'security' -WorkMode 'review' -Size 'medium' -Risk 'critical' -AvailableProfiles @('sol', 'sonnet') -ExpectedProfile 'opus' -ExpectedStatus 'BLOCKED_PROFILE_UNAVAILABLE' -ExpectedExitCode 3
Invoke-RouteCase -Name 'Verfuegbarkeit unbekannt' -TaskCategory 'architecture' -WorkMode 'architecture' -Size 'large' -Risk 'high' -AvailableProfiles @() -ExpectedProfile 'sol' -ExpectedStatus 'BLOCKED_AVAILABILITY_UNVERIFIED' -ExpectedExitCode 3
Invoke-RouteCase -Name 'Riskante Massenarbeit' -TaskCategory 'metadata' -WorkMode 'bulk' -Size 'large' -Risk 'medium' -Deterministic $true -ExpectedProfile $null -ExpectedStatus 'BLOCKED_HUMAN_REQUIRED' -ExpectedExitCode 3
Invoke-RouteCase -Name 'Nichtdeterministische Massenarbeit' -TaskCategory 'metadata' -WorkMode 'bulk' -Size 'large' -Risk 'low' -ExpectedProfile $null -ExpectedStatus 'BLOCKED_HUMAN_REQUIRED' -ExpectedExitCode 3

if ($failures.Count -gt 0) {
    Write-Error ("MODEL_ROUTING_READINESS=FEHLER CASES={0} FAILURES={1}: {2}" -f $caseCount, $failures.Count, ($failures -join '; '))
    exit 1
}

Write-Host "MODEL_ROUTING_READINESS=OK CASES=$caseCount"
exit 0
