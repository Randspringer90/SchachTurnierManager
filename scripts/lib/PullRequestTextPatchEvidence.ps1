#requires -Version 7.0
# Trusted-base text evidence; online activation requires the reviewed base runtime.
# SECURITY-PATTERN-FILE: Defensive text evidence; no PR paths are materialized or executed.
Set-StrictMode -Version Latest

function Assert-ReviewTextSha {
    param([string]$Value)
    if ($Value -cnotmatch '^[0-9a-f]{40}$') { throw 'TEXT_EVIDENCE_SHA_INVALID' }
}

function Assert-ReviewTextPath {
    param([string]$Path)
    # A deliberately conservative subset of the existing Windows-safe path policy.
    if (-not $Path -or $Path.Length -gt 1024 -or $Path -cnotmatch '^[A-Za-z0-9_. /-]+$' -or
        $Path.StartsWith('/') -or $Path.Contains('//') -or
        @($Path.Split('/') | Where-Object { $_ -in @('.','..','') -or $_ -match '(?i)^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)|[. ]$' }).Count) {
        throw 'TEXT_EVIDENCE_PATH_INVALID'
    }
    if ($Path -match '(?i)(?:^|/)(?:\.git|\.secrets|secrets|node_modules|bin|obj|logs|output|tmp|backups?)(?:/|$)' -or
        $Path -match '(?i)(?:^|/)(?:\.env(?:\..*)?|\.npmrc|credentials?(?:\..*)?)$' -or
        $Path -match '(?i)\.(?:db|sqlite(?:3)?|bak|dump|log|exe|dll|msi|zip|7z|rar|cab|jar|com|scr|pif|sys|so|dylib|nupkg|png|jpg|jpeg|gif|webp|ico|pdf|woff2?|ttf|mp4|apk)$') {
        throw 'TEXT_EVIDENCE_NON_SOURCE_PATH'
    }
}

function Invoke-ReviewBoundedNativeRead {
    param([Parameter(Mandatory)][string]$Executable, [ValidateSet('git','gh')][string]$Tool,
        [Parameter(Mandatory)][string[]]$Arguments, [Parameter(Mandatory)][string]$WorkingDirectory,
        [ValidateRange(1,7522080)][int]$MaximumStdoutBytes, [ValidateRange(1,30000)][int]$DeadlineMilliseconds=20000,
        [switch]$NeutralGitEnvironment)
    $exe=[IO.Path]::GetFullPath($Executable)
    $expectedName=if($IsWindows){"$Tool.exe"}else{$Tool}
    if ([IO.Path]::GetFileName($exe) -cne $expectedName -or -not [IO.File]::Exists($exe)) { throw 'TEXT_EVIDENCE_NATIVE_TOOL' }
    [void](Assert-NoReviewReparseAncestor -Path $exe -Context 'Trusted native review tool')
    [void](Assert-NoReviewReparseAncestor -Path $WorkingDirectory -Context 'Neutral review working directory')
    $info=[Diagnostics.ProcessStartInfo]::new(); $info.FileName=$exe; $info.WorkingDirectory=$WorkingDirectory
    $info.UseShellExecute=$false; $info.CreateNoWindow=$true
    $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true
    foreach($argument in $Arguments){[void]$info.ArgumentList.Add($argument)}
    if($NeutralGitEnvironment){
        $info.Environment.Clear()
        foreach($name in @('SystemRoot','WINDIR')){
            $value=[Environment]::GetEnvironmentVariable($name)
            if($value){$info.Environment[$name]=$value}
        }
        $info.Environment['PATH']=[IO.Path]::GetDirectoryName($exe)
        $info.Environment['GIT_CONFIG_NOSYSTEM']='1'
        $info.Environment['GIT_CONFIG_GLOBAL']=Join-Path $WorkingDirectory 'empty.config'
        $info.Environment['GIT_CEILING_DIRECTORIES']=$WorkingDirectory
        $info.Environment['GIT_DISCOVERY_ACROSS_FILESYSTEM']='0'
        $info.Environment['LC_ALL']='C'; $info.Environment['LANG']='C'
    }
    if($Tool -ceq 'gh'){$info.Environment['GH_PROMPT_DISABLED']='1'}
    $process=[Diagnostics.Process]::new(); $process.StartInfo=$info; $started=$false
    $streams=@([IO.MemoryStream]::new(),[IO.MemoryStream]::new())
    $buffers=@([byte[]]::new(8192),[byte[]]::new(8192)); $closed=@($false,$false)
    $tasks=@($null,$null); $clock=[Diagnostics.Stopwatch]::StartNew()
    try {
        $started=$process.Start()
        if(-not $started){throw 'TEXT_EVIDENCE_NATIVE_START'}
        $pipes=@($process.StandardOutput.BaseStream,$process.StandardError.BaseStream)
        for($i=0;$i -lt 2;$i++){ $tasks[$i]=$pipes[$i].ReadAsync($buffers[$i],0,$buffers[$i].Length) }
        while(-not ($closed[0] -and $closed[1] -and $process.HasExited)){
            if($clock.ElapsedMilliseconds -ge $DeadlineMilliseconds){throw 'TEXT_EVIDENCE_PROCESS_DEADLINE'}
            for($i=0;$i -lt 2;$i++){
                if($closed[$i] -or -not $tasks[$i].IsCompleted){continue}
                $count=$tasks[$i].GetAwaiter().GetResult()
                if($count -eq 0){$closed[$i]=$true;continue}
                $maximum=if($i -eq 0){$MaximumStdoutBytes}else{65536}
                if($streams[$i].Length+$count -gt $maximum){throw 'TEXT_EVIDENCE_PROCESS_OUTPUT_LIMIT'}
                $streams[$i].Write($buffers[$i],0,$count)
                $tasks[$i]=$pipes[$i].ReadAsync($buffers[$i],0,$buffers[$i].Length)
            }
            [Threading.Thread]::Sleep(2)
        }
        $utf8=[Text.UTF8Encoding]::new($false,$true)
        [pscustomobject]@{ exitCode=$process.ExitCode; stdout=$utf8.GetString($streams[0].ToArray()); stderrBytes=$streams[1].Length }
    }
    finally {
        if($started -and -not $process.HasExited){
            try{$process.Kill($true);[void]$process.WaitForExit(1000)}catch{throw 'TEXT_EVIDENCE_PROCESS_TERMINATION_FAILED'}
        }
        $process.Dispose(); foreach($stream in $streams){$stream.Dispose()}
    }
}

