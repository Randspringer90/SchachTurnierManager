[CmdletBinding()]
param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-ExpectedSuccess {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    & pwsh @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Erwarteter Erfolg ist fehlgeschlagen (ExitCode=$LASTEXITCODE): $($Arguments -join ' ')"
    }
}

function Invoke-ExpectedFailure {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    & pwsh @Arguments *> $null
    if ($LASTEXITCODE -eq 0) {
        throw "Erwarteter Fehler blieb aus: $($Arguments -join ' ')"
    }
}

$runRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("stm-release-trust-" + [Guid]::NewGuid().ToString('N'))
try {
    $webApp = Join-Path $runRoot 'src/SchachTurnierManager.WebApp'
    $artifactRoot = Join-Path $runRoot 'output'
    $installerRoot = Join-Path $artifactRoot 'installer'
    New-Item -ItemType Directory -Force -Path $webApp,$artifactRoot,$installerRoot | Out-Null

    '{"name":"synthetic","version":"9.8.7"}' | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $webApp 'package.json')
    'desktop synthetic payload' | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $artifactRoot 'SchachTurnierManager_Desktop_9.8.7.zip')
    'portable synthetic payload' | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $artifactRoot 'SchachTurnierManager_Portable_9.8.7.zip')
    'installer synthetic payload' | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $installerRoot 'SchachTurnierManager_Setup_9.8.7.exe')

    $manifestPath = Join-Path $artifactRoot 'release\SchachTurnierManager_Update_9.8.7.json'
    $newManifest = @(
        '-NoLogo','-NoProfile','-ExecutionPolicy','Bypass',
        '-File',(Join-Path $Root 'scripts/New-ReleaseUpdateManifest.ps1'),
        '-Root',$runRoot,
        '-ArtifactRoot',$artifactRoot,
        '-OutputPath',$manifestPath,
        '-Channel','preview'
    )
    Invoke-ExpectedSuccess -Arguments $newManifest

    $validate = @(
        '-NoLogo','-NoProfile','-ExecutionPolicy','Bypass',
        '-File',(Join-Path $Root 'scripts/Test-ReleaseUpdateManifest.ps1'),
        '-ManifestPath',$manifestPath,
        '-ArtifactRoot',$artifactRoot,
        '-ExpectedVersion','9.8.7',
        '-RequireCompleteSet',
        '-RequireInstaller'
    )
    Invoke-ExpectedSuccess -Arguments $validate

    # Hash-Manipulation muss fail-closed blockieren.
    Add-Content -Encoding UTF8 -LiteralPath (Join-Path $artifactRoot 'SchachTurnierManager_Desktop_9.8.7.zip') -Value 'tampered'
    Invoke-ExpectedFailure -Arguments $validate

    # Manifest neu erzeugen und danach Path-Traversal synthetisch einschleusen.
    Invoke-ExpectedSuccess -Arguments $newManifest
    $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
    $manifest.artifacts[0].relativePath = '../escape.zip'
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 -LiteralPath $manifestPath
    Invoke-ExpectedFailure -Arguments $validate

    # Signiervertrag statisch absichern: keine PFX-/Passwort-basierte Repo-Automation,
    # explizite Freigabe und CurrentUser-Zertifikatsspeicher sind Pflicht.
    $signingScript = Get-Content -Raw -LiteralPath (Join-Path $Root 'scripts/Sign-ReleaseArtifacts.ps1')
    if ($signingScript -notmatch 'ApproveSigning') { throw 'Signierfreigabe fehlt.' }
    if ($signingScript -notmatch 'signtool\.exe') { throw 'SignTool-Vertrag fehlt.' }
    if ($signingScript -notmatch '/sha1') { throw 'Thumbprint-Auswahl fuer SignTool fehlt.' }
    if ($signingScript -notmatch 'Get-AuthenticodeSignature') { throw 'Signatur-Nachpruefung fehlt.' }
    $validationHelper = Get-Content -Raw -LiteralPath (Join-Path $Root 'scripts/lib/ReleaseTrustValidation.ps1')
    if ($signingScript -notmatch 'Assert-StmReleaseSignature' -or $validationHelper -notmatch '1\.3\.6\.1\.5\.5\.7\.3\.3') { throw 'Code-Signing-EKU-Pruefung fehlt.' }
    if ($signingScript -match '(?i)\.pfx|password|securestring.*password') {
        throw 'PFX-/Passwort-basierte Signierautomation ist nicht freigegeben.'
    }

    foreach ($scriptName in 'New-ReleaseUpdateManifest.ps1','Test-ReleaseUpdateManifest.ps1','Invoke-ReleaseTrustReadiness.ps1') {
        $scriptText = Get-Content -Raw -LiteralPath (Join-Path $Root "scripts/$scriptName")
        if ($scriptText -match '(?i)Invoke-WebRequest|Invoke-RestMethod|Start-Process.+https?://') {
            throw "Auto-Download/Auto-Execute im Update-Trust-Pfad blockiert: $scriptName"
        }
    }

    Invoke-ExpectedSuccess -Arguments @('-NoLogo', '-NoProfile', '-NonInteractive', '-File', (Join-Path $Root 'scripts/Test-ReleaseSigningValidation.ps1'), '-Root', $Root)
    Write-Host 'RELEASE_TRUST_READINESS=OK'
}
finally {
    Remove-Item -LiteralPath $runRoot -Recurse -Force -ErrorAction SilentlyContinue
}
