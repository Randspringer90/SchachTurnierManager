#requires -Version 7.0
<#
.SYNOPSIS
Ermittelt aus der repo-internen Policy ein logisches Ausfuehrungsprofil.

.DESCRIPTION
Der Resolver startet kein Modell und fuehrt keinen Fallback aus. Die aufrufende Runtime
muss die verfuegbaren logischen Profile explizit melden. Ist das empfohlene Profil nicht
verfuegbar oder passt keine sichere Regel, endet der Resolver fail-closed mit Exitcode 3.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z][a-z0-9-]*$')]
    [string]$TaskCategory,

    [Parameter(Mandatory)]
    [ValidateSet('orchestration', 'planning', 'architecture', 'implementation', 'review', 'final-integration', 'bulk')]
    [string]$WorkMode,

    [Parameter(Mandatory)]
    [ValidateSet('small', 'medium', 'large')]
    [string]$Size,

    [Parameter(Mandatory)]
    [ValidateSet('low', 'medium', 'high', 'critical')]
    [string]$Risk,

    [switch]$Deterministic,

    [string[]]$AvailableProfiles = @(),

    [string]$ConfigPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'config/model-routing.json')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-DecisionAndExit {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Decision,

        [Parameter(Mandatory)]
        [int]$ExitCode
    )

    $Decision | ConvertTo-Json -Depth 8 -Compress
    exit $ExitCode
}

function Test-RuleDimension {
    param(
        [Parameter(Mandatory)]
        [psobject]$Rule,

        [Parameter(Mandatory)]
        [string]$PropertyName,

        [Parameter(Mandatory)]
        [object]$Value
    )

    if ($Rule.PSObject.Properties.Name -notcontains $PropertyName) {
        return $true
    }

    return @($Rule.$PropertyName) -contains $Value
}

$configFullPath = [IO.Path]::GetFullPath($ConfigPath)
if (-not (Test-Path -LiteralPath $configFullPath -PathType Leaf)) {
    throw "Model-Routing-Policy fehlt: $configFullPath"
}

$config = Get-Content -LiteralPath $configFullPath -Raw | ConvertFrom-Json
$profiles = @($config.profiles)
$profileIds = @($profiles | ForEach-Object { [string]$_.id })
$AvailableProfiles = @(
    $AvailableProfiles |
        ForEach-Object { $_ -split ',' } |
        ForEach-Object { $_.Trim().ToLowerInvariant() } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -Unique
)

$unknownAvailableProfiles = @($AvailableProfiles | Where-Object { $_ -notin $profileIds })
if ($unknownAvailableProfiles.Count -gt 0) {
    Write-DecisionAndExit -ExitCode 2 -Decision @{
        schemaVersion = $config.schemaVersion
        taskCategory = $TaskCategory
        workMode = $WorkMode
        size = $Size
        risk = $Risk
        deterministic = $Deterministic.IsPresent
        matchedRule = $null
        recommendedProfile = $null
        availabilityVerified = $false
        status = 'BLOCKED_INVALID_AVAILABILITY'
        reason = "Unbekannte logische Profile in AvailableProfiles: $($unknownAvailableProfiles -join ', ')"
        silentSwitchPerformed = $false
    }
}

$matchedRule = $null
foreach ($rule in @($config.selectionRules | Sort-Object priority)) {
    if (-not (Test-RuleDimension -Rule $rule -PropertyName 'taskCategories' -Value $TaskCategory)) { continue }
    if (-not (Test-RuleDimension -Rule $rule -PropertyName 'workModes' -Value $WorkMode)) { continue }
    if (-not (Test-RuleDimension -Rule $rule -PropertyName 'sizes' -Value $Size)) { continue }
    if (-not (Test-RuleDimension -Rule $rule -PropertyName 'risks' -Value $Risk)) { continue }
    if (($rule.PSObject.Properties.Name -contains 'requiresDeterministic') -and
        ([bool]$rule.requiresDeterministic -ne $Deterministic.IsPresent)) { continue }

    $matchedRule = $rule
    break
}

