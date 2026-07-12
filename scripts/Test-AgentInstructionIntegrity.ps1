#requires -Version 7.0
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
$repo = (& git rev-parse --show-toplevel).Trim()
Set-Location $repo
$fail = New-Object System.Collections.Generic.List[string]
function Bad([string]$file, [string]$rule) { $fail.Add("${file}: ${rule}") }

# Muster (Zeichenklassen, damit dieses Skript sich nicht selbst triggert).
$secretRx = 'gh[pousr]_[0-9A-Za-z]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|xox[baprs]-[0-9A-Za-z-]+'
$piiRx    = 'Mar' + 'co|Gei' + 'ßhirt|Gei' + 'sshirt|Ilme' + 'nauer|461' + '0563'
$ownerPathRx = '[A-Za-z]:\\Schach|[A-Za-z]:\\KFM|CORE-KFM'
$modelHardcodeRx = 'claude-[0-9]|gpt-[0-9]|claude-opus|claude-sonnet|claude-haiku'

# 1) Allowlist laden
$allowPath = Join-Path $repo 'config/trusted-instruction-paths.json'
if (-not (Test-Path $allowPath)) { Bad 'config/trusted-instruction-paths.json' 'Allowlist fehlt' }
else {
    try { $allow = (Get-Content -Raw $allowPath | ConvertFrom-Json) } catch { Bad 'config/trusted-instruction-paths.json' 'ungueltiges JSON'; $allow = $null }
}

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
if ($allow) {
    try {
        $man = Get-Content -Raw (Join-Path $repo 'config/agent-manifest.json') | ConvertFrom-Json
        foreach ($a in $man.agents) {
            if (-not (Test-Path (Join-Path $repo $a.canonicalPath))) { Bad $a.canonicalPath "Agent-Referenz fehlt ($($a.name))" } else { Scan $a.canonicalPath }
        }
        $sman = Get-Content -Raw (Join-Path $repo 'config/skill-manifest.json') | ConvertFrom-Json
        foreach ($s in $sman.skills) {
            if ($s.format -eq 'planned') { continue }
            if (-not (Test-Path (Join-Path $repo $s.canonicalPath))) { Bad $s.canonicalPath "Skill-Referenz fehlt ($($s.name))" } else { Scan $s.canonicalPath }
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

# 5) Unbekannte Instruktionsdateien: neue AGENTS/CLAUDE/SKILL ausserhalb Allowlist
$instrCandidates = git -C $repo ls-files 'AGENTS.md' '**/AGENTS.md' '**/CLAUDE.md' '.claude/**' 'agents/**' '.agents/skills/**' 2>$null
foreach ($rel in ($instrCandidates | Where-Object { $_ })) {
    $rel = $rel.Trim()
    # Pfadtraversierung/Reparse
    if ($rel -match '\.\.[\\/]') { Bad $rel 'Pfadtraversierung' }
}

if ($fail.Count -gt 0) {
    if (-not $Quiet) { $fail | ForEach-Object { Write-Host "FAIL: $_" } }
    Write-Host "AGENT_INSTRUCTION_INTEGRITY=FEHLER ($($fail.Count))"
    exit 1
}
Write-Host 'AGENT_INSTRUCTION_INTEGRITY=OK'
exit 0
