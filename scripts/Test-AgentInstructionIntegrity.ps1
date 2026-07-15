#requires -Version 7.0
# SECURITY-PATTERN-FILE: Diese Datei enthaelt bewusst Detection-/Blocklist-Regexe, keine echten Daten.
<#
.SYNOPSIS
Instruction-Integrity-Gate: prueft, dass nur freigegebene Instruktionsquellen existieren und
gueltig sind. Leichtgewichtig und in andere Gates/CI einbettbar.
.DESCRIPTION
Prueft Allowlist (config/trusted-instruction-paths.json), gueltige JSON-Policies/Manifeste,
Agenten-/Skill-Referenzen, unbekannte Instruktionsdateien, Pfadtraversierung/Reparse Points,
externe Abhaengigkeiten, lokale absolute Pfade, Secrets, PII, Modell-Hardcoding. Gibt
AGENT_INSTRUCTION_INTEGRITY=OK oder einen klaren Fehler (Datei + Regel) aus. Exit 0/1.
#>
[CmdletBinding()]
param([switch]$Quiet)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((& git rev-parse --show-toplevel).Trim())
Set-Location $repo
$fail = New-Object System.Collections.Generic.List[string]
function Bad([string]$file, [string]$rule) { $fail.Add("${file}: ${rule}") }
function Test-IsAllowedInstructionPath([string]$rel) {
    $normalized = $rel -replace '\\','/'
    foreach ($glob in $script:allowGlobs) {
        $rx = '^' + [regex]::Escape($glob).Replace('\*\*','.*').Replace('\*','[^/]*') + '$'
        if ($normalized -match $rx) { return $true }
    }
    return $false
}

# Muster (Zeichenklassen, damit dieses Skript sich nicht selbst triggert).
$secretRx = 'gh[pousr]_[0-9A-Za-z]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|xox[baprs]-[0-9A-Za-z-]+'
$piiRx    = '(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b|\b(?:\+?49|0)[1-9][0-9][0-9\s()/.-]{6,}\b|\b(?:FIDE|DSB)[- ]?(?:ID)?\s*[:=]?\s*[0-9]{5,}\b'
$ownerPathRx = '(?i)[A-Za-z]:\\(?:KFM|Schach|Users)(?:\\|$)'
$modelHardcodeRx = 'claude-[0-9]|gpt-[0-9]|claude-opus|claude-sonnet|claude-haiku'

# 1) Allowlist laden
$allowPath = Join-Path $repo 'config/trusted-instruction-paths.json'
if (-not (Test-Path $allowPath)) { Bad 'config/trusted-instruction-paths.json' 'Allowlist fehlt' }
else {
    try { $allow = (Get-Content -Raw $allowPath | ConvertFrom-Json) } catch { Bad 'config/trusted-instruction-paths.json' 'ungueltiges JSON'; $allow = $null }
}
if ($allow) {
    $script:allowGlobs = @($allow.allowedInstructionPaths)
    if ($script:allowGlobs.Count -eq 0) { Bad 'config/trusted-instruction-paths.json' 'Allowlist ist leer' }
    foreach ($glob in $script:allowGlobs) {
        if ([string]::IsNullOrWhiteSpace($glob) -or [IO.Path]::IsPathRooted($glob) -or $glob -match '(^|[\\/])\.\.([\\/]|$)') {
            Bad 'config/trusted-instruction-paths.json' "unsicherer Allowlist-Pfad: $glob"
        }
    }
}
else { $script:allowGlobs = @() }

# 2) JSON-Policies/Manifeste gueltig
foreach ($j in 'config/agent-manifest.json','config/skill-manifest.json','config/agent-routing.json','config/agent-trust-policy.json','config/tool-permission-profiles.json','config/model-routing.json') {
    $p = Join-Path $repo $j
    if (-not (Test-Path $p)) { Bad $j 'fehlt'; continue }
    try { Get-Content -Raw $p | ConvertFrom-Json | Out-Null } catch { Bad $j 'ungueltiges JSON' }
}