if ($null -eq $matchedRule) {
    Write-DecisionAndExit -ExitCode 3 -Decision @{
        schemaVersion = $config.schemaVersion
        taskCategory = $TaskCategory
        workMode = $WorkMode
        size = $Size
        risk = $Risk
        deterministic = $Deterministic.IsPresent
        matchedRule = $null
        recommendedProfile = $null
        availabilityVerified = ($AvailableProfiles.Count -gt 0)
        status = 'BLOCKED_HUMAN_REQUIRED'
        reason = [string]$config.unmatchedRoute.reason
        silentSwitchPerformed = $false
    }
}

$profile = $profiles | Where-Object { $_.id -eq $matchedRule.profile } | Select-Object -First 1
if ($null -eq $profile) {
    throw "Routing-Regel '$($matchedRule.id)' referenziert ein unbekanntes Profil."
}

$profileRank = [int]$config.qualityClassRank.($profile.qualityClass)
$minimumRank = [int]$config.qualityClassRank.($matchedRule.minimumQualityClass)
if (($profile.allowedRisk -notcontains $Risk) -or
    ([bool]$profile.deterministicOnly -and -not $Deterministic.IsPresent) -or
    ($profileRank -lt $minimumRank)) {
    Write-DecisionAndExit -ExitCode 3 -Decision @{
        schemaVersion = $config.schemaVersion
        taskCategory = $TaskCategory
        workMode = $WorkMode
        size = $Size
        risk = $Risk
        deterministic = $Deterministic.IsPresent
        matchedRule = [string]$matchedRule.id
        recommendedProfile = [string]$profile.id
        availabilityVerified = ($AvailableProfiles.Count -gt 0)
        status = 'BLOCKED_POLICY_CONFLICT'
        reason = 'Das empfohlene Profil unterschreitet eine Risiko-, Determinismus- oder Qualitaetsanforderung.'
        silentSwitchPerformed = $false
    }
}

if ($AvailableProfiles.Count -eq 0) {
    Write-DecisionAndExit -ExitCode 3 -Decision @{
        schemaVersion = $config.schemaVersion
        taskCategory = $TaskCategory
        workMode = $WorkMode
        size = $Size
        risk = $Risk
        deterministic = $Deterministic.IsPresent
        matchedRule = [string]$matchedRule.id
        recommendedProfile = [string]$profile.id
        availabilityVerified = $false
        status = 'BLOCKED_AVAILABILITY_UNVERIFIED'
        reason = 'Die aufrufende Runtime hat keine verfuegbaren logischen Profile bestaetigt.'
        silentSwitchPerformed = $false
    }
}

if ($AvailableProfiles -notcontains $profile.id) {
    Write-DecisionAndExit -ExitCode 3 -Decision @{
        schemaVersion = $config.schemaVersion
        taskCategory = $TaskCategory
        workMode = $WorkMode
        size = $Size
        risk = $Risk
        deterministic = $Deterministic.IsPresent
        matchedRule = [string]$matchedRule.id
        recommendedProfile = [string]$profile.id
        availabilityVerified = $true
        status = 'BLOCKED_PROFILE_UNAVAILABLE'
        reason = "Das erforderliche Profil '$($profile.id)' ist nicht verfuegbar; ein stiller Fallback ist verboten."
        silentSwitchPerformed = $false
    }
}

Write-DecisionAndExit -ExitCode 0 -Decision @{
    schemaVersion = $config.schemaVersion
    taskCategory = $TaskCategory
    workMode = $WorkMode
    size = $Size
    risk = $Risk
    deterministic = $Deterministic.IsPresent
    matchedRule = [string]$matchedRule.id
    recommendedProfile = [string]$profile.id
    minimumQualityClass = [string]$matchedRule.minimumQualityClass
    availabilityVerified = $true
    status = 'SELECTED'
    reason = [string]$matchedRule.reason
    silentSwitchPerformed = $false
}
