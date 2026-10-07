/** A bounded viewer for stm-audit-bundle-1 JSONL, not an integrity validator. */
export const MAX_BYTES = 5 * 1024 * 1024;
const MAX_LINES = 10000, MAX_EVENTS = 5000;
const fail = code => { throw new Error(code); };
const own = (value, key) => Object.prototype.hasOwnProperty.call(value, key);
const object = value => value !== null && typeof value === 'object' && !Array.isArray(value);
const severities = ['Info', 'Warning', 'Critical'];
function field(value, key) { return own(value, key) ? value[key] : undefined; }
function boundedText(value, limit) {
  if (typeof value !== 'string' || value.length > limit) fail('INVALID_EVENT');
  return value;
}
function numberOrNull(value) {
  if (value == null) return null;
  if (!Number.isSafeInteger(value) || value < 1) fail('INVALID_EVENT');
  return value;
}
function readEvent(value, ids) {
  if (!object(value)) fail('INVALID_EVENT');
  const id = boundedText(field(value, 'id'), 36).toLowerCase();
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(id)) fail('INVALID_EVENT');
  if (ids.has(id)) fail('DUPLICATE_ID');
  ids.add(id);
  const action = boundedText(field(value, 'action'), 80);
  if (!/^[A-Za-z][A-Za-z0-9]*$/.test(action)) fail('INVALID_EVENT');
  const createdAt = boundedText(field(value, 'createdAt'), 64);
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,7})?(?:Z|[+-]\d{2}:\d{2})$/.test(createdAt) || !Number.isFinite(Date.parse(createdAt))) fail('INVALID_EVENT');
  const severity = field(value, 'severity');
  if (!severities.includes(severity)) fail('INVALID_EVENT');
  return {
    id, action, severity,
    createdAt,
    round: numberOrNull(field(value, 'roundNumber')),
    board: numberOrNull(field(value, 'boardNumber')),
    summary: boundedText(field(value, 'summary') ?? '', 4000),
  };
}
export function readAuditJsonl(bytes) {
  if (!(bytes instanceof Uint8Array) || bytes.length === 0 || bytes.length > MAX_BYTES) fail('INVALID_SIZE');
  let text;
  try { text = new TextDecoder('utf-8', { fatal: true }).decode(bytes); } catch { fail('INVALID_UTF8'); }
  const lines = text.split('\n');
  if (lines.length > MAX_LINES) fail('TOO_MANY_LINES');
  let manifest = null, skippedRecords = 0, unknownRecords = 0;
  const events = [], ids = new Set();
  for (const raw of lines) {
    const line = raw.trim();
    if (!line) continue;
    let record;
    try { record = JSON.parse(line); } catch { fail('INVALID_JSONL'); }
    if (!object(record)) fail('INVALID_JSONL');
    const type = field(record, 'type');
    if (!manifest) {
      if (type !== 'manifest' || field(record, 'schemaVersion') !== 'stm-audit-bundle-1' || field(record, 'format') !== 'jsonl') fail('UNSUPPORTED_BUNDLE');
      const count = field(record, 'auditEntryCount');
      if (!Number.isSafeInteger(count) || count < 0 || count > MAX_EVENTS) fail('INVALID_COUNT');
      manifest = { count };
    } else if (type === 'manifest') {
      fail('DUPLICATE_MANIFEST');
    } else if (type === 'audit-event') {
      if (events.length >= MAX_EVENTS) fail('TOO_MANY_EVENTS');
      events.push(readEvent(field(record, 'entry'), ids));
    } else if (type === 'tournament-snapshot' || type === 'pairing-forensics') {
      skippedRecords++;
    } else {
      unknownRecords++;
    }
  }
  if (!manifest) fail('UNSUPPORTED_BUNDLE');
  if (events.length !== manifest.count) fail('COUNT_MISMATCH');
  return { events, skippedRecords, unknownRecords };
}
export function filterAudit(events, options = {}) {
  if (!Array.isArray(events) || events.length > MAX_EVENTS) fail('INVALID_EVENTS');
  const severity = options.severity ?? '', action = options.action ?? '', round = options.round ?? '';
  if (severity && !severities.includes(severity)) fail('INVALID_FILTER');
  if (typeof action !== 'string' || action.length > 80 || typeof round !== 'string' || (round && !/^[1-9][0-9]{0,8}$/.test(round))) fail('INVALID_FILTER');
  const limit = options.limit ?? 200, offset = options.offset ?? 0;
  if (!Number.isSafeInteger(limit) || limit < 1 || limit > 200 || !Number.isSafeInteger(offset) || offset < 0) fail('INVALID_FILTER');
  const matches = events.filter(event => (!severity || event.severity === severity) && (!action || event.action === action) && (!round || event.round === Number(round)));
  // Original export order is intentional; timestamp strings are not reinterpreted.
  return { total: matches.length, offset, entries: matches.slice(offset, offset + limit), hasMore: offset + limit < matches.length };
}
