/** Read-only projection of a native TournamentState. No scoring or import logic. */
export const MAX_BACKUP_BYTES = 5 * 1024 * 1024;
export class SnapshotError extends Error {
  constructor(code) { super(code); this.name = 'SnapshotError'; this.code = code; }
}
const fail = code => { throw new SnapshotError(code); };
const own = (value, key) => Object.prototype.hasOwnProperty.call(value, key);
const object = value => value !== null && typeof value === 'object' && !Array.isArray(value);
const GUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
function id(value) {
  if (typeof value !== 'string' || !GUID.test(value) || /^0{8}-0{4}-0{4}-0{4}-0{12}$/.test(value)) fail('INVALID_ID');
  return value.toLowerCase();
}
function field(value, camel, required = false) {
  if (!object(value)) fail('INVALID_SNAPSHOT');
  const pascal = camel[0].toUpperCase() + camel.slice(1);
  if (own(value, camel) && own(value, pascal)) fail('AMBIGUOUS_FIELD');
  if (own(value, camel)) return value[camel];
  if (own(value, pascal)) return value[pascal];
  if (required) fail('INVALID_SNAPSHOT');
  return undefined;
}
function text(value) {
  if (typeof value !== 'string' || value.length > 300) fail('INVALID_TEXT');
  return value;
}
function integer(value, minimum) {
  if (!Number.isSafeInteger(value) || value < minimum) fail('INVALID_NUMBER');
  return value;
}
function boolean(value) {
  if (value === undefined) return false;
  if (typeof value !== 'boolean') fail('INVALID_BOOLEAN');
  return value;
}
function collection(value, limit) {
  if (!Array.isArray(value) || value.length > limit) fail('INVALID_COLLECTION');
  return value;
}
// Bound nesting and tokens before JSON.parse and reject duplicate decoded keys.
function parseJson(text) {
  const stack = []; let tokens = 0;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (ch === '"') {
      const start = i++;
      while (i < text.length && text[i] !== '"') { if (text[i] === '\\') i++; i++; }
      if (i >= text.length) fail('INVALID_JSON');
      let next = i + 1;
      while (/[\x20\r\n\t]/.test(text[next] ?? '') && next < text.length) next++;
      if (text[next] === ':' && stack.at(-1) instanceof Set) {
        const key = JSON.parse(text.slice(start, i + 1));
        if (stack.at(-1).has(key)) fail('DUPLICATE_FIELD');
        stack.at(-1).add(key);
      }
    } else if (ch === '{' || ch === '[') {
      stack.push(ch === '{' ? new Set() : null);
      if (stack.length > 32) fail('TOO_COMPLEX');
    } else if (ch === '}' || ch === ']') stack.pop();
    if ('{}[],:'.includes(ch) && ++tokens > 200000) fail('TOO_COMPLEX');
  }
  return JSON.parse(text);
}
const statuses = ['Active', 'Paused', 'Withdrawn'];
const kinds = ['NotPlayed', 'WhiteWin', 'Draw', 'BlackWin', 'WhiteForfeitWin', 'BlackForfeitWin', 'DoubleForfeit', 'Bye', 'ArmageddonWhiteWin', 'ArmageddonBlackWin'];
const decodeEnum = (value, names) => Number.isInteger(value) ? names[value] ?? null : names.includes(value) ? value : null;
export const RESULT_LABELS = Object.freeze({
  NotPlayed: 'Noch kein Ergebnis', WhiteWin: 'Weiss gewinnt', Draw: 'Remis', BlackWin: 'Schwarz gewinnt',
  WhiteForfeitWin: 'Weiss gewinnt kampflos', BlackForfeitWin: 'Schwarz gewinnt kampflos',
  DoubleForfeit: 'Beide kampflos verloren', Bye: 'Freilos',
  ArmageddonWhiteWin: 'Armageddon: Weiss gewinnt', ArmageddonBlackWin: 'Armageddon: Schwarz gewinnt',
});
export function readSnapshot(bytes) {
  if (!(bytes instanceof Uint8Array) || bytes.length === 0 || bytes.length > MAX_BACKUP_BYTES) fail('INVALID_SIZE');
  let source;
  try { source = parseJson(new TextDecoder('utf-8', { fatal: true }).decode(bytes)); }
  catch (error) { if (error instanceof SnapshotError) throw error; fail('INVALID_JSON'); }
  const tournamentId = id(field(source, 'id', true)), name = text(field(source, 'name', true));
  const playerIds = new Set(), roundIds = new Set();
  let unknownValues = 0, unresolvedReferences = 0, pairingCount = 0;
  const players = collection(field(source, 'players', true), 5000).map((raw, index) => {
    const playerId = id(field(raw, 'id', true));
    if (playerIds.has(playerId)) fail('DUPLICATE_PLAYER');
    playerIds.add(playerId);
    const status = decodeEnum(field(raw, 'status'), statuses);
    if (status === null) unknownValues++;
    return Object.freeze({ id: playerId, name: text(field(raw, 'name', true)), index: index + 1,
      startingRank: integer(field(raw, 'startingRank') ?? 0, 0), status });
  });
  const reference = value => {
    if (value == null) return null;
    const playerId = id(value);
    if (!playerIds.has(playerId)) unresolvedReferences++;
    return playerId;
  };
  const rounds = collection(field(source, 'rounds', true), 1000).map(raw => {
    const number = integer(field(raw, 'roundNumber', true), 1);
    if (roundIds.has(number)) fail('DUPLICATE_ROUND');
    roundIds.add(number);
    const boardIds = new Set();
    const pairings = collection(field(raw, 'pairings', true), 5000).map(pairing => {
      if (++pairingCount > 20000) fail('TOO_COMPLEX');
      const board = integer(field(pairing, 'boardNumber', true), 1);
      if (boardIds.has(board)) fail('DUPLICATE_BOARD');
      boardIds.add(board);
      const result = field(pairing, 'result');
      const kind = object(result) ? decodeEnum(field(result, 'kind'), kinds) : null;
      if (kind === null) unknownValues++;
      return Object.freeze({ board, white: reference(field(pairing, 'whitePlayerId')),
        black: reference(field(pairing, 'blackPlayerId')), kind });
    });
    return Object.freeze({ number, locked: boolean(field(raw, 'isLocked')),
      verified: boolean(field(raw, 'isVerified')), pairings: Object.freeze(pairings) });
  });
  return Object.freeze({ id: tournamentId, name, players: Object.freeze(players), rounds: Object.freeze(rounds),
    pairingCount, unknownValues, unresolvedReferences });
}
export function visiblePlayers(snapshot, { query = '', status = '', offset = 0, limit = 50 } = {}) {
  if (typeof query !== 'string' || query.length > 100 || !['', ...statuses].includes(status) ||
      !Number.isSafeInteger(offset) || offset < 0 || ![20, 50, 100].includes(limit)) fail('INVALID_FILTER');
  const needle = query.normalize('NFC').trim().toLowerCase();
  const rows = snapshot.players.filter(player => (!status || player.status === status) &&
    (!needle || player.name.normalize('NFC').toLowerCase().includes(needle)));
  return { total: rows.length, rows: rows.slice(offset, offset + limit), hasMore: offset + limit < rows.length };
}