function ConvertFrom-ReviewVerifiedTextBlob {
    param([Parameter(Mandatory)]$Blob, [Parameter(Mandatory)][string]$ExpectedSha,
        [ValidateRange(0,5242880)][int64]$ExpectedSize)
    Assert-ReviewTextSha $ExpectedSha
    if([string](Get-ReviewPropertyValue $Blob 'sha' '') -cne $ExpectedSha -or
        [string](Get-ReviewPropertyValue $Blob 'encoding' '') -cne 'base64' -or
        [int64](Get-ReviewPropertyValue $Blob 'size' -1) -ne $ExpectedSize){throw 'TEXT_EVIDENCE_BLOB_METADATA'}
    $encoded=[string](Get-ReviewPropertyValue $Blob 'content' '')
    $encodedLimit=4L*[int64][Math]::Ceiling($ExpectedSize/3.0)+[int64][Math]::Ceiling($ExpectedSize/45.0)*2+4
    if($encoded.Length -gt $encodedLimit -or $encoded -cmatch '[^A-Za-z0-9+/=\r\n]'){throw 'TEXT_EVIDENCE_BLOB_ENCODING'}
    $chars=$encoded.Replace("`r",'').Replace("`n",'').ToCharArray()
    try{[byte[]]$bytes=[Convert]::FromBase64CharArray($chars,0,$chars.Length)}catch{throw 'TEXT_EVIDENCE_BLOB_ENCODING'}
    if($bytes.Length -ne $ExpectedSize){throw 'TEXT_EVIDENCE_BLOB_SIZE'}
    $hash=[Security.Cryptography.IncrementalHash]::CreateHash([Security.Cryptography.HashAlgorithmName]::SHA1)
    try{
        $hash.AppendData([Text.Encoding]::ASCII.GetBytes("blob $($bytes.Length)"+[char]0)); $hash.AppendData($bytes)
        $actual=([Convert]::ToHexString($hash.GetHashAndReset())).ToLowerInvariant()
    }finally{$hash.Dispose()}
    if($actual -cne $ExpectedSha){throw 'TEXT_EVIDENCE_BLOB_HASH'}
    if([Array]::IndexOf($bytes,[byte]0) -ge 0){throw 'TEXT_EVIDENCE_BLOB_NUL'}
    try{[void]([Text.UTF8Encoding]::new($false,$true).GetString($bytes))}catch{throw 'TEXT_EVIDENCE_BLOB_UTF8'}
    return ,$bytes
}

