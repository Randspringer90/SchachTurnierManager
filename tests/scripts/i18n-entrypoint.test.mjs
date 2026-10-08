import test from 'node:test';
import assert from 'node:assert/strict';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { pathToFileURL } from 'node:url';
import { isMainModule } from '../../scripts/Test-I18nCatalogs.mjs';
const real = join(tmpdir(), 'stm-entry-real', 'a.mjs');
const alias = join(tmpdir(), 'stm-entry-alias', 'a.mjs');
const url = pathToFileURL(real).href;

test('canonical direct entry executes', () => {
  assert.equal(isMainModule(real, url, value => value), true);
});
test('symlink or junction spelling resolves to same entry', () => {
  const paths = new Map([[alias, real], [real, real]]);
  assert.equal(isMainModule(alias, url, value => paths.get(value)), true);
});
test('importing audit from test or another script does not execute CLI', () => {
  assert.equal(isMainModule(join(tmpdir(), 'tests.mjs'), url, value => value), false);
});
test('missing process entry never touches filesystem', () => {
  assert.equal(isMainModule(undefined, url, () => { throw Error('unexpected'); }), false);
});
