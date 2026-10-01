// Structural preview for native TournamentState JSON. No import, API, storage or evaluation.
export const MAX_BYTES = 5 * 1024 * 1024;
const MAX_DEPTH = 64;
const MAX_ITEMS = 20000;
const MAX_ISSUES = 100;
const GUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const EMPTY_GUID = '00000000-0000-0000-0000-000000000000';
const object = value => value !== null && typeof value === 'object' && !Array.isArray(value);
const id = value => typeof value === 'string' && value.length === 36 && GUID.test(value) && value !== EMPTY_GUID;
const nonempty = value => typeof value === 'string' && value.trim().length > 0;
const positive = value => Number.isSafeInteger(value) && value > 0;
// DateOnly is serialized as yyyy-MM-dd; reject impossible calendar dates as well.
const isoDate = value => {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const [year, month, day] = value.split('-').map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  return date.getUTCFullYear() === year && date.getUTCMonth() === month - 1 && date.getUTCDate() === day;
};
// Backend TournamentSettings.PlannedRounds default when the field is absent.
const DEFAULT_PLANNED_ROUNDS = 5;

// JSON.parse alone discards duplicate properties. Detect duplicates (including
// escaped spellings) before parsing; strings are decoded as JSON data, never code.
function checkJsonStructure(text) {
  const stack = [];
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (ch === '{' || ch === '[') {
      stack.push(ch === '{' ? new Set() : null);
      if (stack.length > MAX_DEPTH) throw Error('TOO_DEEP');
    } else if (ch === '}' || ch === ']') {
      stack.pop();
    } else if (ch === '"') {
      const start = i++;
      while (i < text.length && text[i] !== '"') {
        if (text[i] === '\\') i++;
        i++;
      }
      if (i >= text.length) throw Error('INVALID_JSON');
      let next = i + 1;
      while (next < text.length && /\s/.test(text[next])) next++;
      if (text[next] === ':' && stack.at(-1) instanceof Set) {
        const key = JSON.parse(text.slice(start, i + 1));
        if (stack.at(-1).has(key)) throw Error('DUPLICATE_KEY');
        stack.at(-1).add(key);
      }
    }
  }
}

