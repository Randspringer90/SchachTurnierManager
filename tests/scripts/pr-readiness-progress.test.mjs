import test from 'node:test';
import assert from 'node:assert/strict';
import { collectSnapshot } from '../../scripts/lib/PrReadiness.mjs';
import { main } from '../../scripts/Get-PrReadiness.mjs';
const repository = 'example-owner/example-repository';
const head = 'a'.repeat(40);
const get = route => {
  if (route.endsWith('git/ref/heads/development')) return { object: { sha: head } };
  if (route.includes('/pulls?')) return [{ number: 1 }];
  if (route.endsWith('/pulls/1')) return { head: { sha: head } };
  if (route.includes('/check-runs?')) return { total_count: 0, check_runs: [] };
  return [];
};

test('collector reports discovery, bounded PR progress and completion without identifiers', () => {
  const events = [];
  collectSnapshot(repository, get, { onProgress: event => events.push(event) });
  assert.deepEqual(events, [
    { phase: 'discovery', current: 0, total: 0 },
    { phase: 'pull-request', current: 1, total: 1 },
    { phase: 'complete', current: 1, total: 1 }
  ]);
  assert.ok(!JSON.stringify(events).includes(repository));
});

test('CLI separates progress from parseable report JSON', () => {
  let report = ''; let progress = '';
  const code = main(['--repo', repository], { get, write: text => { report += text; }, progress: text => { progress += text; } });
  assert.equal(code, 2);
  assert.equal(JSON.parse(report).mergeAuthorized, false);
  assert.ok(!report.includes('[PrReadiness]'));
  assert.ok(progress.includes('pull-request 1/1'));
  assert.ok(!progress.includes(repository));
});

test('invalid progress callback is rejected before any read', () => {
  let reads = 0;
  assert.throws(() => collectSnapshot(repository, () => { reads++; }, { onProgress: true }), /INVALID_PROGRESS_CALLBACK/);
  assert.equal(reads, 0);
});
