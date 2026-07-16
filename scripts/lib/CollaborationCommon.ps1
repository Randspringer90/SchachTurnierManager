# CollaborationCommon.ps1
# Gemeinsame, injection-sichere Hilfsfunktionen fuer die Kollaborations-Skripte.
# Wird per Dot-Sourcing eingebunden. Enthaelt KEINE Secrets und keine Fremdprojekt-Pfade.
# SECURITY-PATTERN-FILE: definiert Validierungs-Regexe fuer Branch-/ID-Namen.

Set-StrictMode -Version Latest

# --- Validierung (verhindert Shell-/Branchname-Injection) ---

function Test-SafeNameSegment {
    param([Parameter(Mandatory)][string]$Value)
    # Nur Kleinbuchstaben, Ziffern, Bindestrich; kein fuehrender/abschliessender Bindestrich.
    return [bool]($Value -cmatch '^[a-z0-9]([a-z0-9-]*[a-z0-9])?$')
}

function Test-BacklogIdFormat {
    param([Parameter(Mandatory)][string]$Value)
    return [bool]($Value -cmatch '^STM-[A-Z]+-[0-9]{3}$')
}

function Test-SemVer {
    param([Parameter(Mandatory)][string]$Value)
    return [bool]($Value -match '^[0-9]+\.[0-9]+\.[0-9]+$')
}

function Assert-SafeNameSegment {
    param([Parameter(Mandatory)][string]$Value, [string]$What = 'Name')
    if (-not (Test-SafeNameSegment $Value)) {
        throw "$What '$Value' ist ungueltig. Erlaubt: ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ (keine Sonderzeichen, kein Injection-Risiko)."
    }
}

function Assert-BacklogId {
    param([Parameter(Mandatory)][string]$Value)
    if (-not (Test-BacklogIdFormat $Value)) {
        throw "Backlog-ID '$Value' ist ungueltig. Erwartet: STM-<KATEGORIE>-<NNN>, z. B. STM-IE-001."
    }
}

function Assert-SemVer {
    param([Parameter(Mandatory)][string]$Value)
    if (-not (Test-SemVer $Value)) {
        throw "Version '$Value' ist keine gueltige SemVer (MAJOR.MINOR.PATCH)."
    }
}

function Test-BacklogIdExists {
    param([Parameter(Mandatory)][string]$BacklogId, [string]$BacklogPath)
    if (-not $BacklogPath) { $BacklogPath = Join-Path (Get-RepoRoot) 'docs/planning/BACKLOG.md' }
    if (-not (Test-Path -LiteralPath $BacklogPath)) { return $false }
    $content = Get-Content -LiteralPath $BacklogPath -Raw
    return [bool]($content -match [regex]::Escape($BacklogId))
}

# --- Repo / Git ---

function Get-RepoRoot {
    $root = (& git rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $root) { throw 'Kein Git-Repository gefunden.' }
    return $root.Trim()
}

function Assert-CleanWorktree {
    $status = (& git status --porcelain)
    if ($status) { throw "Arbeitsbaum ist nicht sauber. Bitte zuerst committen/stashen:`n$status" }
}

# --- Run-Kontext: Details unter dem plattformneutralen System-Temp-Pfad, genau EIN Upload-ZIP ---

function New-RunContext {
    param([Parameter(Mandatory)][string]$RunName)
    Assert-SafeNameSegment ($RunName.ToLowerInvariant()) 'RunName'
    $stamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
    $base = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if (-not (Test-Path -LiteralPath $base)) { New-Item -ItemType Directory -Force -Path $base | Out-Null }
    $dir = Join-Path $base ("{0}_{1}" -f $RunName, $stamp)
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $log = Join-Path $dir 'run.log'
    "[{0}] Run '{1}' gestartet." -f (Get-Date -Format o), $RunName | Set-Content -LiteralPath $log -Encoding utf8
    return [pscustomobject]@{ RunName = $RunName; Dir = $dir; Log = $log; Stamp = $stamp }
}

function Write-RunLog {
    param([Parameter(Mandatory)]$Run, [Parameter(Mandatory)][string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format o), $Message
    Add-Content -LiteralPath $Run.Log -Value $line -Encoding utf8
    Write-Host $Message
}

function Complete-RunZip {
    param([Parameter(Mandatory)]$Run)
    $zip = Join-Path (Split-Path $Run.Dir -Parent) ("{0}_{1}.zip" -f $Run.RunName, $Run.Stamp)
    if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
    Compress-Archive -Path (Join-Path $Run.Dir '*') -DestinationPath $zip -Force
    Write-RunLog $Run ("Upload-ZIP erstellt: {0}" -f $zip)
    return $zip
}
