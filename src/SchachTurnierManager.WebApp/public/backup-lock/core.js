/** Versioned local backup envelope using Web Crypto, not custom cryptography. */
export const MAX_PLAIN_BYTES = 24 * 1024 * 1024;
export const HEADER_BYTES = 44;
export const ITERATIONS = 600000;
const MAGIC = new TextEncoder().encode('STMENC01');
export class BackupCipherError extends Error {
  constructor(code) { super(code); this.name = 'BackupCipherError'; this.code = code; }
}
const fail = code => { throw new BackupCipherError(code); };
const cancelled = signal => { if (signal?.aborted) fail('CANCELLED'); };
function provider(value) {
  if (!value?.subtle || typeof value.getRandomValues !== 'function' ||
      ['importKey', 'deriveKey', 'encrypt', 'decrypt'].some(key => typeof value.subtle[key] !== 'function')) fail('CRYPTO_UNAVAILABLE');
  return value;
}
function passwordBytes(value) {
  if (typeof value !== 'string' || value.length > 1024 || !value.isWellFormed() ||
      Array.from(value).length < 12 || !value.trim()) fail('INVALID_PASSPHRASE');
  const bytes = new TextEncoder().encode(value);
  if (bytes.length > 1024) { bytes.fill(0); fail('INVALID_PASSPHRASE'); }
  return bytes;
}
function byteInput(value, maximum) {
  if (!(value instanceof Uint8Array) || !(value.buffer instanceof ArrayBuffer) || value.length < 1 || value.length > maximum) fail('INVALID_SIZE');
  return new Uint8Array(value);
}
async function keyFor(phrase, salt, usage, crypto, signal) {
  cancelled(signal);
  const bytes = passwordBytes(phrase);
  let material;
  try { material = await crypto.subtle.importKey('raw', bytes, 'PBKDF2', false, ['deriveKey']); }
  finally { bytes.fill(0); }
  cancelled(signal);
  const key = await crypto.subtle.deriveKey({ name: 'PBKDF2', salt, iterations: ITERATIONS, hash: 'SHA-256' },
    material, { name: 'AES-GCM', length: 256 }, false, [usage]);
  cancelled(signal);
  return key;
}
function headerLength(bytes) {
  if (bytes.length < HEADER_BYTES + 17 || !MAGIC.every((value, i) => bytes[i] === value)) fail('UNSUPPORTED_ENVELOPE');
  const view = new DataView(bytes.buffer, bytes.byteOffset, HEADER_BYTES);
  // Reject attacker-controlled work factors BEFORE running the KDF.
  if (view.getUint32(8, false) !== ITERATIONS) fail('UNSUPPORTED_ENVELOPE');
  const length = view.getUint32(40, false);
  if (length < 1 || length > MAX_PLAIN_BYTES || bytes.length !== HEADER_BYTES + length + 16) fail('INVALID_ENVELOPE');
  return length;
}
export async function encryptBackup(value, phrase, { crypto = globalThis.crypto, signal } = {}) {
  const input = byteInput(value, MAX_PLAIN_BYTES);
  try {
    cancelled(signal); provider(crypto);
    const header = new Uint8Array(HEADER_BYTES);
    header.set(MAGIC);
    const view = new DataView(header.buffer);
    view.setUint32(8, ITERATIONS, false);
    view.setUint32(40, input.length, false);
    crypto.getRandomValues(header.subarray(12, 28));
    crypto.getRandomValues(header.subarray(28, 40));
    const key = await keyFor(phrase, header.slice(12, 28), 'encrypt', crypto, signal);
    const encrypted = await crypto.subtle.encrypt({ name: 'AES-GCM', iv: header.slice(28, 40),
      additionalData: header, tagLength: 128 }, key, input);
    cancelled(signal);
    if (!(encrypted instanceof ArrayBuffer) || encrypted.byteLength !== input.length + 16) fail('ENCRYPTION_FAILED');
    const result = new Uint8Array(HEADER_BYTES + encrypted.byteLength);
    result.set(header); result.set(new Uint8Array(encrypted), HEADER_BYTES);
    return result;
  } catch (error) {
    if (error instanceof BackupCipherError) throw error;
    fail('ENCRYPTION_FAILED');
  } finally { input.fill(0); }
}
export async function decryptBackup(value, phrase, { crypto = globalThis.crypto, signal } = {}) {
  const input = byteInput(value, MAX_PLAIN_BYTES + HEADER_BYTES + 16);
  let plaintext;
  try {
    const length = headerLength(input);
    cancelled(signal); provider(crypto);
    const header = input.slice(0, HEADER_BYTES);
    const key = await keyFor(phrase, header.slice(12, 28), 'decrypt', crypto, signal);
    plaintext = new Uint8Array(await crypto.subtle.decrypt({ name: 'AES-GCM', iv: header.slice(28, 40),
      additionalData: header, tagLength: 128 }, key, input.subarray(HEADER_BYTES)));
    cancelled(signal);
    if (plaintext.length !== length) fail('INVALID_ENVELOPE');
    return plaintext;
  } catch (error) {
    plaintext?.fill(0);
    if (error instanceof BackupCipherError) throw error;
    // Password mistakes and authentication failures share one neutral error.
    fail('DECRYPTION_FAILED');
  } finally { input.fill(0); }
}
