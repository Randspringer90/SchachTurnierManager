import test from 'node:test';
import assert from 'node:assert/strict';
import { webcrypto, pbkdf2Sync, createCipheriv, createDecipheriv } from 'node:crypto';
import { encryptBackup, decryptBackup, BackupCipherError, MAX_PLAIN_BYTES, HEADER_BYTES, ITERATIONS } from '../../src/SchachTurnierManager.WebApp/public/backup-lock/core.js';
import { installBackupLock } from '../../src/SchachTurnierManager.WebApp/public/backup-lock/ui.js';
import { dom, deferred, blobUrls } from './read-tools-test-dom.mjs';
const phrase = 'Synthetic test passphrase 2026';
const encode = value => new TextEncoder().encode(value);
const payload = encode('\uFEFF{\r\n "name":"Synthetic", "n":9007199254740993, "d":0.10000000000000001\r\n}');
const envelope = await encryptBackup(payload, phrase);

test('exact original bytes survive a real Web Crypto roundtrip', async () => {
  const original = envelope.slice();
  assert.deepEqual(await decryptBackup(envelope, phrase), payload);
  assert.deepEqual(envelope, original);
});
test('envelope binds version, work factor and length without a filename', () => {
  assert.equal(new TextDecoder().decode(envelope.slice(0, 8)), 'STMENC01');
  const view = new DataView(envelope.buffer); assert.equal(view.getUint32(8, false), ITERATIONS);
  assert.equal(view.getUint32(40, false), payload.length); assert.equal(envelope.length, HEADER_BYTES + payload.length + 16);
});
test('Node cipher independently decrypts the produced wire format', () => {
  const key = pbkdf2Sync(phrase, envelope.slice(12, 28), ITERATIONS, 32, 'sha256');
  const decipher = createDecipheriv('aes-256-gcm', key, envelope.slice(28, 40));
  decipher.setAAD(envelope.slice(0, HEADER_BYTES)); decipher.setAuthTag(envelope.slice(-16));
  assert.deepEqual(new Uint8Array(Buffer.concat([decipher.update(envelope.slice(HEADER_BYTES, -16)), decipher.final()])), payload);
});
test('Web Crypto decrypts an independently built Node envelope', async () => {
  const header = envelope.slice(0, HEADER_BYTES); header.fill(7, 12, 28); header.fill(9, 28, 40);
  const key = pbkdf2Sync(phrase, header.slice(12, 28), ITERATIONS, 32, 'sha256');
  const cipher = createCipheriv('aes-256-gcm', key, header.slice(28, 40)); cipher.setAAD(header);
  const result = Buffer.concat([header, cipher.update(payload), cipher.final(), cipher.getAuthTag()]);
  assert.deepEqual(await decryptBackup(new Uint8Array(result), phrase), payload);
});
test('new encryptions do not reuse salt, nonce or ciphertext', async () => {
  const other = await encryptBackup(payload, phrase);
  assert.notDeepEqual(other.slice(12, 28), envelope.slice(12, 28));
  assert.notDeepEqual(other.slice(28, 40), envelope.slice(28, 40)); assert.notDeepEqual(other, envelope);
});
test('wrong password fails without partial plaintext', async () => {
  await assert.rejects(decryptBackup(envelope, phrase + 'x'), error => error.code === 'DECRYPTION_FAILED');
});
for (const [part, index] of [['salt', 12], ['nonce', 28], ['ciphertext', HEADER_BYTES], ['tag', envelope.length - 1]]) {
  test(`tampered ${part} fails authentication`, async () => {
    const bad = envelope.slice(); bad[index] ^= 1;
    await assert.rejects(decryptBackup(bad, phrase), /DECRYPTION_FAILED/);
  });
}
for (const mutate of [x => { x[0] = 0; }, x => { new DataView(x.buffer).setUint32(8, 0xffffffff, false); },
  x => { new DataView(x.buffer).setUint32(40, MAX_PLAIN_BYTES + 1, false); }]) {
  test('malformed header is rejected before any key derivation', async () => {
    const bad = envelope.slice(); mutate(bad); let calls = 0;
    const fake = { getRandomValues() {}, subtle: { importKey() { calls++; }, deriveKey() {}, encrypt() {}, decrypt() {} } };
    await assert.rejects(decryptBackup(bad, phrase, { crypto: fake })); assert.equal(calls, 0);
  });
}
test('appended and truncated ciphertext are rejected', async () => {
  await assert.rejects(decryptBackup(envelope.slice(0, -1), phrase), /INVALID_ENVELOPE/);
  const larger = new Uint8Array(envelope.length + 1); larger.set(envelope);
  await assert.rejects(decryptBackup(larger, phrase), /INVALID_ENVELOPE/);
});
for (const value of [null, 'not bytes', new Uint8Array(), new Uint8Array(MAX_PLAIN_BYTES + 1)]) {
  test('invalid plaintext input is bounded before crypto', async () => { await assert.rejects(encryptBackup(value, phrase), /INVALID_SIZE/); });
}
for (const value of ['', 'short', ' '.repeat(20), 'x'.repeat(1025), '\uD800'.repeat(12), null]) {
  test('invalid passphrase is rejected without normalization', async () => { await assert.rejects(encryptBackup(payload, value), /INVALID_PASSPHRASE/); });
}
test('Unicode and significant outer whitespace are preserved', async () => {
  const p = '  Synthetic \u00dc\u4e2d passphrase  ';
  const encrypted = await encryptBackup(Uint8Array.of(1), p);
  assert.deepEqual(await decryptBackup(encrypted, p), Uint8Array.of(1));
  await assert.rejects(decryptBackup(encrypted, p.trim()), /DECRYPTION_FAILED/);
});
test('subarray boundaries and caller-owned bytes remain intact', async () => {
  const all = Uint8Array.of(9, 1, 2, 3, 9); const original = all.slice();
  const encrypted = await encryptBackup(all.subarray(1, 4), phrase);
  assert.deepEqual(await decryptBackup(encrypted, phrase), Uint8Array.of(1, 2, 3)); assert.deepEqual(all, original);
});
test('absent crypto never falls back to an insecure algorithm', async () => {
  await assert.rejects(encryptBackup(payload, phrase, { crypto: null }), /CRYPTO_UNAVAILABLE/);
});
test('pre-cancellation stops before random generation', async () => {
  const controller = new AbortController(); controller.abort();
  await assert.rejects(encryptBackup(payload, phrase, { signal: controller.signal, crypto: null }), /CANCELLED/);
});
test('cancellation during KDF suppresses further encryption', async () => {
  const controller = new AbortController(); let encrypted = false;
  const crypto = { getRandomValues: a => webcrypto.getRandomValues(a), subtle: {
    importKey: (...a) => webcrypto.subtle.importKey(...a),
    deriveKey: async (...a) => { const key = await webcrypto.subtle.deriveKey(...a); controller.abort(); return key; },
    encrypt: () => { encrypted = true; }, decrypt() {},
  } };
  await assert.rejects(encryptBackup(payload, phrase, { signal: controller.signal, crypto }), /CANCELLED/); assert.equal(encrypted, false);
});
test('derived key is nonextractable and only permits the intended operation', async () => {
  let checked = false;
  const crypto = { getRandomValues: a => webcrypto.getRandomValues(a), subtle: {
    importKey: (...a) => webcrypto.subtle.importKey(...a), deriveKey: (...a) => webcrypto.subtle.deriveKey(...a), decrypt() {},
    encrypt: (algorithm, key, data) => { checked = true; assert.equal(key.extractable, false); assert.deepEqual(key.usages, ['encrypt']); return webcrypto.subtle.encrypt(algorithm, key, data); },
  } };
  await encryptBackup(payload, phrase, { crypto }); assert.equal(checked, true);
});
function setup(operations) {
  const d = dom('backup-lock'), urls = blobUrls(); const view = installBackupLock(d.document, operations, urls);
  d.nodes.file.files = [new File([payload], 'synthetic.json')]; d.nodes.password.value = phrase; d.nodes.confirmation.value = phrase;
  return { ...d, urls, view };
}
test('UI performs a real roundtrip and only prepares a manual download', async () => {
  const d = setup(); await d.nodes.encrypt.fire('click');
  assert.equal(d.urls.active.size, 1); assert.equal(d.nodes.password.value, ''); assert.equal(d.nodes.confirmation.value, '');
  const encrypted = await d.urls.active.values().next().value.arrayBuffer();
  d.nodes.file.files = [new File([encrypted], 'synthetic.stmenc')]; d.nodes.password.value = phrase;
  await d.nodes.decrypt.fire('click');
  assert.equal(d.urls.active.size, 1); const restored = await d.urls.active.values().next().value.arrayBuffer();
  assert.deepEqual(new Uint8Array(restored), payload); assert.equal(d.nodes.download.download, 'wiederhergestellte-sicherung.json'); d.view.dispose();
});
test('password mismatch prevents file access', async () => {
  const d = setup(); let reads = 0; d.nodes.confirmation.value = 'different';
  d.nodes.file.files = [{ size: 1, arrayBuffer() { reads++; throw Error(); } }];
  await d.nodes.encrypt.fire('click'); assert.equal(reads, 0); assert.equal(d.urls.active.size, 0);
});
test('cancel and repeated clicks do not create overlapping crypto operations', async () => {
  const wait = deferred(); let calls = 0, signal;
  const d = setup({ encrypt: (_, __, options) => { calls++; signal = options.signal; return wait.promise; } });
  const run = d.nodes.encrypt.fire('click'); await new Promise(resolve => setImmediate(resolve));
  await d.nodes.cancel.fire('click'); await d.nodes.encrypt.fire('click');
  assert.equal(signal.aborted, true); assert.equal(calls, 1); assert.equal(d.nodes.encrypt.disabled, true);
  wait.resolve(Uint8Array.of(1)); await run; assert.equal(d.urls.active.size, 0); assert.equal(d.nodes.encrypt.disabled, false);
});
test('an input change revokes prior download links', async () => {
  const d = setup({ encrypt: async () => Uint8Array.of(1) }); await d.nodes.encrypt.fire('click');
  await d.nodes.password.fire('input'); assert.equal(d.urls.active.size, 0); assert.equal(d.nodes.download.hidden, true);
});
test('failure does not display raw private errors or leave a download', async () => {
  const d = setup({ encrypt: async () => { throw Error('PRIVATE original error'); } });
  await d.nodes.encrypt.fire('click'); assert.equal(d.nodes.status.textContent.includes('PRIVATE'), false); assert.equal(d.urls.active.size, 0);
});
test('dispose cancels pending reads and removes handlers', async () => {
  const wait = deferred(), d = setup(); d.nodes.file.files = [{ size: 1, arrayBuffer: () => wait.promise }];
  const run = d.nodes.encrypt.fire('click'); d.view.dispose(); d.view.dispose(); wait.resolve(new ArrayBuffer(1)); await run;
  assert.equal(d.urls.active.size, 0); assert.equal(d.nodes.encrypt.disabled, true);
  assert.ok(Object.values(d.nodes).every(node => [...node.listeners.values()].every(set => set.size === 0)));
});
test('HTML disallows network/form submission and uses password controls', () => {
  const { html } = dom('backup-lock'); assert.match(html, /connect-src 'none'/); assert.match(html, /form-action 'none'/);
  assert.equal((html.match(/type="password"/g) ?? []).length, 2); assert.match(html, /role="status"/);
});

test('Node Buffer input remains unchanged across both operations', async () => {
  const original = Buffer.from(payload), saved = Buffer.from(original);
  const encrypted = await encryptBackup(original, phrase);
  assert.deepEqual(original, saved);
  const transport = Buffer.from(encrypted), backup = Buffer.from(transport);
  assert.deepEqual(await decryptBackup(transport, phrase), payload);
  assert.deepEqual(transport, backup);
});
