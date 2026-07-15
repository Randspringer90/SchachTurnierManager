#requires -Version 7.0
# SECURITY-PATTERN-FILE: Dieser Contract-Test enthaelt bewusst Detection-Regexe, keine echten Daten.
# Pester v5 Contract-Tests fuer Agenten-/Skill-/Security-Grundlage (STM-AI-001).
# Lokal ist ggf. nur Pester 3.x vorhanden; ausfuehrbare Gates:
# scripts/Test-AgentSkillReadiness.ps1, Test-AgentInstructionIntegrity.ps1,
# Test-PromptInjectionDefense.ps1, Test-KnowledgePersistenceSafety.ps1.

BeforeAll {
    $script:Repo = (& git rev-parse --show-toplevel).Trim()
    $script:AgentMan = Get-Content -Raw (Join-Path $Repo 'config/agent-manifest.json') | ConvertFrom-Json
    $script:SkillMan = Get-Content -Raw (Join-Path $Repo 'config/skill-manifest.json') | ConvertFrom-Json
    $script:Routing  = Get-Content -Raw (Join-Path $Repo 'config/agent-routing.json') | ConvertFrom-Json
    $script:Permissions = Get-Content -Raw (Join-Path $Repo 'config/tool-permission-profiles.json') | ConvertFrom-Json
}

Describe 'Manifeste gueltig und konsistent' {
    It 'Agentennamen eindeutig, Dateien existieren' {
        $names = @($AgentMan.agents.name)
        ($names | Sort-Object -Unique).Count | Should -Be $names.Count
        foreach ($a in $AgentMan.agents) {
            $a.canonicalPath | Should -Not -Match '(^|[\\/])\.\.([\\/]|$)|^[A-Za-z]:'
            Test-Path (Join-Path $Repo $a.canonicalPath) | Should -BeTrue
        }
    }
    It 'Skillnamen eindeutig; nicht-planned Skills existieren' {
        $sn = @($SkillMan.skills.name)
        ($sn | Sort-Object -Unique).Count | Should -Be $sn.Count
        foreach ($s in $SkillMan.skills) {
            $s.canonicalPath | Should -Not -Match '(^|[\\/])\.\.([\\/]|$)|^[A-Za-z]:'
            if ($s.format -ne 'planned') { Test-Path (Join-Path $Repo $s.canonicalPath) | Should -BeTrue }
        }
    }
    It 'Agent-Skill-Referenzen existieren im Skill-Manifest' {
        $sn = @($SkillMan.skills.name)
        foreach ($a in $AgentMan.agents) { foreach ($sk in $a.skills) { $sn | Should -Contain $sk } }
    }
    It 'Routing referenziert existierende Agenten/Skills, Qualitaetsklassen' {
        $names = @($AgentMan.agents.name); $sn = @($SkillMan.skills.name); $qc = @($Routing.qualityClasses)
        foreach ($r in $Routing.routes) {
            $names | Should -Contain $r.primaryAgent
            $names | Should -Contain $r.reviewerAgent
            $qc | Should -Contain $r.minimumQualityClass
            foreach ($rs in $r.requiredSkills) { $sn | Should -Contain $rs }
        }
    }
    It 'alle vorhandenen Skillquellen sind manifestiert' {
        $manifestPaths = @($SkillMan.skills.canonicalPath | ForEach-Object { $_ -replace '\\','/' })
        $files = @(
            Get-ChildItem (Join-Path $Repo '.agents/skills') -File -Filter '*.md' | Where-Object Name -ne 'README.md'
            Get-ChildItem (Join-Path $Repo '.agents/skills') -Recurse -File -Filter 'SKILL.md'
        )
        foreach ($file in ($files | Sort-Object FullName -Unique)) {
            $rel = $file.FullName.Substring($Repo.Length + 1) -replace '\\','/'
            $manifestPaths | Should -Contain $rel
        }
    }
    It 'kanonische Skills haben discoverbares Frontmatter' {
        foreach ($s in ($SkillMan.skills | Where-Object format -eq 'canonical')) {
            $content = Get-Content -Raw (Join-Path $Repo $s.canonicalPath)
            $content | Should -Match '(?s)\A---\r?\nname:\s*[^\r\n]+\r?\ndescription:\s*[^\r\n]+\r?\n---'
        }
    }
    It 'Agentenrechte sind Teilmenge ihres Permission-Profils' {
        foreach ($a in $AgentMan.agents) {
            $profileProperty = $Permissions.profiles.PSObject.Properties[$a.permissionProfile]
            $profileProperty | Should -Not -BeNullOrEmpty
            $content = Get-Content -Raw (Join-Path $Repo $a.canonicalPath)
            $match = [regex]::Match($content, '(?m)^- \*\*Erlaubte Tools:\*\*\s*(.+)$')
            $match.Success | Should -BeTrue
            foreach ($tool in ($match.Groups[1].Value -split ',' | ForEach-Object { $_.Trim() })) {
                @($profileProperty.Value.allowed) | Should -Contain $tool
                @($profileProperty.Value.forbidden) | Should -Not -Contain $tool
                @($Permissions.globalForbidden) | Should -Not -Contain $tool
            }
        }
    }
}

