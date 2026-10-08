/** Offline search of an explicitly selected, unpacked FIDE standard TXT list. */
export const MAX_FILE_BYTES = 256 * 1024 * 1024;
const MAX_ROWS = 2000000;
class RatingFileError extends Error { constructor(code) { super(code); this.code = code; } }
const error = code => new RatingFileError(code);
const normalize = text => text.normalize('NFKD').replace(/\p{M}/gu, '').toLowerCase().replace(/[^\p{L}\p{N}]+/gu, ' ').trim();
const titles = Object.freeze({ g: 'GM', m: 'IM', f: 'FM', c: 'CM', wg: 'WGM', wm: 'WIM', wf: 'WFM', wc: 'WCM' });

export function prepareQuery(name, federation = '', limit = 50) {
  if (typeof name !== 'string' || name.length > 100 || typeof federation !== 'string') throw error('INVALID_QUERY');
  const query = normalize(name);
  const id = /^[1-9][0-9]{0,11}$/.test(query) ? query : null;
  if (!id && (query.length < 2 || query.split(' ').length > 8)) throw error('INVALID_QUERY');
  const fed = federation.trim().toUpperCase();
  if (fed && !/^[A-Z]{3}$/.test(fed)) throw error('INVALID_FEDERATION');
  if (!Number.isInteger(limit) || limit < 1 || limit > 100) throw error('INVALID_LIMIT');
  return { id, tokens: query.split(' '), federation: fed, limit };
}

export function readHeader(line) {
  if (typeof line !== 'string' || line.length > 1024) throw error('UNSUPPORTED_HEADER');
  const matches = [...line.matchAll(/ID Number|[A-Za-z][A-Za-z0-9-]*/g)];
  if (!matches.length || matches[0].index !== 0 || matches[0][0] !== 'ID Number') throw error('UNSUPPORTED_HEADER');
  const columns = new Map();
  let last = 0;
  for (let i = 0; i < matches.length; i++) {
    const token = matches[i], name = token[0].toLowerCase();
    if (!/^ *$/.test(line.slice(last, token.index)) || columns.has(name)) throw error('UNSUPPORTED_HEADER');
    columns.set(name, { start: token.index, end: matches[i + 1]?.index ?? line.length });
    last = token.index + token[0].length;
  }
  if (!/^ *$/.test(line.slice(last))) throw error('UNSUPPORTED_HEADER');
  if (!['id number', 'name', 'fed'].every(key => columns.has(key))) throw error('UNSUPPORTED_HEADER');
  const ratings = ['srtng', 'std'].filter(key => columns.has(key));
  if (ratings.length !== 1) throw error('UNSUPPORTED_HEADER');
  const ratingKey = ratings[0];
  // Fixed-width required fields need a subsequent column as a reliable boundary.
  for (const key of ['id number', 'name', 'fed', ratingKey]) {
    if (columns.get(key).end === line.length) throw error('UNSUPPORTED_HEADER');
  }
  return { columns, ratingKey };
}

export function readPlayer(line, header) {
  if (line.length > 1024 || /[\u0000-\u001f\u007f]/.test(line)) throw error('INVALID_ROW');
  const chars = Array.from(line);
  const field = key => {
    const range = header.columns.get(key);
    if (!range) return '';
    if (chars.length < range.end && ['id number', 'name', 'fed', header.ratingKey].includes(key)) throw error('INVALID_ROW');
    return chars.slice(range.start, range.end).join('').trim();
  };
  const id = field('id number'), name = field('name'), federation = field('fed'), ratingText = field(header.ratingKey);
  if (!/^[1-9][0-9]{0,11}$/.test(id) || !name || name.length > 150 || !/^[A-Z]{3}$/.test(federation)) throw error('INVALID_ROW');
  if (!/^[0-9]{1,4}$/.test(ratingText) || Number(ratingText) > 4000) throw error('INVALID_ROW');
  const title = field('tit').toLowerCase(), womanTitle = field('wtit').toLowerCase();
  const titleLabel = raw => (Object.hasOwn(titles, raw) ? titles[raw] : null) ?? (/^(GM|IM|FM|CM|WGM|WIM|WFM|WCM)$/.test(raw.toUpperCase()) ? raw.toUpperCase() : '');
  return { id, name, federation, standardRating: Number(ratingText) || null, title: titleLabel(title), womanTitle: titleLabel(womanTitle) };
}

export async function searchRatingFile(file, name, federation = '', options = {}) {
  const query = prepareQuery(name, federation, options.limit ?? 50);
  if (!file || !Number.isSafeInteger(file.size) || file.size <= 0 || file.size > MAX_FILE_BYTES || typeof file.stream !== 'function') throw error('INVALID_FILE');
  const signal = options.signal;
  const checkAbort = () => { if (signal?.aborted) throw error('CANCELLED'); };
  checkAbort();
  const reader = file.stream().getReader();
  const abort = () => { void reader.cancel().catch(() => {}); };
  signal?.addEventListener('abort', abort, { once: true });
  const decoder = new TextDecoder('utf-8', { fatal: true });
  let buffer = '', bytesRead = 0, rows = 0, matches = 0, header = null;
  const items = [];
  const visit = async raw => {
    checkAbort();
    const line = raw.endsWith('\r') ? raw.slice(0, -1) : raw;
    if (!header) { header = readHeader(line); return; }
    if (!line.trim()) return;
    if (++rows > MAX_ROWS) throw error('TOO_MANY_ROWS');
    const player = readPlayer(line, header);
    const hit = (!query.federation || query.federation === player.federation)
      && (query.id ? player.id === query.id : query.tokens.every(token => normalize(player.name).includes(token)));
    if (hit) { matches++; if (items.length < query.limit) items.push(player); }
    if (rows % 2000 === 0) {
      options.onProgress?.({ rows, bytesRead, totalBytes: file.size });
      await new Promise(resolve => setTimeout(resolve, 0));
      checkAbort();
    }
  };
  try {
    for (;;) {
      checkAbort();
      const { done, value } = await reader.read();
      checkAbort();
      if (done) break;
      if (!(value instanceof Uint8Array)) throw error('FILE_READ_ERROR');
      bytesRead += value.byteLength;
      if (bytesRead > file.size || bytesRead > MAX_FILE_BYTES) throw error('FILE_CHANGED');
      buffer += decoder.decode(value, { stream: true });
      let end;
      while ((end = buffer.indexOf('\n')) >= 0) {
        await visit(buffer.slice(0, end)); buffer = buffer.slice(end + 1);
      }
      if (buffer.length > 1024) throw error('INVALID_ROW');
    }
    buffer += decoder.decode();
    if (buffer.length) await visit(buffer);
    if (!header || rows === 0) throw error('EMPTY_LIST');
    if (bytesRead !== file.size) throw error('FILE_CHANGED');
    checkAbort();
    options.onProgress?.({ rows, bytesRead, totalBytes: file.size });
    return { rows, matches, items, omitted: matches - items.length };
  } catch (failure) {
    if (signal?.aborted) throw error('CANCELLED');
    if (failure instanceof RatingFileError) throw failure;
    throw error('FILE_READ_ERROR');
  } finally {
    signal?.removeEventListener('abort', abort);
    void reader.cancel().catch(() => {});
    reader.releaseLock();
  }
}
