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
    if ($null -eq $plainText) { $plainText = '' }
    $secure = ConvertTo-SecureString -String $plainText -AsPlainText -Force
}
else {
    $secure = Read-Host -AsSecureString "Wert fuer $Name eingeben"
}

$serializedSecret = $secure | ConvertFrom-SecureString
if ([string]::IsNullOrWhiteSpace($serializedSecret)) {
    throw 'DPAPI-Serialisierung lieferte keinen Wert. Secret wurde nicht gespeichert.'
}

# Keine abschliessende neue Zeile schreiben: Get-LocalSecret liest den DPAPI-Blob zwar robust,
# aber die lokale Datei soll maschinenlesbar und editorunabhaengig bleiben.
Set-Content -Encoding UTF8 -NoNewline -LiteralPath $target -Value $serializedSecret
Write-Info "Gespeichert: .secrets/local/$Name.dpapi.txt"
Write-Info 'Der Secret-Wert wurde nicht ausgegeben. Datei bleibt lokal/gitignored.'
