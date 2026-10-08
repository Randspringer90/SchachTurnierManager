#requires -Version 7.0
# Synthetic static-evidence regressions; candidate content remains inert.
[CmdletBinding()]
param([Parameter(Mandatory)][string]$ScratchParent)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$RepositoryRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
foreach($relative in @('scripts/lib/PullRequestReviewCommon.ps1','scripts/lib/PullRequestTextPatchEvidence.ps1')) {
    $trustedPath=[IO.Path]::GetFullPath((Join-Path $RepositoryRoot $relative))
    $cursor=$trustedPath
    while($cursor) {
        $item=Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue
        if($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Untrusted regression runtime path.' }
        $parent=Split-Path -Parent $cursor
        if(-not $parent -or $parent -ceq $cursor) { break }
        $cursor=$parent
    }
}
. (Join-Path $RepositoryRoot 'scripts/lib/PullRequestReviewCommon.ps1')
. (Join-Path $RepositoryRoot 'scripts/lib/PullRequestTextPatchEvidence.ps1')
if(-not [IO.Path]::IsPathRooted($ScratchParent)) { $ScratchParent=Join-Path $RepositoryRoot $ScratchParent }
$ScratchParent=[IO.Path]::GetFullPath($ScratchParent)
$outputRoot=[IO.Path]::GetFullPath((Join-Path $RepositoryRoot 'output'))
$pathComparison=if($IsWindows){[StringComparison]::OrdinalIgnoreCase}else{[StringComparison]::Ordinal}
if($ScratchParent -cne $outputRoot -and -not $ScratchParent.StartsWith($outputRoot+[IO.Path]::DirectorySeparatorChar,$pathComparison)) {
    throw 'Regression scratch must stay inside project output.'
}
[void](Assert-NoReviewReparseAncestor -Path $ScratchParent -Context 'Regression scratch')
$git=(Get-Command git -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
$policy=Import-PullRequestReviewPolicies -RepositoryRoot $RepositoryRoot
$script:assertions=0; $script:readCounter=[pscustomobject]@{value=0}
function Assert-Equal($Actual,$Expected,[string]$Name){
    if($Actual -cne $Expected){throw ('Assertion failed: '+$Name)}
    $script:assertions++
}
function Assert-Throws([scriptblock]$Action,[string]$Code){
    $caught=$false
    try{& $Action | Out-Null}catch{
        if(-not $_.Exception.Message.Contains($Code)){throw ('Unexpected exception for '+$Code)}
        $caught=$true
    }
    Assert-Equal $caught $true $Code
}
function New-Blob([byte[]]$Bytes){
    $hasher=[Security.Cryptography.IncrementalHash]::CreateHash([Security.Cryptography.HashAlgorithmName]::SHA1)
    try{
        $hasher.AppendData([Text.Encoding]::ASCII.GetBytes("blob $($Bytes.Length)"+[char]0));$hasher.AppendData($Bytes)
        $sha=([Convert]::ToHexString($hasher.GetHashAndReset())).ToLowerInvariant()
    }finally{$hasher.Dispose()}
    [pscustomobject]@{sha=$sha;encoding='base64';size=$Bytes.Length;content=[Convert]::ToBase64String($Bytes)}
}
function New-Scenario([string]$Status,[string]$Before,[string]$After,[int]$Added,[int]$Removed){
    $oldBlob=New-Blob ([Text.Encoding]::UTF8.GetBytes($Before));$newBlob=New-Blob ([Text.Encoding]::UTF8.GetBytes($After))
    $base='a'*40;$head='b'*40;$baseTreeSha='c'*40;$headTreeSha='d'*40
    $oldPath=if($Status -ceq 'renamed'){'src/old.txt'}else{'src/test.txt'}
    $oldEntry=[pscustomobject]@{path=$oldPath;type='blob';mode='100644';sha=$oldBlob.sha;size=$oldBlob.size}
    $newEntry=[pscustomobject]@{path='src/test.txt';type='blob';mode='100644';sha=$newBlob.sha;size=$newBlob.size}
    $file=[pscustomobject]@{filename='src/test.txt';status=$Status;additions=$Added;deletions=$Removed;patch=$null}
    if($Status -ceq 'renamed'){$file|Add-Member previous_filename $oldPath}
    $file|Add-Member sha $(if($Status -ceq 'removed'){$oldBlob.sha}else{$newBlob.sha})
    [pscustomobject]@{
        metadata=[pscustomobject]@{number=1;baseRefOid=$base;headRefOid=$head;currentTrustedBaseSha=$base;changedFiles=1}
        baseCommit=[pscustomobject]@{sha=$base;tree=[pscustomobject]@{sha=$baseTreeSha}}
        headCommit=[pscustomobject]@{sha=$head;tree=[pscustomobject]@{sha=$headTreeSha}}
        baseTree=[pscustomobject]@{sha=$baseTreeSha;truncated=$false;tree=@(if($Status -cne 'added'){$oldEntry})}
        headTree=[pscustomobject]@{sha=$headTreeSha;truncated=$false;tree=@(if($Status -cne 'removed'){$newEntry})}
        comparison=[pscustomobject]@{base_commit=[pscustomobject]@{sha=$base};merge_base_commit=[pscustomobject]@{sha=$base}}
        files=@($file);oldBlob=$oldBlob;newBlob=$newBlob
    }
}
function Invoke-Scenario($Scenario){
    $blobs=@{};$blobs[$Scenario.oldBlob.sha]=$Scenario.oldBlob;$blobs[$Scenario.newBlob.sha]=$Scenario.newBlob
    $counter=$script:readCounter
    $provider={param($Sha,$Size)$counter.value++;if(-not $blobs.ContainsKey($Sha)){throw 'Unknown synthetic blob'};return $blobs[$Sha]}.GetNewClosure()
    @(Add-ReviewVerifiedTextPatchEvidence -ApiFiles $Scenario.files -Metadata $Scenario.metadata -BaseCommit $Scenario.baseCommit `
        -HeadCommit $Scenario.headCommit -BaseTree $Scenario.baseTree -HeadTree $Scenario.headTree -Comparison $Scenario.comparison `
        -ExpectedBaseSha ('a'*40) -ExpectedHeadSha ('b'*40) -BlobProvider $provider -GitExecutable $git `
        -ScratchParent $ScratchParent -ReviewPolicy $policy.review)
}

# Known external content-address value, including the exact Git blob header and terminal LF.
$known=New-Blob ([Text.Encoding]::UTF8.GetBytes("hello`n"))
Assert-Equal $known.sha 'ce013625030ba8dba906f756967f9e9ca394464a' 'known Git SHA1'
$decoded=ConvertFrom-ReviewVerifiedTextBlob $known $known.sha $known.size
Assert-Equal ([Text.Encoding]::UTF8.GetString($decoded)) "hello`n" 'exact original bytes'
$blob=New-Blob ([byte[]]@(0));Assert-Throws {ConvertFrom-ReviewVerifiedTextBlob $blob $blob.sha $blob.size} 'TEXT_EVIDENCE_BLOB_NUL'
$blob=New-Blob ([byte[]]@(255));Assert-Throws {ConvertFrom-ReviewVerifiedTextBlob $blob $blob.sha $blob.size} 'TEXT_EVIDENCE_BLOB_UTF8'
$blob=New-Blob ([Text.Encoding]::UTF8.GetBytes('safe'));$sha=$blob.sha;$blob.content='Y2hhbmdlZA=='
Assert-Throws {ConvertFrom-ReviewVerifiedTextBlob $blob $sha 4} 'TEXT_EVIDENCE_BLOB_SIZE'
$blob=New-Blob ([Text.Encoding]::UTF8.GetBytes('safe'));$blob.sha='e'*40
Assert-Throws {ConvertFrom-ReviewVerifiedTextBlob $blob $blob.sha 4} 'TEXT_EVIDENCE_BLOB_HASH'
$blob=New-Blob ([Text.Encoding]::UTF8.GetBytes('safe'));$blob.encoding='utf8'
Assert-Throws {ConvertFrom-ReviewVerifiedTextBlob $blob $blob.sha 4} 'TEXT_EVIDENCE_BLOB_METADATA'
$blob=New-Blob ([Text.Encoding]::UTF8.GetBytes('safe'));$blob.content='!!!!'
Assert-Throws {ConvertFrom-ReviewVerifiedTextBlob $blob $blob.sha 4} 'TEXT_EVIDENCE_BLOB_ENCODING'

# Added/deleted content beginning with three signs counts as actual content, not a file header.
$hunks="@@ -1,1 +1,1 @@`n---- old`n++++ new`n"
$stats=Get-ReviewUnifiedHunkStatistics $hunks 1 1
Assert-Equal $stats.additions 1 'plus prefix';Assert-Equal $stats.deletions 1 'minus prefix'
Assert-Throws {Get-ReviewUnifiedHunkStatistics "@@ -1,2 +1,2 @@`n same`n" 0 0} 'TEXT_EVIDENCE_STATS_MISMATCH'
Assert-Throws {Get-ReviewUnifiedHunkStatistics "@@ -1 +1 @@`n+new`n" 1 0} 'TEXT_EVIDENCE_STATS_MISMATCH'
Assert-Throws {Get-ReviewUnifiedHunkStatistics "@@ -1 +1 @@`n same`n extra`n" 0 0} 'TEXT_EVIDENCE_HUNK_OVERFLOW'
Assert-Throws {Get-ReviewUnifiedHunkStatistics "not a hunk`n" 0 0} 'TEXT_EVIDENCE_HUNK_BODY'
Assert-Throws {Get-ReviewUnifiedHunkStatistics "\ No newline at end of file`n" 0 0} 'TEXT_EVIDENCE_NEWLINE_MARKER'
[void](Get-ReviewUnifiedHunkStatistics "@@ -1 +1 @@`n-old`n\ No newline at end of file`n+new`n\ No newline at end of file`n" 1 1)
$script:assertions++

foreach($case in @(
    @('modified',"old`n","new`n",1,1),@('added','',"new`n",1,0),
    @('removed',"old`n",'',0,1),@('renamed',"old`n","new`n",1,1),
    @('added','','',0,0),@('modified','old','new',1,1),
    @('modified',"old`r`n","new`r`n",1,1),@('modified',"--- old`n","+++ new`n",1,1))){
    $scenario=New-Scenario @case;$rows=@(Invoke-Scenario $scenario)
    Assert-Equal $rows.Count 1 'one changed file';Assert-Equal $rows[0].textPatchEvidence.status 'VERIFIED' 'verified fallback'
    $converted=ConvertFrom-GitHubPullRequestReviewData -ApiFiles $rows -BaseTree $scenario.baseTree -HeadTree $scenario.headTree
    Assert-Equal $converted.files[0].patchComplete $true 'converter complete'
    Assert-Equal $converted.files[0].patchAvailable $true 'converter available'
    Assert-Equal ($converted.patch.StartsWith('diff --git a/')) $true 'empty files retain envelope'
}
$scenario=New-Scenario modified "old`n" "new`n" 1 1
$scenario.files[0].patch="@@ -1 +1 @@`n-old`n+new`n"
$scenario.files[0]|Add-Member textPatchEvidence ([pscustomobject]@{status='VERIFIED';headSha=('e'*40)})
$script:readCounter.value=0;$rows=@(Invoke-Scenario $scenario)
Assert-Equal $script:readCounter.value 0 'complete API needs no blob';Assert-Equal ($null -eq $rows[0].PSObject.Properties['textPatchEvidence']) $true 'T4 provenance stripped'
$scenario=New-Scenario modified "old`n" "new`n" 1 1;$scenario.files[0].patch="@@ -1 +1 @@`n-old`n"
$rows=@(Invoke-Scenario $scenario);Assert-Equal $rows[0].textPatchEvidence.status 'VERIFIED' 'truncated API reconstructed'
$canary='synthetic-not-for-report-'+[Guid]::NewGuid().ToString('N')
$rows[0].textPatchEvidence|Add-Member privateNote $canary
$safeEvidence=ConvertTo-SafeReviewTextPatchEvidence -Evidence $rows[0].textPatchEvidence -Metadata $scenario.metadata
Assert-Equal (($safeEvidence|ConvertTo-Json -Compress).Contains($canary)) $false 'unknown provenance fields not persisted'
Assert-Equal $safeEvidence.status 'VERIFIED' 'safe provenance preserved'
$rows[0].textPatchEvidence.headSha='e'*40
Assert-Equal ($null -eq (ConvertTo-SafeReviewTextPatchEvidence -Evidence $rows[0].textPatchEvidence -Metadata $scenario.metadata)) $true 'cross-head provenance rejected'

# Every negative preflight must finish before any synthetic blob provider invocation.
foreach($case in @('head','base','merge-base','tree-sha','truncated-tree','count','duplicate','mode','unsafe-path','later-unsafe-path','size')){
    $scenario=New-Scenario modified "old`n" "new`n" 1 1;$script:readCounter.value=0
    $expected='TEXT_EVIDENCE_COMMIT_BINDING'
    switch($case){
        head{$scenario.metadata.headRefOid='e'*40}
        base{$scenario.metadata.currentTrustedBaseSha='e'*40}
        merge-base{$scenario.comparison.merge_base_commit.sha='e'*40}
        tree-sha{$scenario.headTree.sha='e'*40;$expected='TEXT_EVIDENCE_TREE_BINDING'}
        truncated-tree{$scenario.baseTree.truncated=$true;$expected='TEXT_EVIDENCE_TREE_BINDING'}
        count{$scenario.metadata.changedFiles=2;$expected='TEXT_EVIDENCE_INVENTORY_COUNT'}
        duplicate{$scenario.files=@($scenario.files[0],$scenario.files[0]);$scenario.metadata.changedFiles=2;$expected='TEXT_EVIDENCE_INVENTORY_DUPLICATE'}
        mode{$scenario.headTree.tree[0].mode='120000';$expected='TEXT_EVIDENCE_MODE'}
        unsafe-path{$scenario.files[0].filename='src/../outside.txt';$expected='TEXT_EVIDENCE_PATH_INVALID'}
        later-unsafe-path{
            $scenario.files+=([pscustomobject]@{filename='src/../later.txt';status='added';additions=1;deletions=0;patch=$null})
            $scenario.metadata.changedFiles=2;$expected='TEXT_EVIDENCE_PATH_INVALID'
        }
        size{$scenario.headTree.tree[0].size=5242881;$expected='TEXT_EVIDENCE_BLOB_BUDGET'}
    }
    Assert-Throws {Invoke-Scenario $scenario} $expected
    Assert-Equal $script:readCounter.value 0 ('preflight before provider '+$case)
}
$scenario=New-Scenario modified "old`n" "new`n" 2 1
Assert-Throws {Invoke-Scenario $scenario} 'TEXT_EVIDENCE_STATS_MISMATCH'
$scenario=New-Scenario modified "old`n" "new`n" 1 1;$scenario.newBlob.content=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("bad`n"))
Assert-Throws {Invoke-Scenario $scenario} 'TEXT_EVIDENCE_BLOB_HASH'
$scenario=New-Scenario modified "old`n" "new`n" 1 1;$scenario.headTree.tree+=($scenario.headTree.tree[0])
Assert-Throws {Invoke-Scenario $scenario} 'TEXT_EVIDENCE_TREE_DUPLICATE'
$scenario=New-Scenario modified "old`n" "new`n" 1 1;$scenario.files[0].sha='e'*40;$script:readCounter.value=0
Assert-Throws {Invoke-Scenario $scenario} 'TEXT_EVIDENCE_FILE_BLOB_BINDING'
Assert-Equal $script:readCounter.value 0 'API blob identity before provider'
$scenario=New-Scenario modified "old`n" "new`n" 1 1
$scenario.headTree.tree+=([pscustomobject]@{path='src/omitted.txt';type='blob';mode='100644';sha=$scenario.newBlob.sha;size=$scenario.newBlob.size})
$script:readCounter.value=0
Assert-Throws {Invoke-Scenario $scenario} 'TEXT_EVIDENCE_TREE_INVENTORY_MISMATCH'
Assert-Equal $script:readCounter.value 0 'omitted inventory before provider'

# Native stdout is bounded independently of regex/parser behavior; tool stderr is never surfaced.
Assert-Throws {Invoke-ReviewBoundedNativeRead -Executable $git -Tool git -Arguments @('--version') -WorkingDirectory $ScratchParent -MaximumStdoutBytes 1} 'TEXT_EVIDENCE_PROCESS_OUTPUT_LIMIT'
$native=Invoke-ReviewBoundedNativeRead -Executable $git -Tool git -Arguments @('--version') -WorkingDirectory $ScratchParent -MaximumStdoutBytes 4096
Assert-Equal $native.exitCode 0 'native stdout drain';Assert-Equal $native.stderrBytes 0 'native stderr drain'

# Exercise the real Git process and owned test-only child: concurrent full pipes
# and a deadline must neither deadlock nor leave its child running.
$nativeFixture=Join-Path $ScratchParent ('native-read-'+[Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($nativeFixture)
$fixtureSource=Join-Path $nativeFixture 'fixture.cjs'
$fixtureIdentity=Join-Path $nativeFixture 'identity.json'
$nodeApplication=(Get-Command node -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
$fixtureCode=@'
const fs = require('node:fs');
if (process.argv[2] === 'pipes') {
  const block = Buffer.alloc(1024, 120);
  for (let index = 0; index < 60; index++) {
    fs.writeSync(1, block);
    fs.writeSync(2, block);
  }
} else if (process.argv[2] === 'wait') {
  fs.writeFileSync(process.argv[3], JSON.stringify({ pid: process.pid }));
  setTimeout(() => process.exit(0), 30000);
} else {
  process.exitCode = 2;
}
'@
function Quote-NativeFixtureArgument([string]$Value) {
    return "'" + $Value.Replace("'", "'\''") + "'"
}
try {
    [IO.File]::WriteAllText($fixtureSource,$fixtureCode,[Text.UTF8Encoding]::new($false))
    $alias='!' + (Quote-NativeFixtureArgument $nodeApplication.Replace('\','/')) + ' ' +
        (Quote-NativeFixtureArgument $fixtureSource.Replace('\','/'))
    $pipes=Invoke-ReviewBoundedNativeRead -Executable $git -Tool git -WorkingDirectory $ScratchParent `
        -MaximumStdoutBytes 65536 -Arguments @('-c',('alias.stm-review-fixture='+$alias),'stm-review-fixture','pipes')
    Assert-Equal $pipes.exitCode 0 'simultaneous pipes complete'
    Assert-Equal $pipes.stdout.Length 61440 'complete stdout larger than pipe buffer'
    Assert-Equal $pipes.stderrBytes 61440 'complete stderr larger than pipe buffer'
    Assert-Throws {
        Invoke-ReviewBoundedNativeRead -Executable $git -Tool git -WorkingDirectory $ScratchParent `
            -MaximumStdoutBytes 65536 -DeadlineMilliseconds 1500 `
            -Arguments @('-c',('alias.stm-review-fixture='+$alias),'stm-review-fixture','wait',$fixtureIdentity)
    } 'TEXT_EVIDENCE_PROCESS_DEADLINE'
    if(-not [IO.File]::Exists($fixtureIdentity)) { throw 'Owned deadline fixture never started.' }
    $identity=[IO.File]::ReadAllText($fixtureIdentity) | ConvertFrom-Json
    $surviving=$null
    try { $surviving=[Diagnostics.Process]::GetProcessById([int]$identity.pid) }
    catch [ArgumentException] { }
    try { Assert-Equal ($null -eq $surviving -or $surviving.HasExited) $true 'deadline terminates owned child' }
    finally { if($surviving){$surviving.Dispose()} }
} finally {
    foreach($name in @('fixture.cjs','identity.json')) {
        $ownedPath=Join-Path $nativeFixture $name
        [void](Assert-NoReviewReparseAncestor -Path $ownedPath -Context 'Owned native test cleanup')
        if([IO.File]::Exists($ownedPath)){[IO.File]::Delete($ownedPath)}
    }
    [void](Assert-NoReviewReparseAncestor -Path $nativeFixture -Context 'Owned native test directory')
    [IO.Directory]::Delete($nativeFixture,$false)
}
$scenario=New-Scenario modified "old`r`n" "new`r`n" 1 1
$rows=@(Invoke-Scenario $scenario)
Assert-Equal ($rows[0].patch.Contains("-old`r`n")) $true 'original removed CR retained'
Assert-Equal ($rows[0].patch.Contains("+new`r`n")) $true 'original added CR retained'
# Deliberately hostile inherited configuration is synthetic test data, never a candidate path.
# The generated command must never run. Use only a new local ignored test subdirectory.
if($IsWindows){
    $fixture=Join-Path $ScratchParent ('neutrality-'+[Guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($fixture)
    $command=Join-Path $fixture 'inherited-diff.cmd';$marker=Join-Path $fixture 'ran.txt'
    $config=Join-Path $fixture 'inherited-git.config';$attributes=Join-Path $fixture 'inherited-attributes'
    [IO.File]::WriteAllText($command,('@echo off'+"`r`n"+'echo detected > "'+$marker+'"'+"`r`n"+'exit /b 77'+"`r`n"))
    [IO.File]::WriteAllText($attributes,'* diff=synthetic')
    $configCommand=$command.Replace('\','/')
    [IO.File]::WriteAllText($config,('[core]'+"`n"+' autocrlf = true'+"`n"+' attributesFile = "'+$attributes.Replace('\','/')+'"'+"`n"+
        '[diff]'+"`n"+' external = "'+$configCommand+'"'+"`n"+'[diff "synthetic"]'+"`n"+' textconv = "'+$configCommand+'"'+"`n"))
    $oldGlobal=[Environment]::GetEnvironmentVariable('GIT_CONFIG_GLOBAL')
    $oldExternal=[Environment]::GetEnvironmentVariable('GIT_EXTERNAL_DIFF')
    try{
        [Environment]::SetEnvironmentVariable('GIT_CONFIG_GLOBAL',$config)
        [Environment]::SetEnvironmentVariable('GIT_EXTERNAL_DIFF',$command)
        $scenario=New-Scenario modified "old`r`n" "new`r`n" 1 1;$rows=@(Invoke-Scenario $scenario)
        Assert-Equal ([IO.File]::Exists($marker)) $false 'inherited external/textconv never run'
        Assert-Equal ($rows[0].patch.Contains("+new`r`n")) $true 'inherited autocrlf ignored'
    }finally{
        [Environment]::SetEnvironmentVariable('GIT_CONFIG_GLOBAL',$oldGlobal)
        [Environment]::SetEnvironmentVariable('GIT_EXTERNAL_DIFF',$oldExternal)
        foreach($name in @('inherited-diff.cmd','inherited-git.config','inherited-attributes','ran.txt')){
            $path=Join-Path $fixture $name
            [void](Assert-NoReviewReparseAncestor -Path $path -Context 'Synthetic neutrality cleanup')
            if([IO.File]::Exists($path)){[IO.File]::Delete($path)}
        }
        [IO.Directory]::Delete($fixture,$false)
    }
}
Assert-Equal $policy.review.maxChangedFiles 3000 'unchanged files limit'
Assert-Equal $policy.review.maxPatchBytes 5242880 'unchanged patch limit'
Assert-Equal $policy.suspicious.regexTimeoutMilliseconds 1000 'owner-authorized bounded regex deadline'
Write-Output ('TEXT_PATCH_EVIDENCE_ASSERTIONS='+$script:assertions+' NETWORK_CALLS=0 PROVIDER_CALLS=0 CANDIDATE_EXECUTION=0')
