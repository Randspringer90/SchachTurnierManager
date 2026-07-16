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
$script:expectedInstructionFiles = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$script:manifestRoots = @()
function Bad([string]$file, [string]$rule) { $fail.Add("${file}: ${rule}") }
function Test-IsAllowedInstructionPath([string]$rel) {
    $normalized = $rel -replace '\\','/'
    if ($script:expectedInstructionFiles.Contains($normalized)) { return $true }
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
    $script:manifestRoots = @($allow.manifestControlledRoots | ForEach-Object { ([string]$_) -replace '\\','/' })
    $requiredManifestRoots = @('agents/','.agents/skills/','.claude/agents/','.claude/skills/')
    foreach ($required in $requiredManifestRoots) {
        if ($script:manifestRoots -notcontains $required) { Bad 'config/trusted-instruction-paths.json' "manifestgesteuerter Root fehlt: $required" }
    }
    foreach ($root in $script:manifestRoots) {
        if ([string]::IsNullOrWhiteSpace($root) -or [IO.Path]::IsPathRooted($root) -or $root -match '(^|/)\.\.(/|$)' -or -not $root.EndsWith('/')) {
            Bad 'config/trusted-instruction-paths.json' "unsicherer manifestgesteuerter Root: $root"
        }
        elseif ($requiredManifestRoots -notcontains $root) { Bad 'config/trusted-instruction-paths.json' "unbekannter manifestgesteuerter Root: $root" }
    }
    $requiredControlledFiles = @('agents/README.md','.agents/skills/README.md','.claude/agents/README.md','.claude/skills/README.md')
    $controlledFiles = @($allow.manifestControlledFiles | ForEach-Object { ([string]$_) -replace '\\','/' })
    foreach ($required in $requiredControlledFiles) {
        if ($controlledFiles -notcontains $required) { Bad 'config/trusted-instruction-paths.json' "manifestgesteuerte Datei fehlt: $required" }
    }
    foreach ($controlled in $controlledFiles) {
        if ($requiredControlledFiles -notcontains $controlled) { Bad 'config/trusted-instruction-paths.json' "unbekannte manifestgesteuerte Datei: $controlled" }
    }
}
else { $script:allowGlobs = @() }

# 2) JSON-Policies/Manifeste gueltig
foreach ($j in 'config/agent-manifest.json','config/skill-manifest.json','config/agent-routing.json','config/agent-trust-policy.json','config/tool-permission-profiles.json','config/model-routing.json','config/model-routing.schema.json','config/pull-request-review-policy.json','config/dependency-review-policy.json','config/suspicious-change-patterns.json','config/pr-adoption-policy.json') {
    $p = Join-Path $repo $j
    if (-not (Test-Path $p)) { Bad $j 'fehlt'; continue }
    try { Get-Content -Raw $p | ConvertFrom-Json | Out-Null } catch { Bad $j 'ungueltiges JSON' }
}

