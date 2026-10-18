import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn, spawnSync } from 'node:child_process';

const repository = fileURLToPath(new URL('../../', import.meta.url));
const scriptPath = join(repository, 'scripts', 'Invoke-NpmSafe.ps1');
const fixtureConfig = '# synthetic npm lifecycle fixture\nregistry=https://registry.example.invalid/\n';
const harness = String.raw`
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$global:LASTEXITCODE = 0
$global:stmNpmRecords = [Collections.Generic.List[object]]::new()
$global:stmNpmCalls = 0
$global:stmNestedRestored = $true
$global:stmOuterStillPresent = $true
$names = @('NPM_CONFIG_USERCONFIG', 'NPM_CONFIG_ALWAYS_AUTH', 'npm_config_always_auth')
if ($env:STM_NPM_INITIAL -eq 'present') {
    $env:NPM_CONFIG_USERCONFIG = 'synthetic-original-config'
    $env:NPM_CONFIG_ALWAYS_AUTH = 'synthetic-original-always-auth'
    if (-not $IsWindows) { $env:npm_config_always_auth = 'synthetic-original-lowercase' }
}
$before = @($names | ForEach-Object { [Environment]::GetEnvironmentVariable($_) })
if ($env:STM_NPM_NATIVE_PREF -eq 'true') { $PSNativeCommandUseErrorActionPreference = $true }
function npm {
    $global:stmNpmCalls++
    $path = $env:NPM_CONFIG_USERCONFIG
    $directory = Split-Path -Parent $path
    $protected = $false
    if ($IsWindows) {
        $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        $acl = Get-Acl -LiteralPath $directory
        $allowed = @($acl.Access | Where-Object { $_.AccessControlType -eq 'Allow' })
        $protected = $acl.AreAccessRulesProtected -and $allowed.Count -gt 0 -and
            @($allowed | Where-Object { $_.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value -ne $sid }).Count -eq 0
    } else {
        $protected = [int][IO.File]::GetUnixFileMode($directory) -eq 448 -and
            [int][IO.File]::GetUnixFileMode($path) -eq 384
    }
    $record = [pscustomobject]@{
        path = $path; protected = $protected
        configPresent = (Test-Path -LiteralPath $path -PathType Leaf)
        configMatchesFixture = if ($env:STM_NPM_EMPTY -eq 'true') { (Get-Content -LiteralPath $path -Raw) -match '^# intentionally empty:' } else { (Get-Content -LiteralPath $path -Raw) -match '^# synthetic npm lifecycle fixture' }
    }
    $global:stmNpmRecords.Add($record)
    if ($env:STM_NPM_CASE -eq 'nested' -and $global:stmNpmCalls -eq 1) {
        & $env:STM_NPM_SCRIPT -Root $env:STM_NPM_ROOT -WorkingDirectory '.' -NpmCommand ci
        $global:stmNestedRestored = $env:NPM_CONFIG_USERCONFIG -ceq $path
        $global:stmOuterStillPresent = Test-Path -LiteralPath $path -PathType Leaf
    }
    if ($env:STM_NPM_CASE -eq 'parallel') {
        Set-Content -LiteralPath $env:STM_NPM_READY -Value 'ready'
        $deadline = [DateTime]::UtcNow.AddSeconds(10)
        while (-not (Test-Path -LiteralPath $env:STM_NPM_PEER)) {
            if ([DateTime]::UtcNow -gt $deadline) { throw 'SYNTHETIC_PEER_TIMEOUT' }
            Start-Sleep -Milliseconds 25
        }
        $record.configPresent = Test-Path -LiteralPath $path -PathType Leaf
    }
    if ($env:STM_NPM_CASE -eq 'throw') { throw 'SYNTHETIC_NPM_START_FAILURE' }
    if ($env:STM_NPM_CASE -eq 'native-failure') {
        $hostName = if ($IsWindows) { 'pwsh.exe' } else { 'pwsh' }
        & (Join-Path $PSHOME $hostName) -NoLogo -NoProfile -NonInteractive -Command 'exit 17'
        $global:LASTEXITCODE = $LASTEXITCODE
    } else { $global:LASTEXITCODE = 0 }
}
$failed = $false
try {
    $arguments = @{ Root=$env:STM_NPM_ROOT; WorkingDirectory='.'; NpmCommand='ci' }
    if ($env:STM_NPM_CASE -eq 'missing-directory') { $arguments.WorkingDirectory='does-not-exist' }
    if ($env:STM_NPM_CASE -eq 'missing-command') { $arguments.NpmCommand='' }
    & $env:STM_NPM_SCRIPT @arguments
} catch { $failed = $true }
$npmExit = $LASTEXITCODE
$after = @($names | ForEach-Object { [Environment]::GetEnvironmentVariable($_) })
$remaining = @(Get-ChildItem -LiteralPath $env:STM_NPM_ROOT -Filter user.npmrc -File -Recurse -Force)
$result = [ordered]@{
    failed=$failed; npmExit=$npmExit; calls=$global:stmNpmCalls
    records=@($global:stmNpmRecords); before=$before; after=$after
    remainingConfigs=$remaining.Count
    recordedPathsRemaining=@($global:stmNpmRecords | Where-Object { Test-Path -LiteralPath $_.path }).Count
    recordedDirectoriesRemaining=@($global:stmNpmRecords | Where-Object { Test-Path -LiteralPath (Split-Path -Parent $_.path) }).Count
    remainingTempDirectories=@(Get-ChildItem -LiteralPath (Join-Path $env:STM_NPM_ROOT 'temp') -Directory -Filter 'stm-npm-*').Count
    nestedEnvironmentRestored=$global:stmNestedRestored
    outerConfigSurvivedNestedInvocation=$global:stmOuterStillPresent
}
'RESULT=' + ($result | ConvertTo-Json -Depth 8 -Compress)
exit 0
`;

