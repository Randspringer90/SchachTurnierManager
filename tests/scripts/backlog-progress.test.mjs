import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, readFileSync, rmSync, statSync, symlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { parseBacklog, measureBacklog, MAX_BACKLOG_BYTES } from '../../scripts/lib/BacklogProgress.mjs';
import { main } from '../../scripts/Measure-BacklogProgress.mjs';

const header = '## Übersicht\n\n| ID | Titel | Prio | Status | Kategorie | Ziel-Bearb. | Issue | Release |\n|---|---|---|---|---|---|---|---|\n';
const row = (id = 'STM-UX-001', status = 'Done', release = 'v1.0.0', title = 'Synthetic') => `| ${id} | ${title} | P2 | ${status} | ui | owner | - | ${release} |\n`;
const doc = (...rows) => header + rows.join('');
const good = doc(row());
const code = expected => error => error?.code === expected;

for (const status of ['Backlog', 'Ready', 'In Progress', 'In Review', 'Blocked', 'Done', 'Deferred']) {
  test(`status ${status} is not fractional progress`, () => {
    const summary = measureBacklog(doc(row('STM-UX-001', status))).summary;
    assert.equal(summary.total, 1); assert.equal(summary.donePercent, status === 'Done' ? 100 : 0);
    assert.equal(summary.byStatus[status], 1);
  });
}
for (const newline of ['\n', '\r\n', '\r']) test(`newline ${JSON.stringify(newline)}`, () => assert.equal(measureBacklog(good.replaceAll('\n', newline)).summary.done, 1));
for (const [label, text, expected] of [
  ['missing overview', row(), 'OVERVIEW_NOT_UNIQUE'],
  ['double overview', good + '\n' + good, 'OVERVIEW_NOT_UNIQUE'],
  ['empty overview', header, 'EMPTY_OVERVIEW'],
  ['header mismatch', good.replace('Ziel-Bearb.', 'Owner'), 'INVALID_HEADER'],
  ['separator mismatch', good.replace('|---|', '|--|'), 'INVALID_SEPARATOR'],
  ['duplicate id', doc(row(), row()), 'DUPLICATE_ID'],
  ['duplicate across releases', doc(row(), row('STM-UX-001', 'Done', 'post-1.0')), 'DUPLICATE_ID'],
  ['status typo', doc(row('STM-UX-001', 'Finished')), 'INVALID_STATUS'],
  ['bad id', doc(row('STM-UX-01')), 'INVALID_ID'],
  ['bad priority', good.replace('P2', 'P9'), 'INVALID_PRIORITY'],
  ['unknown release', doc(row('STM-UX-001', 'Done', 'soon')), 'INVALID_RELEASE'],
  ['extra cell', doc(row('STM-UX-001', 'Done', 'v1.0.0', 'A | B')), 'INVALID_COLUMN_COUNT'],
  ['missing cell', good.replace('| ui ', ''), 'INVALID_COLUMN_COUNT'],
  ['nonrow after header', good + 'Unexpected task\n', 'INVALID_TABLE_ROW'],
  ['unclosed fence', good + '```\n', 'UNCLOSED_FENCE'],
  ['oversize text', 'x'.repeat(MAX_BACKLOG_BYTES + 1), 'INPUT_TOO_LARGE'],
  ['bad input', null, 'INVALID_INPUT'],
]) test(label, () => assert.throws(() => measureBacklog(text), code(expected)));

test('escaped pipes and inline code do not shift columns', () => assert.equal(measureBacklog(doc(row('STM-UX-001', 'Done', 'v1.0.0', '`A\\|B`'))).summary.total, 1));
test('suffix task ids supported', () => assert.equal(parseBacklog(doc(row('STM-AI-001b')))[0].id, 'STM-AI-001b'));
test('detailed repeat after overview not counted', () => assert.equal(measureBacklog(good + '\n---\n## Ready\n' + row()).summary.total, 1));
test('examples outside overview ignored', () => assert.equal(measureBacklog('```md\n' + good + '```\n' + good).summary.total, 1));
test('tilde examples ignored', () => assert.equal(measureBacklog('~~~~md\n' + good + '~~~~\n' + good).summary.total, 1));
test('BOM preserved in source identity but not header matching', () => assert.equal(measureBacklog('\uFEFF' + good).sourceSha256, createHash('sha256').update('\uFEFF' + good).digest('hex')));
test('done percentage is equal weight and roundable', () => {
  const result = measureBacklog(doc(row(), row('STM-UX-002', 'In Review'), row('STM-UX-003', 'Deferred')));
  assert.equal(result.summary.donePercent, 33.33); assert.equal(result.summary.remaining, 2);
  assert.deepEqual(result.remainingIds, ['STM-UX-002', 'STM-UX-003']);
});
test('release-specific denominator excludes future scope', () => {
  const source = doc(row(), row('STM-UX-002', 'Backlog', 'post-1.0'));
  assert.equal(measureBacklog(source).summary.donePercent, 50);
  assert.equal(measureBacklog(source, 'v1.0.0').summary.donePercent, 100);
  assert.equal(measureBacklog(source, 'post-1.0').summary.donePercent, 0);
});
test('unknown release filter rejected', () => assert.throws(() => measureBacklog(good, 'soon'), code('INVALID_RELEASE_FILTER')));
test('empty selected release not fake 100 percent', () => assert.throws(() => measureBacklog(good, 'v9.0.0'), code('RELEASE_NOT_FOUND')));
test('titles/links are not emitted and no merge approval inferred', () => {
  const result = measureBacklog(doc(row('STM-UX-001', 'Done', 'v1.0.0', 'PRIVATE-SYNTHETIC-TITLE')));
  assert.equal(JSON.stringify(result).includes('PRIVATE-SYNTHETIC-TITLE'), false);
  assert.equal(result.mergeAuthorized, false); assert.equal(result.verification.ci, 'NOT_CHECKED');
});
test('deterministic result without clock or environment', () => assert.deepEqual(measureBacklog(good), measureBacklog(good)));