# 3) Agenten-/Skill-Referenzen existieren; Inhalte ohne Secrets/PII/Owner-Pfade
function Scan([string]$rel) {
    $p = Join-Path $repo $rel
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { return }
    $c = Get-Content -Raw -LiteralPath $p
    if ($c -match $secretRx) { Bad $rel 'moegliches Secret' }
    if ($c -match $piiRx) { Bad $rel 'personenbezogener Anker (PII)' }
    if ($c -match $ownerPathRx) { Bad $rel 'lokaler Owner-/Fremdprojektpfad' }
}
function Resolve-ManifestInstructionFile([string]$rel, [string]$context) {
    $normalized = ($rel ?? '') -replace '\\','/'
    if ([string]::IsNullOrWhiteSpace($normalized) -or [IO.Path]::IsPathRooted($normalized) -or $normalized -match '(^|/)\.\.(/|$)') {
        Bad $context "unsicherer Manifestpfad: $rel"
        return $null
    }
    if (-not (Test-IsAllowedInstructionPath $normalized)) {
        Bad $context "Manifestpfad ausserhalb Instruction-Allowlist: $rel"
        return $null
    }
    $full = [IO.Path]::GetFullPath((Join-Path $repo $normalized))
    $rootPrefix = $repo.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        Bad $context "Manifestpfad verlaesst Repository-Root: $rel"
        return $null
    }
    $stage = (& git -C $repo ls-files --stage -- $normalized 2>$null | Select-Object -First 1)
    if ($stage -match '^120000\s') { Bad $context "Git-Symlink unzulaessig: $rel"; return $null }
    $item = Get-Item -LiteralPath $full -Force -ErrorAction SilentlyContinue
    if ($item -and (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) { Bad $context "Reparse-Point unzulaessig: $rel"; return $null }
    return $full
}
if ($allow) {
    try {
        $man = Get-Content -Raw (Join-Path $repo 'config/agent-manifest.json') | ConvertFrom-Json
        foreach ($a in $man.agents) {
            $p = Resolve-ManifestInstructionFile $a.canonicalPath "Agent $($a.name)"
            if (-not $p -or -not (Test-Path -LiteralPath $p -PathType Leaf)) { Bad $a.canonicalPath "Agent-Referenz fehlt/unsicher ($($a.name))" } else { Scan $a.canonicalPath }
        }
        $sman = Get-Content -Raw (Join-Path $repo 'config/skill-manifest.json') | ConvertFrom-Json
        foreach ($s in $sman.skills) {
            if ($s.format -eq 'planned') { continue }
            $p = Resolve-ManifestInstructionFile $s.canonicalPath "Skill $($s.name)"
            if (-not $p -or -not (Test-Path -LiteralPath $p -PathType Leaf)) { Bad $s.canonicalPath "Skill-Referenz fehlt/unsicher ($($s.name))" } else { Scan $s.canonicalPath }
        }
    } catch { Bad 'config' "Manifest-Auswertung fehlgeschlagen: $($_.Exception.Message)" }
}

# 4) Kein Modell-Hardcoding in Routing-/Agenten-Instruktionen (model-routing.json ist die Ausnahme mit Defaults)
foreach ($f in (Get-ChildItem (Join-Path $repo 'agents') -Filter *.md -ErrorAction SilentlyContinue)) {
    if ((Get-Content -Raw $f.FullName) -match $modelHardcodeRx) { Bad "agents/$($f.Name)" 'Modell-Hardcoding (Qualitaetsklassen verwenden)' }
}
if ((Test-Path (Join-Path $repo 'config/agent-routing.json')) -and ((Get-Content -Raw (Join-Path $repo 'config/agent-routing.json')) -match $modelHardcodeRx)) {
    Bad 'config/agent-routing.json' 'Modell-Hardcoding (nur Qualitaetsklassen erlaubt)'
}

# 5) Alle allowlisteten Quellen sowie AGENTS/CLAUDE/SKILL-Kandidaten pruefen.
# Symlinks/Reparse-Points sind fuer Instruktionsquellen unzulaessig, weil ihr Ziel den Repo-Root
# verlassen oder nach dem Review ausgetauscht werden koennte.
$tracked = @(git -C $repo ls-files 2>$null | Where-Object { $_ })
$instrCandidates = @($tracked | Where-Object {
    (Test-IsAllowedInstructionPath $_) -or ([IO.Path]::GetFileName($_) -in @('AGENTS.md','CLAUDE.md','SKILL.md'))
} | Sort-Object -Unique)
foreach ($rel in ($instrCandidates | Where-Object { $_ })) {
    $rel = ($rel.Trim() -replace '\\','/')
    if (-not (Test-IsAllowedInstructionPath $rel)) { Bad $rel 'Instruktionsdatei liegt ausserhalb der Allowlist'; continue }
    if ([IO.Path]::IsPathRooted($rel) -or $rel -match '(^|/)\.\.(/|$)') { Bad $rel 'Pfadtraversierung/absoluter Pfad'; continue }
    $path = Join-Path $repo $rel
    $full = [IO.Path]::GetFullPath($path)
    $rootPrefix = $repo.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) { Bad $rel 'aufgeloester Pfad verlaesst Repository-Root'; continue }
    $stage = (& git -C $repo ls-files --stage -- $rel 2>$null | Select-Object -First 1)
    if ($stage -match '^120000\s') { Bad $rel 'Git-Symlink als Instruktionsquelle verboten'; continue }
    $item = Get-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
    if ($item -and (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) { Bad $rel 'Reparse-Point als Instruktionsquelle verboten'; continue }
    Scan $rel
}

if ($fail.Count -gt 0) {
    if (-not $Quiet) { $fail | ForEach-Object { Write-Host "FAIL: $_" } }
    Write-Host "AGENT_INSTRUCTION_INTEGRITY=FEHLER ($($fail.Count))"
    exit 1
}
Write-Host 'AGENT_INSTRUCTION_INTEGRITY=OK'
exit 0
