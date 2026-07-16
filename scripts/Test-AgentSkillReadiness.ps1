#requires -Version 7.0
# SECURITY-PATTERN-FILE: Diese Datei enthaelt bewusst Detection-/Blocklist-Regexe, keine echten Daten.
<#
.SYNOPSIS
Prueft Agenten-/Skill-/Routing-Manifeste und -Dateien auf Schema, Eindeutigkeit, gueltige
Referenzen, keine Owner-Pfade/Secrets/Modell-Hardcoding. Ein Upload-ZIP.
#>
[CmdletBinding()]
param([switch]$NoArchive)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/CollaborationCommon.ps1')
$run = New-RunContext -RunName 'agent-skill-readiness'
$repo = [IO.Path]::GetFullPath((Get-RepoRoot)); Set-Location $repo
$fail = New-Object System.Collections.Generic.List[string]
function Check([bool]$c, [string]$m) { if ($c) { Write-RunLog $run "OK  : $m" } else { $fail.Add($m); Write-RunLog $run "FAIL: $m" } }
function Resolve-RepositoryFile([string]$rel, [string]$kind) {
    $normalized = ($rel ?? '') -replace '\\','/'
    if ([string]::IsNullOrWhiteSpace($normalized) -or [IO.Path]::IsPathRooted($normalized) -or $normalized -match '(^|/)\.\.(/|$)') {
        $fail.Add("${kind}: unsicherer Manifestpfad '$rel'")
        return $null
    }
    $full = [IO.Path]::GetFullPath((Join-Path $repo $normalized))
    $rootPrefix = $repo.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        $fail.Add("${kind}: Manifestpfad verlaesst Repository-Root '$rel'")
        return $null
    }
    $stage = (& git -C $repo ls-files --stage -- $normalized 2>$null | Select-Object -First 1)
    if ($stage -match '^120000\s') {
        $fail.Add("${kind}: Git-Symlink unzulaessig '$rel'")
        return $null
    }
    $item = Get-Item -LiteralPath $full -Force -ErrorAction SilentlyContinue
    if ($item -and (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
        $fail.Add("${kind}: Reparse-Point unzulaessig '$rel'")
        return $null
    }
    return $full
}

$agentSchema = @('Name','Version','Zweck','Zustaendigkeitsbereich','Nicht-Zustaendigkeit','Erlaubte Tools','Verbotene Tools','Benoetigte Skills','Sicherheitsgrenzen','Eskalationsbedingungen','Uebergabe')
$skillSchema = @('name','version','purpose','trigger','trusted-inputs','untrusted-inputs','required-tools','forbidden-tools','procedure','security-controls','verification','owning-agent')

# Manifeste laden
$man = Get-Content -Raw (Join-Path $repo 'config/agent-manifest.json') | ConvertFrom-Json
$sman = Get-Content -Raw (Join-Path $repo 'config/skill-manifest.json') | ConvertFrom-Json
$rman = Get-Content -Raw (Join-Path $repo 'config/agent-routing.json') | ConvertFrom-Json
$permissions = Get-Content -Raw (Join-Path $repo 'config/tool-permission-profiles.json') | ConvertFrom-Json

