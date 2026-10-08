/** Read-only byte fingerprint. A matching hash is not provenance or restore validation. */
export const MAX_BYTES = 5 * 1024 * 1024;
export function parseExpectedHash(value) {
  if (typeof value !== 'string') throw new Error('INVALID_HASH');
  const normalized = value.trim();
  if (!normalized) return null;
  if (!/^[0-9a-fA-F]{64}$/.test(normalized)) throw new Error('INVALID_HASH');
  return normalized.toLowerCase();
}
export async function hashBytes(bytes, subtle = globalThis.crypto?.subtle) {
  if (!(bytes instanceof Uint8Array)) throw new Error('INVALID_BYTES');
  if (bytes.byteLength > MAX_BYTES) throw new Error('TOO_LARGE');
  if (!subtle || typeof subtle.digest !== 'function') throw new Error('CRYPTO_UNAVAILABLE');
  const digest = await subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(digest), byte => byte.toString(16).padStart(2, '0')).join('');
}
export async function fingerprintFile(file, expected = '', subtle = globalThis.crypto?.subtle) {
  const wanted = parseExpectedHash(expected);
  if (!file || !Number.isSafeInteger(file.size) || file.size < 0 || typeof file.arrayBuffer !== 'function') throw new Error('FILE_REQUIRED');
  if (file.size > MAX_BYTES) throw new Error('TOO_LARGE');
  const bytes = new Uint8Array(await file.arrayBuffer());
  if (bytes.byteLength !== file.size) throw new Error('FILE_CHANGED');
  const hash = await hashBytes(bytes, subtle);
  return { hash, bytes: bytes.byteLength, comparison: wanted === null ? 'NOT_REQUESTED' : wanted === hash ? 'MATCH' : 'MISMATCH' };
}