function fixture(config = 'plaintext') {
  const root = mkdtempSync(join(tmpdir(), 'stm-npm-lifecycle-'));
  mkdirSync(join(root, '.secrets', 'local'), { recursive: true });
  mkdirSync(join(root, 'temp'));
  if (config === 'plaintext') writeFileSync(join(root, '.secrets', 'local', 'npmrc'), fixtureConfig);
  if (config === 'broken-encrypted') writeFileSync(join(root, '.secrets', 'local', 'npmrc.dpapi.txt'), 'synthetic-malformed-encrypted-config');
  const harnessPath = join(root, 'harness.ps1');
  writeFileSync(harnessPath, harness);
  return { root, harnessPath };
}

function environment(item, scenario, extra = {}) {
  // Only launch essentials are inherited; no real npm or provider credentials.
  const env = {};
  for (const key of ['PATH', 'SystemRoot', 'HOME', 'USERPROFILE', 'PSModulePath']) {
    if (process.env[key]) env[key] = process.env[key];
  }
  return { ...env, TEMP: join(item.root, 'temp'), TMP: join(item.root, 'temp'),
    TMPDIR: join(item.root, 'temp'), STM_NPM_ROOT: item.root, STM_NPM_SCRIPT: scriptPath,
    STM_NPM_CASE: scenario, STM_NPM_INITIAL: 'present', ...extra };
}

function decode(result) {
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  const line = result.stdout.split(/\r?\n/).find(value => value.startsWith('RESULT='));
  assert.ok(line, result.stdout + result.stderr);
  return JSON.parse(line.slice(7));
}

function run(item, scenario, extra) {
  return decode(spawnSync('pwsh', ['-NoLogo', '-NoProfile', '-NonInteractive', '-File', item.harnessPath],
    { cwd: repository, env: environment(item, scenario, extra), encoding: 'utf8', timeout: 20000, windowsHide: true }));
}

function cleanResult(result, { calls = 1, failed = false, exit = 0 } = {}) {
  assert.equal(result.failed, failed);
  assert.equal(result.calls, calls);
  assert.equal(result.npmExit, exit, 'native npm exit code must survive cleanup');
  assert.deepEqual(result.after, result.before, 'caller environment must be restored');
  assert.equal(result.remainingConfigs, 0, 'no generated npmrc may survive any outcome');
  assert.equal(result.recordedPathsRemaining, 0, 'every invocation must remove its own temporary config');
  assert.equal(result.recordedDirectoriesRemaining, 0, 'every invocation must remove its own temporary directory');
  if (calls === 0) assert.equal(result.remainingTempDirectories, 0, 'failures before npm starts must also remove temporary directories');
  for (const record of result.records) {
    assert.equal(record.configPresent, true);
    assert.equal(record.configMatchesFixture, true);
    assert.equal(record.protected, true, 'temporary configuration must be protected before npm starts');
  }
}