Describe 'Sicherheit / keine Owner-Pfade / kein Modell-Hardcoding' {
    It 'agent-routing.json ohne Modellnamen' {
        (Get-Content -Raw (Join-Path $Repo 'config/agent-routing.json')) | Should -Not -Match 'claude-[0-9]|gpt-[0-9]'
    }
    It 'Agenten-/Skilldateien ohne Owner-/Fremdpfade und Secrets' {
        $files = @()
        $files += $AgentMan.agents.canonicalPath
        $files += ($SkillMan.skills | Where-Object { $_.format -ne 'planned' }).canonicalPath
        foreach ($rel in $files) {
            $c = Get-Content -Raw (Join-Path $Repo $rel)
            $c | Should -Not -Match '[A-Za-z]:\\Schach|[A-Za-z]:\\KFM|CORE-KFM'
            $c | Should -Not -Match 'gh[pousr]_[0-9A-Za-z]{20,}'
        }
    }
    It 'Instruction-Allowlist und Trust-Policy sind gueltiges JSON mit Kernfeldern' {
        $allow = Get-Content -Raw (Join-Path $Repo 'config/trusted-instruction-paths.json') | ConvertFrom-Json
        $allow.allowedInstructionPaths | Should -Not -BeNullOrEmpty
        $trust = Get-Content -Raw (Join-Path $Repo 'config/agent-trust-policy.json') | ConvertFrom-Json
        $trust.zones.T5.isolated | Should -BeTrue
    }
    It 'Agenten und Claude-Adapter enthalten keine Steuerzeichen oder Platzhalter' {
        foreach ($file in @(Get-ChildItem (Join-Path $Repo 'agents') -File -Filter '*.md') + @(Get-ChildItem (Join-Path $Repo '.claude/agents') -File -Filter '*.md')) {
            $content = Get-Content -Raw $file.FullName
            $content | Should -Not -Match '[\x00-\x08\x0B\x0C\x0E-\x1F]'
            $content | Should -Not -Match '\$canonical'
        }
    }
}

Describe 'Guard-Skripte parsen' {
    It 'alle neuen Skripte sind syntaktisch gueltig' {
        foreach ($s in 'Test-AgentInstructionIntegrity.ps1','Test-AgentSkillReadiness.ps1','Test-PromptInjectionDefense.ps1','Test-KnowledgePersistenceSafety.ps1','Sync-ClaudeAgentAdapters.ps1') {
            $errs = $null
            [void][System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Repo "scripts/$s"), [ref]$null, [ref]$errs)
            (@($errs).Count) | Should -Be 0
        }
    }
}
