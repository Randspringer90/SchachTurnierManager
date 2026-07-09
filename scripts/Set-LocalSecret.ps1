param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z][A-Za-z0-9_.-]{1,80}$')]
    [string]$Name,

    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,

    [string]$InputFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info([string]$Message) {
    Write-Host "[Set-LocalSecret] $Message"
}

$secretDir = Join-Path $Root '.secrets/local'
New-Item -ItemType Directory -Force -Path $secretDir | Out-Null
$target = Join-Path $secretDir "$Name.dpapi.txt"

if ($InputFile) {
    if (-not (Test-Path -LiteralPath $InputFile -PathType Leaf)) {
        throw "InputFile nicht gefunden: $InputFile"
    }
    $plainText = Get-Content -Raw -LiteralPath $InputFile
    $secure = ConvertTo-SecureString -String $plainText -AsPlainText -Force
}
else {
    $secure = Read-Host -AsSecureString "Wert fuer $Name eingeben"
}

$secure | ConvertFrom-SecureString | Set-Content -Encoding UTF8 -LiteralPath $target
Write-Info "Gespeichert: .secrets/local/$Name.dpapi.txt"
Write-Info 'Der Secret-Wert wurde nicht ausgegeben. Datei bleibt lokal/gitignored.'
