import test from 'node:test';
import assert from 'node:assert/strict';
import { detectLanguage, selectLanguage, translateText } from '../../src/SchachTurnierManager.WebApp/src/i18n/core.ts';
const supported = ['de', 'en', 'es', 'pt', 'zh', 'ar'];
const select = (stored, preferred = []) => selectLanguage(supported, 'de', stored, preferred);

for (const [stored, preferred, expected] of [
  ['es', ['en-US'], 'es'], [null, ['en-US'], 'en'], ['invalid', ['zz-ZZ', 'es-AR'], 'es'],
  ['', ['zz', 'pt-BR'], 'pt'], ['DE', ['en'], 'de'], [' es-MX ', [], 'es'],
  [undefined, ['zh-Hant-TW'], 'zh'], [null, ['ar_EG'], 'ar'], [null, [], 'de'],
  [null, ['zz-ZZ'], 'de'], ['constructor', [], 'de'], [42, [null, 'en'], 'en'],
  ['english', [], 'de'], ['es<script>', ['en'], 'en'], ['es--AR', [], 'de'],
  ['es-', [], 'de'], [null, ['EN-us'], 'en'], ['__proto__', ['pt'], 'pt'],
  // BCP-47 extensions and private use use one-character singletons (u, t, x).
  [null, ['en-US-u-ca-gregory'], 'en'], [null, ['es-x-private'], 'es'], [null, ['pt-BR-t-de'], 'pt'],
  ['es-u-', [], 'de'], [null, ['en-u-toolongsubtag'], 'de'],
]) {
  test(`language ${JSON.stringify([stored, preferred])}`, () => assert.equal(select(stored, preferred), expected));
}
test('invalid fallback is explicit', () => assert.throws(() => selectLanguage(['en'], 'de', null)));
test('storage denial still uses browser order', () => assert.equal(detectLanguage(supported, 'de', () => { throw Error(); }, () => ['zz', 'es']), 'es'));
test('navigator denial keeps stored choice', () => assert.equal(detectLanguage(supported, 'de', () => 'en', () => { throw Error(); }), 'en'));
test('no platform globals needed', () => assert.equal(detectLanguage(supported, 'de', () => { throw Error(); }, () => { throw Error(); }), 'de'));
test('non-array preference response ignored', () => assert.equal(detectLanguage(supported, 'de', () => null, () => 'en'), 'de'));

for (const replacement of ['$&', '$$', "$'", '$`', '${value}', '{other}', '=1+2', '<b>Synthetic</b>', 'Synthetic', 0, -2, 1.5]) {
  test(`literal replacement ${replacement}`, () => assert.equal(translateText('k', [{ k: 'Hello {name} / {name}' }], { name: replacement }), `Hello ${replacement} / ${replacement}`));
}
test('inserted placeholders are not interpolated recursively', () => assert.equal(translateText('k', [{ k: '{a} {b}' }], { a: '{b}', b: 'B' }), '{b} B'));
test('parameter insertion order does not change output', () => {
  assert.equal(translateText('k', [{ k: '{a} {b}' }], { a: '{b}', b: 'B' }), translateText('k', [{ k: '{a} {b}' }], { b: 'B', a: '{b}' }));
});
test('current then English then German fallback', () => {
  assert.equal(translateText('k', [{ k: 'current' }, { k: 'English' }, { k: 'Deutsch' }]), 'current');
  assert.equal(translateText('k', [{}, { k: 'English' }, { k: 'Deutsch' }]), 'English');
  assert.equal(translateText('k', [{}, {}, { k: 'Deutsch' }]), 'Deutsch');
});
test('missing key remains visible', () => assert.equal(translateText('missing.key', [{}]), 'missing.key'));
test('empty translations fall through', () => assert.equal(translateText('k', [{ k: ' ' }, { k: '' }, { k: 'D' }]), 'D'));
test('non-string translations fall through', () => assert.equal(translateText('k', [{ k: 42 }, { k: 'D' }]), 'D'));
test('prototype is not a translation catalogue', () => assert.equal(translateText('k', [Object.create({ k: 'wrong' }), { k: 'D' }]), 'D'));
test('prototype is not a parameter value', () => assert.equal(translateText('k', [{ k: '{x}' }], Object.create({ x: 'wrong' })), '{x}'));
test('unknown placeholders survive', () => assert.equal(translateText('k', [{ k: '{x} {y}' }], { x: 'X' }), 'X {y}'));
test('catalogues and params remain unchanged', () => {
  const dictionary = Object.freeze({ k: '{x}' }); const params = Object.freeze({ x: '$&' });
  assert.equal(translateText('k', [dictionary], params), '$&'); assert.equal(dictionary.k, '{x}');
});
test('null-prototype parameters work', () => assert.equal(translateText('k', [{ k: '{x}' }], Object.assign(Object.create(null), { x: 0 })), '0'));
test('non-text runtime parameters are not coerced', () => assert.equal(translateText('k', [{ k: '{x}' }], { x: { toString() { throw Error(); } } }), '{x}'));
test('literal regression is reproducible in former implementation', () => assert.notEqual('Hello {name}'.replaceAll('{name}', '$&'), 'Hello $&'));