function fileTest(callback) {
  const directory = mkdtempSync(join(tmpdir(), 'stm-progress-'));
  try { callback(directory); } finally { rmSync(directory, { recursive: true, force: true }); }
}
const cli = fileURLToPath(new URL('../../scripts/Measure-BacklogProgress.mjs', import.meta.url));
function runMain(args) {
  let stdout = ''; let stderr = '';
  const exit = main(args, { write: value => { stdout += value; } }, { write: value => { stderr += value; } });
  return { exit, stdout, stderr };
}
test('CLI reads real file, emits valid JSON, does not modify input', () => fileTest(directory => {
  const path = join(directory, 'backlog.md'); writeFileSync(path, good); const before = statSync(path).mtimeMs;
  const run = spawnSync(process.execPath, [cli, path, '--release', 'v1.0.0'], { encoding: 'utf8' });
  assert.equal(run.status, 0, run.stderr); assert.equal(JSON.parse(run.stdout).summary.done, 1);
  assert.equal(statSync(path).mtimeMs, before); assert.equal(readFileSync(path, 'utf8'), good);
}));
test('CLI redacts unreadable input paths', () => {
  const run = runMain(['/not-here/PRIVATE-SYNTHETIC-PATH.md']);
  assert.equal(run.exit, 2); assert.equal(run.stdout, ''); assert.equal(run.stderr.includes('PRIVATE-SYNTHETIC'), false);
});
for (const args of [['--bad'], ['--release'], ['--release', '--bad'], ['a', 'b'], ['--release', 'v1.0.0', '--release', 'v1.0.0']]) {
  test(`CLI invalid args ${args.join(' ')}`, () => assert.equal(JSON.parse(runMain(args).stderr).code, 'INVALID_ARGUMENTS'));
}
test('CLI rejects invalid UTF-8 without emitting input', () => fileTest(directory => {
  const path = join(directory, 'bad.md'); writeFileSync(path, Buffer.from([0xff, 0xfe]));
  assert.equal(JSON.parse(runMain([path]).stderr).code, 'INPUT_UNREADABLE');
}));
test('CLI rejects directory', () => fileTest(directory => assert.equal(runMain([directory]).exit, 2)));
test('CLI rejects oversized file', () => fileTest(directory => {
  const path = join(directory, 'big.md'); writeFileSync(path, 'x'.repeat(MAX_BACKLOG_BYTES + 1));
  assert.equal(JSON.parse(runMain([path]).stderr).code, 'INPUT_TOO_LARGE');
}));
test('CLI reports parse errors without success output', () => fileTest(directory => {
  const path = join(directory, 'bad.md'); writeFileSync(path, doc(row(), row()));
  const run = runMain([path]); assert.equal(run.stdout, ''); assert.equal(JSON.parse(run.stderr).code, 'DUPLICATE_ID');
}));
test('CLI executes through a real directory symlink or Windows junction', () => fileTest(directory => {
  const alias = join(directory, 'alias');
  const scripts = fileURLToPath(new URL('../../scripts/', import.meta.url));
  symlinkSync(scripts, alias, process.platform === 'win32' ? 'junction' : 'dir');
  const path = join(directory, 'ok.md'); writeFileSync(path, good);
  const run = spawnSync(process.execPath, [join(alias, 'Measure-BacklogProgress.mjs'), path], { encoding: 'utf8' });
  assert.equal(run.status, 0, run.stderr); assert.equal(JSON.parse(run.stdout).summary.total, 1);
}));
