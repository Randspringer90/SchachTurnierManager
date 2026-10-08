import test from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, readFileSync, mkdirSync, rmSync, statSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { inspectLocalState, summarizeStatus, isCanonicalRemote, main } from '../../scripts/Get-LocalIntegrationState.mjs';

const script = fileURLToPath(new URL('../../scripts/Get-LocalIntegrationState.mjs', import.meta.url));
const git = (root, ...args) => execFileSync('git', args, { cwd: root, encoding: 'utf8', windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] }).trim();
function fixture(run) {
  const outer = mkdtempSync(join(tmpdir(), 'stm-local-state-'));
  const root = join(outer, 'repo'); mkdirSync(root);
  try {
    git(root, 'init', '-b', 'development');
    git(root, 'config', 'user.name', 'Synthetic Fixture');
    git(root, 'config', 'user.email', 'fixture@example.invalid');
    git(root, 'config', 'commit.gpgsign', 'false');
    git(root, 'remote', 'add', 'origin', 'https://github.com/Randspringer90/SchachTurnierManager.git');
    writeFileSync(join(root, 'source.txt'), 'baseline\n');
    git(root, 'add', 'source.txt'); git(root, 'commit', '-m', 'fixture');
    git(root, 'update-ref', 'refs/remotes/origin/development', 'HEAD');
    return run(root, outer);
  } finally { rmSync(outer, { recursive: true, force: true }); }
}

for (const [raw, expected] of [
  ['', { entries: 0 }], [' M file\0', { entries: 1, unstaged: 1 }],
  ['M  file\0', { staged: 1, unstaged: 0 }], ['MM file\0', { entries: 1, staged: 1, unstaged: 1 }],
  ['?? new\nname\0', { entries: 1, untracked: 1 }], [' D file\0', { deleted: 1 }],
  ['R  target\0source\0', { entries: 1, renamed: 1, staged: 1 }],
  ['C  target\0source\0?? next\0', { entries: 2, renamed: 1, untracked: 1 }],
  ['UU file\0', { conflicts: 1 }], ['AA file\0', { conflicts: 1 }],
  ['!! hidden\0', { entries: 0 }],
]) {
  test(`porcelain ${JSON.stringify(raw)}`, () => {
    const summary = summarizeStatus(raw);
    for (const [key, value] of Object.entries(expected)) assert.equal(summary[key], value);
  });
}
for (const raw of [' M file', 'M\0', 'ZZ file\0', 'R  target\0', '  file\0']) {
  test(`reject malformed porcelain ${JSON.stringify(raw)}`, () => assert.throws(() => summarizeStatus(raw), /INVALID_STATUS/));
}
for (const url of ['https://github.com/Randspringer90/SchachTurnierManager.git', 'git@github.com:Randspringer90/SchachTurnierManager.git', 'ssh://git@github.com/Randspringer90/SchachTurnierManager']) {
  test(`canonical ${url.split(':')[0]}`, () => assert.equal(isCanonicalRemote(url), true));
}
for (const url of ['https://github.com.evil.invalid/Randspringer90/SchachTurnierManager', 'https://user:DO_NOT_REPORT@github.com/Randspringer90/SchachTurnierManager.git', 'https://github.com/Other/SchachTurnierManager', 'https://github.com/Randspringer90/SchachTurnierManager.git\nother']) {
  test('noncanonical remote is rejected', () => assert.equal(isCanonicalRemote(url), false));
}

