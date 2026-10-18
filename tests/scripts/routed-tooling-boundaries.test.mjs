import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const repository = fileURLToPath(new URL('../../', import.meta.url));
const validIds = ['t-inventory', 'STM-AI-005', 'Step_01', 'task.part-2', '_step', '1', 'a'.repeat(128)];
const invalidIds = ['', null, 123, '.', '..', '../escape', '..\\escape', '/absolute', 'C:\\escape',
  'a/b', 'a\\b', 'a:b', 'a?b', 'a*b', 'a b', 'task.', 'task ', ' task', 'a\n', 'a'.repeat(129),
  'CON', 'con.extra', 'PRN', 'AUX', 'NUL', 'COM1', 'COM9.part', 'LPT1', 'LPT9.txt', 'CONIN$', 'CONOUT$'];
const harness = String.raw`
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $env:STM_TEST_REPO 'scripts/lib/RoutedExecutionCommon.ps1')
$policy = Get-RoutedPolicy
$ids = $env:STM_TEST_IDS | ConvertFrom-Json
function New-TestGraph($TaskId) {
    $task = [pscustomobject]@{
        taskId=$TaskId; parentId=''; backlogId='STM-AI-005'; purpose='Synthetic review'; inputs='Synthetic input'
        allowedFiles=@(); forbiddenFiles=@('AGENTS.md'); dependsOn=@(); risk='low'; category='documentation'; workMode='bulk'
        size='small'; deterministic=$true; minimumQuality='reviewed-by-stronger-profile'; preferredProvider='openai'
        preferredProfile=''; tokenBudget=8000; timeoutSeconds=300; requiredTests=@('synthetic'); reviewer='sol'
        resultFormat='markdown-report'; status='PENDING'; readOnly=$true
    }
    return [pscustomobject]@{ graphId='synthetic-review'; masterPrompt='Synthetic input'; orchestratorProfile='sol'; tasks=@($task) }
}
$idResults = @(foreach ($id in $ids) {
    $issues = @(Test-RoutedTaskGraph -Graph (New-TestGraph $id) -Policy $policy)
    [pscustomobject]@{ id=$id; accepted=($issues.Count -eq 0) }
})
$collision = New-TestGraph 'Step-A'
$collision.tasks += (New-TestGraph 'step-a').tasks[0]
$caseCollisionRejected = @(Test-RoutedTaskGraph -Graph $collision -Policy $policy).Count -gt 0
$graph = New-TestGraph 'checkpoint-test'
$path = Join-Path $env:STM_TEST_FIXTURE 'checkpoint.json'
Write-RoutedCheckpoint -CheckpointPath $path -Graph $graph -GraphHash (Get-TaskGraphHash $graph) -RunStatus 'INTERRUPTED_RATE_LIMIT'
$original = Get-Content -LiteralPath $path -Raw
$global:stmGit = (Get-Command git -CommandType Application | Select-Object -First 1).Source
$global:stmGitMode = 'normal'
function git {
    if ($args -contains '--abbrev-ref' -and $global:stmGitMode -eq 'branch-failure') {
        & $global:stmGit @args
        $global:LASTEXITCODE = 71
        return
    }
    if ($args -contains 'HEAD' -and $args -notcontains '--abbrev-ref') {
        if ($global:stmGitMode -eq 'head-failure') {
            & $global:stmGit @args
            $global:LASTEXITCODE = 72
            return
        }
        if ($global:stmGitMode -eq 'head-malformed') {
            $global:LASTEXITCODE = 0
            'synthetic-not-a-commit'
            return
        }
    }
    & $global:stmGit @args
}
$checkpointResults = @(foreach ($case in @('current', 'old-head', 'invalid-head', 'wrong-branch', 'skip-head', 'head-failure', 'head-malformed', 'branch-failure')) {
    $checkpoint = $original | ConvertFrom-Json
    $global:stmGitMode = $case
    if ($case -in @('old-head','skip-head')) { $checkpoint.head = '0' * 40 }
    if ($case -eq 'invalid-head') { $checkpoint.head = 'synthetic-not-a-commit' }
    if ($case -in @('wrong-branch','skip-head')) { $checkpoint.branch = 'synthetic-other-branch' }
    $checkpoint | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $path
    $accepted = $false
    try {
        $null = Read-RoutedCheckpoint -CheckpointPath $path -SkipHeadValidation:($case -eq 'skip-head')
        $accepted = $true
    } catch { }
    [pscustomobject]@{ case=$case; accepted=$accepted }
})
$global:stmGitMode = 'normal'
$cli = $null
# A guard prevents a regressed baseline from writing through the traversal ID.
# The real CLI must reject it before creating any output directory or lock.
if (-not ($idResults | Where-Object { $_.id -ceq '../escape' }).accepted) {
    $invalidGraph = New-TestGraph '../escape'
    $graphPath = Join-Path $env:STM_TEST_FIXTURE 'unsafe-graph.json'
    [ordered]@{ kind='routed-task-graph'; graphHash=(Get-TaskGraphHash $invalidGraph); graph=$invalidGraph } |
        ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $graphPath
    $runPath = Join-Path $env:STM_TEST_FIXTURE 'must-not-be-created'
    & pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $env:STM_TEST_REPO 'scripts/Invoke-RoutedTaskGraph.ps1') -TaskGraphPath $graphPath -RunRoot $runPath -DryRun | Out-Null
    $cli = [pscustomobject]@{ exit=$LASTEXITCODE; outputAbsent=(-not (Test-Path -LiteralPath $runPath)) }
}
[ordered]@{ ids=$idResults; caseCollisionRejected=$caseCollisionRejected; checkpoints=$checkpointResults; cli=$cli } | ConvertTo-Json -Depth 8 -Compress
`;