# Agenten: eindeutige Namen, Datei existiert, Schema, keine Owner-Pfade/Secrets
$names = @()
foreach ($a in $man.agents) {
    $names += $a.name
    Check ((([string]$a.canonicalPath) -replace '\\','/') -match '^agents/[a-z0-9-]+\.md$') "Agent $($a.name): kanonischer Pfad unter agents/"
    $p = Resolve-RepositoryFile $a.canonicalPath "Agent $($a.name)"
    Check ($p -and (Test-Path -LiteralPath $p -PathType Leaf)) "Agent-Datei vorhanden/sicher: $($a.canonicalPath)"
    if ($p -and (Test-Path -LiteralPath $p -PathType Leaf)) {
        $c = Get-Content -Raw $p
        foreach ($fld in $agentSchema) { if ($c -notmatch [regex]::Escape($fld)) { $fail.Add("Agent $($a.name): Schemafeld '$fld' fehlt"); } }
        Check ($c -notmatch '(?i)[A-Za-z]:\\(?:KFM|Schach|Users)(?:\\|$)') "Agent $($a.name): keine Owner-/Fremdpfade"
        Check ($c -notmatch 'gh[pousr]_[0-9A-Za-z]{20,}') "Agent $($a.name): keine Secrets"
        Check ($c -notmatch '[\x00-\x08\x0B\x0C\x0E-\x1F]') "Agent $($a.name): keine Steuerzeichen"

        $profileProperty = $permissions.profiles.PSObject.Properties[$a.permissionProfile]
        Check ($null -ne $profileProperty) "Agent $($a.name): Permission-Profil '$($a.permissionProfile)' existiert"
        if ($profileProperty) {
            $profile = $profileProperty.Value
            $allowedMatch = [regex]::Match($c, '(?m)^- \*\*Erlaubte Tools:\*\*\s*(.+)$')
            Check $allowedMatch.Success "Agent $($a.name): Erlaubte Tools sind auswertbar"
            if ($allowedMatch.Success) {
                $agentAllowed = @($allowedMatch.Groups[1].Value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
                foreach ($tool in $agentAllowed) {
                    Check (@($profile.allowed) -contains $tool) "Agent $($a.name): Tool '$tool' im Profil erlaubt"
                    Check (@($profile.forbidden) -notcontains $tool) "Agent $($a.name): Tool '$tool' nicht im Profil verboten"
                    Check (@($permissions.globalForbidden) -notcontains $tool) "Agent $($a.name): Tool '$tool' nicht global verboten"
                }
            }
        }
    }
    # Skill-Referenzen existieren im Skill-Manifest
    foreach ($sk in $a.skills) { Check (($sman.skills.name) -contains $sk) "Agent $($a.name): Skill '$sk' im Skill-Manifest" }
}
Check (($names | Sort-Object -Unique).Count -eq $names.Count) 'Agentennamen eindeutig'
$expectedAgentFiles = @('agents/README.md') + @($man.agents.canonicalPath | ForEach-Object { $_ -replace '\\','/' })
$trackedAgentFiles = @(git -C $repo ls-files 'agents/**' | ForEach-Object { $_ -replace '\\','/' })
foreach ($rel in $trackedAgentFiles) { Check ($expectedAgentFiles -contains $rel) "Agentenquelle manifestiert/fest freigegeben: $rel" }
foreach ($rel in $expectedAgentFiles) { Check ($trackedAgentFiles -contains $rel) "Erwartete Agentenquelle getrackt: $rel" }

# Skills: eindeutige Namen; canonical -> Schema; nicht planned -> Datei existiert
$snames = @($sman.skills.name)
Check (($snames | Sort-Object -Unique).Count -eq $snames.Count) 'Skillnamen eindeutig'
foreach ($s in $sman.skills) {
    if ($s.format -eq 'planned') { continue }
    $p = Resolve-RepositoryFile $s.canonicalPath "Skill $($s.name)"
    Check ($p -and (Test-Path -LiteralPath $p -PathType Leaf)) "Skill-Datei vorhanden/sicher: $($s.canonicalPath)"
    if ($p -and (Test-Path -LiteralPath $p -PathType Leaf) -and $s.format -eq 'canonical') {
        $c = Get-Content -Raw $p
        Check ($c -match '(?s)\A---\r?\nname:\s*[^\r\n]+\r?\ndescription:\s*[^\r\n]+\r?\n---') "Skill $($s.name): discoverbares YAML-Frontmatter"
        foreach ($fld in $skillSchema) { if ($c -notmatch [regex]::Escape($fld)) { $fail.Add("Skill $($s.name): Feld '$fld' fehlt") } }
    }
    if ($p -and (Test-Path -LiteralPath $p -PathType Leaf)) { Check ((Get-Content -Raw $p) -notmatch '(?i)[A-Za-z]:\\(?:KFM|Schach|Users)(?:\\|$)') "Skill $($s.name): keine Owner-/Fremdpfade" }
}

# Jede vorhandene Skillquelle muss manifestiert sein; Migration des Formats bleibt STM-AI-001b.
$manifestPaths = @($sman.skills | Where-Object format -ne 'planned' | ForEach-Object { $_.canonicalPath -replace '\\','/' })
$expectedSkillFiles = @('.agents/skills/README.md') + $manifestPaths
$trackedSkillFiles = @(git -C $repo ls-files '.agents/skills/**' | ForEach-Object { $_ -replace '\\','/' })
foreach ($rel in $trackedSkillFiles) { Check ($expectedSkillFiles -contains $rel) "Skillquelle manifestiert/fest freigegeben: $rel" }
foreach ($rel in $expectedSkillFiles) { Check ($trackedSkillFiles -contains $rel) "Erwartete Skillquelle getrackt: $rel" }

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
        $content = Get-Content -Raw $f.FullName
        Check ($content -match [regex]::Escape("../../agents/$base.md")) "Claude-Adapter '$($f.Name)' verweist auf kanonischen Pfad"
        Check ($content -notmatch '\$canonical') "Claude-Adapter '$($f.Name)' enthaelt keinen Platzhalter"
        Check ($content -notmatch '[\x00-\x08\x0B\x0C\x0E-\x1F]') "Claude-Adapter '$($f.Name)' enthaelt keine Steuerzeichen"
    }
    $expectedAdapters = @('.claude/agents/README.md') + @($man.agents.canonicalPath | ForEach-Object { '.claude/agents/' + [IO.Path]::GetFileName($_) })
    $trackedAdapters = @(git -C $repo ls-files '.claude/agents/**' | ForEach-Object { $_ -replace '\\','/' })
    foreach ($rel in $trackedAdapters) { Check ($expectedAdapters -contains $rel) "Claude-Agentadapter manifestiert/fest freigegeben: $rel" }
    foreach ($rel in $expectedAdapters) { Check ($trackedAdapters -contains $rel) "Erwarteter Claude-Agentadapter getrackt: $rel" }
}
$trackedClaudeSkills = @(git -C $repo ls-files '.claude/skills/**' | ForEach-Object { $_ -replace '\\','/' })
foreach ($rel in $trackedClaudeSkills) { Check ($rel -eq '.claude/skills/README.md') "Claude-Skillpfad auf freigegebenes README begrenzt: $rel" }

$zip = if ($NoArchive) { $null } else { Complete-RunZip $run }
if ($fail.Count -gt 0) { $fail | ForEach-Object { Write-Host "FAIL: $_" }; Write-Host "AgentSkillReadiness: $($fail.Count) FEHLER"; if ($zip) { Write-Host "UPLOAD_ZIP=$zip" }; exit 1 }
Write-Host 'AgentSkillReadiness: OK'; if ($zip) { Write-Host "UPLOAD_ZIP=$zip" }; exit 0