for (const scenario of ['success', 'native-failure', 'missing-directory', 'missing-command', 'throw']) {
  test(`npm temporary config lifecycle: ${scenario}`, () => {
    const item = fixture();
    try {
      const early = scenario === 'missing-directory' || scenario === 'missing-command';
      cleanResult(run(item, scenario), { calls: early ? 0 : 1,
        failed: early || scenario === 'throw', exit: scenario === 'native-failure' ? 17 : 0 });
    } finally { rmSync(item.root, { recursive: true, force: true }); }
  });
}

test('npm removes temporary state when synthetic encrypted config cannot be read', () => {
  const item = fixture('broken-encrypted');
  try { cleanResult(run(item, 'success'), { calls: 0, failed: true }); }
  finally { rmSync(item.root, { recursive: true, force: true }); }
});

test('npm isolates an empty config when the project has no local auth configuration', () => {
  const item = fixture('absent');
  try { cleanResult(run(item, 'success', { STM_NPM_EMPTY: 'true' })); }
  finally { rmSync(item.root, { recursive: true, force: true }); }
});

test('npm preserves native failure exit codes with inherited native-error exceptions enabled', () => {
  const item = fixture();
  try { cleanResult(run(item, 'native-failure', { STM_NPM_NATIVE_PREF: 'true' }), { exit: 17 }); }
  finally { rmSync(item.root, { recursive: true, force: true }); }
});

test('npm leaves originally absent environment variables absent', () => {
  const item = fixture();
  try { cleanResult(run(item, 'success', { STM_NPM_INITIAL: 'absent' })); }
  finally { rmSync(item.root, { recursive: true, force: true }); }
});

test('nested npm invocations preserve the outer config and use separate temporary files', () => {
  const item = fixture();
  try {
    const result = run(item, 'nested');
    cleanResult(result, { calls: 2 });
    assert.equal(new Set(result.records.map(value => value.path)).size, 2);
    assert.equal(result.nestedEnvironmentRestored, true);
    assert.equal(result.outerConfigSurvivedNestedInvocation, true);
  } finally { rmSync(item.root, { recursive: true, force: true }); }
});

function runAsync(item, extra) {
  return new Promise((resolve, reject) => {
    const child = spawn('pwsh', ['-NoLogo', '-NoProfile', '-NonInteractive', '-File', item.harnessPath],
      { cwd: repository, env: environment(item, 'parallel', extra), windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] });
    let stdout = '', stderr = '';
    child.stdout.setEncoding('utf8').on('data', value => { stdout += value; });
    child.stderr.setEncoding('utf8').on('data', value => { stderr += value; });
    const timer = setTimeout(() => { child.kill(); }, 20000);
    child.once('error', error => { clearTimeout(timer); reject(error); });
    child.once('close', status => {
      clearTimeout(timer);
      try { resolve(decode({ status, stdout, stderr })); } catch (error) { reject(error); }
    });
  });
}

test('parallel npm invocations in one project do not share or delete each other\'s config', async () => {
  const item = fixture();
  try {
    const left = join(item.root, 'left.ready'), right = join(item.root, 'right.ready');
    const results = await Promise.all([
      runAsync(item, { STM_NPM_READY: left, STM_NPM_PEER: right }),
      runAsync(item, { STM_NPM_READY: right, STM_NPM_PEER: left }),
    ]);
    for (const result of results) {
      // The other invocation may still be live when this process reports; only its own file must be gone.
      cleanResult({ ...result, remainingConfigs: result.recordedPathsRemaining });
    }
    assert.notEqual(results[0].records[0].path, results[1].records[0].path);
  } finally { rmSync(item.root, { recursive: true, force: true }); }
});
