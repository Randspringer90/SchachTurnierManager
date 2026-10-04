#requires -Version 7.0
# SECURITY-PATTERN-FILE: Synthetische Negativ-Fixtures und Versionspin-Erkennung;
# kein Modellaufruf, kein Netzwerk und keine Ausfuehrung von Fixture-Inhalten.
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $PSScriptRoot 'lib/RoutedExecutionCommon.ps1')
$passed = 0
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('stm-model-catalog-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixtureRoot | Out-Null

function Assert-CatalogCheck([string]$Name, [bool]$Condition) {
    if (-not $Condition) { throw "FAIL $Name" }
    $script:passed++
    Write-Host "PASS $Name"
}

function Assert-Rejected([string]$Name, [scriptblock]$Mutation, [string]$Expected) {
    $policy = Get-Content (Join-Path $repo 'config/provider-runtime-policy.json') -Raw | ConvertFrom-Json
    $catalog = Get-Content (Join-Path $repo 'config/model-catalog.json') -Raw | ConvertFrom-Json
    & $Mutation $policy $catalog
    $policy | ConvertTo-Json -Depth 30 | Set-Content (Join-Path $fixtureRoot 'provider-runtime-policy.json') -Encoding utf8NoBOM
    $catalog | ConvertTo-Json -Depth 30 | Set-Content (Join-Path $fixtureRoot 'model-catalog.json') -Encoding utf8NoBOM
    $rejected = $false
    try { Get-ProviderRuntimePolicy -PolicyPath (Join-Path $fixtureRoot 'provider-runtime-policy.json') | Out-Null }
    catch { $rejected = $_.Exception.Message -match $Expected }
    Assert-CatalogCheck $Name $rejected
}

$oldNativeDirectory = [Environment]::CurrentDirectory
$oldPowerShellLocation = Get-Location
try {
    Set-Location -LiteralPath $repo
    [Environment]::CurrentDirectory = $fixtureRoot
    $relativeRuntime = Get-ProviderRuntimePolicy -PolicyPath 'config/provider-runtime-policy.json'
    Assert-CatalogCheck 'relative-policy-uses-powershell-location' ($relativeRuntime.schemaVersion -eq 2)
} finally {
    [Environment]::CurrentDirectory = $oldNativeDirectory
    Set-Location -LiteralPath $oldPowerShellLocation.Path
}
$runtime = Get-ProviderRuntimePolicy
Assert-CatalogCheck 'runtime-uses-catalog' ($runtime.PSObject.Properties.Name -contains 'modelCatalogFile')
$catalogPath = Join-Path $repo 'config/model-catalog.json'
$catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
foreach ($schema in 'provider-runtime-policy.schema.json', 'model-catalog.schema.json') {
    Copy-Item -LiteralPath (Join-Path $repo "config/$schema") -Destination (Join-Path $fixtureRoot $schema)
}
foreach ($providerName in $runtime.providers.PSObject.Properties.Name) {
    foreach ($profile in $runtime.providers.$providerName.profiles.PSObject.Properties) {
        $entry = $catalog.models.($profile.Value.modelKey)
        $resolved = Get-ProfileProvider -RuntimePolicy $runtime -ProfileId $profile.Name
        Assert-CatalogCheck "profile-$($profile.Name)-resolved" ($resolved.Model -ceq $entry.id -and $entry.provider -ceq $providerName)
    }
}
Assert-CatalogCheck 'large-implementation-preserves-quality' ($runtime.providers.openai.profiles.luna.modelKey -ceq $runtime.providers.openai.profiles.sol.modelKey)
Assert-CatalogCheck 'bulk-profile-distinct' ($runtime.providers.openai.profiles.terra.modelKey -cne $runtime.providers.openai.profiles.sol.modelKey)
Assert-Rejected 'unknown-model-key' { param($p, $c) $p.providers.openai.profiles.sol.modelKey = 'missing' } 'Katalogschluessel'
Assert-Rejected 'provider-mismatch' { param($p, $c) $c.models.openaiSol.provider = 'anthropic' } 'Provider'
Assert-Rejected 'inline-model-forbidden' { param($p, $c) $p.providers.openai.profiles.sol | Add-Member -NotePropertyName model -NotePropertyValue 'synthetic-model' } 'Schema'
Assert-Rejected 'catalog-traversal-forbidden' { param($p, $c) $p.modelCatalogFile = '../model-catalog.json' } 'Schema'
Assert-Rejected 'model-argument-injection' { param($p, $c) $c.models.openaiSol.id = '--unsafe-option' } 'Schema'
Assert-Rejected 'unofficial-source-forbidden' { param($p, $c) $c.sources.openai = 'https://example.invalid/models' } 'Quelle'
Assert-Rejected 'silent-fallback-forbidden' { param($p, $c) $c.updatePolicy.noSilentFallback = $false } 'Schema'
Assert-Rejected 'unreviewed-generation-forbidden' { param($p, $c) $c.updatePolicy.requireOfficialSources = $false } 'Schema'
Assert-Rejected 'duplicate-id-forbidden' { param($p, $c) $c.models.openaiLuna.id = $c.models.openaiSol.id } 'doppelt'
Assert-Rejected 'future-verification-forbidden' { param($p, $c) $c.verifiedOn = '9999-12-31' } 'Pruefdatum'

# Eine neue Generation darf allein durch Aendern des Katalogs alle Aufrufer erreichen.
$catalog.models.openaiSol.id = 'synthetic-successor'
$catalog | ConvertTo-Json -Depth 30 | Set-Content (Join-Path $fixtureRoot 'model-catalog.json') -Encoding utf8NoBOM
Copy-Item (Join-Path $repo 'config/provider-runtime-policy.json') (Join-Path $fixtureRoot 'provider-runtime-policy.json')
$updated = Get-ProviderRuntimePolicy -PolicyPath (Join-Path $fixtureRoot 'provider-runtime-policy.json')
Assert-CatalogCheck 'catalog-only-update-reaches-runtime' ((Get-ProfileProvider $updated 'sol').Model -ceq 'synthetic-successor')
Assert-CatalogCheck 'catalog-only-update-reaches-large-implementation' ((Get-ProfileProvider $updated 'luna').Model -ceq 'synthetic-successor')

$redirectPath = $fixtureRoot + '-redirect'
$linkType = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
New-Item -ItemType $linkType -Path $redirectPath -Target $fixtureRoot | Out-Null
$reparseRejected = $false
try { Get-ProviderRuntimePolicy -PolicyPath (Join-Path $redirectPath 'provider-runtime-policy.json') | Out-Null }
catch { $reparseRejected = $_.Exception.Message -match 'Reparse' }
Assert-CatalogCheck 'ancestor-filesystem-redirect-forbidden' $reparseRejected

$missingSchemaRoot = Join-Path $fixtureRoot 'missing-schema'
New-Item -ItemType Directory -Path $missingSchemaRoot | Out-Null
foreach ($file in 'provider-runtime-policy.json', 'model-catalog.json') {
    Copy-Item (Join-Path $fixtureRoot $file) (Join-Path $missingSchemaRoot $file)
}
$missingSchemaRejected = $false
try { Get-ProviderRuntimePolicy -PolicyPath (Join-Path $missingSchemaRoot 'provider-runtime-policy.json') | Out-Null }
catch { $missingSchemaRejected = $_.Exception.Message -match 'provider-runtime-policy.schema.json' }
Assert-CatalogCheck 'missing-schema-fails-closed' $missingSchemaRejected

$versionPin = '(?i)\b(?:gpt[- ]\d+(?:[.\-]\d+)*(?:[- ](?:sol|luna|terra|astra))?|claude[- ](?:opus|sonnet|haiku|fable)[- ]\d+(?:[.\-]\d+)*|(?:Fable|Fabel|Opus|Sol|Luna|Terra|Sonnet|ChatGPT)\s+\d+(?:\.\d+)*)(?![A-Za-z0-9])'
$duplicates = @()
foreach ($relative in (& git -C $repo ls-files)) {
    if ($relative -ceq 'config/model-catalog.json' -or [IO.Path]::GetExtension($relative) -notin '.md','.json','.ps1','.yml','.yaml','.toml','.txt','.mjs','.js','.ts','.tsx') { continue }
    if ((Get-Content -LiteralPath (Join-Path $repo $relative) -Raw) -match $versionPin) { $duplicates += $relative }
}
Assert-CatalogCheck 'model-versions-only-in-catalog' ($duplicates.Count -eq 0)
Write-Host "MODEL_CATALOG_READINESS=OK CHECKS=$passed"
Write-Host "SYNTHETIC_FIXTURES=$fixtureRoot"