export function inspectBackup(input) {
  const report = { status: 'INVALID', restoreAuthorized: false, scope: 'STRUCTURAL_PREVIEW_ONLY', summary: null, issues: [], issueCount: 0, truncated: false };
  const add = (code, location = '$', severity = 'error') => {
    report.issueCount++;
    if (report.issues.length < MAX_ISSUES) report.issues.push({ code, location, severity });
    else report.truncated = true;
  };
  let data;
  try {
    const bytes = typeof input === 'string' ? new TextEncoder().encode(input) : input;
    if (!(bytes instanceof Uint8Array)) throw Error('INVALID_INPUT');
    if (bytes.byteLength > MAX_BYTES) throw Error('TOO_LARGE');
    let text;
    try { text = new TextDecoder('utf-8', { fatal: true }).decode(bytes); }
    catch { throw Error('INVALID_UTF8'); }
    if (!text.trim()) throw Error('EMPTY_FILE');
    checkJsonStructure(text);
    try { data = JSON.parse(text); } catch { throw Error('INVALID_JSON'); }
  } catch (error) {
    const codes = new Set(['INVALID_INPUT', 'TOO_LARGE', 'INVALID_UTF8', 'EMPTY_FILE', 'TOO_DEEP', 'DUPLICATE_KEY']);
    add(codes.has(error?.message) ? error.message : 'INVALID_JSON');
    return report;
  }
  if (!object(data) || Object.hasOwn(data, 'schema') || Object.hasOwn(data, 'tournament')) {
    add('UNSUPPORTED_FORMAT'); return report;
  }
  if (!id(data.id)) add('INVALID_TOURNAMENT_ID', '$.id');
  if (!nonempty(data.name)) add('MISSING_NAME', '$.name');
  if (!object(data.settings)) add('MISSING_SETTINGS', '$.settings');
  // The backend silently uses today when createdOn is missing; that would change the backup.
  if (!Object.hasOwn(data, 'createdOn') || data.createdOn === null) add('MISSING_CREATED_ON', '$.createdOn');
  else if (!isoDate(data.createdOn)) add('INVALID_CREATED_ON', '$.createdOn');
  const arrays = ['players', 'rounds', 'auditJournal'];
  for (const field of arrays) {
    if (!Array.isArray(data[field])) add('MISSING_ARRAY', `$.${field}`);
    else if (data[field].length > MAX_ITEMS) add('TOO_MANY_ITEMS', `$.${field}`);
  }
  if (report.issueCount) return report;
  const playerIds = new Set(); const names = new Set();
  for (const [index, player] of data.players.entries()) {
    const where = `$.players[${index}]`;
    if (!object(player)) { add('INVALID_PLAYER', where); continue; }
    if (!id(player.id)) add('INVALID_PLAYER_ID', `${where}.id`);
    else {
      const normalized = player.id.toLowerCase();
      if (playerIds.has(normalized)) add('DUPLICATE_PLAYER_ID', `${where}.id`);
      playerIds.add(normalized);
    }
    if (!nonempty(player.name)) add('MISSING_NAME', `${where}.name`);
    else {
      const normalized = player.name.trim().toLowerCase();
      // EnsureUniquePlayerNames rejects the whole import, so this is an error, not a warning.
      if (names.has(normalized)) add('DUPLICATE_PLAYER_NAME', `${where}.name`);
      names.add(normalized);
    }
  }
  const roundNumbers = new Set(); let boards = 0;
  for (const [index, round] of data.rounds.entries()) {
    const where = `$.rounds[${index}]`;
    if (!object(round)) { add('INVALID_ROUND', where); continue; }
    if (!positive(round.roundNumber)) add('INVALID_ROUND_NUMBER', `${where}.roundNumber`);
    else if (roundNumbers.has(round.roundNumber)) add('DUPLICATE_ROUND', `${where}.roundNumber`);
    roundNumbers.add(round.roundNumber);
    if (!Array.isArray(round.pairings)) { add('MISSING_ARRAY', `${where}.pairings`); continue; }
    if (round.pairings.length > MAX_ITEMS) { add('TOO_MANY_ITEMS', `${where}.pairings`); continue; }
    const boardNumbers = new Set(); const assigned = new Set();
    for (const [pairIndex, pairing] of round.pairings.entries()) {
      const pairWhere = `${where}.pairings[${pairIndex}]`;
      boards++;
      if (!object(pairing)) { add('INVALID_PAIRING', pairWhere); continue; }
      if (!positive(pairing.boardNumber)) add('INVALID_BOARD_NUMBER', `${pairWhere}.boardNumber`);
      else if (boardNumbers.has(pairing.boardNumber)) add('DUPLICATE_BOARD', `${pairWhere}.boardNumber`);
      boardNumbers.add(pairing.boardNumber);
      const white = typeof pairing.whitePlayerId === 'string' ? pairing.whitePlayerId.toLowerCase() : null;
      const black = typeof pairing.blackPlayerId === 'string' ? pairing.blackPlayerId.toLowerCase() : null;
      if (white && white === black) add('SELF_PAIRING', pairWhere);
      for (const field of ['whitePlayerId', 'blackPlayerId']) {
        const value = pairing[field];
        if (field === 'blackPlayerId' && value === null) continue;
        if (!id(value)) { add('INVALID_PLAYER_REFERENCE', `${pairWhere}.${field}`); continue; }
        const normalized = value.toLowerCase();
        if (!playerIds.has(normalized)) add('UNKNOWN_PLAYER', `${pairWhere}.${field}`);
        if (assigned.has(normalized)) add('PLAYER_ASSIGNED_TWICE', `${pairWhere}.${field}`);
        assigned.add(normalized);
      }
    }
  }
  // ValidateImportedRounds: rounds must run 1..n without gaps and n <= PlannedRounds.
  const numbers = [...roundNumbers].filter(positive).sort((a, b) => a - b);
  if (numbers.some((number, index) => number !== index + 1)) add('ROUND_SEQUENCE_GAP', '$.rounds');
  const planned = data.settings.plannedRounds;
  if (planned !== undefined && !Number.isSafeInteger(planned)) add('INVALID_PLANNED_ROUNDS', '$.settings.plannedRounds');
  else if (data.rounds.length > Math.max(1, planned ?? DEFAULT_PLANNED_ROUNDS)) add('TOO_MANY_ROUNDS', '$.rounds');
  report.summary = {
    name: data.name.trim().slice(0, 160), players: data.players.length,
    rounds: data.rounds.length, boards, auditEntries: data.auditJournal.length,
  };
  report.status = report.issues.some(issue => issue.severity === 'error') || report.truncated ? 'INVALID' :
    report.issueCount ? 'WARNINGS' : 'STRUCTURE_OK';
  return report;
}
