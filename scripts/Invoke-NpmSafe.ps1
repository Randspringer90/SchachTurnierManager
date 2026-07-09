[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,

    [string]$WorkingDirectory = '.',

    [string]$NpmCommand,

    [string]$NpmScript,

    [string[]]$NpmArguments = @(),

    [switch]$NoAudit,

    [switch]$NoFund
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info([string]$Message) {
    Write-Host "[NpmSafe] $Message"
}

function ConvertFrom-DpapiFile([string]$Path) {
    $encrypted = Get-Content -Raw -LiteralPath $Path
    $secure = $encrypted | ConvertTo-SecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function Write-SanitizedNpmrc([string]$Content, [string]$TargetPath) {
    $lines = $Content -split "`r?`n"
    $kept = New-Object System.Collections.Generic.List[string]
    $removedAlwaysAuth = 0
    foreach ($line in $lines) {
        if ($line -match '^[\s;#]*always-auth\s*=') {
            $removedAlwaysAuth++
            continue
        }
        $kept.Add($line)
    }
    ($kept -join "`n") | Set-Content -Encoding UTF8 -LiteralPath $TargetPath
    if ($removedAlwaysAuth -gt 0) {
        Write-Info "veraltete always-auth-Zeile(n) aus lokaler npmrc entfernt: $removedAlwaysAuth"
    }
}

function Get-NpmArgumentList {
    $result = New-Object System.Collections.Generic.List[string]

    if (-not [string]::IsNullOrWhiteSpace($NpmCommand)) {
        $result.Add($NpmCommand)
    }

    if (-not [string]::IsNullOrWhiteSpace($NpmScript)) {
        $result.Add($NpmScript)
    }

    foreach ($argument in $NpmArguments) {
        if (-not [string]::IsNullOrWhiteSpace($argument)) {
            $result.Add($argument)
        }
    }

    if ($NoAudit) {
        $result.Add('--no-audit')
    }

    if ($NoFund) {
        $result.Add('--fund=false')
    }

    if ($result.Count -eq 0) {
        throw 'Kein npm-Befehl angegeben. Nutze z. B. -NpmCommand install oder -NpmCommand run -NpmScript build.'
    }

    return [string[]]$result.ToArray()
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$tmpDir = Join-Path $resolvedRoot 'tmp/npm-safe'
New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
$tempNpmrc = Join-Path $tmpDir 'user.npmrc'

$localNpmrc = Join-Path $resolvedRoot '.secrets/local/npmrc'
$legacyLocalNpmrc = Join-Path $resolvedRoot 'secrets/local/npmrc'
$dpapiNpmrc = Join-Path $resolvedRoot '.secrets/local/npmrc.dpapi.txt'
$legacyDpapiNpmrc = Join-Path $resolvedRoot 'secrets/local/npmrc.dpapi.txt'

if (Test-Path -LiteralPath $localNpmrc -PathType Leaf) {
    Write-SanitizedNpmrc -Content (Get-Content -Raw -LiteralPath $localNpmrc) -TargetPath $tempNpmrc
    Write-Info 'lokale npmrc aus .secrets/local verwendet.'
}
elseif (Test-Path -LiteralPath $dpapiNpmrc -PathType Leaf) {
    Write-SanitizedNpmrc -Content (ConvertFrom-DpapiFile $dpapiNpmrc) -TargetPath $tempNpmrc
    Write-Info 'DPAPI-geschuetzte npmrc aus .secrets/local verwendet.'
}
elseif (Test-Path -LiteralPath $legacyLocalNpmrc -PathType Leaf) {
    Write-SanitizedNpmrc -Content (Get-Content -Raw -LiteralPath $legacyLocalNpmrc) -TargetPath $tempNpmrc
    Write-Info 'lokale npmrc aus secrets/local verwendet (Legacy-Ablage).'
}
elseif (Test-Path -LiteralPath $legacyDpapiNpmrc -PathType Leaf) {
    Write-SanitizedNpmrc -Content (ConvertFrom-DpapiFile $legacyDpapiNpmrc) -TargetPath $tempNpmrc
    Write-Info 'DPAPI-geschuetzte npmrc aus secrets/local verwendet (Legacy-Ablage).'
}
else {
    '# intentionally empty: isolate npm from user/global auth config' | Set-Content -Encoding UTF8 -LiteralPath $tempNpmrc
    Write-Info 'isolierte temporaere npmrc ohne lokale Secrets verwendet.'
}

$oldUserConfig = $env:NPM_CONFIG_USERCONFIG
$oldAlwaysAuth = $env:NPM_CONFIG_ALWAYS_AUTH
$oldNpmConfigAlwaysAuth = $env:npm_config_always_auth
$npmArgumentsToRun = Get-NpmArgumentList

try {
    $env:NPM_CONFIG_USERCONFIG = $tempNpmrc
    Remove-Item Env:NPM_CONFIG_ALWAYS_AUTH -ErrorAction SilentlyContinue
    Remove-Item Env:npm_config_always_auth -ErrorAction SilentlyContinue

    $resolvedWorkingDirectory = if ([System.IO.Path]::IsPathRooted($WorkingDirectory)) {
        (Resolve-Path -LiteralPath $WorkingDirectory).Path
    }
    else {
        (Resolve-Path -LiteralPath (Join-Path $resolvedRoot $WorkingDirectory)).Path
    }

    Push-Location $resolvedWorkingDirectory
    try {
        Write-Info ("npm " + ($npmArgumentsToRun -join ' '))
        & npm @npmArgumentsToRun
        exit $LASTEXITCODE
    }
    finally {
        Pop-Location
    }
}
finally {
    if ($null -eq $oldUserConfig) { Remove-Item Env:NPM_CONFIG_USERCONFIG -ErrorAction SilentlyContinue } else { $env:NPM_CONFIG_USERCONFIG = $oldUserConfig }
    if ($null -eq $oldAlwaysAuth) { Remove-Item Env:NPM_CONFIG_ALWAYS_AUTH -ErrorAction SilentlyContinue } else { $env:NPM_CONFIG_ALWAYS_AUTH = $oldAlwaysAuth }
    if ($null -eq $oldNpmConfigAlwaysAuth) { Remove-Item Env:npm_config_always_auth -ErrorAction SilentlyContinue } else { $env:npm_config_always_auth = $oldNpmConfigAlwaysAuth }
}
