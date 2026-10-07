import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, lstatSync, rmSync } from 'node:fs';
import { dirname, join, resolve, basename } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../../', import.meta.url));
const packagePath = 'io/github/randspringer90/schachturniermanager';
const source = join(root, 'src/SchachTurnierManager.Mobile/android/app/src/main/java', packagePath);

// Compiles/runs only the pure Java contracts, never Gradle/Android/APK or a network probe.
test('native companion URL/origin, health and bounded-reader contracts', { timeout: 60000 }, t => {
  const javaVersion = spawnSync('java', ['-version'], { encoding: 'utf8', windowsHide: true, timeout: 10000 });
  const compilerVersion = spawnSync('javac', ['-version'], { encoding: 'utf8', windowsHide: true, timeout: 10000 });
  if (javaVersion.error?.code === 'ENOENT' || compilerVersion.error?.code === 'ENOENT') {
    t.skip('JDK unavailable: pure Java companion contracts are unverified; Android build/device smoke remains separate.');
    return;
  }
  assert.equal(javaVersion.status, 0, 'Installed Java must be executable.');
  assert.equal(compilerVersion.status, 0, 'Installed Java compiler must be executable.');
  const taskTempRoot = resolve(root, 'tmp');
  mkdirSync(taskTempRoot, { recursive: true });
  assert.equal(lstatSync(taskTempRoot).isSymbolicLink(), false, 'Contract temp root must not be a symlink/junction.');
  const taskTemp = mkdtempSync(join(taskTempRoot, 'companion-contract-'));
  try {
    const compile = spawnSync('javac', ['-encoding', 'UTF-8', '-source', '8', '-target', '8',
      '-d', taskTemp, join(source, 'CompanionPolicy.java'), join(source, 'HealthReplyReader.java'),
      join(root, 'tests/SchachTurnierManager.Mobile.Tests/CompanionContract.java')],
      { encoding: 'utf8', windowsHide: true, timeout: 20000 });
    assert.equal(compile.status, 0, 'Pure companion Java contracts must compile: ' + (compile.stderr ?? '').slice(0, 1500));
    const run = spawnSync('java', ['-cp', taskTemp, 'io.github.randspringer90.schachturniermanager.CompanionContract'],
      { encoding: 'utf8', windowsHide: true, timeout: 20000 });
    assert.equal(run.status, 0, 'Pure companion Java contracts must pass.');
    assert.match(run.stdout, /^COMPANION_CONTRACT_PASS assertions=[1-9][0-9]*\s*$/);
    t.diagnostic(run.stdout.trim());
  } finally {
    const checkedPath = resolve(taskTemp);
    assert.equal(dirname(checkedPath), taskTempRoot, 'Cleanup path must remain inside the test temp root.');
    assert.equal(basename(checkedPath).startsWith('companion-contract-'), true);
    assert.equal(lstatSync(checkedPath).isSymbolicLink(), false);
    rmSync(checkedPath, { recursive: true });
  }
});
