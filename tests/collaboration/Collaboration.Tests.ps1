#requires -Version 7.0
# Pester v5 Contract-Tests fuer die Kollaborationsstruktur.
# Ausfuehren:  pwsh -c "Invoke-Pester tests/collaboration/Collaboration.Tests.ps1"

BeforeAll {
    $script:RepoRoot = (& git rev-parse --show-toplevel).Trim()
    . (Join-Path $RepoRoot 'scripts/lib/CollaborationCommon.ps1')
}

Describe 'Branch-/ID-/SemVer-Validierung' {
    It 'akzeptiert gueltige Namenssegmente' {
        foreach ($v in @('trf-export','fide-dutch','a','a1-b2')) { Test-SafeNameSegment $v | Should -BeTrue }
    }
    It 'lehnt unsichere/injection-verdaechtige Namen ab' {
        foreach ($v in @('Bad Name','; rm -rf','feature/../x','a--','-a','a-','UPPER','a_b','$(x)','a;b')) {
            Test-SafeNameSegment $v | Should -BeFalse
        }
    }
    It 'validiert Backlog-IDs streng' {
        Test-BacklogIdFormat 'STM-IE-001' | Should -BeTrue
        foreach ($v in @('STM-ie-001','STM-IE-1','IE-001','STM-IE-0001','STM--001')) {
            Test-BacklogIdFormat $v | Should -BeFalse
        }
    }
    It 'validiert SemVer' {
        Test-SemVer '1.0.0' | Should -BeTrue
        foreach ($v in @('1.0','v1.0.0','1.0.0-rc','1.a.0')) { Test-SemVer $v | Should -BeFalse }
    }
    It 'Assert-* wirft bei ungueltigen Werten' {
        { Assert-SafeNameSegment 'Bad Name' } | Should -Throw
        { Assert-BacklogId 'nope' } | Should -Throw
        { Assert-SemVer '1.0' } | Should -Throw
    }
}

Describe 'Backlog-Schema' {
    BeforeAll { $script:Backlog = Get-Content -Raw (Join-Path $RepoRoot 'docs/planning/BACKLOG.md') }
    It 'markiert sich als kanonische Quelle' { $Backlog | Should -Match 'kanonisch' }
    It 'hat eindeutige Aufgaben-IDs' {
        $ids = [regex]::Matches($Backlog,'\bSTM-[A-Z]+-[0-9]{3}\b') | ForEach-Object { $_.Value }
        ($ids | Group-Object | Where-Object Count -gt ($ids.Count)) | Should -BeNullOrEmpty
        ($ids | Sort-Object -Unique).Count | Should -BeGreaterThan 0
    }
    It 'nutzt nur erlaubte Statuswerte in der Uebersichtstabelle' {
        $allowed = @('Backlog','Ready','In Progress','In Review','Blocked','Done','Deferred')
        $rows = [regex]::Matches($Backlog,'(?m)^\|\s*(STM-[A-Z]+-[0-9]{3})\s*\|[^|]*\|[^|]*\|\s*([^|]+?)\s*\|')
        $rows.Count | Should -BeGreaterThan 0
        foreach ($m in $rows) { $allowed | Should -Contain (($m.Groups[2].Value -replace '\*','').Trim()) }
    }
    It 'enthaelt mindestens eine Ready-Aufgabe' { $Backlog | Should -Match '\*\*Ready\*\*' }
    It 'definiert die Pflichtfelder' {
        foreach ($f in @('Akzeptanzkriterien','Tests','Security','Definition of Done','Ziel-Release','Branch')) {
            $Backlog | Should -Match ([regex]::Escape($f))
        }
    }
}

Describe 'CODEOWNERS' {
    BeforeAll { $script:Co = Get-Content -Raw (Join-Path $RepoRoot '.github/CODEOWNERS') }
    It 'nennt den Owner' { $Co | Should -Match '@Randspringer90' }
    It 'schuetzt sicherheitskritische Pfade' {
        foreach ($p in @('AGENTS.md','.claude/','.agents/','config/','.github/','docs/security/','docs/architecture/','installer/')) {
            $Co | Should -Match ([regex]::Escape($p))
        }
    }
}

