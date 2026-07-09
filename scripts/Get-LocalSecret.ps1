param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z][A-Za-z0-9_.-]{1,80}$')]
    [string]$Name,

    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,

    [switch]$AsPlainTextForChildProcessOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-SecretPath {
    param([string]$SecretName)

    $candidates = @(
        (Join-Path $Root ".secrets/local/$SecretName.dpapi.txt"),
        (Join-Path $Root "secrets/local/$SecretName.dpapi.txt")
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw "Lokales Secret nicht gefunden: $SecretName. Erwartet unter .secrets/local/ oder legacy secrets/local/."
}

function ConvertTo-RelativeDisplayPath {
    param([string]$Path)

    $resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
    if ($Path.StartsWith($resolvedRoot, [StringComparison]::OrdinalIgnoreCase)) {
        $relative = $Path.Substring($resolvedRoot.Length)
        $trimChars = [char[]]@(
            [System.IO.Path]::DirectorySeparatorChar,
            [System.IO.Path]::AltDirectorySeparatorChar
        )
        return $relative.TrimStart($trimChars)
    }

    return $Path
}

$path = Resolve-SecretPath -SecretName $Name
$serializedSecret = Get-Content -Raw -LiteralPath $path -ErrorAction Stop
if ($null -eq $serializedSecret) {
    $serializedSecret = ''
}

# ConvertFrom-SecureString schreibt je nach PowerShell/Editor eine abschliessende neue Zeile.
# Fuer ConvertTo-SecureString darf der DPAPI-Blob aber keine Leerzeichen/Zeilenumbrueche enthalten.
$serializedSecret = $serializedSecret.Trim()
$displayPath = ConvertTo-RelativeDisplayPath -Path $path

if ([string]::IsNullOrWhiteSpace($serializedSecret)) {
    throw "Lokales Secret ist leer oder unlesbar: $displayPath. Bitte mit scripts/Set-LocalSecret.ps1 neu setzen."
}

try {
    $secure = ConvertTo-SecureString -String $serializedSecret
}
catch {
    throw "Lokales Secret konnte nicht per Windows-DPAPI entschluesselt werden: $displayPath. Es muss mit demselben Windows-Benutzer auf diesem Rechner erzeugt werden. Detail: $($_.Exception.Message)"
}

if (-not $AsPlainTextForChildProcessOnly) {
    Write-Output $secure
    return
}

$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try {
    # Nur fuer direkte Uebergabe an einen Child-Prozess verwenden. Nicht loggen, nicht committen.
    [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
}
finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
}
