#requires -Version 7.0
<#
.SYNOPSIS
Synchronisiert duenne Claude-Code-Adapter (.claude/agents/**) aus der kanonischen Struktur
(agents/**, config/agent-manifest.json). Adapter verweisen nur, duplizieren keine Regeln.
.DESCRIPTION
Standard ist Check/WhatIf (keine Aenderung). Nur -Apply schreibt. Idempotent, sichere
Pfadvalidierung (kein Symlink/Traversal), ruhige Konsole, Details im Runordner, ein Upload-ZIP.
.PARAMETER Check
Prueft Adapter-Synchronitaet ohne Aenderung (Default).
.PARAMETER Apply
Schreibt/aktualisiert Adapter.
.PARAMETER WhatIf
Erzwingt Plan-Modus.
.PARAMETER RepositoryRoot
Optionaler Repo-Root (sonst automatisch).
.PARAMETER NoArchive
Unterdrueckt das eigenstaendige Run-ZIP, wenn ein uebergeordneter Lauf die Logs buendelt.
#>
[CmdletBinding()]
param([switch]$Check, [switch]$Apply, [switch]$WhatIf, [switch]$NoArchive, [string]$RepositoryRoot)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/CollaborationCommon.ps1')

$repo = if ($RepositoryRoot) { (Resolve-Path -LiteralPath $RepositoryRoot).Path } else { Get-RepoRoot }
if (-not (Test-Path (Join-Path $repo 'SchachTurnierManager.sln'))) { throw "RepositoryRoot ungueltig: $repo" }
$doApply = $Apply.IsPresent -and -not $WhatIf.IsPresent

$run = New-RunContext -RunName 'sync-claude-adapters'
Write-RunLog $run ("Repo: $repo  Modus: " + ($(if ($doApply) { 'APPLY' } else { 'CHECK/PLAN' })))

$man = Get-Content -Raw (Join-Path $repo 'config/agent-manifest.json') | ConvertFrom-Json
$claudeAgents = Join-Path $repo '.claude/agents'
$drift = @(); $written = @()

function Render-Adapter($name, $canonical) {
$rendered = (@'
# Claude-Adapter: {0}

> Duenner Adapter. **Kanonische Wahrheit:** [`{1}`](../../{1}) sowie `AGENTS.md`,
> `agents/README.md`, `config/agent-manifest.json`. Dieser Adapter definiert **keine** eigenen
> Regeln und dupliziert keine Modellnamen. Trust-Grenzen: `docs/architecture/AGENT_TRUST_BOUNDARIES.md`.
'@ -f $name, $canonical)
return $rendered + [Environment]::NewLine
}

foreach ($a in $man.agents) {
    $base = [IO.Path]::GetFileNameWithoutExtension($a.canonicalPath)
    # Sichere Pfadvalidierung
    if ($base -notmatch '^[a-z0-9-]+$') { throw "Ungueltiger Agentendateiname: $base" }
    $target = Join-Path $claudeAgents "$base.md"
    $expected = Render-Adapter $a.name $a.canonicalPath
    $current = if (Test-Path $target) { Get-Content -Raw $target } else { $null }
    if ($current -ne $expected) {
        $drift += $base
        if ($doApply) {
            New-Item -ItemType Directory -Force -Path $claudeAgents | Out-Null
            Set-Content -LiteralPath $target -Value $expected -Encoding utf8 -NoNewline
            $written += $base
        }
    }
}

# READMEs
$agentsReadme = @'
# Claude-Adapter: Agenten

> Duenne Adapter auf die kanonische Struktur `agents/**`. Keine eigenen Regeln. Siehe `AGENTS.md`.
'@
$skillsReadme = @'
# Claude-Adapter: Skills

> Duenne Verweise auf `.agents/skills/**` (kanonisch). Keine Regel-/Wahrheitsduplikate.
'@
$agentsReadme += [Environment]::NewLine
$skillsReadme += [Environment]::NewLine
foreach ($pair in @(@{p=(Join-Path $claudeAgents 'README.md'); c=$agentsReadme}, @{p=(Join-Path $repo '.claude/skills/README.md'); c=$skillsReadme})) {
    $cur = if (Test-Path $pair.p) { Get-Content -Raw $pair.p } else { $null }
    if ($cur -ne $pair.c) { $drift += (Split-Path $pair.p -Leaf); if ($doApply) { New-Item -ItemType Directory -Force -Path (Split-Path $pair.p -Parent) | Out-Null; Set-Content -LiteralPath $pair.p -Value $pair.c -Encoding utf8 -NoNewline; $written += (Split-Path $pair.p -Leaf) } }
}

if ($doApply) { Write-RunLog $run ("Geschrieben/aktualisiert: " + ($written -join ', ')) }
else { Write-RunLog $run ("Drift (wuerde geschrieben): " + ($(if ($drift.Count) { $drift -join ', ' } else { 'keine - synchron' }))) }

$zip = if ($NoArchive) { $null } else { Complete-RunZip $run }
if (-not $doApply -and $drift.Count -gt 0) { Write-Host "ADAPTERS=DRIFT ($($drift.Count))"; if ($zip) { Write-Host "UPLOAD_ZIP=$zip" }; exit 1 }
Write-Host ("ADAPTERS=" + ($(if ($doApply) { "APPLIED ($($written.Count))" } else { 'IN-SYNC' })))
if ($zip) { Write-Host "UPLOAD_ZIP=$zip" }; exit 0
