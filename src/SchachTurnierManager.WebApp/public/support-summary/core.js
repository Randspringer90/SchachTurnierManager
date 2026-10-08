/** Count-only support projection, not anonymization or restore validation. */
export const MAX_BYTES = 5 * 1024 * 1024;
const fail = code => { throw Object.assign(new Error(code), { code }); };
const own = (value, key) => Object.prototype.hasOwnProperty.call(value, key);
const isObject = value => value !== null && typeof value === 'object' && !Array.isArray(value);

// Bounded JSON reader rejecting duplicate keys before they can hide a list.
function parseUnique(text) {
  let i = 0, nodes = 0;
  const ws = () => { while (i < text.length && /[ \t\r\n]/.test(text[i])) i++; };
  function string() {
    const start = i++;
    while (i < text.length) {
      const ch = text[i++];
      if (ch === '\\') { i++; continue; }
      if (ch === '"') {
        try { return JSON.parse(text.slice(start, i)); } catch { fail('INVALID_JSON'); }
      }
    }
    fail('INVALID_JSON');
  }
  function value(depth) {
    if (++nodes > 100000 || depth > 32) fail('TOO_COMPLEX');
    ws();
    const ch = text[i];
    if (ch === '"') return string();
    if (ch === '{') {
      i++; ws(); const out = Object.create(null);
      if (text[i] === '}') { i++; return out; }
      for (;;) {
        ws(); if (text[i] !== '"') fail('INVALID_JSON');
        const key = string();
        if (own(out, key)) fail('DUPLICATE_KEY');
        ws(); if (text[i++] !== ':') fail('INVALID_JSON');
        out[key] = value(depth + 1); ws(); const separator = text[i++];
        if (separator === '}') return out;
        if (separator !== ',') fail('INVALID_JSON');
      }
    }
    if (ch === '[') {
      i++; ws(); const out = [];
      if (text[i] === ']') { i++; return out; }
      for (;;) {
        out.push(value(depth + 1)); ws(); const separator = text[i++];
        if (separator === ']') return out;
        if (separator !== ',') fail('INVALID_JSON');
      }
    }
    for (const [token, result] of [['null', null], ['true', true], ['false', false]]) {
      if (text.startsWith(token, i)) { i += token.length; return result; }
    }
    const number = text.slice(i).match(/^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?/);
    if (number) { i += number[0].length; return Number(number[0]); }
    fail('INVALID_JSON');
  }
  const result = value(0); ws(); if (i !== text.length) fail('INVALID_JSON'); return result;
}
function field(record, name, required = true) {
  const pascal = name[0].toUpperCase() + name.slice(1);
  if (own(record, name) && own(record, pascal)) fail('AMBIGUOUS_FIELD');
  if (own(record, name)) return record[name];
  if (own(record, pascal)) return record[pascal];
  if (required) fail('INVALID_BACKUP');
  return undefined;
}
function list(value) {
  if (!Array.isArray(value) || value.length > 5000 || value.some(item => !isObject(item))) fail('INVALID_BACKUP');
  return value;
}
function flag(record, name) {
  const value = field(record, name, false);
  if (value !== undefined && typeof value !== 'boolean') fail('INVALID_BACKUP');
  return value === true;
}
export function summarizeBackup(bytes) {
  if (!(bytes instanceof Uint8Array) || !bytes.length || bytes.length > MAX_BYTES) fail('INVALID_SIZE');
  let text;
  try { text = new TextDecoder('utf-8', { fatal: true }).decode(bytes); } catch { fail('INVALID_UTF8'); }
  const root = parseUnique(text);
  if (!isObject(root) || typeof field(root, 'id') !== 'string' || typeof field(root, 'name') !== 'string' || !isObject(field(root, 'settings'))) fail('INVALID_BACKUP');
  const players = list(field(root, 'players')), rounds = list(field(root, 'rounds'));
  const journal = field(root, 'auditJournal', false);
  const audit = journal === undefined ? [] : list(journal);
  let pairings = 0, locked = 0, verified = 0;
  for (const round of rounds) {
    pairings += list(field(round, 'pairings')).length;
    if (pairings > 100000) fail('TOO_COMPLEX');
    if (flag(round, 'isLocked')) locked++;
    if (flag(round, 'isVerified')) verified++;
  }
  return {
    schema: 'stm-support-counts-1',
    counts: { players: players.length, rounds: rounds.length, pairings, auditEntries: audit.length, lockedRounds: locked, verifiedRounds: verified },
    exclusions: ['names', 'identifiers', 'dates', 'ratings', 'freeText', 'settingsValues', 'paths', 'sourceHashes'],
    assurance: 'COUNT_ONLY_NOT_ANONYMITY_OR_RESTORE_PROOF',
  };
}
export async function summarizeFile(file) {
  if (!file || !Number.isSafeInteger(file.size) || file.size <= 0 || file.size > MAX_BYTES || typeof file.arrayBuffer !== 'function') fail('INVALID_SIZE');
  const bytes = new Uint8Array(await file.arrayBuffer());
  if (bytes.length !== file.size) fail('FILE_CHANGED');
  return summarizeBackup(bytes);
}