Describe 'PR-Template' {
    BeforeAll { $script:Pr = Get-Content -Raw (Join-Path $RepoRoot '.github/pull_request_template.md') }
    It 'verlangt die Pflichtangaben' {
        foreach ($s in @('Backlog-ID','GitHub-Issue','Zielbranch','ReleaseGate','Security-Check','Prompt-Injection','Breaking Change','Secrets')) {
            $Pr | Should -Match ([regex]::Escape($s))
        }
    }
}

Describe 'Workflows / Branch-Policy' {
    BeforeAll { $script:WfDir = Join-Path $RepoRoot '.github/workflows' }
    It 'enthaelt keinen pull_request_target-Trigger' {
        foreach ($f in Get-ChildItem $WfDir -Filter *.yml) {
            $lines = Get-Content $f.FullName
            (@($lines | Where-Object { $_ -match '^\s*[^#]*pull_request_target\s*:' }).Count) | Should -Be 0
        }
    }
    It 'branch-policy erlaubt nach main nur release/hotfix' {
        $bp = Get-Content -Raw (Join-Path $WfDir 'branch-policy.yml')
        $bp | Should -Match 'release/\*\|hotfix/\*'
    }
    It 'ci laeuft fuer development, main, release/**' {
        $ci = Get-Content -Raw (Join-Path $WfDir 'ci.yml')
        $ci | Should -Match 'development'; $ci | Should -Match 'release/\*\*'
    }
}

Describe 'Keine Secrets / keine Fremdpfade in Kollaborations-Skripten' {
    It 'enthaelt keine harten Fremdprojekt-Pfade oder Secrets' {
        $files = Get-ChildItem (Join-Path $RepoRoot 'scripts') -Filter '*ollaboration*'
        $files += Get-ChildItem (Join-Path $RepoRoot 'scripts') -Filter 'New-FeatureBranch.ps1'
        $files += Get-ChildItem (Join-Path $RepoRoot 'scripts') -Filter 'Prepare-*Branch.ps1'
        foreach ($f in $files) {
            $c = Get-Content -Raw $f.FullName
            $c | Should -Not -Match 'CORE-KFM'
            $c | Should -Not -Match 'BEGIN [A-Z ]*PRIVATE KEY'
        }
    }
}

Describe 'Configure-GitHubCollaboration: WhatIf macht keine Aenderungen' {
    It 'laeuft im Plan-Modus ohne gh-Schreibzugriff (statische Pruefung)' {
        $c = Get-Content -Raw (Join-Path $RepoRoot 'scripts/Configure-GitHubCollaboration.ps1')
        # Schreibzugriffe (POST/PUT/PATCH) nur wenn $doApply wahr ist.
        $c | Should -Match '\$doApply\s*=\s*\$Apply\.IsPresent\s*-and\s*-not\s*\$WhatIf\.IsPresent'
        $c | Should -Match 'if\s*\(-not\s*\$doApply\)'
    }
    It 'nutzt Admin-Bypass ueber RepositoryRole (nicht geraten/hartkodierter User)' {
        $c = Get-Content -Raw (Join-Path $RepoRoot 'scripts/Configure-GitHubCollaboration.ps1')
        $c | Should -Match "actor_type\s*=\s*'RepositoryRole'"
    }
}

Describe 'Config: model-routing ist self-contained' {
    It 'ist gueltiges JSON ohne Fremdpfade' {
        $p = Join-Path $RepoRoot 'config/model-routing.json'
        { Get-Content -Raw $p | ConvertFrom-Json } | Should -Not -Throw
        (Get-Content -Raw $p) | Should -Not -Match 'CORE-KFM'
    }
}