test('real clean checkout: local refs only, no merge or writer claim', () => fixture(root => {
  const before = readFileSync(join(root, '.git/index')); const mtime = statSync(join(root, '.git/index')).mtimeMs;
  const report = inspectLocalState(root);
  assert.equal(report.status, 'NO_VISIBLE_CHANGES'); assert.equal(report.complete, true);
  assert.equal(report.branchState, 'DEVELOPMENT'); assert.deepEqual(report.aheadBehind, { ahead: 0, behind: 0 });
  assert.equal(report.mergeAuthorized, false); assert.equal(report.remoteObservation, 'LOCAL_TRACKING_REFS_ONLY');
  assert.equal(report.activeWriters, 'NOT_DETERMINED'); assert.equal(report.contentChangesDuringRead, 'NOT_DETERMINED');
  assert.deepEqual(readFileSync(join(root, '.git/index')), before); assert.equal(statSync(join(root, '.git/index')).mtimeMs, mtime);
}));
test('staged and unstaged changes are both retained, no filenames/content leaked', () => fixture(root => {
  writeFileSync(join(root, 'source.txt'), 'staged\n'); git(root, 'add', 'source.txt');
  writeFileSync(join(root, 'source.txt'), 'unstaged\n');
  writeFileSync(join(root, 'DO_NOT_REPORT.secret'), 'DO_NOT_REPORT');
  const report = inspectLocalState(root);
  assert.equal(report.status, 'LOCAL_CHANGES_PRESENT');
  assert.equal(report.changes.staged, 1); assert.equal(report.changes.unstaged, 1); assert.equal(report.changes.untracked, 1);
  assert.ok(!JSON.stringify(report).includes('DO_NOT_REPORT')); assert.ok(!JSON.stringify(report).includes(root));
  assert.equal(readFileSync(join(root, 'source.txt'), 'utf8'), 'unstaged\n');
}));
test('real rename consumes the source record only once', () => fixture(root => {
  git(root, 'mv', 'source.txt', 'renamed.txt'); const report = inspectLocalState(root);
  assert.equal(report.changes.entries, 1); assert.equal(report.changes.renamed, 1);
}));
test('ahead/behind is measured against tracking ref without fetch', () => fixture(root => {
  writeFileSync(join(root, 'source.txt'), 'new\n'); git(root, 'add', 'source.txt'); git(root, 'commit', '-m', 'next');
  assert.deepEqual(inspectLocalState(root).aheadBehind, { ahead: 1, behind: 0 });
}));
test('missing tracking reference is unknown, never zero divergence', () => fixture(root => {
  git(root, 'update-ref', '-d', 'refs/remotes/origin/development');
  assert.equal(inspectLocalState(root).aheadBehind, null);
}));
test('detached head is explicit', () => fixture(root => {
  git(root, 'checkout', '--detach'); assert.equal(inspectLocalState(root).branchState, 'DETACHED');
}));
test('unborn branch is observable without fabricated commit', () => fixture(root => {
  git(root, 'checkout', '--orphan', 'unborn'); const report = inspectLocalState(root);
  assert.equal(report.complete, true); assert.equal(report.head, null); assert.equal(report.aheadBehind, null);
}));
test('existing rebase metadata is preserved and reported', () => fixture(root => {
  mkdirSync(join(root, '.git/rebase-merge')); const report = inspectLocalState(root);
  assert.equal(report.status, 'INTEGRATION_IN_PROGRESS'); assert.equal(report.operations.rebaseMerge, true);
  assert.ok(statSync(join(root, '.git/rebase-merge')).isDirectory());
}));
test('linked worktrees work with their own metadata paths', () => fixture((root, outer) => {
  const linked = join(outer, 'linked'); git(root, 'worktree', 'add', '-b', 'review', linked);
  const report = inspectLocalState(linked); assert.equal(report.complete, true);
  assert.equal(report.worktreeCount, 2); assert.equal(report.branchState, 'OTHER_BRANCH');
}));
test('push restriction is reported, not removed', () => fixture(root => {
  git(root, 'config', 'remote.origin.pushurl', 'disabled-by-owner');
  assert.equal(inspectLocalState(root).pushTarget, 'NONCANONICAL_OR_MULTIPLE');
  assert.equal(git(root, 'config', '--get', 'remote.origin.pushurl'), 'disabled-by-owner');
}));
test('wrong repository fails closed without disclosing remote value', () => fixture(root => {
  git(root, 'remote', 'set-url', 'origin', 'https://example.invalid/DO_NOT_REPORT'); const report = inspectLocalState(root);
  assert.equal(report.complete, false); assert.deepEqual(report.errors, ['REPOSITORY_IDENTITY_MISMATCH']);
  assert.ok(!JSON.stringify(report).includes('DO_NOT_REPORT'));
}));
test('subdirectory is not silently used as repository root', () => fixture(root => {
  mkdirSync(join(root, 'nested')); assert.deepEqual(inspectLocalState(join(root, 'nested')).errors, ['ROOT_REQUIRED']);
}));
test('Windows drive-letter casing still identifies the same canonical root', { skip: process.platform !== 'win32' }, () => fixture(root => {
  const lowerDriveRoot = root[0].toLowerCase() + root.slice(1);
  const report = inspectLocalState(lowerDriveRoot);
  assert.equal(report.complete, true);
  assert.equal(report.status, 'NO_VISIBLE_CHANGES');
  assert.deepEqual(report.errors, []);
}));
test('Windows drive-letter normalization still rejects a nested directory', { skip: process.platform !== 'win32' }, () => fixture(root => {
  mkdirSync(join(root, 'nested'));
  const lowerDriveRoot = root[0].toLowerCase() + root.slice(1);
  assert.deepEqual(inspectLocalState(join(lowerDriveRoot, 'nested')).errors, ['ROOT_REQUIRED']);
}));
test('nonexistent root reports only a bounded error code', () => {
  const report = inspectLocalState(join(tmpdir(), 'nonexistent-stm-fixture-173947'));
  assert.equal(report.complete, false); assert.deepEqual(report.errors, ['LOCAL_INSPECTION_FAILED']);
});
test('inherited GIT_DIR cannot route the query to a different repository', () => fixture(root => {
  const old = process.env.GIT_DIR; process.env.GIT_DIR = join(root, 'wrong');
  try { assert.equal(inspectLocalState(root).complete, true); }
  finally { if (old === undefined) delete process.env.GIT_DIR; else process.env.GIT_DIR = old; }
}));
test('filesystem-monitor hook is not executed', () => fixture(root => {
  git(root, 'config', 'core.fsmonitor', 'an-intentionally-missing-fixture-command');
  assert.equal(inspectLocalState(root).complete, true);
  assert.equal(git(root, 'config', 'core.fsmonitor'), 'an-intentionally-missing-fixture-command');
}));
test('CLI produces JSON stdout and progress stderr', () => fixture(root => {
  const result = spawnSync(process.execPath, [script, root], { encoding: 'utf8', windowsHide: true });
  assert.equal(result.status, 0); assert.equal(JSON.parse(result.stdout).status, 'NO_VISIBLE_CHANGES');
  assert.match(result.stderr, /LocalIntegration/); assert.ok(!result.stderr.includes(root));
}));
test('CLI misuse and failed read have nonzero exit', () => {
  let err = ''; assert.equal(main(['--push'], { write() {} }, { write: x => { err += x; } }), 2);
  assert.match(err, /Usage/);
  const result = spawnSync(process.execPath, [script, resolve(tmpdir(), 'nonexistent-stm-fixture-173947')], { encoding: 'utf8', windowsHide: true });
  assert.equal(result.status, 2); assert.equal(JSON.parse(result.stdout).complete, false);
});

