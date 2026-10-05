/** Sequential byte identity checks only; no restore decision or deletion. */
export const MAX_FILES = 20;
export const MAX_FILE_BYTES = 5 * 1024 * 1024;
export const MAX_TOTAL_BYTES = 50 * 1024 * 1024;
const fail = code => { throw new Error(code); };
const checkAbort = signal => { if (signal?.aborted) fail('CANCELLED'); };

export async function findIdenticalBackups(files, options = {}) {
  if (!Array.isArray(files) || files.length < 2 || files.length > MAX_FILES) fail('FILE_COUNT');
  const selected = files.map(file => ({ file, size: file?.size }));
  let totalBytes = 0;
  for (const { file, size } of selected) {
    if (!file || !Number.isSafeInteger(size) || size < 0 || typeof file.arrayBuffer !== 'function') fail('INVALID_FILE');
    if (size > MAX_FILE_BYTES) fail('FILE_TOO_LARGE');
    totalBytes += size;
  }
  if (totalBytes > MAX_TOTAL_BYTES) fail('TOTAL_TOO_LARGE');
  checkAbort(options.signal);
  const subtle = options.subtle === undefined ? globalThis.crypto?.subtle : options.subtle;
  if (!subtle || typeof subtle.digest !== 'function') fail('CRYPTO_UNAVAILABLE');
  const entries = [], byHash = new Map();
  for (let i = 0; i < selected.length; i++) {
    checkAbort(options.signal);
    const { file, size } = selected[i];
    if (file.size !== size) fail('FILE_CHANGED');
    const buffer = await file.arrayBuffer();
    checkAbort(options.signal);
    if (!(buffer instanceof ArrayBuffer) || buffer.byteLength !== size) fail('FILE_CHANGED');
    const digest = await subtle.digest('SHA-256', buffer);
    checkAbort(options.signal);
    if (!(digest instanceof ArrayBuffer) || digest.byteLength !== 32) fail('INVALID_DIGEST');
    const hash = Array.from(new Uint8Array(digest), b => b.toString(16).padStart(2, '0')).join('');
    const item = { index: i + 1, bytes: size, hash };
    entries.push(item);
    const key = size + ':' + hash;
    if (!byHash.has(key)) byHash.set(key, []);
    byHash.get(key).push(item.index);
    options.onProgress?.({ completed: i + 1, total: selected.length });
  }
  checkAbort(options.signal);
  return { entries, totalBytes, identicalGroups: [...byHash.values()].filter(group => group.length > 1) };
}
