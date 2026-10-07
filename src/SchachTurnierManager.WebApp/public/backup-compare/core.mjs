/** Bounded, non-executing JSON comparison. Not an import or restore validator. */
export const MAX_BYTES = 5 * 1024 * 1024;
const MAX_NODES = 100000, MAX_DEPTH = 32, MAX_ITEMS = 5000, MAX_DETAILS = 200;
class NumberToken { constructor(text) { this.text = text; } }
const fail = code => { throw new Error(code); };
const own = (object, key) => Object.prototype.hasOwnProperty.call(object, key);
const object = value => value !== null && typeof value === 'object' && !Array.isArray(value) && !(value instanceof NumberToken);

// Preserve number tokens instead of silently rounding large integers/precise decimals.
// JSON.parse is used only on one already delimited string token, never on code.
function parseJson(text) {
  let position = 0, nodes = 0;
  const white = () => { while (/[\x20\t\r\n]/.test(text[position] ?? '') && position < text.length) position++; };
  function string() {
    const start = position++;
    while (position < text.length) {
      const ch = text[position++];
      if (ch === '\\') { position++; continue; }
      if (ch === '"') {
        try { return JSON.parse(text.slice(start, position)); } catch { fail('INVALID_JSON'); }
      }
    }
    fail('INVALID_JSON');
  }
  function value(depth) {
    if (depth > MAX_DEPTH || ++nodes > MAX_NODES) fail('TOO_COMPLEX');
    white(); const ch = text[position];
    if (ch === '"') return string();
    if (ch === '{') {
      position++; white(); const result = Object.create(null);
      if (text[position] === '}') { position++; return result; }
      for (;;) {
        white(); if (text[position] !== '"') fail('INVALID_JSON');
        const key = string(); if (own(result, key)) fail('DUPLICATE_KEY');
        white(); if (text[position++] !== ':') fail('INVALID_JSON');
        result[key] = value(depth + 1); white(); const separator = text[position++];
        if (separator === '}') return result;
        if (separator !== ',') fail('INVALID_JSON');
      }
    }
    if (ch === '[') {
      position++; white(); const result = [];
      if (text[position] === ']') { position++; return result; }
      for (;;) {
        result.push(value(depth + 1)); white(); const separator = text[position++];
        if (separator === ']') return result;
        if (separator !== ',') fail('INVALID_JSON');
      }
    }
    for (const [word, result] of [['true', true], ['false', false], ['null', null]]) {
      if (text.startsWith(word, position)) { position += word.length; return result; }
    }
    const match = text.slice(position).match(/^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?/);
    if (match) { position += match[0].length; return new NumberToken(match[0]); }
    fail('INVALID_JSON');
  }
  const result = value(0); white(); if (position !== text.length) fail('INVALID_JSON');
  return result;
}
function field(record, camel, required = true) {
  const pascal = camel[0].toUpperCase() + camel.slice(1);
  if (own(record, camel) && own(record, pascal)) fail('AMBIGUOUS_FIELD');
  const key = own(record, camel) ? camel : pascal;
  if (!own(record, key) && required) fail('INVALID_BACKUP');
  return record[key];
}
function identifier(value) {
  if (typeof value !== 'string' || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value) || /^0{8}-0{4}-0{4}-0{4}-0{12}$/.test(value)) fail('INVALID_ID');
  return value.toLowerCase();
}
function roundNumber(value) {
  if (!(value instanceof NumberToken)) fail('INVALID_ROUND');
  const n = Number(value.text);
  if (!Number.isSafeInteger(n) || n < 1) fail('INVALID_ROUND');
  return String(n);
}
function keyed(items, key) {
  if (!Array.isArray(items) || items.length > MAX_ITEMS) fail('INVALID_COLLECTION');
  const result = new Map();
  for (const item of items) {
    if (!object(item)) fail('INVALID_BACKUP');
    const id = key === 'roundNumber' ? roundNumber(field(item, key)) : identifier(field(item, key));
    if (result.has(id)) fail('DUPLICATE_ID');
    result.set(id, item);
  }
  return result;
}
function canonical(value) {
  if (value instanceof NumberToken) return 'N' + value.text;
  if (Array.isArray(value)) return '[' + value.map(canonical).join(',') + ']';
  if (object(value)) return '{' + Object.keys(value).sort().map(key => JSON.stringify(key) + ':' + canonical(value[key])).join(',') + '}';
  return JSON.stringify(value);
}
export function readSnapshot(bytes) {
  if (!(bytes instanceof Uint8Array)) fail('INVALID_BYTES');
  if (!bytes.length || bytes.length > MAX_BYTES) fail('INVALID_SIZE');
  let text;
  try { text = new TextDecoder('utf-8', { fatal: true }).decode(bytes); } catch { fail('INVALID_UTF8'); }
  const root = parseJson(text);
  if (!object(root)) fail('INVALID_BACKUP');
  const id = identifier(field(root, 'id'));
  if (typeof field(root, 'name') !== 'string' || !object(field(root, 'settings'))) fail('INVALID_BACKUP');
  const players = keyed(field(root, 'players'), 'id');
  const rounds = keyed(field(root, 'rounds'), 'roundNumber');
  const auditValue = field(root, 'auditJournal', false);
  const audit = keyed(auditValue === undefined ? [] : auditValue, 'id');
  const metadata = Object.create(null);
  for (const key of Object.keys(root)) if (!['players', 'Players', 'rounds', 'Rounds', 'auditJournal', 'AuditJournal'].includes(key)) metadata[key] = root[key];
  return { id, players, rounds, audit, metadata };
}
function delta(before, after) {
  const result = { before: before.size, after: after.size, added: 0, removed: 0, changed: 0, details: [], omitted: 0 };
  for (const id of [...new Set([...before.keys(), ...after.keys()])].sort()) {
    const kind = !before.has(id) ? 'added' : !after.has(id) ? 'removed' : canonical(before.get(id)) !== canonical(after.get(id)) ? 'changed' : null;
    if (kind) {
      result[kind]++;
      if (result.details.length < MAX_DETAILS) result.details.push({ id, kind }); else result.omitted++;
    }
  }
  return result;
}
export function compareBackupBytes(beforeBytes, afterBytes) {
  const before = readSnapshot(beforeBytes), after = readSnapshot(afterBytes);
  if (before.id !== after.id) fail('DIFFERENT_TOURNAMENT');
  const players = delta(before.players, after.players), rounds = delta(before.rounds, after.rounds), audit = delta(before.audit, after.audit);
  const metadataChanged = canonical(before.metadata) !== canonical(after.metadata);
  const different = metadataChanged || [players, rounds, audit].some(group => group.added + group.removed + group.changed > 0);
  return { sameComparedContent: !different, metadataChanged, players, rounds, audit };
}
export async function compareBackupFiles(before, after) {
  for (const file of [before, after]) {
    if (!file || !Number.isSafeInteger(file.size) || file.size <= 0 || file.size > MAX_BYTES || typeof file.arrayBuffer !== 'function') fail('INVALID_SIZE');
  }
  const a = new Uint8Array(await before.arrayBuffer());
  if (a.byteLength !== before.size) fail('FILE_CHANGED');
  const b = new Uint8Array(await after.arrayBuffer());
  if (b.byteLength !== after.size) fail('FILE_CHANGED');
  return compareBackupBytes(a, b);
}
