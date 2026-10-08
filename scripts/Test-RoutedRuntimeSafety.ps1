#requires -Version 7.0
[CmdletBinding()]
param([string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. (Join-Path $Root 'scripts/lib/RoutedExecutionCommon.ps1')
$checks=0
function Assert-Result([string]$Actual,[string]$Expected) {
    if($Actual -cne $Expected){throw "Runtime classification differs: $Actual / $Expected"}
    $script:checks++
}
foreach($method in @('claude.ai','oauth_token')) {
    $data=@{loggedIn=$true;authMethod=$method}|ConvertTo-Json -Compress
    Assert-Result (Get-RoutedAuthenticationClassification -Provider anthropic -Text $data -ExitCode 0) 'SUBSCRIPTION_AUTH_VERIFIED'
}
foreach($method in @('api_key','api_key_helper','third_party','unknown')) {
    $data=@{loggedIn=$true;authMethod=$method}|ConvertTo-Json -Compress
    Assert-Result (Get-RoutedAuthenticationClassification -Provider anthropic -Text $data -ExitCode 0) 'HOLD_API_OR_CLOUD_AUTH'
}
foreach($data in @('not-json','{}','{"loggedIn":false,"authMethod":"claude.ai"}','{"loggedIn":"true","authMethod":"claude.ai"}')) {
    Assert-Result (Get-RoutedAuthenticationClassification -Provider anthropic -Text $data -ExitCode 0) 'HOLD_AUTH_UNVERIFIED'
}
Assert-Result (Get-RoutedAuthenticationClassification -Provider openai -Text 'Logged in using ChatGPT' -ExitCode 0) 'SUBSCRIPTION_AUTH_VERIFIED'
Assert-Result (Get-RoutedAuthenticationClassification -Provider openai -Text 'Logged in using API key' -ExitCode 0) 'HOLD_AUTH_UNVERIFIED'
Assert-Result (Get-RoutedAuthenticationClassification -Provider openai -Text 'Logged in using ChatGPT' -ExitCode 0 -HasApiOverride $true) 'HOLD_API_OR_CLOUD_OVERRIDE'
Assert-Result (Get-RoutedAuthenticationClassification -Provider openai -Text 'Logged in using ChatGPT' -ExitCode 1) 'HOLD_AUTH_UNVERIFIED'
Assert-Result (Get-RoutedAuthenticationClassification -Provider openai -Text 'Logged in using ChatGPT' -ExitCode 0 -TimedOut $true) 'HOLD_AUTH_UNVERIFIED'

# Independent names-only vectors: no environment values, provider CLI or auth calls.
Assert-Result (Get-RoutedEnvironmentOverrideClassification -Provider anthropic -EnvironmentNames @()) 'NO_ENVIRONMENT_OVERRIDE'
Assert-Result (Get-RoutedEnvironmentOverrideClassification -Provider openai -EnvironmentNames @()) 'NO_ENVIRONMENT_OVERRIDE'
foreach ($name in @('ANTHROPIC_API_KEY','ANTHROPIC_AUTH_TOKEN','ANTHROPIC_CUSTOM_HEADERS','ANTHROPIC_BASE_URL',
        'CLAUDE_CODE_USE_BEDROCK','CLAUDE_CODE_USE_VERTEX','CLAUDE_CODE_USE_FOUNDRY')) {
    Assert-Result (Get-RoutedEnvironmentOverrideClassification -Provider anthropic -EnvironmentNames @($name)) 'HOLD_API_OR_CLOUD_OVERRIDE'
}
foreach ($name in @('OPENAI_API_KEY','OPENAI_BASE_URL','CODEX_API_KEY')) {
    Assert-Result (Get-RoutedEnvironmentOverrideClassification -Provider openai -EnvironmentNames @($name)) 'HOLD_API_OR_CLOUD_OVERRIDE'
}
Assert-Result (Get-RoutedEnvironmentOverrideClassification -Provider anthropic -EnvironmentNames @('CLAUDE_CODE_EFFORT_LEVEL')) 'HOLD_EFFORT_OVERRIDE'
Assert-Result (Get-RoutedEnvironmentOverrideClassification -Provider anthropic -EnvironmentNames @('CLAUDE_CODE_EFFORT_LEVEL','ANTHROPIC_AUTH_TOKEN')) 'HOLD_API_OR_CLOUD_OVERRIDE'
Assert-Result (Get-RoutedEnvironmentOverrideClassification -Provider anthropic -EnvironmentNames @('claude_code_effort_level')) 'HOLD_EFFORT_OVERRIDE'
Assert-Result (Get-RoutedEnvironmentOverrideClassification -Provider anthropic -EnvironmentNames @('PATH','UNRELATED_NAME')) 'NO_ENVIRONMENT_OVERRIDE'
Assert-Result (Get-RoutedEnvironmentOverrideClassification -Provider openai -EnvironmentNames @('ANTHROPIC_AUTH_TOKEN','CLAUDE_CODE_EFFORT_LEVEL')) 'NO_ENVIRONMENT_OVERRIDE'

# Verify HOLD occurs before an auth subprocess, without altering the real environment.
$originalBoundaryFunction = (Get-Item Function:Get-RoutedEnvironmentOverrideClassification).ScriptBlock
$originalRunnerFunction = (Get-Item Function:Invoke-ExternalRunner).ScriptBlock
$unexpectedAuthCalls = 0
try {
    Set-Item Function:Get-RoutedEnvironmentOverrideClassification {
        param([string]$Provider, [string[]]$EnvironmentNames)
        'HOLD_EFFORT_OVERRIDE'
    }
    Set-Item Function:Invoke-ExternalRunner {
        param([string]$Executable, [string[]]$Arguments, [string]$PromptText, [int]$TimeoutSeconds)
        $script:unexpectedAuthCalls++
        throw 'Unexpected auth runner call in synthetic HOLD test.'
    }
    Assert-Result (Test-RoutedSubscriptionAuthentication -Provider anthropic -Executable 'synthetic-never-start') 'HOLD_EFFORT_OVERRIDE'
    Assert-Result ([string]$unexpectedAuthCalls) '0'
} finally {
    Set-Item Function:Get-RoutedEnvironmentOverrideClassification $originalBoundaryFunction
    Set-Item Function:Invoke-ExternalRunner $originalRunnerFunction
}

$temporary=Join-Path ([IO.Path]::GetTempPath()) ('stm-runtime-'+[Guid]::NewGuid().ToString('N'))
$full=[IO.Path]::GetFullPath($temporary)
try {
    [void][IO.Directory]::CreateDirectory($full)
    $fixture=Join-Path $full 'native-fixture.ps1'
    [IO.File]::WriteAllText($fixture,'param([string]$Payload,[int]$Pause=0) Start-Sleep -Milliseconds $Pause; [Console]::Out.Write($Payload)')
    $payload='synthetic literal '+ '$' + '(no-command)' + " ' ; unicode ä"
    $result=Invoke-ExternalRunner -Executable pwsh -Arguments @('-NoProfile','-NonInteractive','-File',$fixture,'-Payload',$payload) -PromptText '' -TimeoutSeconds 10
    Assert-Result ([string]$result.ExitCode) '0'
    Assert-Result $result.StdOut $payload
    $result=Invoke-ExternalRunner -Executable pwsh -Arguments @('-NoProfile','-NonInteractive','-File',$fixture,'-Payload','never','-Pause','10000') -PromptText '' -TimeoutSeconds 1
    Assert-Result ([string]$result.TimedOut) 'True'
    Assert-Result ([string]$result.ExitCode) '-1'
    Assert-Result $result.StdOut ''
    Write-Output "ROUTED_RUNTIME_SAFETY=PASS assertions=$checks MODEL_CALLS=0"
}
finally {
    $parent=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
    if(-not $full.StartsWith($parent,[StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($full) -notmatch '^stm-runtime-[a-f0-9]{32}$'){throw 'Unexpected runtime test cleanup path'}
    if(Test-Path -LiteralPath $full){
        if((Get-Item -LiteralPath $full -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Runtime test cleanup root is a link'}
        Remove-Item -LiteralPath $full -Recurse -Force
    }
}
