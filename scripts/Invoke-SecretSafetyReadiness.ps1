param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$RunName = 'STM_RUN50_SecretSafety',
    [string]$BaseDirectory = 'D:\Temp'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-SafeFileName([string]$Value) {
    $safe = $Value -replace '[^a-zA-Z0-9_.-]+', '_'
    if ([string]::IsNullOrWhiteSpace($safe)) { return 'run' }
    return $safe.Trim('_')
}

function New-SecretRunDirectory {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$DirectoryRoot
    )

    $safeName = ConvertTo-SafeFileName $Name
    $candidate = Join-Path $DirectoryRoot ("${safeName}_$(Get-Date -Format yyyyMMdd_HHmmss)")
    New-Item -ItemType Directory -Force -Path $candidate | Out-Null
    return (Resolve-Path -LiteralPath $candidate).Path
}

$bundleScript = Join-Path $PSScriptRoot 'New-RunLogBundle.ps1'
$loggedCommandScript = Join-Path $PSScriptRoot 'Invoke-LoggedCommand.ps1'
$runDirectory = New-SecretRunDirectory -Name $RunName -DirectoryRoot $BaseDirectory
Write-Host "RUN_DIR=$runDirectory"

function Write-RunText {
    param(
        [Parameter(Mandatory = $true)][string]$FileName,
        [Parameter(Mandatory = $true)][string]$Content
    )

    if ([string]::IsNullOrWhiteSpace($script:runDirectory)) {
        throw 'RunDirectory ist leer; SecretSafety kann keine Logdateien schreiben.'
    }

    $path = Join-Path $script:runDirectory $FileName
    $Content | Set-Content -Encoding UTF8 -LiteralPath $path
}

function Resolve-UploadZipPath {
    param([Parameter(Mandatory = $true)][string]$Directory)

    $zipPath = & $bundleScript -RunDirectory $Directory -RunName $RunName
    if ([string]::IsNullOrWhiteSpace($zipPath)) {
        $zipPath = Join-Path (Split-Path -Parent $Directory) ("$(Split-Path -Leaf $Directory).zip")
    }

    if (-not (Test-Path -LiteralPath $zipPath -PathType Leaf)) {
        throw "Run-ZIP wurde nicht erzeugt: $zipPath"
    }

    return (Resolve-Path -LiteralPath $zipPath).Path
}

function Complete-SecretRunBundle {
    $zipPath = Resolve-UploadZipPath -Directory $script:runDirectory
    Write-Host "UPLOAD_ZIP=$zipPath"
}

try {
    & $loggedCommandScript -RunDirectory $runDirectory -Name 'git-safety' -WorkingDirectory $Root -CommandLine 'pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-GitCommitSafety.ps1'

    $secretName = 'selftest_' + (Get-Date -Format 'yyyyMMdd_HHmmss')
    $plainValue = 'secret-safety-selftest-' + [Guid]::NewGuid().ToString('N')
    $inputPath = Join-Path $runDirectory 'secret-input.local.txt'
    $setLogPath = Join-Path $runDirectory 'dpapi-set-local-secret.log'
    $resultPath = Join-Path $runDirectory 'dpapi-roundtrip-result.txt'

    $plainValue | Set-Content -Encoding UTF8 -NoNewline -LiteralPath $inputPath
    try {
        & (Join-Path $PSScriptRoot 'Set-LocalSecret.ps1') -Root $Root -Name $secretName -InputFile $inputPath *> $setLogPath
        $encryptedPath = Join-Path $Root ".secrets/local/$secretName.dpapi.txt"
        if (-not (Test-Path -LiteralPath $encryptedPath -PathType Leaf)) {
            throw "DPAPI-Datei wurde nicht erzeugt: .secrets/local/$secretName.dpapi.txt"
        }

        $encryptedRaw = Get-Content -Raw -LiteralPath $encryptedPath
        if ($null -eq $encryptedRaw -or [string]::IsNullOrWhiteSpace($encryptedRaw.Trim())) {
            throw "DPAPI-Datei ist leer oder nur Whitespace: .secrets/local/$secretName.dpapi.txt"
        }

        $roundtrip = & (Join-Path $PSScriptRoot 'Get-LocalSecret.ps1') -Root $Root -Name $secretName -AsPlainTextForChildProcessOnly
        if ($roundtrip -ne $plainValue) {
            throw 'DPAPI-Roundtrip lieferte nicht den erwarteten Wert.'
        }

        @"
Secret safety selftest: OK
Encrypted file: .secrets/local/$secretName.dpapi.txt
Value logged: no
Gitignored local secret cleanup: performed
"@ | Set-Content -Encoding UTF8 -LiteralPath $resultPath
    }
    finally {
        Remove-Item -LiteralPath $inputPath -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath (Join-Path $Root ".secrets/local/$secretName.dpapi.txt") -Force -ErrorAction SilentlyContinue
    }

    $gitignore = Get-Content -Raw -LiteralPath (Join-Path $Root '.gitignore')
    foreach ($required in @('.secrets/local/', 'secrets/local/', '*.dpapi.txt', '.npmrc', 'NEXT_PROMPT.md')) {
        if ($gitignore -notmatch [regex]::Escape($required)) {
            throw ".gitignore enthaelt Pflichtmuster nicht: $required"
        }
    }

    Write-RunText -FileName 'secret-safety-summary.txt' -Content @"
OK: GitSafety, DPAPI-Roundtrip, lokale Secret-Ablage und Gitignore-Schutz geprueft.
Root: $Root
Run: $runDirectory
"@

    Complete-SecretRunBundle
}
catch {
    if (-not [string]::IsNullOrWhiteSpace($runDirectory)) {
        Write-RunText -FileName 'FAILED.txt' -Content $_.Exception.ToString()
        Complete-SecretRunBundle
    }
    throw
}
