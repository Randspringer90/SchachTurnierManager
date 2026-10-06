import test from 'node:test';
import assert from 'node:assert/strict';
import { loadQr } from './helpers/qr-runtime.mjs';

const native = loadQr();
const fallback = loadQr(null);
const same = qr => JSON.stringify(qr.modules);
const namedError = name => error => error?.name === name;

for (const [label, input] of [['null', null], ['undefined', undefined], ['number', 7],
  ['boolean', true], ['array', ['x']], ['object', {}], ['boxed string', new String('x')]]) {
  test(`reject non-string input: ${label}`, () => {
    assert.throws(() => native.encodeText(input), namedError('TypeError'));
  });
}
for (const level of [-1, 4, 1.5, NaN, Infinity, -Infinity, '1', null, {}]) {
  test(`reject invalid ECC: ${String(level)}`, () => {
    assert.throws(() => native.encodeText('test', level), namedError('RangeError'));
  });
}
for (const text of ['', 'plain ascii', 'https://example.test/turnier/1', '\u00e4\u00f1\u00e9', '\u4e2d\u6587',
  '\u{1f600}', '\u0000x\r\n', '\ud800', '\udc00', '\ud800x\udc00', '\ud800\ud800\udc00', '\ufeffx']) {
  test(`UTF-8 parity: ${JSON.stringify(text)}`, () => {
    assert.equal(same(fallback.encodeText(text)), same(native.encodeText(text)));
  });
}
for (const [label, x, y] of [['fractional x', 1.5, 1], ['fractional y', 1, 1.5],
  ['NaN', NaN, 0], ['infinite', 0, Infinity], ['negative', -1, 1], ['outside', 21, 0],
  ['string', '1', 1], ['null', null, 1], ['undefined', 0, undefined]]) {
  test(`getModule returns false for ${label}`, () => {
    assert.equal(native.encodeText('').getModule(x, y), false);
  });
}
test('valid coordinate access equals the matrix and is always boolean', () => {
  const qr = native.encodeText('https://example.test');
  for (let y = 0; y < qr.size; y++) for (let x = 0; x < qr.size; x++) {
    assert.equal(qr.getModule(x, y), qr.modules[y][x]);
    assert.equal(typeof qr.getModule(x, y), 'boolean');
  }
});
for (const [ecl, max] of [[0, 2953], [1, 2331], [2, 1663], [3, 1273]]) {
  test(`ECC ${ecl}: exact byte capacity and one byte overflow`, () => {
    assert.equal(native.encodeText('x'.repeat(max), ecl).size, 177);
    assert.throws(() => native.encodeText('x'.repeat(max + 1), ecl), namedError('RangeError'));
    const unicode = '\u00e9'.repeat(Math.floor(max / 2)) + 'x'.repeat(max % 2);
    assert.equal(native.encodeText(unicode, ecl).size, 177);
    assert.throws(() => native.encodeText(unicode + 'x', ecl), namedError('RangeError'));
  });
}
test('reject impossible input length before allocating an encoded buffer', () => {
  let calls = 0;
  class RecordingEncoder { encode() { calls++; throw new Error('encoder must not run'); } }
  assert.throws(() => loadQr(RecordingEncoder).encodeText('x'.repeat(100000)), namedError('RangeError'));
  assert.equal(calls, 0);
});
test('do not invoke implicit string conversions', () => {
  let calls = 0;
  const input = { toString() { calls++; return 'private text'; } };
  assert.throws(() => native.encodeText(input), namedError('TypeError'));
  assert.equal(calls, 0);
});
test('default ECC remains Medium and normal output is deterministic', () => {
  assert.equal(same(native.encodeText('test')), same(native.encodeText('test', native.Ecl.Medium)));
  assert.equal(same(native.encodeText('test')), same(native.encodeText('test')));
});
