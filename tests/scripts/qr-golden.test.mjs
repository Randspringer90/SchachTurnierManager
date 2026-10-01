import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { loadQr } from './helpers/qr-runtime.mjs';

const fixture = JSON.parse(readFileSync(new URL('./fixtures/qr-golden.json', import.meta.url), 'utf8'));
const { encodeText } = loadQr();
const formatLevel = [1, 0, 3, 2];
const payload = n => Array.from({ length: n }, (_, i) => String.fromCharCode(33 + (i * 17) % 90)).join('');
const digest = matrix => createHash('sha256').update(matrix.flat().map(b => b ? '1' : '0').join('')).digest('base64');

function formatWord(level, mask) {
  const data = (formatLevel[level] << 3) | mask;
  let remainder = data;
  for (let i = 0; i < 10; i++) remainder = (remainder << 1) ^ ((remainder >>> 9) * 0x537);
  return ((data << 10) | remainder) ^ 0x5412;
}
function formatLocations(size) {
  const a = [], b = [];
  for (let i = 0; i < 15; i++) {
    a.push(i <= 5 ? [8, i] : i === 6 ? [8, 7] : i === 7 ? [8, 8] : i === 8 ? [7, 8] : [14 - i, 8]);
    b.push(i < 8 ? [size - 1 - i, 8] : [8, size - 15 + i]);
  }
  return [a, b];
}
function masked(mask, x, y) {
  switch (mask) {
    case 0: return (x + y) % 2 === 0;
    case 1: return y % 2 === 0;
    case 2: return x % 3 === 0;
    case 3: return (x + y) % 3 === 0;
    case 4: return (Math.floor(y / 2) + Math.floor(x / 3)) % 2 === 0;
    case 5: return (x * y) % 2 + (x * y) % 3 === 0;
    case 6: return ((x * y) % 2 + (x * y) % 3) % 2 === 0;
    case 7: return ((x + y) % 2 + (x * y) % 3) % 2 === 0;
    default: throw new Error('Invalid format mask.');
  }
}
function normalizeMask(qr, version, level) {
  const n = version * 4 + 17;
  assert.equal(qr.size, n);
  assert.equal(qr.modules.length, n);
  assert.ok(qr.modules.every(row => row.length === n && row.every(b => typeof b === 'boolean')));
  const coords = formatLocations(n);
  const words = coords.map(points => points.reduce((word, [x, y], i) => word | (Number(qr.modules[y][x]) << i), 0));
  assert.equal(words[0], words[1], 'Duplicated format fields disagree.');
  const mask = Array.from({ length: 8 }, (_, i) => i).find(m => formatWord(level, m) === words[0]);
  assert.notEqual(mask, undefined, 'Format ECC/BCH is invalid.');
  const reserved = Array.from({ length: n }, () => Array(n).fill(false));
  function rectangle(x, y, w, h) {
    for (let yy = y; yy < y + h; yy++) for (let xx = x; xx < x + w; xx++) reserved[yy][xx] = true;
  }
  rectangle(0, 0, 9, 9); rectangle(n - 8, 0, 8, 9); rectangle(0, n - 8, 9, 8);
  rectangle(6, 0, 1, n); rectangle(0, 6, n, 1);
  const centers = fixture.alignmentCenters[version - 1];
  for (let i = 0; i < centers.length; i++) for (let j = 0; j < centers.length; j++) {
    if ((i === 0 && j === 0) || (i === 0 && j === centers.length - 1) || (i === centers.length - 1 && j === 0)) continue;
    rectangle(centers[i] - 2, centers[j] - 2, 5, 5);
  }
  if (version >= 7) { rectangle(n - 11, 0, 3, 6); rectangle(0, n - 11, 6, 3); }
  const normalized = qr.modules.map((row, y) => row.map((b, x) => reserved[y][x] ? b :
    Boolean(Number(b) ^ Number(masked(mask, x, y)) ^ Number(masked(0, x, y)))));
  const zeroWord = formatWord(level, 0);
  for (const points of coords) points.forEach(([x, y], i) => { normalized[y][x] = ((zeroWord >>> i) & 1) !== 0; });
  return normalized;
}

test('fixture covers every version/ECC pair exactly once', () => {
  assert.equal(fixture.schema, 1); assert.equal(fixture.vectors.length, 160);
  assert.equal(new Set(fixture.vectors.map(([v, e]) => `${v}/${e}`)).size, 160);
  for (let v = 1; v <= 40; v++) for (let e = 0; e < 4; e++) {
    assert.ok(fixture.vectors.some(row => row[0] === v && row[1] === e));
  }
});
for (const [version, level, length, expected] of fixture.vectors) {
  test(`reference matrix version ${version}, ECC ${level}, ${length} bytes`, () => {
    const qr = encodeText(payload(length), level);
    assert.equal(digest(normalizeMask(qr, version, level)), expected);
  });
}
test('oracle comparison detects a changed data module', () => {
  const [v, e, length, expected] = fixture.vectors[0]; const qr = encodeText(payload(length), e);
  qr.modules[qr.size - 1][qr.size - 1] = !qr.modules[qr.size - 1][qr.size - 1];
  assert.notEqual(digest(normalizeMask(qr, v, e)), expected);
});
test('oracle comparison detects a changed finder module', () => {
  const [v, e, length, expected] = fixture.vectors[0]; const qr = encodeText(payload(length), e);
  qr.modules[0][0] = !qr.modules[0][0];
  assert.notEqual(digest(normalizeMask(qr, v, e)), expected);
});
test('oracle comparison rejects disagreeing format copies', () => {
  const [v, e, length] = fixture.vectors[0]; const qr = encodeText(payload(length), e);
  qr.modules[0][8] = !qr.modules[0][8];
  assert.throws(() => normalizeMask(qr, v, e), /format fields/);
});