test('newline and whitespace are not accepted inside a remote URL', () => {
  for (const suffix of ['\n', ' ', '\t', '\r']) assert.equal(isCanonicalRemote('https://github.com/Randspringer90/SchachTurnierManager.git' + suffix), false);
});
test('insteadOf rewriting is considered for repository identity', () => fixture(root => {
  git(root, 'config', 'url.https://example.invalid/.insteadOf', 'https://github.com/');
  assert.deepEqual(inspectLocalState(root).errors, ['REPOSITORY_IDENTITY_MISMATCH']);
}));
test('pushInsteadOf is observed and left unchanged', () => fixture(root => {
  git(root, 'config', 'url.https://example.invalid/.pushInsteadOf', 'https://github.com/');
  assert.equal(inspectLocalState(root).pushTarget, 'NONCANONICAL_OR_MULTIPLE');
  assert.equal(git(root, 'config', 'url.https://example.invalid/.pushInsteadOf'), 'https://github.com/');
}));
test('real merge conflict and MERGE_HEAD survive inspection', () => fixture(root => {
  git(root, 'checkout', '-b', 'other'); writeFileSync(join(root, 'source.txt'), 'other\n'); git(root, 'add', 'source.txt'); git(root, 'commit', '-m', 'other');
  git(root, 'checkout', 'development'); writeFileSync(join(root, 'source.txt'), 'ours\n'); git(root, 'add', 'source.txt'); git(root, 'commit', '-m', 'ours');
  assert.throws(() => git(root, 'merge', 'other'));
  const before = readFileSync(join(root, '.git/MERGE_HEAD')); const report = inspectLocalState(root);
  assert.equal(report.status, 'INTEGRATION_IN_PROGRESS'); assert.equal(report.changes.conflicts, 1); assert.equal(report.operations.merge, true);
  assert.deepEqual(readFileSync(join(root, '.git/MERGE_HEAD')), before);
}));
test('ignored files are not reported as untracked or read', () => fixture(root => {
  writeFileSync(join(root, '.gitignore'), '*.secret\n'); git(root, 'add', '.gitignore'); git(root, 'commit', '-m', 'ignore');
  writeFileSync(join(root, 'DO_NOT_REPORT.secret'), 'DO_NOT_REPORT');
  const report = inspectLocalState(root); assert.equal(report.changes.untracked, 0); assert.ok(!JSON.stringify(report).includes('DO_NOT_REPORT'));
}));
test('index lock is observed without removal', () => fixture(root => {
  writeFileSync(join(root, '.git/index.lock'), 'fixture-owned-lock'); const report = inspectLocalState(root);
  assert.equal(report.operations.indexLock, true); assert.equal(report.status, 'INTEGRATION_IN_PROGRESS');
  assert.equal(readFileSync(join(root, '.git/index.lock'), 'utf8'), 'fixture-owned-lock');
}));