function checkAll() {
  const fixture = mkdtempSync(join(tmpdir(), 'stm-routed-boundaries-'));
  try {
    const script = join(fixture, 'boundaries.ps1');
    writeFileSync(script, harness);
    const env = {};
    for (const key of ['PATH', 'SystemRoot', 'TEMP', 'TMP', 'HOME', 'USERPROFILE', 'PSModulePath']) {
      if (process.env[key]) env[key] = process.env[key];
    }
    Object.assign(env, { STM_TEST_REPO: repository, STM_TEST_FIXTURE: fixture,
      STM_TEST_IDS: JSON.stringify([...validIds, ...invalidIds]) });
    const result = spawnSync('pwsh', ['-NoLogo', '-NoProfile', '-NonInteractive', '-File', script],
      { cwd: repository, env, encoding: 'utf8', timeout: 20000, windowsHide: true });
    assert.ifError(result.error);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    return JSON.parse(result.stdout);
  } finally { rmSync(fixture, { recursive: true, force: true }); }
}
const results = checkAll();

for (const [index, id] of validIds.entries()) {
  test(`routed task accepts existing portable identifier ${id}`, () => assert.equal(results.ids[index].accepted, true));
}
for (const [index, id] of invalidIds.entries()) {
  test(`routed task rejects unsafe identifier ${JSON.stringify(id)}`, () => assert.equal(results.ids[validIds.length + index].accepted, false));
}
test('routed task identifiers cannot collide on Windows case-insensitive paths', () => assert.equal(results.caseCollisionRejected, true));
for (const result of results.checkpoints) {
  test(`routed checkpoint source binding: ${result.case}`, () => {
    assert.equal(result.accepted, result.case === 'current' || result.case === 'skip-head');
  });
}

test('routed CLI rejects traversal before creating its run directory', () => {
  assert.ok(results.cli, 'unsafe graph must be rejected before attempting the CLI regression');
  assert.equal(results.cli.exit, 3);
  assert.equal(results.cli.outputAbsent, true);
});