# PR-Review-Policies muessen die nicht verhandelbaren statischen Trust-Grenzen explizit halten.
try {
    $prPolicy = Get-Content -Raw (Join-Path $repo 'config/pull-request-review-policy.json') | ConvertFrom-Json
    if ($prPolicy.trustedBaseBranch -ne 'development') { Bad 'config/pull-request-review-policy.json' 'trustedBaseBranch muss development sein' }
    foreach ($property in 'initialReviewExecutionAllowed','initialReviewNetworkAllowed','initialReviewSecretAccessAllowed') {
        if ($prPolicy.$property -ne $false) { Bad 'config/pull-request-review-policy.json' "$property muss false sein" }
    }
    if ($prPolicy.integrationBranchPattern -ne '^integration/pr-[1-9][0-9]*-safe-adoption$') {
        Bad 'config/pull-request-review-policy.json' 'Integrationsbranch-Muster ist zu weit oder ungueltig'
    }
    foreach ($property in 'contributorAttributionRequired','feedbackRequired','ownerReviewRequired') {
        if ($prPolicy.$property -ne $true) { Bad 'config/pull-request-review-policy.json' "$property muss true sein" }
    }
    if ($prPolicy.isolatedExecutionApproval.shaBoundReviewMarkerPrefix -cne 'STATIC-EXECUTION-APPROVED:' -or
        $prPolicy.isolatedExecutionApproval.reviewTriggerLabel -cne 'security:static-review-trigger' -or
        $prPolicy.isolatedExecutionApproval.approvalMustMatchHeadSha -ne $true -or
        $prPolicy.isolatedExecutionApproval.approvalReviewerMustBeRepositoryOwner -ne $true -or
        $prPolicy.isolatedExecutionApproval.ownerAuthoredIntegrationRequired -ne $true -or
        @($prPolicy.isolatedExecutionApproval.neverAllowed) -notcontains 'BLOCKED_UNVERIFIED') {
        Bad 'config/pull-request-review-policy.json' 'isolierte Ausfuehrung braucht exaktes Owner-Integrations-Approval und muss BLOCKED_UNVERIFIED sperren'
    }
    foreach ($requiredRisk in 'LOW','MEDIUM','HIGH','CRITICAL','UNVERIFIED') {
        if (@($prPolicy.riskClasses) -notcontains $requiredRisk) { Bad 'config/pull-request-review-policy.json' "Risikoklasse fehlt: $requiredRisk" }
    }
    foreach ($requiredDecision in 'SAFE_FOR_ISOLATED_BUILD','ADAPTATION_REQUIRED','OWNER_REVIEW_REQUIRED','BLOCKED_UNVERIFIED') {
        if (@($prPolicy.decisions) -notcontains $requiredDecision) { Bad 'config/pull-request-review-policy.json' "Entscheidung fehlt: $requiredDecision" }
    }

    $dependencyPolicy = Get-Content -Raw (Join-Path $repo 'config/dependency-review-policy.json') | ConvertFrom-Json
    foreach ($property in 'forbidFloatingVersions','requireLockfileConsistency','requireDirectDependencyJustification','inspectTransitiveDelta','inspectLicenses','inspectVulnerabilities','prohibitLocalPackagePaths','prohibitGitDependenciesWithoutOwnerReview','prohibitPackageManagerLifecycleScriptsWithoutOwnerReview') {
        if ($dependencyPolicy.$property -ne $true) { Bad 'config/dependency-review-policy.json' "$property muss true sein" }
    }
    if (@($dependencyPolicy.allowedPackageSources).Count -eq 0) { Bad 'config/dependency-review-policy.json' 'allowedPackageSources ist leer' }

    $adoptionPolicy = Get-Content -Raw (Join-Path $repo 'config/pr-adoption-policy.json') | ConvertFrom-Json
    if ($adoptionPolicy.trustedBaseRef -ne 'origin/development' -or $adoptionPolicy.integrationBranchPattern -ne '^integration/pr-[1-9][0-9]*-safe-adoption$') {
        Bad 'config/pr-adoption-policy.json' 'Adoption muss vom aktuellen development und engem Integrationsbranch-Muster starten'
    }
    if ($adoptionPolicy.foreignPullRequestMayBeMergedDirectly -ne $false) { Bad 'config/pr-adoption-policy.json' 'direkter Fremd-PR-Merge muss verboten sein' }
    foreach ($requiredState in 'DISCOVERED','QUARANTINED','STATIC_REVIEWED','DEPENDENCY_REVIEWED','MALWARE_RISK_REVIEWED','LOGIC_COMPARED','ADOPTION_PLANNED','INTEGRATION_BRANCH_READY','TESTED','FEEDBACK_READY','FEEDBACK_POSTED','SAFE_TO_MERGE','MERGED','BLOCKED_NEEDS_OWNER') {
        if (@($adoptionPolicy.reviewStates) -notcontains $requiredState) { Bad 'config/pr-adoption-policy.json' "Status fehlt: $requiredState" }
    }

    $patternPolicy = Get-Content -Raw (Join-Path $repo 'config/suspicious-change-patterns.json') | ConvertFrom-Json
    if ([int]$patternPolicy.regexTimeoutMilliseconds -lt 10 -or [int]$patternPolicy.regexTimeoutMilliseconds -gt 1000) {
        Bad 'config/suspicious-change-patterns.json' 'Regex-Timeout muss zwischen 10 und 1000 ms liegen'
    }
    if (@($patternPolicy.patterns).Count -eq 0) { Bad 'config/suspicious-change-patterns.json' 'defensive Patternliste ist leer' }

    $toolPolicy = Get-Content -Raw (Join-Path $repo 'config/tool-permission-profiles.json') | ConvertFrom-Json
    $staticProfile = $toolPolicy.profiles.'pr-review-static'
    if ($null -eq $staticProfile) { Bad 'config/tool-permission-profiles.json' 'pr-review-static Profil fehlt' }
    else {
        foreach ($allowed in @($staticProfile.allowed)) {
            if ($allowed -notin @('Read','Grep','Glob','GitHubMetadataRead','WriteReviewArtifacts')) { Bad 'config/tool-permission-profiles.json' "pr-review-static erlaubt zu viel: $allowed" }
        }
        foreach ($forbidden in 'Edit','Write','restore','build','test','install','merge','git-push','arbitrary-network','secret-read') {
            if (@($staticProfile.forbidden) -notcontains $forbidden) { Bad 'config/tool-permission-profiles.json' "pr-review-static Verbot fehlt: $forbidden" }
        }
    }
    $integrationProfile = $toolPolicy.profiles.'pr-integration-controlled'
    if ($null -eq $integrationProfile) { Bad 'config/tool-permission-profiles.json' 'pr-integration-controlled Profil fehlt' }
    else {
        foreach ($required in 'Edit','Write','restore','build','test') {
            if (@($integrationProfile.allowed) -notcontains $required) { Bad 'config/tool-permission-profiles.json' "pr-integration-controlled Erlaubnis fehlt: $required" }
        }
        foreach ($forbidden in 'execute-foreign-script','unapproved-install','network-during-untrusted','secret-read','merge-foreign-pr','git-push','tag','release') {
            if (@($integrationProfile.forbidden) -notcontains $forbidden) { Bad 'config/tool-permission-profiles.json' "pr-integration-controlled Verbot fehlt: $forbidden" }
        }
    }
} catch {
    Bad 'config/*pull-request*-policy.json' "semantische Policy-Auswertung fehlgeschlagen: $($_.Exception.Message)"
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
        foreach ($fixed in @($script:allowGlobs | Where-Object { $_ -notmatch '\*' }) + @($allow.manifestControlledFiles)) {
            [void]$script:expectedInstructionFiles.Add((([string]$fixed) -replace '\\','/'))
        }
        foreach ($a in $man.agents) {
            $normalized = ([string]$a.canonicalPath) -replace '\\','/'
            if ($normalized -notmatch '^agents/(?<base>[a-z0-9-]+)\.md$') {
                Bad "Agent $($a.name)" "kanonischer Pfad entspricht nicht agents/<name>.md: $normalized"
                continue
            }
            [void]$script:expectedInstructionFiles.Add($normalized)
            [void]$script:expectedInstructionFiles.Add(".claude/agents/$($Matches.base).md")
        }
        $sman = Get-Content -Raw (Join-Path $repo 'config/skill-manifest.json') | ConvertFrom-Json
        foreach ($s in $sman.skills) {
            $normalized = ([string]$s.canonicalPath) -replace '\\','/'
            $validSkillPath = if ($s.format -eq 'canonical' -or $s.format -eq 'planned') {
                $normalized -match '^\.agents/skills/[a-z0-9-]+/SKILL\.md$'
            }
            else {
                $normalized -match '^\.agents/skills/(?:[a-z0-9-]+\.md|[a-z0-9-]+/SKILL\.md)$'
            }
            if (-not $validSkillPath) {
                Bad "Skill $($s.name)" "kanonischer Pfad entspricht nicht dem Skillformat: $normalized"
                continue
            }
            if ($s.format -ne 'planned') { [void]$script:expectedInstructionFiles.Add($normalized) }
        }

        foreach ($a in $man.agents) {
            $p = Resolve-ManifestInstructionFile $a.canonicalPath "Agent $($a.name)"
            if (-not $p -or -not (Test-Path -LiteralPath $p -PathType Leaf)) { Bad $a.canonicalPath "Agent-Referenz fehlt/unsicher ($($a.name))" } else { Scan $a.canonicalPath }
        }
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
$trackedNormalized = @($tracked | ForEach-Object { $_ -replace '\\','/' })
foreach ($expected in $script:expectedInstructionFiles) {
    if ($trackedNormalized -notcontains $expected) { Bad $expected 'erwartete Instruktionsquelle ist nicht getrackt' }
}
$instrCandidates = @($tracked | Where-Object {
    $candidate = $_ -replace '\\','/'
    $inManifestRoot = $false
    foreach ($root in $script:manifestRoots) {
        if ($candidate.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) { $inManifestRoot = $true; break }
    }
    $inManifestRoot -or (Test-IsAllowedInstructionPath $candidate) -or ([IO.Path]::GetFileName($candidate) -in @('AGENTS.md','CLAUDE.md','SKILL.md'))
} | Sort-Object -Unique)
foreach ($rel in ($instrCandidates | Where-Object { $_ })) {
    $rel = ($rel.Trim() -replace '\\','/')
    if (-not $script:expectedInstructionFiles.Contains($rel)) { Bad $rel 'unmanifestierte Instruktionsquelle'; continue }
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
