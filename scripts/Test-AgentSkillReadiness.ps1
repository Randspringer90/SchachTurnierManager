#requires -Version 7.0
<#
.SYNOPSIS
Prueft Agenten-/Skill-/Routing-Manifeste und -Dateien auf Schema, Eindeutigkeit, gueltige
Referenzen, keine Owner-Pfade/Secrets/Modell-Hardcoding. Ein Upload-ZIP.
#>
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/CollaborationCommon.ps1')
$run = New-RunContext -RunName 'agent-skill-readiness'
$repo = Get-RepoRoot; Set-Location $repo
$fail = New-Object System.Collections.Generic.List[string]
function Check([bool]$c, [string]$m) { if ($c) { Write-RunLog $run "OK  : $m" } else { $fail.Add($m); Write-RunLog $run "FAIL: $m" } }

$agentSchema = @('Name','Version','Zweck','Zustaendigkeitsbereich','Nicht-Zustaendigkeit','Erlaubte Tools','Verbotene Tools','Benoetigte Skills','Sicherheitsgrenzen','Eskalationsbedingungen','Uebergabe')
$skillSchema = @('name','version','purpose','trigger','trusted-inputs','untrusted-inputs','required-tools','forbidden-tools','procedure','security-controls','verification','owning-agent')

# Manifeste laden
$man = Get-Content -Raw (Join-Path $repo 'config/agent-manifest.json') | ConvertFrom-Json
$sman = Get-Content -Raw (Join-Path $repo 'config/skill-manifest.json') | ConvertFrom-Json
$rman = Get-Content -Raw (Join-Path $repo 'config/agent-routing.json') | ConvertFrom-Json

# Agenten: eindeutige Namen, Datei existiert, Schema, keine Owner-Pfade/Secrets
$names = @()
foreach ($a in $man.agents) {
    $names += $a.name
    $p = Join-Path $repo $a.canonicalPath
    Check (Test-Path $p) "Agent-Datei vorhanden: $($a.canonicalPath)"
    if (Test-Path $p) {
        $c = Get-Content -Raw $p
        foreach ($fld in $agentSchema) { if ($c -notmatch [regex]::Escape($fld)) { $fail.Add("Agent $($a.name): Schemafeld '$fld' fehlt"); } }
        Check ($c -notmatch '[A-Za-z]:\\Schach|CORE-KFM') "Agent $($a.name): keine Owner-/Fremdpfade"
        Check ($c -notmatch 'gh[pousr]_[0-9A-Za-z]{20,}') "Agent $($a.name): keine Secrets"
    }
    # Skill-Referenzen existieren im Skill-Manifest
    foreach ($sk in $a.skills) { Check (($sman.skills.name) -contains $sk) "Agent $($a.name): Skill '$sk' im Skill-Manifest" }
}
Check (($names | Sort-Object -Unique).Count -eq $names.Count) 'Agentennamen eindeutig'

# Skills: eindeutige Namen; canonical -> Schema; nicht planned -> Datei existiert
$snames = @($sman.skills.name)
Check (($snames | Sort-Object -Unique).Count -eq $snames.Count) 'Skillnamen eindeutig'
foreach ($s in $sman.skills) {
    if ($s.format -eq 'planned') { continue }
    $p = Join-Path $repo $s.canonicalPath
    Check (Test-Path $p) "Skill-Datei vorhanden: $($s.canonicalPath)"
    if ((Test-Path $p) -and $s.format -eq 'canonical') {
        $c = Get-Content -Raw $p
        foreach ($fld in $skillSchema) { if ($c -notmatch [regex]::Escape($fld)) { $fail.Add("Skill $($s.name): Feld '$fld' fehlt") } }
    }
    if (Test-Path $p) { Check ((Get-Content -Raw $p) -notmatch '[A-Za-z]:\\Schach|CORE-KFM') "Skill $($s.name): keine Owner-/Fremdpfade" }
}

# Routing: gueltige Agenten/Skills, keine Modellnamen, Qualitaetsklassen bekannt
$qc = @($rman.qualityClasses)
foreach ($r in $rman.routes) {
    Check ($names -contains $r.primaryAgent) "Routing: primaryAgent '$($r.primaryAgent)' existiert"
    Check ($names -contains $r.reviewerAgent) "Routing: reviewerAgent '$($r.reviewerAgent)' existiert"
    Check ($qc -contains $r.minimumQualityClass) "Routing: Qualitaetsklasse '$($r.minimumQualityClass)' bekannt"
    foreach ($rs in $r.requiredSkills) { Check ($snames -contains $rs) "Routing: Skill '$rs' existiert" }
}
Check ((Get-Content -Raw (Join-Path $repo 'config/agent-routing.json')) -notmatch 'claude-[0-9]|gpt-[0-9]') 'Routing ohne Modell-Hardcoding'

# Adapter-Konsistenz (falls .claude/agents vorhanden): jeder Adapter zeigt auf existierenden Agenten
$claudeAgents = Join-Path $repo '.claude/agents'
if (Test-Path $claudeAgents) {
    foreach ($f in Get-ChildItem $claudeAgents -Filter *.md) {
        if ($f.Name -eq 'README.md') { continue }
        $base = [IO.Path]::GetFileNameWithoutExtension($f.Name)
        Check (Test-Path (Join-Path $repo "agents/$base.md")) "Claude-Adapter '$($f.Name)' hat kanonischen Agenten"
    }
}

$zip = Complete-RunZip $run
if ($fail.Count -gt 0) { $fail | ForEach-Object { Write-Host "FAIL: $_" }; Write-Host "AgentSkillReadiness: $($fail.Count) FEHLER"; Write-Host "UPLOAD_ZIP=$zip"; exit 1 }
Write-Host 'AgentSkillReadiness: OK'; Write-Host "UPLOAD_ZIP=$zip"; exit 0
