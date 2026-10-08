import test from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { mkdtempSync, writeFileSync, mkdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { parseCatalog, auditCatalogs, placeholders } from '../../scripts/lib/I18nCatalogAudit.mjs';
import { readCatalogs, runAudit } from '../../scripts/Test-I18nCatalogs.mjs';
const ts = createRequire(new URL('../../src/SchachTurnierManager.WebApp/package.json', import.meta.url))('typescript');
const parse = (text, locale = 'de') => parseCatalog(text, locale, ts);
const catalog = entries => new Map(Object.entries(entries));
const collection = values => new Map(Object.entries(values).map(([locale, entries]) => [locale, catalog(entries)]));

for (const text of [
  "export const de = { 'app.title': 'Synthetic' };",
  "export const de = { 'app.title': 'Synthetic' } as const;",
  "export const de = ({ 'app.title': 'Synthetic' });",
  "export const de = { 'app.title': `Synthetic` };",
  "export const de: Record<string, string> = { 'app.title': 'Synthetic' };",
  "export const de = { 'app.title': 'Synthetic' } satisfies Record<string, string>;",
  "/* comment */ export const de = { 'app.title': 'Synthetic', }; // comment",
  "import type { Messages } from './types'; export const de = { 'app.title': 'Synthetic' };",
  "export type Messages = string; export const de = { 'app.title': 'Synthetic' };",
  "interface Messages {} export const de = { 'app.title': 'Synthetic' };",
]) {
  test(`literal form ${text.slice(0, 55)}`, () => assert.deepEqual([...parse(text)], [['app.title', 'Synthetic']]));
}
for (const [text, code] of [
  ["export const de = { 'app.title': 'A', 'app.title': 'B' };", 'DUPLICATE_KEY'],
  ["export const de = { 'app.title': 'A', '\\u0061pp.title': 'B' };", 'DUPLICATE_KEY'],
  ["export const de = { ...other };", 'NON_LITERAL_PROPERTY'],
  ["export const de = { ['app.title']: 'A' };", 'NON_LITERAL_PROPERTY'],
  ["export const de = { get title() { return 'A'; } };", 'NON_LITERAL_PROPERTY'],
  ["export const de = { title: 'A' };", 'NON_LITERAL_PROPERTY'],
  ["export const de = { 'app.title': 42 };", 'NON_LITERAL_VALUE'],
  ["export const de = { 'app.title': fn() };", 'NON_LITERAL_VALUE'],
  ["export const de = { 'app.title': `A ${value}` };", 'NON_LITERAL_VALUE'],
  ["export const de = { 'app.title': 'A' + 'B' };", 'NON_LITERAL_VALUE'],
  ["export const de = { 'app.title': 'A' }; doSomething();", 'UNSUPPORTED_STATEMENT'],
  ["import './sideEffect'; export const de = {};", 'UNSUPPORTED_STATEMENT'],
  ["const hidden = 'A'; export const de = {};", 'UNSUPPORTED_STATEMENT'],
  ["export let de = {};", 'UNSUPPORTED_STATEMENT'],
  ["export const de = {}, en = {};", 'UNSUPPORTED_STATEMENT'],
  ["export default {};", 'UNSUPPORTED_STATEMENT'],
  ["export const en = {};", 'INVALID_EXPORT'],
  ["export const de = makeCatalog();", 'NON_LITERAL_CATALOG'],
  ["export const de = { '__proto__': 'A' };", 'INVALID_KEY'],
  ["export const de = { 'bad key': 'A' };", 'INVALID_KEY'],
  ["// no catalogue", 'MISSING_EXPORT'],
  ["export const de = { 'key': 'unterminated };", 'SYNTAX_ERROR'],
]) {
  test(`reject ${code}: ${text.slice(0, 55)}`, () => assert.throws(() => parse(text), error => error.code === code));
}
test('escaped and Unicode strings decoded as values', () => assert.equal(parse("export const de = { 'key': '\\u00E4\\nline' };").get('key'), '\u00e4\nline'));
test('locale name cannot become a path', () => assert.throws(() => parse('anything', '../de'), error => error.code === 'INVALID_LOCALE'));
test('large source rejected before parsing', () => assert.throws(() => parse(' '.repeat(262145)), error => error.code === 'SOURCE_LIMIT'));
test('catalogue code is never executed', () => {
  globalThis.catalogueExecuted = false;
  assert.throws(() => parse("globalThis.catalogueExecuted = true; export const de = {};"));
  assert.equal(globalThis.catalogueExecuted, false); delete globalThis.catalogueExecuted;
});
test('placeholder names sorted and repetitions allowed', () => assert.deepEqual(placeholders('{b} {a} {b}'), ['a', 'b']));
test('complete catalogues pass without printing values', () => {
  const result = auditCatalogs(collection({ de: { key: 'PRIVATE_SAMPLE' }, en: { key: 'Translation' } }));
  assert.equal(result.status, 'PASS'); assert.equal(result.errors, 0); assert.equal(result.baseKeys, 1);
  assert.equal(JSON.stringify(result).includes('PRIVATE_SAMPLE'), false);
});
test('Partial dictionaries remain supported and visible', () => {
  const result = auditCatalogs(collection({ de: { a: 'A', b: 'B' }, en: { a: 'A' } }));
  assert.equal(result.status, 'PARTIAL'); assert.equal(result.valid, true); assert.equal(result.missingTranslations, 1);
  assert.deepEqual(result.catalogs.find(row => row.locale === 'en').missingKeys, ['b']);
});
test('strict completeness blocks missing translations', () => assert.equal(auditCatalogs(collection({ de: { a: 'A' }, en: {} }), { requireComplete: true }).status, 'FAIL'));
test('unknown keys fail rather than disappearing', () => {
  const result = auditCatalogs(collection({ de: { a: 'A' }, en: { a: 'A', typo: 'B' } }));
  assert.equal(result.valid, false); assert.deepEqual(result.catalogs[1].unknownKeys, ['typo']);
});
for (const text of ['', '   ', '\n\t']) {
  test(`empty value ${JSON.stringify(text)} fails`, () => assert.equal(auditCatalogs(collection({ de: { a: 'A' }, en: { a: text } })).valid, false));
}
test('empty base value also fails', () => assert.equal(auditCatalogs(collection({ de: { a: '' } })).valid, false));
for (const translated of ['Hello', 'Hello {wrong}', 'Hello {name} {extra}']) {
  test(`placeholder mismatch ${translated}`, () => {
    const result = auditCatalogs(collection({ de: { a: 'Hello {name}' }, en: { a: translated } }));
    assert.equal(result.valid, false); assert.equal(result.catalogs[1].placeholderErrors.length, 1);
  });
}
test('placeholder order and count may differ between languages', () => assert.equal(auditCatalogs(collection({ de: { a: '{first} {last} {first}' }, en: { a: '{last} {first}' } })).status, 'PASS'));
// PR #72 review: the runtime renders "{{name}}" as "{value}"; brace structure must be exact.
for (const translated of ['Hello {{name}}', 'Hello {name', 'Hello name}', 'Hello {name}}', 'Hello {}', 'Hello { name }']) {
  test(`malformed placeholder syntax ${JSON.stringify(translated)}`, () => {
    const result = auditCatalogs(collection({ de: { a: 'Hallo {name}' }, en: { a: translated } }));
    assert.equal(result.valid, false);
    assert.deepEqual(result.catalogs.find(row => row.locale === 'en').placeholderSyntaxErrors, ['a']);
  });
}
test('malformed base placeholder syntax also fails', () => assert.equal(auditCatalogs(collection({ de: { a: 'Hallo {{name}}' } })).valid, false));
test('no base catalogue never yields a vacuous pass', () => assert.throws(() => auditCatalogs(collection({ en: { a: 'A' } })), error => error.code === 'MISSING_BASE_CATALOG'));
test('empty base catalogue never yields a vacuous pass', () => assert.throws(() => auditCatalogs(collection({ de: {} })), error => error.code === 'MISSING_BASE_CATALOG'));
test('report independent of insertion order', () => {
  assert.deepEqual(auditCatalogs(collection({ en: { b: 'B', a: 'A' }, de: { a: 'A', b: 'B' } })), auditCatalogs(collection({ de: { b: 'B', a: 'A' }, en: { a: 'A', b: 'B' } })));
});
function fixture(action) {
  const directory = mkdtempSync(join(tmpdir(), 'stm-catalog-'));
  try { return action(directory); } finally { rmSync(directory, { recursive: true, force: true }); }
}
test('filesystem corpus parsed without executing modules', () => fixture(directory => {
  writeFileSync(join(directory, 'README.md'), 'ignored');
  writeFileSync(join(directory, 'de.ts'), "export const de = { 'key': 'A' };");
  writeFileSync(join(directory, 'en.ts'), "import type { Messages } from './de'; export const en: Partial<Messages> = { 'key': 'B' };");
  const values = readCatalogs(directory, ts); assert.equal(values.size, 2); assert.equal(auditCatalogs(values).status, 'PASS');
}));
test('every catalogue file beyond de/en is read and audited', () => fixture(directory => {
  writeFileSync(join(directory, 'de.ts'), "export const de = { 'key': 'Hallo {name}' };");
  writeFileSync(join(directory, 'en.ts'), "export const en = { 'key': 'Hello {name}' };");
  writeFileSync(join(directory, 'es.ts'), "export const es = { 'key': 'Hola {{name}}' };");
  const values = readCatalogs(directory, ts); assert.equal(values.size, 3);
  const result = auditCatalogs(values);
  assert.equal(result.valid, false); assert.deepEqual(result.catalogs.find(row => row.locale === 'es').placeholderSyntaxErrors, ['key']);
}));
test('the real WebApp catalogue set (18 languages) is read and has no structural errors', () => {
  const values = readCatalogs(new URL('../../src/SchachTurnierManager.WebApp/src/i18n/locales/', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1'), ts);
  assert.equal(values.size, 18);
  const result = auditCatalogs(values);
  assert.equal(result.catalogCount, 18); assert.equal(result.errors, 0, JSON.stringify(result.catalogs.filter(row => row.placeholderErrors.length || row.placeholderSyntaxErrors?.length || row.unknownKeys.length || row.emptyKeys.length)));
});
test('invalid catalogue filename rejected', () => fixture(directory => {
  writeFileSync(join(directory, 'unknown.ts'), ''); assert.throws(() => readCatalogs(directory, ts), error => error.code === 'INVALID_CATALOG_FILENAME');
}));
test('directory cannot masquerade as catalogue file', () => fixture(directory => {
  mkdirSync(join(directory, 'de.ts')); assert.throws(() => readCatalogs(directory, ts), error => error.code === 'NON_REGULAR_CATALOG');
}));
test('bounded file read', () => fixture(directory => {
  writeFileSync(join(directory, 'de.ts'), ' '.repeat(262145)); assert.throws(() => readCatalogs(directory, ts), error => error.code === 'SOURCE_LIMIT');
}));
test('invalid UTF8 rejected instead of silently replacing characters', () => fixture(directory => {
  writeFileSync(join(directory, 'de.ts'), Buffer.from([0xff])); assert.throws(() => readCatalogs(directory, ts), error => error.code === 'INVALID_UTF8');
}));
test('empty directory still fails base-catalogue gate', () => fixture(directory => {
  assert.throws(() => auditCatalogs(readCatalogs(directory, ts)), error => error.code === 'MISSING_BASE_CATALOG');
}));
function execute(args, load) {
  const stdout = []; const stderr = [];
  const exit = runAudit(args, { load, output: value => stdout.push(value), error: value => stderr.push(value) });
  return { exit, stdout, stderr };
}
const partial = () => ({ catalogs: collection({ de: { key: 'A' }, en: {} }), compilerVersion: ts.version });
test('CLI partial report succeeds but remains PARTIAL', () => {
  const result = execute([], partial); assert.equal(result.exit, 0); assert.equal(JSON.parse(result.stdout[0]).status, 'PARTIAL');
});
test('CLI strict partial report fails', () => assert.equal(execute(['--require-complete'], partial).exit, 1));
test('CLI malformed input returns operational failure', () => {
  const result = execute([], () => { throw Error('sensitive-path-or-credential'); });
  assert.equal(result.exit, 2); assert.deepEqual(result.stdout, []); assert.deepEqual(result.stderr, ['CATALOG_READ_OR_COMPILER_ERROR']);
});
for (const args of [['--unknown'], ['--require-complete', '--require-complete'], ['elsewhere']]) {
  test(`CLI rejects unsupported arguments ${args}`, () => {
    let loaded = false; const result = execute(args, () => { loaded = true; return partial(); });
    assert.equal(result.exit, 2); assert.equal(loaded, false);
  });
}
test('CLI includes actual compiler version', () => assert.equal(JSON.parse(execute([], partial).stdout[0]).compilerVersion, ts.version));