function New-ReviewVerifiedNativeTextPatch {
    param([Parameter(Mandatory)][AllowEmptyCollection()][byte[]]$Before,
        [Parameter(Mandatory)][AllowEmptyCollection()][byte[]]$After,
        [Parameter(Mandatory)][string]$GitExecutable,[Parameter(Mandatory)][string]$ScratchParent,
        [ValidateRange(1,5242880)][int]$MaximumPatchBytes)
    $parent=Assert-NoReviewReparseAncestor -Path $ScratchParent -Context 'Text evidence scratch parent'
    if(-not [IO.Directory]::Exists($parent)){throw 'TEXT_EVIDENCE_SCRATCH_PARENT'}
    $scratch=Join-Path $parent ('text-evidence-'+[Guid]::NewGuid().ToString('N'))
    if([IO.Directory]::Exists($scratch) -or [IO.File]::Exists($scratch)){throw 'TEXT_EVIDENCE_SCRATCH_COLLISION'}
    [void][IO.Directory]::CreateDirectory($scratch)
    $names=@('before.txt','after.txt','empty.config','empty.attributes')
    try{
        [void](Assert-NoReviewReparseAncestor -Path $scratch -Context 'Text evidence scratch')
        for($i=0;$i -lt $names.Count;$i++){
            $bytes=[byte[]]::new(0)
            if($i -eq 0){$bytes=$Before}elseif($i -eq 1){$bytes=$After}
            $stream=[IO.File]::Open((Join-Path $scratch $names[$i]),[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
            try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
        }
        $result=Invoke-ReviewBoundedNativeRead -Executable $GitExecutable -Tool git -WorkingDirectory $scratch -NeutralGitEnvironment `
            -MaximumStdoutBytes $MaximumPatchBytes -Arguments @('--no-pager','-c','core.autocrlf=false','-c','core.safecrlf=false',
                '-c',('core.attributesFile='+ (Join-Path $scratch 'empty.attributes')),
                'diff','--no-index','--no-ext-diff','--no-textconv','--text','--no-color','--no-renames','--diff-algorithm=myers',
                '--unified=3','--src-prefix=a/','--dst-prefix=b/','--','before.txt','after.txt')
        if($result.exitCode -notin @(0,1) -or $result.stderrBytes -ne 0){throw 'TEXT_EVIDENCE_NATIVE_DIFF_FAILED'}
        if($result.exitCode -eq 0){if($result.stdout){throw 'TEXT_EVIDENCE_NATIVE_DIFF_UNEXPECTED'};return ''}
        $lines=$result.stdout.Split("`n")
        if($lines.Length -lt 5 -or $lines[0] -cne 'diff --git a/before.txt b/after.txt' -or
            $lines[1] -cnotmatch '^index [0-9a-f]+\.\.[0-9a-f]+ 100644$' -or
            $lines[2] -cne '--- a/before.txt' -or $lines[3] -cne '+++ b/after.txt') {throw 'TEXT_EVIDENCE_NATIVE_DIFF_HEADERS'}
        return ($lines[4..($lines.Length-1)] -join "`n")
    }finally{
        # Delete only our four exact inert files, never recurse or follow candidate paths.
        [void](Assert-NoReviewReparseAncestor -Path $scratch -Context 'Text evidence cleanup')
        foreach($name in $names){
            $path=Join-Path $scratch $name
            [void](Assert-NoReviewReparseAncestor -Path $path -Context 'Text evidence inert file')
            if([IO.File]::Exists($path)){[IO.File]::Delete($path)}
        }
        if([IO.Directory]::Exists($scratch)){[IO.Directory]::Delete($scratch,$false)}
    }
}

function Add-ReviewVerifiedTextPatchEvidence {
    param([Parameter(Mandatory)][object[]]$ApiFiles,[Parameter(Mandatory)]$Metadata,
        [Parameter(Mandatory)]$BaseCommit,[Parameter(Mandatory)]$HeadCommit,
        [Parameter(Mandatory)]$BaseTree,[Parameter(Mandatory)]$HeadTree,[Parameter(Mandatory)]$Comparison,
        [Parameter(Mandatory)][string]$ExpectedBaseSha,[Parameter(Mandatory)][string]$ExpectedHeadSha,
        [Parameter(Mandatory)][scriptblock]$BlobProvider,[Parameter(Mandatory)][string]$GitExecutable,
        [Parameter(Mandatory)][string]$ScratchParent,[Parameter(Mandatory)]$ReviewPolicy)
    Assert-ReviewTextSha $ExpectedBaseSha; Assert-ReviewTextSha $ExpectedHeadSha
    if([int]$ReviewPolicy.maxChangedFiles -ne 3000 -or [int]$ReviewPolicy.maxPatchBytes -ne 5242880){throw 'TEXT_EVIDENCE_POLICY_DRIFT'}
    if([string]$Metadata.baseRefOid -cne $ExpectedBaseSha -or [string]$Metadata.headRefOid -cne $ExpectedHeadSha -or
        [string]$Metadata.currentTrustedBaseSha -cne $ExpectedBaseSha -or
        [string]$BaseCommit.sha -cne $ExpectedBaseSha -or [string]$HeadCommit.sha -cne $ExpectedHeadSha -or
        [string]$Comparison.base_commit.sha -cne $ExpectedBaseSha -or [string]$Comparison.merge_base_commit.sha -cne $ExpectedBaseSha){
        throw 'TEXT_EVIDENCE_COMMIT_BINDING'
    }
    foreach($pair in @(@($BaseCommit,$BaseTree),@($HeadCommit,$HeadTree))){
        Assert-ReviewTextSha ([string]$pair[0].tree.sha)
        if([string]$pair[1].sha -cne [string]$pair[0].tree.sha -or [bool](Get-ReviewPropertyValue $pair[1] 'truncated' $true)){
            throw 'TEXT_EVIDENCE_TREE_BINDING'
        }
    }
    if($ApiFiles.Count -gt 3000 -or [int]$Metadata.changedFiles -ne $ApiFiles.Count){throw 'TEXT_EVIDENCE_INVENTORY_COUNT'}
    $baseMap=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    $headMap=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    foreach($pair in @(@($BaseTree,$baseMap),@($HeadTree,$headMap))){
        $aliases=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach($entry in @($pair[0].tree)){
            $entryPath=[string]$entry.path
            if(-not $entryPath -or -not $aliases.Add($entryPath)){throw 'TEXT_EVIDENCE_TREE_DUPLICATE'}
            $pair[1].Add($entryPath,$entry)
        }
    }
    # Complete inventory preflight precedes every blob read, including later files.
    $inventoryPaths=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $coveredPaths=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach($file in $ApiFiles){
        $extension=[IO.Path]::GetExtension([string]$file.filename).ToLowerInvariant()
        if($extension -notin (@($ReviewPolicy.blockedFileTypes)+@($ReviewPolicy.archiveFileTypes)+
            @('.png','.jpg','.jpeg','.gif','.webp','.ico','.pdf','.woff','.woff2','.ttf','.mp4','.apk'))){
            Assert-ReviewTextPath ([string]$file.filename)
            $previous=[string](Get-ReviewPropertyValue $file 'previous_filename' '')
            if($previous){Assert-ReviewTextPath $previous}
        }
        [void]$coveredPaths.Add([string]$file.filename)
        $previous=[string](Get-ReviewPropertyValue $file 'previous_filename' '')
        if($previous){[void]$coveredPaths.Add($previous)}
    }
    $treePaths=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $actualDelta=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach($map in @($baseMap,$headMap)){foreach($key in $map.Keys){[void]$treePaths.Add($key)}}
    foreach($path in $treePaths){
        $oldEntry=$null;$newEntry=$null
        [void]$baseMap.TryGetValue($path,[ref]$oldEntry);[void]$headMap.TryGetValue($path,[ref]$newEntry)
        if(($oldEntry -and [string]$oldEntry.type -ceq 'tree') -or ($newEntry -and [string]$newEntry.type -ceq 'tree')){continue}
        $changed=-not $oldEntry -or -not $newEntry -or [string]$oldEntry.sha -cne [string]$newEntry.sha -or [string]$oldEntry.mode -cne [string]$newEntry.mode
        if($changed){[void]$actualDelta.Add($path)}
        if($changed -and -not $coveredPaths.Contains($path)){throw 'TEXT_EVIDENCE_TREE_INVENTORY_MISMATCH'}
    }
    foreach($file in $ApiFiles){
        $previous=[string](Get-ReviewPropertyValue $file 'previous_filename' '')
        if(-not $actualDelta.Contains([string]$file.filename) -and (-not $previous -or -not $actualDelta.Contains($previous))){
            throw 'TEXT_EVIDENCE_TREE_INVENTORY_MISMATCH'
        }
    }
    $preflightBlobBytes=0L
    foreach($file in $ApiFiles){
        $path=[string]$file.filename
        if(-not $path -or -not $inventoryPaths.Add($path)){throw 'TEXT_EVIDENCE_INVENTORY_DUPLICATE'}
        $binaryExtension=[IO.Path]::GetExtension($path).ToLowerInvariant()
        $binaryPath=$binaryExtension -in (@($ReviewPolicy.blockedFileTypes)+@($ReviewPolicy.archiveFileTypes)+
            @('.png','.jpg','.jpeg','.gif','.webp','.ico','.pdf','.woff','.woff2','.ttf','.mp4','.apk'))
        if($binaryPath){continue}
        Assert-ReviewTextPath $path
        $oldPath=$path; $status=[string]$file.status
        if($status -cnotin @('added','removed','modified','renamed')){throw 'TEXT_EVIDENCE_STATUS'}
        if($status -ceq 'renamed'){$oldPath=[string]$file.previous_filename;Assert-ReviewTextPath $oldPath}
        $oldEntry=$null;$newEntry=$null
        if($status -cne 'added' -and -not $baseMap.TryGetValue($oldPath,[ref]$oldEntry)){throw 'TEXT_EVIDENCE_BASE_ENTRY'}
        if($status -cne 'removed' -and -not $headMap.TryGetValue($path,[ref]$newEntry)){throw 'TEXT_EVIDENCE_HEAD_ENTRY'}
        if(($status -ceq 'added' -and $baseMap.ContainsKey($path)) -or ($status -ceq 'removed' -and $headMap.ContainsKey($path))){throw 'TEXT_EVIDENCE_STATUS_TREE'}
        $apiBlobEntry=if($status -ceq 'removed'){$oldEntry}else{$newEntry}
        if([string](Get-ReviewPropertyValue $file 'sha' '') -cne [string]$apiBlobEntry.sha){throw 'TEXT_EVIDENCE_FILE_BLOB_BINDING'}
        foreach($entry in @($oldEntry,$newEntry)){
            if($null -eq $entry){continue}
            if([string]$entry.type -cne 'blob' -or [string]$entry.mode -cnotin @('100644','100755')){throw 'TEXT_EVIDENCE_MODE'}
            Assert-ReviewTextSha ([string]$entry.sha)
            $size=[int64](Get-ReviewPropertyValue $entry 'size' -1)
            if($size -lt 0 -or $size -gt 5242880){throw 'TEXT_EVIDENCE_BLOB_BUDGET'}
        }
        $patchValue=Get-ReviewPropertyValue $file 'patch' $null; $complete=$false
        if($null -ne $patchValue){
            try{[void](Get-ReviewUnifiedHunkStatistics -Patch ([string]$patchValue) -ExpectedAdditions $file.additions -ExpectedDeletions $file.deletions);$complete=$true}catch{$complete=$false}
        }
        if(-not $complete){
            foreach($entry in @($oldEntry,$newEntry)){if($entry){$preflightBlobBytes+=[int64]$entry.size}}
            if($preflightBlobBytes -gt 5242880){throw 'TEXT_EVIDENCE_BLOB_BUDGET'}
        }
    }
    $paths=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $budget=0L; $blobBytes=0L; $emittedPatches=0; $prepared=[Collections.Generic.List[object]]::new()
    foreach($file in $ApiFiles){
        $path=[string]$file.filename
        if(-not $paths.Add($path)){throw 'TEXT_EVIDENCE_INVENTORY_DUPLICATE'}
        $patchValue=Get-ReviewPropertyValue $file 'patch' $null
        $complete=$false
        if($null -ne $patchValue){
            try{[void](Get-ReviewUnifiedHunkStatistics -Patch ([string]$patchValue) -ExpectedAdditions $file.additions -ExpectedDeletions $file.deletions);$complete=$true}catch{$complete=$false}
        }
        $row=[ordered]@{};foreach($property in $file.PSObject.Properties){$row[$property.Name]=$property.Value}
        # Never accept a provenance object supplied by T4/API data.
        $row.Remove('textPatchEvidence')
        # Existing independently attested artifact handling remains in its original route.
        # This helper never fetches a binary/archive or a nonregular Git object as text.
        $binaryExtension=[IO.Path]::GetExtension($path).ToLowerInvariant()
        $binaryPath=$binaryExtension -in (@($ReviewPolicy.blockedFileTypes)+@($ReviewPolicy.archiveFileTypes)+
            @('.png','.jpg','.jpeg','.gif','.webp','.ico','.pdf','.woff','.woff2','.ttf','.mp4','.apk'))
        if(-not $complete -and -not $binaryPath){
            Assert-ReviewTextPath $path
            $status=[string]$file.status; $oldPath=$path
            if($status -cnotin @('added','removed','modified','renamed')){throw 'TEXT_EVIDENCE_STATUS'}
            if($status -ceq 'renamed'){$oldPath=[string]$file.previous_filename;Assert-ReviewTextPath $oldPath}
            $oldEntry=$null;$newEntry=$null
            if($status -cne 'added' -and -not $baseMap.TryGetValue($oldPath,[ref]$oldEntry)){throw 'TEXT_EVIDENCE_BASE_ENTRY'}
            if($status -cne 'removed' -and -not $headMap.TryGetValue($path,[ref]$newEntry)){throw 'TEXT_EVIDENCE_HEAD_ENTRY'}
            if(($status -ceq 'added' -and $baseMap.ContainsKey($path)) -or ($status -ceq 'removed' -and $headMap.ContainsKey($path))){throw 'TEXT_EVIDENCE_STATUS_TREE'}
            $sides=[Collections.Generic.List[byte[]]]::new()
            foreach($entry in @($oldEntry,$newEntry)){
                if($null -eq $entry){$sides.Add([byte[]]::new(0));continue}
                if([string]$entry.type -cne 'blob' -or [string]$entry.mode -cnotin @('100644','100755')){throw 'TEXT_EVIDENCE_MODE'}
                $size=[int64](Get-ReviewPropertyValue $entry 'size' -1)
                if($size -lt 0 -or $size -gt 5242880 -or $blobBytes+$size -gt 5242880){throw 'TEXT_EVIDENCE_BLOB_BUDGET'}
                Assert-ReviewTextSha ([string]$entry.sha);$blobBytes+=$size
                $blob=& $BlobProvider ([string]$entry.sha) $size
                $sides.Add((ConvertFrom-ReviewVerifiedTextBlob -Blob $blob -ExpectedSha $entry.sha -ExpectedSize $size))
            }
            $remaining=5242880-$budget
            if($remaining -lt 1){throw 'TEXT_EVIDENCE_PATCH_BUDGET'}
            $hunks=New-ReviewVerifiedNativeTextPatch -Before $sides[0] -After $sides[1] -GitExecutable $GitExecutable -ScratchParent $ScratchParent -MaximumPatchBytes $remaining
            [void](Get-ReviewUnifiedHunkStatistics -Patch $hunks -ExpectedAdditions $file.additions -ExpectedDeletions $file.deletions)
            $row['patch']=$hunks
            $row['textPatchEvidence']=[pscustomobject]@{
                status='VERIFIED'; method='git-no-index-sha1-utf8-v1'; baseSha=$ExpectedBaseSha; headSha=$ExpectedHeadSha
                baseTreeSha=[string]$BaseTree.sha; headTreeSha=[string]$HeadTree.sha
                beforeBlobSha=if($oldEntry){[string]$oldEntry.sha}else{$null}
                afterBlobSha=if($newEntry){[string]$newEntry.sha}else{$null}
                beforeBytes=$sides[0].Length; afterBytes=$sides[1].Length
                beforeSha256=([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($sides[0]))).ToLowerInvariant()
                afterSha256=([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($sides[1]))).ToLowerInvariant()
                patchSha256=Get-ReviewSha256 $hunks; additions=[int]$file.additions; deletions=[int]$file.deletions
            }
        }
        $oldPath=if([string](Get-ReviewPropertyValue $file 'previous_filename' '')){[string]$file.previous_filename}else{$path}
        # Include the exact converter envelope and join separators in the shared 5 MiB budget.
        if($null -ne (Get-ReviewPropertyValue ([pscustomobject]$row) 'patch' $null)){
            $oldHeader=if([string]$file.status -ceq 'added'){'--- /dev/null'}else{"--- a/$oldPath"}
            $newHeader=if([string]$file.status -ceq 'removed'){'+++ /dev/null'}else{"+++ b/$path"}
            $envelope="diff --git a/$oldPath b/$path`n$oldHeader`n$newHeader`n"+[string]$row['patch']
            if($emittedPatches -gt 0){$budget++}
            $budget+=[Text.Encoding]::UTF8.GetByteCount($envelope)
            $emittedPatches++
        }
        if($budget -gt 5242880){throw 'TEXT_EVIDENCE_PATCH_BUDGET'}
        $prepared.Add([pscustomobject]$row)
    }
    return $prepared.ToArray()
}