test('active clean filter is identified without executing or disabling it', () => fixture(root => {
  writeFileSync(join(root, '.gitattributes'), '*.txt filter=synthetic\n');
  git(root, 'config', 'filter.synthetic.clean', 'nonexistent-synthetic-filter');
  writeFileSync(join(root, 'source.txt'), 'newvalue\n');
  const report = inspectLocalState(root);
  assert.equal(report.complete, false); assert.deepEqual(report.errors, ['GIT_FILTER_REQUIRES_REVIEW']);
  assert.equal(git(root, 'config', 'filter.synthetic.clean'), 'nonexistent-synthetic-filter');
}));
test('unused configured filters do not block a normal metadata inspection', () => fixture(root => {
  git(root, 'config', 'filter.unused.process', 'nonexistent-synthetic-filter');
  const report = inspectLocalState(root);
  assert.equal(report.complete, true); assert.equal(report.submoduleWorkingTrees, 'NONE_PRESENT');
}));
// PR #75 review: submodule changes are hidden by --ignore-submodules=all, so a
// checkout with gitlinks must never be reported as clean.
test('gitlinks prevent a clean verdict', () => fixture(root => {
  const head = git(root, 'rev-parse', 'HEAD');
  git(root, 'update-index', '--add', '--cacheinfo', `160000,${head},vendored`);
  git(root, 'commit', '-m', 'gitlink'); git(root, 'update-ref', 'refs/remotes/origin/development', 'HEAD');
  const report = inspectLocalState(root);
  assert.equal(report.submoduleWorkingTrees, 'PRESENT_NOT_INSPECTED');
  assert.equal(report.status, 'SUBMODULES_NOT_INSPECTED'); assert.equal(report.complete, false);
}));
test('no status-derived fingerprint is published', () => fixture(root => {
  writeFileSync(join(root, 'source.txt'), 'changed\n');
  const report = inspectLocalState(root);
  assert.equal(report.status, 'LOCAL_CHANGES_PRESENT');
  assert.ok(!('statusFingerprint' in report));
}));
