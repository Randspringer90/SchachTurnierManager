#requires -Version 7.0
# SECURITY-PATTERN-FILE: Inert synthetic static-review fixtures; no candidate execution.
[CmdletBinding()]
param(
    [string]$CommonPath,
    [ValidatePattern('^[0-9a-f]{40}$')][string]$ReviewedBaseSha
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$trustedRuntime = Join-Path $repositoryRoot 'scripts/lib/PullRequestReviewCommon.ps1'
if ($CommonPath) {
    # An explicit historical-runtime regression only accepts a reviewed Git
    # ancestor copied inside ignored output, never arbitrary candidate source.
    if (-not $ReviewedBaseSha) { throw 'Historical runtime requires ReviewedBaseSha.' }
    $trustedRuntime=[IO.Path]::GetFullPath($CommonPath)
    $outputPrefix=(Join-Path $repositoryRoot 'output')+[IO.Path]::DirectorySeparatorChar
    $comparison=if($IsWindows){[StringComparison]::OrdinalIgnoreCase}else{[StringComparison]::Ordinal}
    if (-not $trustedRuntime.StartsWith($outputPrefix,$comparison)) { throw 'Historical runtime must stay inside project output.' }
    & git -C $repositoryRoot merge-base --is-ancestor $ReviewedBaseSha HEAD
    if ($LASTEXITCODE -ne 0) { throw 'Historical runtime is not a current reviewed ancestor.' }
    $reviewedSource=@(& git -C $repositoryRoot show ($ReviewedBaseSha+':scripts/lib/PullRequestReviewCommon.ps1'))
    if ($LASTEXITCODE -ne 0) { throw 'Reviewed historical runtime is unavailable.' }
} elseif ($ReviewedBaseSha) { throw 'ReviewedBaseSha requires CommonPath.' }
foreach ($runtimePath in @($trustedRuntime,(Join-Path (Split-Path -Parent $trustedRuntime) 'PullRequestArtifactVerification.ps1'),(Join-Path $repositoryRoot 'scripts/lib/PullRequestArtifactVerification.ps1'))) {
    $cursor = $runtimePath
    while ($cursor) {
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue
        if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Untrusted context-test runtime path.' }
        $parent = Split-Path -Parent $cursor
        if (-not $parent -or $parent -ceq $cursor) { break }
        $cursor = $parent
    }
}
if ($CommonPath) {
    $copiedSource=(Get-Content -Raw -LiteralPath $trustedRuntime).Replace("`r`n","`n").TrimEnd([char]10)
    if ($copiedSource -cne ($reviewedSource -join "`n").TrimEnd([char]10)) { throw 'Historical runtime differs from reviewed Git source.' }
    $copiedHelper=Join-Path (Split-Path -Parent $trustedRuntime) 'PullRequestArtifactVerification.ps1'
    $currentHelper=Join-Path $repositoryRoot 'scripts/lib/PullRequestArtifactVerification.ps1'
    if ((Get-Content -Raw -LiteralPath $copiedHelper).Replace("`r`n","`n") -cne (Get-Content -Raw -LiteralPath $currentHelper).Replace("`r`n","`n")) {
        throw 'Historical runtime helper differs from current trusted library.'
    }
}
. $trustedRuntime
$script:assertions = 0
function Assert-ContextEqual($Actual, $Expected, [string]$Name) {
    if ($Actual -cne $Expected) { throw ('Context assertion failed: ' + $Name) }
    $script:assertions++
}
function Get-SyntheticGitBlobSha([string]$Text) {
    $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
    $hasher = [Security.Cryptography.IncrementalHash]::CreateHash([Security.Cryptography.HashAlgorithmName]::SHA1)
    try {
        $hasher.AppendData([Text.Encoding]::ASCII.GetBytes("blob $($bytes.Length)" + [char]0))
        $hasher.AppendData($bytes)
        return ([Convert]::ToHexString($hasher.GetHashAndReset())).ToLowerInvariant()
    } finally { $hasher.Dispose() }
}
function New-ContextScenario {
    $path = 'scripts/fixtures/reviewer.txt'
    $rule = [pscustomobject]@{ id='credential-access'; category='malware'; severity='critical'; appliesTo=@('patch'); pattern='synthetic-risk' }
    $file = [pscustomobject]@{
        path=$path; previousPath=''; status='modified'; mode='100644'; modeAvailable=$true
        beforeMode='100644'; beforeBlobSha=(Get-SyntheticGitBlobSha "seed`n"); headBlobSha=(Get-SyntheticGitBlobSha "synthetic-risk`n")
        patchAvailable=$true; patchComplete=$true; additions=1; deletions=1
    }
    $record = [pscustomobject]@{
        path=$path; mode=$file.mode; blobSha=$file.headBlobSha; beforeBlobSha=$file.beforeBlobSha; beforeMode=$file.beforeMode
        reviewHeadSha=('a'*40); patterns=@([pscustomobject]@{ id=$rule.id; definitionSha256=(Get-ReviewPatternDefinitionHash $rule) })
    }
    [pscustomobject]@{
        metadata=[pscustomobject]@{ headSha=('b'*40); patternContextHeadSha=('b'*40); gitTreeMetadataComplete=$true }
        files=@($file); review=[pscustomobject]@{ sourcePatternContexts=@($record) }
        suspicious=[pscustomobject]@{ regexTimeoutMilliseconds=100; patterns=@($rule) }
        patch="diff --git a/$path b/$path`n--- a/$path`n+++ b/$path`n@@ -1 +1 @@`n-seed`n+synthetic-risk"
    }
}
function Copy-ContextValue($Value) { $Value | ConvertTo-Json -Depth 20 | ConvertFrom-Json }
function Invoke-ContextScenario($Scenario) {
    $findings = [Collections.Generic.List[object]]::new()
    Add-ReviewContextBoundPatchFindings -Findings $findings -Patch $Scenario.patch -Metadata $Scenario.metadata `
        -Files $Scenario.files -ReviewPolicy $Scenario.review -PatternPolicy $Scenario.suspicious
    return $findings.ToArray()
}
function Assert-Risk($Scenario, [string]$Severity, [string]$Name, [string]$Path='') {
    $findings = @(Invoke-ContextScenario $Scenario)
    $risks = @($findings | Where-Object { $_.code -ceq 'CREDENTIAL_ACCESS' -and (-not $Path -or $_.path -ceq $Path) })
    Assert-ContextEqual ($risks.Count -gt 0) $true "$Name finding retained"
    Assert-ContextEqual (@($risks | Where-Object severity -CNE $Severity).Count) 0 "$Name severity"
    Assert-ContextEqual (@($risks | Where-Object sourceZone -CNE 'T4').Count) 0 "$Name remains T4"
    if ($Severity -ceq 'HIGH') {
        Assert-ContextEqual (@($findings | Where-Object severity -CEQ 'CRITICAL').Count) 0 "$Name no independent blocker"
        Assert-ContextEqual (@($risks | Where-Object riskClass -CNE 'HIGH').Count) 0 "$Name owner review risk"
    }
}
function Assert-InvalidPolicy($Scenario, [string]$Name) {
    $caught = $false
    try { Assert-ReviewSourcePatternContexts -ReviewPolicy $Scenario.review -PatternPolicy $Scenario.suspicious }
    catch { $caught = $_.Exception.Message.StartsWith('SOURCE_PATTERN_CONTEXT_', [StringComparison]::Ordinal) }
    Assert-ContextEqual $caught $true "$Name rejected"
}

$baseline = New-ContextScenario
Assert-ReviewSourcePatternContexts -ReviewPolicy $baseline.review -PatternPolicy $baseline.suspicious
Assert-Risk $baseline HIGH 'Exact immutable context'
Assert-ContextEqual @(Invoke-ContextScenario $baseline).Count 1 'Exact context keeps one finding'
# Exercise the actual API normalization route, rather than relying solely on a
# hand-written diff. Synthetic tree entries bind each side to real Git blob IDs.
$apiFile=[pscustomobject]@{ filename=$baseline.files[0].path; status='modified'; additions=1; deletions=1; patch="@@ -1 +1 @@`n-seed`n+synthetic-risk" }
$headTree=[pscustomobject]@{ truncated=$false; tree=@([pscustomobject]@{path=$apiFile.filename;mode='100644';sha=$baseline.files[0].headBlobSha}) }
$baseTree=[pscustomobject]@{ truncated=$false; tree=@([pscustomobject]@{path=$apiFile.filename;mode='100644';sha=$baseline.files[0].beforeBlobSha}) }
$normalized=ConvertFrom-GitHubPullRequestReviewData -ApiFiles @($apiFile) -HeadTree $headTree -BaseTree $baseTree
Assert-ContextEqual $normalized.patch $baseline.patch 'API reconstructed exact headers and hunks'
$scenario=Copy-ContextValue $baseline
$scenario.files=$normalized.files; $scenario.patch=$normalized.patch
$scenario.metadata.gitTreeMetadataComplete=$normalized.treeMetadataComplete
Assert-Risk $scenario HIGH 'API reconstructed context'
# A later commit can preserve the exact reviewed before/after blobs. Historical
# review provenance is deliberately different from the current live Head proof.
$scenario = Copy-ContextValue $baseline
$scenario.metadata.headSha = 'c'*40; $scenario.metadata.patternContextHeadSha = 'c'*40
Assert-Risk $scenario HIGH 'Later commit preserving reviewed blobs'
$scenario = Copy-ContextValue $baseline
$scenario.files[0].mode = '100755'; $scenario.review.sourcePatternContexts[0].mode = '100755'
Assert-Risk $scenario HIGH 'Exact executable mode attestation'

# Each missing or changed fact independently revokes the exception.
$revocations = [ordered]@{
    'No trusted context' = { param($s) $s.review.sourcePatternContexts=@() }
    'Path moved with unchanged bytes' = { param($s) $s.files[0].path='scripts/fixtures/moved.txt'; $s.patch=$s.patch.Replace('scripts/fixtures/reviewer.txt',$s.files[0].path) }
    'Path case changed' = { param($s) $s.files[0].path='scripts/fixtures/Reviewer.txt'; $s.patch=$s.patch.Replace('scripts/fixtures/reviewer.txt',$s.files[0].path) }
    'Missing head blob' = { param($s) $s.files[0].PSObject.Properties.Remove('headBlobSha') }
    'Head byte changed' = { param($s) $s.files[0].headBlobSha=Get-SyntheticGitBlobSha "synthetic-risk changed`n"; $s.patch=$s.patch.Replace('+synthetic-risk','+synthetic-risk changed') }
    'Before byte changed' = { param($s) $s.files[0].beforeBlobSha=Get-SyntheticGitBlobSha "seed changed`n"; $s.patch=$s.patch.Replace('-seed','-seed changed') }
    'Before newline changed' = { param($s) $s.files[0].beforeBlobSha=Get-SyntheticGitBlobSha "seed`r`n" }
    'After newline changed' = { param($s) $s.files[0].headBlobSha=Get-SyntheticGitBlobSha "synthetic-risk`r`n" }
    'Missing before blob' = { param($s) $s.files[0].PSObject.Properties.Remove('beforeBlobSha') }
    'Mode drift' = { param($s) $s.files[0].mode='100755' }
    'Unavailable mode' = { param($s) $s.files[0].modeAvailable=$false }
    'Missing mode availability' = { param($s) $s.files[0].PSObject.Properties.Remove('modeAvailable') }
    'Before mode drift' = { param($s) $s.files[0].beforeMode='100755' }
    'Missing before mode' = { param($s) $s.files[0].PSObject.Properties.Remove('beforeMode') }
    'Live head proof drift' = { param($s) $s.metadata.patternContextHeadSha='c'*40 }
    'Current head drift' = { param($s) $s.metadata.headSha='c'*40 }
    'Missing live head proof' = { param($s) $s.metadata.PSObject.Properties.Remove('patternContextHeadSha') }
    'Missing current head' = { param($s) $s.metadata.PSObject.Properties.Remove('headSha') }
    'Malformed live head' = { param($s) $s.metadata.patternContextHeadSha='unknown' }
    'Incomplete offline tree metadata' = { param($s) $s.metadata.gitTreeMetadataComplete=$false }
    'Missing tree proof' = { param($s) $s.metadata.PSObject.Properties.Remove('gitTreeMetadataComplete') }
    'Unavailable patch' = { param($s) $s.files[0].patchAvailable=$false }
    'Incomplete patch' = { param($s) $s.files[0].patchComplete=$false }
    'Definition hash drift' = { param($s) $s.review.sourcePatternContexts[0].patterns[0].definitionSha256='d'*64 }
    'Pattern literal drift' = { param($s) $s.suspicious.patterns[0].pattern='synthetic-(?:risk)' }
    'Pattern category drift' = { param($s) $s.suspicious.patterns[0].category='unverified' }
    'Pattern scope drift' = { param($s) $s.suspicious.patterns[0].appliesTo=@('patch','metadata') }
}
foreach ($entry in $revocations.GetEnumerator()) {
    $scenario = Copy-ContextValue $baseline
    & $entry.Value $scenario
    Assert-Risk $scenario CRITICAL $entry.Key
}

# Invalid policies fail before scanning; trusted provenance cannot be wildcarded.
$invalidPolicies = [ordered]@{
    'Wildcard context path' = { param($s) $s.review.sourcePatternContexts[0].path='scripts/*.txt' }
    'Traversal context path' = { param($s) $s.review.sourcePatternContexts[0].path='../reviewer.txt' }
    'Duplicate context path' = { param($s) $s.review.sourcePatternContexts += Copy-ContextValue $s.review.sourcePatternContexts[0] }
    'Invalid context mode' = { param($s) $s.review.sourcePatternContexts[0].mode='120000' }
    'Invalid context blob' = { param($s) $s.review.sourcePatternContexts[0].blobSha='unknown' }
    'Invalid historical provenance' = { param($s) $s.review.sourcePatternContexts[0].reviewHeadSha='unknown' }
    'Before mode without blob' = { param($s) $s.review.sourcePatternContexts[0].beforeBlobSha='' }
    'Invalid before blob' = { param($s) $s.review.sourcePatternContexts[0].beforeBlobSha='unknown' }
    'Missing rule bindings' = { param($s) $s.review.sourcePatternContexts[0].patterns=@() }
    'Duplicate rule binding' = { param($s) $s.review.sourcePatternContexts[0].patterns += Copy-ContextValue $s.review.sourcePatternContexts[0].patterns[0] }
    'Noneligible rule' = { param($s) $s.review.sourcePatternContexts[0].patterns[0].id='synthetic-other' }
    'Invalid definition hash' = { param($s) $s.review.sourcePatternContexts[0].patterns[0].definitionSha256='unknown' }
    'Noncritical rule binding' = { param($s) $s.suspicious.patterns[0].severity='high' }
}
foreach ($entry in $invalidPolicies.GetEnumerator()) {
    $scenario = Copy-ContextValue $baseline
    & $entry.Value $scenario
    Assert-InvalidPolicy $scenario $entry.Key
}

# No malformed or ambiguous patch can obtain a lower severity.
$malformedPatches = [ordered]@{
    'Wrong old diff path' = { param($s) $s.patch=$s.patch.Replace('diff --git a/scripts/fixtures/reviewer.txt','diff --git a/scripts/fixtures/other.txt') }
    'Wrong old file header' = { param($s) $s.patch=$s.patch.Replace('--- a/scripts/fixtures/reviewer.txt','--- a/scripts/fixtures/other.txt') }
    'Wrong new file header' = { param($s) $s.patch=$s.patch.Replace('+++ b/scripts/fixtures/reviewer.txt','+++ b/scripts/fixtures/other.txt') }
    'Missing old file header' = { param($s) $s.patch=$s.patch.Replace("--- a/scripts/fixtures/reviewer.txt`n",'') }
    'Duplicate new file header' = { param($s) $s.patch=$s.patch.Replace('+++ b/scripts/fixtures/reviewer.txt',"+++ b/scripts/fixtures/reviewer.txt`n+++ b/scripts/fixtures/reviewer.txt") }
    'Unexpected preamble' = { param($s) $s.patch=$s.patch.Replace('--- a/scripts/fixtures/reviewer.txt',"unexpected metadata`n--- a/scripts/fixtures/reviewer.txt") }
    'Truncated hunk' = { param($s) $s.patch=$s.patch.Replace('@@ -1 +1 @@','@@ -1,2 +1,2 @@') }
    'Overflowing hunk' = { param($s) $s.patch += "`n+extra" }
    'Wrong addition statistics' = { param($s) $s.files[0].additions=2 }
    'Wrong deletion statistics' = { param($s) $s.files[0].deletions=0 }
    'Malformed hunk header' = { param($s) $s.patch=$s.patch.Replace('@@ -1 +1 @@','@@ invalid @@') }
    'Content outside hunk' = { param($s) $s.patch=$s.patch.Replace('@@ -1 +1 @@',"+synthetic-risk`n@@ -1 +1 @@") }
    'Unknown file segment' = { param($s) $s.patch += "`ndiff --git a/unknown.txt b/unknown.txt`n--- a/unknown.txt`n+++ b/unknown.txt`n@@ -1 +1 @@`n-old`n+synthetic-risk" }
    'Duplicate file segment' = { param($s) $s.patch += "`n"+$s.patch }
}
foreach ($entry in $malformedPatches.GetEnumerator()) {
    $scenario = Copy-ContextValue $baseline
    & $entry.Value $scenario
    Assert-Risk $scenario CRITICAL $entry.Key
}

# Header matches stay critical even while this file's hunk is fully attested.
$scenario = Copy-ContextValue $baseline
$scenario.patch=$scenario.patch.Replace('@@ -1 +1 @@','@@ -1 +1 @@ synthetic-risk')
$findings=@(Invoke-ContextScenario $scenario)
Assert-ContextEqual (@($findings | Where-Object { $_.code -ceq 'CREDENTIAL_ACCESS' -and $_.severity -ceq 'CRITICAL' }).Count) 1 'Hunk header remains critical'
Assert-ContextEqual (@($findings | Where-Object { $_.code -ceq 'CREDENTIAL_ACCESS' -and $_.severity -ceq 'HIGH' }).Count) 1 'Attested content still retained'

# Preserve regex semantics across physical patch boundaries. All bytes and rule
# definitions are attested here; only an actual match wholly within one hunk
# content interval can receive HIGH. Test both LF and CRLF offset accounting.
foreach ($lineEnding in @("`n","`r`n")) {
    $scenario=Copy-ContextValue $baseline
    $scenario.suspicious.patterns[0].pattern='synthetic-risk\s*\('
    $scenario.review.sourcePatternContexts[0].patterns[0].definitionSha256=Get-ReviewPatternDefinitionHash $scenario.suspicious.patterns[0]
    $path=$scenario.files[0].path
    $scenario.patch=("diff --git a/$path b/$path`n--- a/$path`n+++ b/$path`n@@ -1,2 +1,2 @@ synthetic-risk`n (`n-seed`n+benign").Replace("`n",$lineEnding)
    $scenario.files[0].beforeBlobSha=Get-SyntheticGitBlobSha ('('+$lineEnding+'seed'+$lineEnding)
    $scenario.files[0].headBlobSha=Get-SyntheticGitBlobSha ('('+$lineEnding+'benign'+$lineEnding)
    $scenario.review.sourcePatternContexts[0].beforeBlobSha=$scenario.files[0].beforeBlobSha
    $scenario.review.sourcePatternContexts[0].blobSha=$scenario.files[0].headBlobSha
    $findings=@(Invoke-ContextScenario $scenario)
    Assert-ContextEqual (@($findings | Where-Object { $_.code -ceq 'CREDENTIAL_ACCESS' -and $_.severity -ceq 'CRITICAL' }).Count) 1 'Header-to-context whitespace match remains critical'
    Assert-ContextEqual (@($findings | Where-Object severity -CEQ 'HIGH').Count) 0 'Header-to-context match cannot receive exception'
    Assert-ContextEqual (@($findings | Where-Object code -CEQ 'SOURCE_PATTERN_CONTEXT_SEGMENTATION_INVALID').Count) 0 'Boundary case has valid segmentation'

    # The same regex entirely inside one content interval is eligible, including
    # its newline and context prefixes. This distinguishes boundaries from an
    # overbroad rule that treats every multiline match as critical.
    $scenario.patch=("diff --git a/$path b/$path`n--- a/$path`n+++ b/$path`n@@ -1,3 +1,3 @@`n synthetic-risk`n (`n-seed`n+benign").Replace("`n",$lineEnding)
    $scenario.files[0].beforeBlobSha=Get-SyntheticGitBlobSha ('synthetic-risk'+$lineEnding+'('+$lineEnding+'seed'+$lineEnding)
    $scenario.files[0].headBlobSha=Get-SyntheticGitBlobSha ('synthetic-risk'+$lineEnding+'('+$lineEnding+'benign'+$lineEnding)
    $scenario.review.sourcePatternContexts[0].beforeBlobSha=$scenario.files[0].beforeBlobSha
    $scenario.review.sourcePatternContexts[0].blobSha=$scenario.files[0].headBlobSha
    Assert-Risk $scenario HIGH 'Multiline match wholly within attested hunk content'
}

# A regex spanning two files must keep its whole-patch finding. Both files are
# individually attested, so this cannot pass merely by revoking file B's proof.
$scenario=Copy-ContextValue $baseline
$scenario.suspicious.patterns[0].pattern='synthetic-risk[\s\S]*synthetic-tail'
$scenario.review.sourcePatternContexts[0].patterns[0].definitionSha256=Get-ReviewPatternDefinitionHash $scenario.suspicious.patterns[0]
$secondFile=Copy-ContextValue $scenario.files[0]
$secondFile.path='scripts/fixtures/second-reviewer.txt'
$secondFile.headBlobSha=Get-SyntheticGitBlobSha "synthetic-tail`n"
$secondRecord=Copy-ContextValue $scenario.review.sourcePatternContexts[0]
$secondRecord.path=$secondFile.path; $secondRecord.blobSha=$secondFile.headBlobSha
$scenario.files += $secondFile
$scenario.review.sourcePatternContexts += $secondRecord
$secondPatch=$baseline.patch.Replace($baseline.files[0].path,$secondFile.path).Replace('+synthetic-risk','+synthetic-tail')
$scenario.patch += "`n"+$secondPatch
$findings=@(Invoke-ContextScenario $scenario)
Assert-ContextEqual (@($findings | Where-Object { $_.code -ceq 'CREDENTIAL_ACCESS' -and $_.severity -ceq 'CRITICAL' }).Count) 1 'Cross-file regex match remains critical'
Assert-ContextEqual (@($findings | Where-Object severity -CEQ 'HIGH').Count) 0 'Cross-file regex cannot receive either attestation'
Assert-ContextEqual (@($findings | Where-Object code -CEQ 'SOURCE_PATTERN_CONTEXT_SEGMENTATION_INVALID').Count) 0 'Cross-file case has valid segmentation'

# A regex spanning two hunks in one attested file also crosses a header boundary.
$scenario=Copy-ContextValue $baseline
$scenario.suspicious.patterns[0].pattern='synthetic-risk[\s\S]*synthetic-tail'
$scenario.review.sourcePatternContexts[0].patterns[0].definitionSha256=Get-ReviewPatternDefinitionHash $scenario.suspicious.patterns[0]
$scenario.patch += "`n@@ -3 +3 @@`n-old-tail`n+synthetic-tail"
$scenario.files[0].additions=2; $scenario.files[0].deletions=2
$scenario.files[0].beforeBlobSha=Get-SyntheticGitBlobSha "seed`nunchanged`nold-tail`n"
$scenario.files[0].headBlobSha=Get-SyntheticGitBlobSha "synthetic-risk`nunchanged`nsynthetic-tail`n"
$scenario.review.sourcePatternContexts[0].beforeBlobSha=$scenario.files[0].beforeBlobSha
$scenario.review.sourcePatternContexts[0].blobSha=$scenario.files[0].headBlobSha
$findings=@(Invoke-ContextScenario $scenario)
Assert-ContextEqual (@($findings | Where-Object { $_.code -ceq 'CREDENTIAL_ACCESS' -and $_.severity -ceq 'CRITICAL' }).Count) 1 'Cross-hunk regex match remains critical'
Assert-ContextEqual (@($findings | Where-Object code -CEQ 'SOURCE_PATTERN_CONTEXT_SEGMENTATION_INVALID').Count) 0 'Cross-hunk case has valid segmentation'

# Enumeration must continue after the first eligible match. A later match of
# the same rule crosses from a hunk header into its first context line.
$scenario=Copy-ContextValue $baseline
$scenario.suspicious.patterns[0].pattern='synthetic-risk\s*\('
$scenario.review.sourcePatternContexts[0].patterns[0].definitionSha256=Get-ReviewPatternDefinitionHash $scenario.suspicious.patterns[0]
$scenario.patch=$scenario.patch.Replace('+synthetic-risk','+synthetic-risk (')
$scenario.patch += "`n@@ -3,2 +3,2 @@ synthetic-risk`n (`n-old-tail`n+benign"
$scenario.files[0].additions=2; $scenario.files[0].deletions=2
$scenario.files[0].beforeBlobSha=Get-SyntheticGitBlobSha "seed`nunchanged`n(`nold-tail`n"
$scenario.files[0].headBlobSha=Get-SyntheticGitBlobSha "synthetic-risk (`nunchanged`n(`nbenign`n"
$scenario.review.sourcePatternContexts[0].beforeBlobSha=$scenario.files[0].beforeBlobSha
$scenario.review.sourcePatternContexts[0].blobSha=$scenario.files[0].headBlobSha
$findings=@(Invoke-ContextScenario $scenario)
Assert-ContextEqual (@($findings | Where-Object { $_.code -ceq 'CREDENTIAL_ACCESS' -and $_.severity -ceq 'HIGH' }).Count) 1 'First eligible body match retained'
Assert-ContextEqual (@($findings | Where-Object { $_.code -ceq 'CREDENTIAL_ACCESS' -and $_.severity -ceq 'CRITICAL' }).Count) 1 'Later same-rule boundary match remains critical'
Assert-ContextEqual (@($findings | Where-Object code -CEQ 'SOURCE_PATTERN_CONTEXT_SEGMENTATION_INVALID').Count) 0 'Later boundary case has valid segmentation'

# Attested file A cannot lower findings in file B, regardless of list/patch order.
$otherFile=Copy-ContextValue $baseline.files[0]
$otherFile.path='src/unattested.txt'
$otherPatch=$baseline.patch.Replace('scripts/fixtures/reviewer.txt',$otherFile.path)
foreach ($reverseFiles in @($false,$true)) {
    foreach ($reversePatch in @($false,$true)) {
        $scenario=Copy-ContextValue $baseline
        $scenario.files=if($reverseFiles){@($otherFile,$scenario.files[0])}else{@($scenario.files[0],$otherFile)}
        $scenario.patch=if($reversePatch){$otherPatch+"`n"+$scenario.patch}else{$scenario.patch+"`n"+$otherPatch}
        $findings=@(Invoke-ContextScenario $scenario)
        Assert-ContextEqual (@($findings | Where-Object { $_.code -ceq 'CREDENTIAL_ACCESS' -and $_.path -ceq $baseline.files[0].path -and $_.severity -ceq 'HIGH' }).Count) 1 'Mixed files attested content retained'
        Assert-ContextEqual (@($findings | Where-Object { $_.code -ceq 'CREDENTIAL_ACCESS' -and $_.path -ceq $otherFile.path -and $_.severity -ceq 'CRITICAL' }).Count) 1 'Mixed files unattested content stays critical'
    }
}
$scenario=Copy-ContextValue $baseline
$independent=[pscustomobject]@{id='synthetic-independent';category='malware';severity='critical';appliesTo=@('patch');pattern='synthetic-risk'}
$scenario.suspicious.patterns += $independent
$findings=@(Invoke-ContextScenario $scenario)
Assert-ContextEqual (@($findings | Where-Object { $_.code -ceq 'CREDENTIAL_ACCESS' -and $_.severity -ceq 'HIGH' }).Count) 1 'Bound rule retained alongside independent risk'
Assert-ContextEqual (@($findings | Where-Object { $_.code -ceq 'SUSPICIOUS_CHANGE' -and $_.severity -ceq 'CRITICAL' }).Count) 1 'Unattested rule stays critical'

# Propagate the exception through the complete review decision. Independent
# repository, metadata and binary blockers must still prevent the next phase.
$fullPolicies=Import-PullRequestReviewPolicies -RepositoryRoot $repositoryRoot
$fullPolicies.review.sourcePatternContexts=$baseline.review.sourcePatternContexts
$fullPolicies.suspicious=$baseline.suspicious
$fullScenario=Copy-ContextValue $baseline
$fullScenario.metadata | Add-Member headRefName 'feature/synthetic-context'
$fullScenario.metadata | Add-Member baseSha ('d'*40)
$fullScenario.metadata | Add-Member currentTrustedBaseSha ('d'*40)
$fullScenario.metadata | Add-Member changedFiles 1
$fullScenario.metadata | Add-Member baseTreeAvailable $true
$report=Invoke-PullRequestStaticAnalysis -Metadata $fullScenario.metadata -ChangedFiles $fullScenario.files -PatchText $fullScenario.patch -Policies $fullPolicies
Assert-ContextEqual $report.decision 'OWNER_REVIEW_REQUIRED' 'Exact context still needs owner review'
Assert-ContextEqual $report.foreignCodeExecuted $false 'Review does not execute candidate'
Assert-ContextEqual $report.secretAccess 'denied' 'Review has no secret access'
$independentCases=[ordered]@{
    'Base drift'=@('BASE_SHA_DRIFT',{ param($s) $s.metadata.currentTrustedBaseSha='e'*40 })
    'Missing base tree'=@('BASE_TREE_UNAVAILABLE',{ param($s) $s.metadata.baseTreeAvailable=$false })
    'Incomplete file list'=@('INCOMPLETE_FILE_LIST',{ param($s) $s.metadata.changedFiles=2 })
    'Incomplete full-review tree'=@('GIT_TREE_METADATA_INCOMPLETE',{ param($s) $s.metadata.gitTreeMetadataComplete=$false })
    'Artifact attestation failure'=@('ARTIFACT_ATTESTATION_MISMATCH',{ param($s) $s.metadata | Add-Member artifactAttestationErrors @('synthetic-mismatch') })
    'Metadata Unicode control'=@('BIDI_CONTROL',{ param($s) $s.metadata | Add-Member title ([string][char]0x202E) })
    'Metadata rule match'=@('SUSPICIOUS_CHANGE',{ param($s) $s.metadata | Add-Member title 'synthetic-risk' })
}
foreach ($entry in $independentCases.GetEnumerator()) {
    $scenario=Copy-ContextValue $fullScenario
    $policies=Copy-ContextValue $fullPolicies
    $policies.suspicious.patterns += [pscustomobject]@{id='synthetic-metadata';category='malware';severity='critical';appliesTo=@('metadata');pattern='synthetic-risk'}
    & $entry.Value[1] $scenario
    $report=Invoke-PullRequestStaticAnalysis -Metadata $scenario.metadata -ChangedFiles $scenario.files -PatchText $scenario.patch -Policies $policies
    Assert-ContextEqual $report.decision 'BLOCKED_UNVERIFIED' "$($entry.Key) blocks full review"
    Assert-ContextEqual (@($report.findings | Where-Object { $_.code -ceq $entry.Value[0] -and $_.severity -ceq 'CRITICAL' }).Count -gt 0) $true "$($entry.Key) finding retained"
}
foreach ($blocker in @(
    @('src/inert.dll','100644','BLOCKED_BINARY'),
    @('src/inert.zip','100644','BLOCKED_ARCHIVE'),
    @('src/inert.txt','120000','SYMLINK'),
    @('src/inert.txt','160000','SUBMODULE')
)) {
    $scenario=Copy-ContextValue $fullScenario
    $other=Copy-ContextValue $baseline.files[0]
    $other.path=$blocker[0]; $other.mode=$blocker[1]
    $scenario.files += $other
    $scenario.patch += "`n"+$baseline.patch.Replace($baseline.files[0].path,$other.path).Replace('+synthetic-risk','+benign')
    $scenario.metadata.changedFiles=2
    $report=Invoke-PullRequestStaticAnalysis -Metadata $scenario.metadata -ChangedFiles $scenario.files -PatchText $scenario.patch -Policies $fullPolicies
    Assert-ContextEqual $report.decision 'BLOCKED_UNVERIFIED' "$($blocker[2]) blocks full review"
    Assert-ContextEqual (@($report.findings | Where-Object { $_.code -ceq $blocker[2] -and $_.severity -ceq 'CRITICAL' }).Count) 1 "$($blocker[2]) finding retained"
    Assert-ContextEqual (@($report.findings | Where-Object { $_.code -ceq 'CREDENTIAL_ACCESS' -and $_.severity -ceq 'HIGH' }).Count) 1 'Independent blocker does not erase attested finding'
}

# A timeout in an eligible, exactly bound rule is still an independent blocker.
$scenario=Copy-ContextValue $baseline
$scenario.suspicious.regexTimeoutMilliseconds=1
$scenario.suspicious.patterns[0].pattern='(a+)+b'
$scenario.review.sourcePatternContexts[0].patterns[0].definitionSha256=Get-ReviewPatternDefinitionHash $scenario.suspicious.patterns[0]
$scenario.patch=$scenario.patch.Replace('+synthetic-risk','+'+('a'*30000))
$scenario.files[0].headBlobSha=Get-SyntheticGitBlobSha (('a'*30000)+"`n")
$scenario.review.sourcePatternContexts[0].blobSha=$scenario.files[0].headBlobSha
$findings=@(Invoke-ContextScenario $scenario)
Assert-ContextEqual (@($findings | Where-Object { $_.code -ceq 'SCAN_TIMEOUT' -and $_.severity -ceq 'CRITICAL' }).Count -gt 0) $true 'Bound rule timeout stays critical'
Assert-ContextEqual (@($findings | Where-Object severity -CEQ 'HIGH').Count) 0 'Timeout cannot gain exception'
Assert-ContextEqual (@($findings | Where-Object detail -CEQ 'SCAN_TIMEOUT_PHASE=BOUNDARY_NATIVE; SCAN_TIMEOUT_PATTERN=CREDENTIAL_ACCESS').Count -gt 0) $true 'Native boundary timeout has closed diagnostics'

# A native regex can be fast while attribution crosses many valid hunk ranges.
# Two cheap occurrences in one final content line produce one attested finding;
# NextMatch also checks the bookkeeping spent reaching that final range. No
# wall-clock assertion or fixture deadline override is needed for this contract.
$scenario=Copy-ContextValue $baseline
$hunkCount=100000
$patchBuilder=[Text.StringBuilder]::new()
$beforeBuilder=[Text.StringBuilder]::new()
$afterBuilder=[Text.StringBuilder]::new()
$path=$scenario.files[0].path
[void]$patchBuilder.Append("diff --git a/$path b/$path`n--- a/$path`n+++ b/$path")
for ($hunkIndex=0; $hunkIndex -lt $hunkCount; $hunkIndex++) {
    $lineNumber=1+2*$hunkIndex
    $after=if($hunkIndex -eq $hunkCount-1){'synthetic-risk synthetic-risk'}else{'benign'}
    [void]$patchBuilder.Append("`n@@ -$lineNumber +$lineNumber @@`n-seed`n+$after")
    [void]$beforeBuilder.Append("seed`n"); [void]$afterBuilder.Append($after+"`n")
    if($hunkIndex -lt $hunkCount-1){[void]$beforeBuilder.Append("unchanged`n"); [void]$afterBuilder.Append("unchanged`n")}
}
$scenario.patch=$patchBuilder.ToString()
$scenario.files[0].additions=$hunkCount; $scenario.files[0].deletions=$hunkCount
$scenario.files[0].beforeBlobSha=Get-SyntheticGitBlobSha $beforeBuilder.ToString()
$scenario.files[0].headBlobSha=Get-SyntheticGitBlobSha $afterBuilder.ToString()
$scenario.review.sourcePatternContexts[0].beforeBlobSha=$scenario.files[0].beforeBlobSha
$scenario.review.sourcePatternContexts[0].blobSha=$scenario.files[0].headBlobSha
Assert-ContextEqual ([Text.Encoding]::UTF8.GetByteCount($scenario.patch) -lt 5242880) $true 'Many-hunk fixture remains inside patch budget'
$strictStatistics=Get-ReviewUnifiedHunkStatistics -Patch ($scenario.patch.Substring($scenario.patch.IndexOf('@@ ',[StringComparison]::Ordinal))) -ExpectedAdditions $hunkCount -ExpectedDeletions $hunkCount
Assert-ContextEqual $strictStatistics.hunks $hunkCount 'Many-hunk fixture has complete strictly counted hunks'
Assert-Risk $scenario HIGH 'Late cheap match across many attribution ranges'
Assert-ContextEqual @(Invoke-ContextScenario $scenario).Count 1 'Repeated many-hunk attribution retains one owner-review finding'

# Many individually cheap, content-only matches cannot evade the bounded
# whole-patch enumeration budget through an otherwise exact attestation.
$scenario=Copy-ContextValue $baseline
$manyMatches=('synthetic-risk ' * 10001)
$scenario.patch=$scenario.patch.Replace('+synthetic-risk','+'+$manyMatches)
$scenario.files[0].headBlobSha=Get-SyntheticGitBlobSha ($manyMatches+"`n")
$scenario.review.sourcePatternContexts[0].blobSha=$scenario.files[0].headBlobSha
$findings=@(Invoke-ContextScenario $scenario)
Assert-ContextEqual (@($findings | Where-Object { $_.code -ceq 'SCAN_TIMEOUT' -and $_.severity -ceq 'CRITICAL' }).Count -gt 0) $true 'Match enumeration budget remains fail closed'
Assert-ContextEqual (@($findings | Where-Object detail -CEQ 'SCAN_TIMEOUT_PHASE=BOUNDARY_ENUMERATION; SCAN_TIMEOUT_PATTERN=CREDENTIAL_ACCESS').Count -gt 0) $true 'Enumeration cap timeout has closed diagnostics'
# Reproduce the real one-line timeout change with its unchanged defensive
# pattern in GitHub's context lines. Bind complete blobs, not just this hunk.
$realPolicies=Import-PullRequestReviewPolicies -RepositoryRoot $repositoryRoot
$policyPath='config/suspicious-change-patterns.json'
$policyText=[IO.File]::ReadAllText((Join-Path $repositoryRoot $policyPath)).Replace("`r`n","`n")
$beforeText=[regex]::Replace($policyText,'("regexTimeoutMilliseconds"\s*:\s*)\d+','${1}100')
$afterText=[regex]::Replace($policyText,'("regexTimeoutMilliseconds"\s*:\s*)\d+','${1}1000')
$beforeLines=$beforeText.Split("`n"); $afterLines=$afterText.Split("`n")
$scenario=New-ContextScenario
$scenario.files[0].path=$policyPath
$scenario.files[0].beforeBlobSha=Get-SyntheticGitBlobSha $beforeText
$scenario.files[0].headBlobSha=Get-SyntheticGitBlobSha $afterText
$scenario.suspicious.patterns=@($realPolicies.suspicious.patterns|Where-Object id -CEQ 'encoded-execution')
$scenario.review.sourcePatternContexts=@($realPolicies.review.sourcePatternContexts|Where-Object path -CEQ $policyPath)
$hunk=[Collections.Generic.List[string]]::new()
$hunk.Add("diff --git a/$policyPath b/$policyPath`n--- a/$policyPath`n+++ b/$policyPath`n@@ -1,7 +1,7 @@")
for($lineIndex=0;$lineIndex -lt 7;$lineIndex++){
    if($beforeLines[$lineIndex] -cne $afterLines[$lineIndex]){
        $hunk.Add('-'+$beforeLines[$lineIndex]); $hunk.Add('+'+$afterLines[$lineIndex])
    }else{$hunk.Add(' '+$beforeLines[$lineIndex])}
}
$scenario.patch=$hunk -join "`n"
$findings=@(Invoke-ContextScenario $scenario)
Assert-ContextEqual (@($findings|Where-Object { $_.code -ceq 'ENCODED_EXECUTION' -and $_.severity -ceq 'HIGH' }).Count) 1 'Exact reviewed timeout-only file retains owner scrutiny'
Assert-ContextEqual (@($findings|Where-Object severity -CEQ 'CRITICAL').Count) 0 'Defensive unchanged context does not execute a payload'
foreach($drift in @('headBlob','beforeBlob','ruleHash','path')){
    $changed=Copy-ContextValue $scenario
    switch($drift){
        headBlob { $changed.files[0].headBlobSha='c'*40 }
        beforeBlob { $changed.files[0].beforeBlobSha='d'*40 }
        ruleHash { $changed.review.sourcePatternContexts[0].patterns[0].definitionSha256='0'*64 }
        path { $changed.review.sourcePatternContexts[0].path='config/other-patterns.json' }
    }
    $findings=@(Invoke-ContextScenario $changed)
    Assert-ContextEqual (@($findings|Where-Object { $_.code -ceq 'ENCODED_EXECUTION' -and $_.severity -ceq 'CRITICAL' }).Count) 1 "Timeout-only attestation rejects $drift drift"
}
Write-Output ('PATTERN_CONTEXT_ASSERTIONS={0} FAIL=0 NETWORK_CALLS=0 FOREIGN_CODE_EXECUTED=false' -f $script:assertions)
