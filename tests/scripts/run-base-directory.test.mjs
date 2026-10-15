import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, mkdtempSync, mkdirSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

// STM-INFRA-005: run folders must not depend on a hard-wired D:\Temp.
const scripts = new URL('../../scripts/', import.meta.url);
const helper = new URL('lib/Get-StmRunBaseDirectory.ps1', scripts);
const callers = ['Invoke-ClickInstallReadiness.ps1', 'Invoke-ColleagueFreshRunTest.ps1',
  'Invoke-ColleagueInstallReadiness.ps1', 'Invoke-LoggingReadiness.ps1', 'Invoke-ReleaseCandidateReadiness.ps1',
  'Invoke-SecretSafetyReadiness.ps1', 'New-RunLogBundle.ps1', 'New-ContributorTaskPrompt.ps1',
  'Test-ContributorKickoffReadiness.ps1'];

test('former D:\\Temp callers use the shared run-base helper instead of a literal path', () => {
  for (const name of callers) {
    const source = readFileSync(new URL(name, scripts), 'utf8');
    assert.doesNotMatch(source, /['"]D:\\(?:Temp)?['"]/i, `${name} still hard-codes D:\\Temp`);
    assert.match(source, /lib\/Get-StmRunBaseDirectory\.ps1/, `${name} does not use the helper`);
  }
});

const pwsh = spawnSync('pwsh', ['-NoLogo', '-NoProfile', '-Command', '$PSVersionTable.PSVersion.Major'], { encoding: 'utf8' });
const pwshAvailable = pwsh.status === 0;

function resolveBase(args, env = {}) {
  const result = spawnSync('pwsh', ['-NoLogo', '-NoProfile', '-NonInteractive', '-File', helper.pathname.replace(/^\/([A-Za-z]:)/, '$1'), ...args],
    { encoding: 'utf8', env: { ...process.env, STM_RUN_BASE_DIRECTORY: '', ...env } });
  assert.equal(result.status, 0, result.stderr);
  return result.stdout.trim();
}

test('helper prefers an existing preferred directory', { skip: !pwshAvailable && 'pwsh not available' }, () => {
  const root = mkdtempSync(join(tmpdir(), 'stm-run-base-'));
  try {
    const preferred = join(root, 'preferred');
    mkdirSync(preferred);
    assert.equal(resolveBase(['-PreferredDirectory', preferred, '-FallbackDirectory', join(root, 'fallback')]), preferred);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test('helper falls back when the preferred drive does not exist', { skip: !pwshAvailable && 'pwsh not available' }, () => {
  const root = mkdtempSync(join(tmpdir(), 'stm-run-base-'));
  try {
    const fallback = join(root, 'fallback');
    // Pick a drive letter that is not mounted on this machine (always true off Windows).
    const unused = 'QRSTUVWXYZ'.split('').find(letter => !existsSync(`${letter}:\\`)) ?? 'Q';
    assert.equal(resolveBase(['-PreferredDirectory', `${unused}:\\NoSuchStmRunBase`, '-FallbackDirectory', fallback]), fallback);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test('explicit STM_RUN_BASE_DIRECTORY overrides every default', { skip: !pwshAvailable && 'pwsh not available' }, () => {
  const override = join(tmpdir(), 'stm-run-base-override');
  assert.equal(resolveBase([], { STM_RUN_BASE_DIRECTORY: override }), override);
});

test('a relative STM_RUN_BASE_DIRECTORY is rejected instead of depending on the current directory',
  { skip: !pwshAvailable && 'pwsh not available' }, () => {
    const result = spawnSync('pwsh', ['-NoLogo', '-NoProfile', '-NonInteractive', '-File', helper.pathname.replace(/^\/([A-Za-z]:)/, '$1')],
      { encoding: 'utf8', env: { ...process.env, STM_RUN_BASE_DIRECTORY: join('relative', 'runs') } });
    assert.notEqual(result.status, 0);
    assert.match(result.stderr + result.stdout, /absoluter Pfad/);
  });
