import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

// POSIX named pipes do not exist as filesystem FIFOs on Windows.
test('CLI rejects a POSIX FIFO before opening it', { skip: process.platform === 'win32' }, () => {
  const directory = mkdtempSync(join(tmpdir(), 'stm-progress-fifo-'));
  try {
    const path = join(directory, 'pipe');
    const cli = fileURLToPath(new URL('../../scripts/Measure-BacklogProgress.mjs', import.meta.url));
    const setup = spawnSync('mkfifo', [path], { encoding: 'utf8' });
    assert.equal(setup.status, 0, setup.stderr);
    const run = spawnSync(process.execPath, [cli, path], { encoding: 'utf8', timeout: 2000 });
    assert.equal(run.status, 2); assert.equal(run.stdout, '');
    assert.equal(JSON.parse(run.stderr).code, 'NOT_A_REGULAR_FILE');
  } finally { rmSync(directory, { recursive: true, force: true }); }
});
