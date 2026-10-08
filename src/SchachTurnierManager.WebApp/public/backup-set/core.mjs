import { ReadError, requireId } from '../workflow-common/read-api.mjs';
export const MAX_ITEMS = 10, MAX_ITEM_BYTES = 2 * 1024 * 1024, MAX_TOTAL_BYTES = 10 * 1024 * 1024, MAX_ARCHIVE_BYTES = 24 * 1024 * 1024;
const utf8 = new TextEncoder();
const fail = code => { throw new ReadError(code); };
const abort = signal => { if (signal?.aborted) fail('CANCELLED'); };
function cryptoProvider(subtle) { if (typeof subtle?.digest !== 'function') fail('CRYPTO_UNAVAILABLE'); return subtle; }
async function digest(text, subtle) {
  const result = await subtle.digest('SHA-256', utf8.encode(text));
  if (!(result instanceof ArrayBuffer) || result.byteLength !== 32) fail('INVALID_DIGEST');
  return Array.from(new Uint8Array(result), byte => byte.toString(16).padStart(2, '0')).join('');
}
function nativeHeader(text, expectedId) {
  if (typeof text !== 'string' || utf8.encode(text).byteLength > MAX_ITEM_BYTES) fail('INVALID_SNAPSHOT');
  let value; try { value = JSON.parse(text.replace(/^\uFEFF/, '')); } catch { fail('INVALID_SNAPSHOT'); }
  const id = requireId(value?.id);
  if (id !== expectedId || typeof value?.name !== 'string' || value.name.length > 300 ||
      !Array.isArray(value.players) || !Array.isArray(value.rounds) || !value.settings || typeof value.settings !== 'object' || Array.isArray(value.settings)) fail('INVALID_SNAPSHOT');
  return { id, name: value.name, players: value.players.length, rounds: value.rounds.length };
}
/** A batch is all-or-nothing. Content is stored as original JSON text, not reserialized objects. */
export async function collectBackupSet(ids, api, { signal, onProgress, subtle = globalThis.crypto?.subtle, now = Date.now } = {}) {
  if (!Array.isArray(ids) || ids.length < 1 || ids.length > MAX_ITEMS) fail('INVALID_SELECTION');
  const selected = ids.map(requireId); if (new Set(selected).size !== selected.length) fail('DUPLICATE_ID');
  cryptoProvider(subtle); abort(signal);
  const items = []; let total = 0;
  const startedAt = new Date(now()).toISOString();
  for (const id of selected) {
    abort(signal);
    const document = await api.document(`/api/tournaments/${id}/export/json`, { signal, maxBytes: MAX_ITEM_BYTES });
    abort(signal);
    const header = nativeHeader(document.text, id), bytes = utf8.encode(document.text).byteLength;
    total += bytes; if (total > MAX_TOTAL_BYTES) fail('TOTAL_TOO_LARGE');
    const sha256 = await digest(document.text, subtle); abort(signal);
    items.push({ ...header, bytes, sha256, content: document.text, capturedAt: new Date(now()).toISOString() });
    onProgress?.({ completed: items.length, total: selected.length });
  }
  abort(signal);
  const archive = { format: 'stm-backup-set-1', startedAt, completedAt: new Date(now()).toISOString(), atomicSnapshot: false, items };
  const text = JSON.stringify(archive);
  if (utf8.encode(text).byteLength > MAX_ARCHIVE_BYTES) fail('ARCHIVE_TOO_LARGE');
  return { text, count: items.length, totalBytes: total };
}
function exactFields(value, keys) {
  return value !== null && typeof value === 'object' && !Array.isArray(value) &&
    Object.keys(value).length === keys.length && keys.every(key => Object.hasOwn(value, key));
}
function timestamp(value) { return typeof value === 'string' && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(value) && Number.isFinite(Date.parse(value)); }
/** Validate the whole container before exposing any individual download. Not a provenance proof. */
export async function readBackupSet(file, { signal, onProgress, subtle = globalThis.crypto?.subtle } = {}) {
  if (!file || !Number.isSafeInteger(file.size) || file.size < 1 || file.size > MAX_ARCHIVE_BYTES || typeof file.arrayBuffer !== 'function') fail('INVALID_FILE');
  cryptoProvider(subtle); abort(signal);
  const size = file.size, buffer = await file.arrayBuffer(); abort(signal);
  if (!(buffer instanceof ArrayBuffer) || buffer.byteLength !== size || file.size !== size) fail('FILE_CHANGED');
  let archive;
  try { archive = JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(buffer)); } catch { fail('INVALID_ARCHIVE'); }
  if (!exactFields(archive, ['format','startedAt','completedAt','atomicSnapshot','items']) || archive.format !== 'stm-backup-set-1' || archive.atomicSnapshot !== false ||
      !timestamp(archive.startedAt) || !timestamp(archive.completedAt) || !Array.isArray(archive.items) || archive.items.length < 1 || archive.items.length > MAX_ITEMS) fail('INVALID_ARCHIVE');
  const ids = new Set(), result = []; let total = 0;
  for (const item of archive.items) {
    abort(signal);
    if (!exactFields(item, ['id','name','players','rounds','bytes','sha256','content','capturedAt']) || !timestamp(item.capturedAt)) fail('INVALID_ARCHIVE');
    const id = requireId(item.id); if (ids.has(id)) fail('DUPLICATE_ID'); ids.add(id);
    const header = nativeHeader(item.content, id), bytes = utf8.encode(item.content).byteLength;
    total += bytes; if (total > MAX_TOTAL_BYTES) fail('TOTAL_TOO_LARGE');
    if (header.name !== item.name || header.players !== item.players || header.rounds !== item.rounds || bytes !== item.bytes ||
        !/^[0-9a-f]{64}$/.test(item.sha256) || await digest(item.content, subtle) !== item.sha256) fail('CHECKSUM_MISMATCH');
    abort(signal);
    result.push(Object.freeze({ ...header, content: item.content, bytes, capturedAt: item.capturedAt }));
    onProgress?.({ completed: result.length, total: archive.items.length });
  }
  abort(signal);
  return result;
}
