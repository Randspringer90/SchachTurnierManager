#requires -Version 7.0
# Pester v5 Contract-Tests fuer Agenten-/Skill-/Security-Grundlage (STM-AI-001).
# Lokal ist ggf. nur Pester 3.x vorhanden; ausfuehrbare Gates:
# scripts/Test-AgentSkillReadiness.ps1, Test-AgentInstructionIntegrity.ps1,
# Test-PromptInjectionDefense.ps1, Test-KnowledgePersistenceSafety.ps1.

BeforeAll {
    $script:Repo = (& git rev-parse --show-toplevel).Trim()
    $script:AgentMan = Get-Content -Raw (Join-Path $Repo 'config/agent-manifest.json') | ConvertFrom-Json
    $script:SkillMan = Get-Content -Raw (Join-Path $Repo 'config/skill-manifest.json') | ConvertFrom-Json
    $script:Routing  = Get-Content -Raw (Join-Path $Repo 'config/agent-routing.json') | ConvertFrom-Json
}

Describe 'Manifeste gueltig und konsistent' {
    It 'Agentennamen eindeutig, Dateien existieren' {
        $names = @($AgentMan.agents.name)
        ($names | Sort-Object -Unique).Count | Should -Be $names.Count
        foreach ($a in $AgentMan.agents) { Test-Path (Join-Path $Repo $a.canonicalPath) | Should -BeTrue }
    }
    It 'Skillnamen eindeutig; nicht-planned Skills existieren' {
        $sn = @($SkillMan.skills.name)
        ($sn | Sort-Object -Unique).Count | Should -Be $sn.Count
        foreach ($s in $SkillMan.skills) { if ($s.format -ne 'planned') { Test-Path (Join-Path $Repo $s.canonicalPath) | Should -BeTrue } }
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
