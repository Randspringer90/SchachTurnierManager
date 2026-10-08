#requires -Version 7.0
# SECURITY-PATTERN-FILE: Exercise the trusted online adapter with synthetic transport only.
[CmdletBinding()]
param([string]$AdapterPath = (Join-Path $PSScriptRoot 'Invoke-SafePullRequestReview.ps1'))
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $PSScriptRoot 'lib/PullRequestReviewCommon.ps1')
. (Join-Path $PSScriptRoot 'lib/PullRequestTextPatchEvidence.ps1')
$tokens = $null; $errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($AdapterPath, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw 'Trusted adapter parse failed.' }
$function = $ast.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq 'Get-OnlineReviewInput' }, $true)
if (-not $function) { throw 'Trusted adapter function missing.' }
$adapter = $function.Body.GetScriptBlock()
$Repository = 'Randspringer90/SchachTurnierManager'; $BaseBranch = 'development'; $PullRequestNumber = 114
$ExpectedBaseSha = 'a' * 40; $ExpectedHeadSha = 'b' * 40
$policies = [pscustomobject]@{ review = [pscustomobject]@{ blockedFileTypes = @(); archiveFileTypes = @() }; artifacts = @{} }
$script:treeRequests = @(); $script:reconstructed = $false; $script:badTree = $false
$script:completePatch = $false; $script:badCommit = $false; $script:truncatedTree = $false
function Test-OriginMatchesReviewRepository { return $true }
function Invoke-TrustedGhJson {
    param($Context, $Arguments)
    $endpoint = $Arguments[1]
    if ($Arguments[0] -ceq 'pr') {
        return [pscustomobject]@{ baseRefOid = $ExpectedBaseSha; headRefOid = $ExpectedHeadSha; baseRefName = $BaseBranch }
    }
    if ($endpoint -match '/git/ref/heads/') { return [pscustomobject]@{ object = @{ sha = $ExpectedBaseSha } } }
    if ($endpoint -match '/pulls/114/files') { return ,@([pscustomobject]@{ filename = 'synthetic.txt' }) }
    if ($endpoint -match '/git/commits/([0-9a-f]{40})$') {
        $sha = $Matches[1]; $tree = if ($sha -ceq $ExpectedHeadSha) { 'd' * 40 } else { 'c' * 40 }
        if ($script:badTree) { $tree = 'invalid/tree' }
        if ($script:badCommit) { $sha = 'e' * 40 }
        return [pscustomobject]@{ sha = $sha; tree = @{ sha = $tree } }
    }
    if ($endpoint -match '/git/trees/([0-9a-f]{40})\?recursive=1$') {
        $reference = $Matches[1]; $script:treeRequests += $reference
        # Reproduce the observed GitHub contract: sha echoes a commit-ish input,
        # whereas an actual tree-ID input returns that actual tree ID.
        return [pscustomobject]@{ sha = $reference; truncated = $script:truncatedTree; tree = @() }
    }
    if ($endpoint -match '/compare/') { return [pscustomobject]@{} }
    throw 'Unexpected synthetic transport call.'
}
function ConvertFrom-GitHubPullRequestReviewData {
    return [pscustomobject]@{ files = @([pscustomobject]@{ path = 'synthetic.txt'; patchAvailable = $script:completePatch; patchComplete = $script:completePatch }); patch = ''; treeMetadataComplete = $true }
}
function Add-ReviewVerifiedTextPatchEvidence {
    param($ApiFiles, $Metadata, $BaseCommit, $HeadCommit, $BaseTree, $HeadTree, $Comparison,
        $ExpectedBaseSha, $ExpectedHeadSha, $BlobProvider, $GitExecutable, $ScratchParent, $ReviewPolicy)
    if ($BaseTree.sha -cne $BaseCommit.tree.sha -or $HeadTree.sha -cne $HeadCommit.tree.sha) { throw 'Synthetic TEXT_EVIDENCE_TREE_BINDING' }
    $script:reconstructed = $true
    return $ApiFiles
}
function Add-PullRequestArtifactVerifications { param($Metadata, $Files, $HeadTree, $ReviewPolicy, $Attestations, $BlobProvider) return $Files }
$null = & $adapter
if (-not $script:reconstructed -or $script:treeRequests.Count -ne 4 -or
    $script:treeRequests[2] -cne ('d' * 40) -or $script:treeRequests[3] -cne ('c' * 40)) { throw 'Actual commit-tree IDs were not used by the online adapter.' }
$script:badTree = $true; $script:treeRequests = @(); $script:reconstructed = $false
$rejected = $false
try { $null = & $adapter } catch {
    if ($_.Exception.Message -cne 'TEXT_EVIDENCE_SHA_INVALID') { throw }
    $rejected = $true
}
if (-not $rejected -or $script:reconstructed -or $script:treeRequests.Count -ne 2) { throw 'Invalid tree ID was used or did not fail closed.' }
$script:badTree=$false; $script:completePatch=$true
$policies.review | Add-Member sourcePatternContexts @([pscustomobject]@{path='synthetic.txt'})
$script:treeRequests=@(); $script:reconstructed=$false
$result=& $adapter
if ($script:reconstructed -or $script:treeRequests.Count -ne 4 -or $result.metadata.patternContextHeadSha -cne $ExpectedHeadSha) { throw 'Complete patch context lacked actual-tree verification.' }
foreach ($failure in @('commit','tree')) {
    $script:badCommit=$failure -ceq 'commit'; $script:truncatedTree=$failure -ceq 'tree'
    $expectedError=if($script:badCommit){'TEXT_EVIDENCE_COMMIT_BINDING'}else{'TEXT_EVIDENCE_TREE_BINDING'}
    $rejected=$false
    try { $null=& $adapter } catch { if($_.Exception.Message -cne $expectedError){throw};$rejected=$true }
    if(-not $rejected){throw 'Incorrect commit or incomplete tree accepted.'}
}
Write-Output 'TREE_REFERENCE_ADAPTER=PASS CASES=5 NETWORK_CALLS=0 FOREIGN_CODE_EXECUTION=0'
