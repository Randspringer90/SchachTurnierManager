import test from 'node:test';
import assert from 'node:assert/strict';
import { inspectBackup, MAX_BYTES } from '../../src/SchachTurnierManager.WebApp/public/backup-check/preflight.mjs';

const tournamentId = '10000000-0000-0000-0000-000000000001';
const alpha = '20000000-0000-0000-0000-000000000001';
const beta = '20000000-0000-0000-0000-000000000002';
const make = () => ({
  id: tournamentId, name: 'Synthetic Cup', createdOn: '2026-10-01', settings: {},
  players: [{ id: alpha, name: 'Synthetic Alpha', rating: {} }, { id: beta, name: 'Synthetic Beta', rating: {} }],
  rounds: [{ roundNumber: 1, pairings: [{ boardNumber: 1, whitePlayerId: alpha, blackPlayerId: beta, result: { kind: 0 } }] }], auditJournal: [],
});
const inspect = value => inspectBackup(JSON.stringify(value));
const has = (report, code) => report.issues.some(issue => issue.code === code);

test('native snapshot shape has a bounded preview, never restore authority', () => {
  const report = inspect(make()); assert.equal(report.status, 'STRUCTURE_OK'); assert.equal(report.restoreAuthorized, false);
  assert.equal(report.scope, 'STRUCTURAL_PREVIEW_ONLY');
  assert.deepEqual(report.summary, { name: 'Synthetic Cup', players: 2, rounds: 1, boards: 1, auditEntries: 0 });
});
test('empty tournament is a valid native structural preview', () => {
  const data = make(); data.players = []; data.rounds = []; assert.equal(inspect(data).status, 'STRUCTURE_OK');
});
test('UTF-8 BOM, non-ASCII and CRLF are supported', () => {
  const data = make(); data.name = 'Torneo sint\u00e9tico \u265f';
  const bytes = new TextEncoder().encode('\uFEFF' + JSON.stringify(data, null, 2).replaceAll('\n', '\r\n'));
  assert.equal(inspectBackup(bytes).summary.name, data.name);
});
for (const [input, code] of [
  ['', 'EMPTY_FILE'], ['   ', 'EMPTY_FILE'], ['{', 'INVALID_JSON'], ['[]', 'UNSUPPORTED_FORMAT'],
  ['null', 'UNSUPPORTED_FORMAT'], ['42', 'UNSUPPORTED_FORMAT'], ['{"schema":"audit"}', 'UNSUPPORTED_FORMAT'],
  ['{"tournament":{}}', 'UNSUPPORTED_FORMAT'], ['{"id":1,"id":2}', 'DUPLICATE_KEY'],
  ['{"id":1,"\\u0069d":2}', 'DUPLICATE_KEY'], ['{"nested":{"a":1,"a":2}}', 'DUPLICATE_KEY'],
  [new Uint8Array([0xff, 0xfe]), 'INVALID_UTF8'], [new Uint8Array([0xc3, 0x28]), 'INVALID_UTF8'],
  [undefined, 'INVALID_INPUT'], [new Uint8Array(MAX_BYTES + 1), 'TOO_LARGE'],
  ['['.repeat(65) + ']'.repeat(65), 'TOO_DEEP'],
]) {
  test(`reject ${code}`, () => {
    const report = inspectBackup(input); assert.equal(report.status, 'INVALID'); assert.equal(report.restoreAuthorized, false); assert.ok(has(report, code));
  });
}
for (const [mutate, code] of [
  [data => { data.id = ''; }, 'INVALID_TOURNAMENT_ID'],
  [data => { data.id = '00000000-0000-0000-0000-000000000000'; }, 'INVALID_TOURNAMENT_ID'],
  [data => { data.name = ' '; }, 'MISSING_NAME'],
  [data => { data.settings = []; }, 'MISSING_SETTINGS'],
  [data => { data.players = null; }, 'MISSING_ARRAY'],
  [data => { delete data.rounds; }, 'MISSING_ARRAY'],
  [data => { data.auditJournal = Array(20001).fill({}); }, 'TOO_MANY_ITEMS'],
  [data => { data.players[0] = null; }, 'INVALID_PLAYER'],
  [data => { data.players[0].id = 'bad'; }, 'INVALID_PLAYER_ID'],
  [data => { data.players[1].id = alpha.toUpperCase(); }, 'DUPLICATE_PLAYER_ID'],
  [data => { data.players[0].name = ''; }, 'MISSING_NAME'],
  [data => { data.rounds[0] = 0; }, 'INVALID_ROUND'],
  [data => { data.rounds[0].roundNumber = -1; }, 'INVALID_ROUND_NUMBER'],
  [data => { data.rounds.push(structuredClone(data.rounds[0])); }, 'DUPLICATE_ROUND'],
  [data => { data.rounds[0].pairings = null; }, 'MISSING_ARRAY'],
  [data => { data.rounds[0].pairings[0] = null; }, 'INVALID_PAIRING'],
  [data => { data.rounds[0].pairings[0].boardNumber = 1.5; }, 'INVALID_BOARD_NUMBER'],
  [data => { data.rounds[0].pairings.push(structuredClone(data.rounds[0].pairings[0])); }, 'DUPLICATE_BOARD'],
  [data => { data.rounds[0].pairings[0].blackPlayerId = alpha; }, 'SELF_PAIRING'],
  [data => { data.rounds[0].pairings[0].whitePlayerId = null; }, 'INVALID_PLAYER_REFERENCE'],
  [data => { delete data.rounds[0].pairings[0].blackPlayerId; }, 'INVALID_PLAYER_REFERENCE'],
  [data => { data.rounds[0].pairings[0].whitePlayerId = tournamentId; }, 'UNKNOWN_PLAYER'],
  [data => { data.rounds[0].pairings.push({ boardNumber: 2, whitePlayerId: beta, blackPlayerId: null }); }, 'PLAYER_ASSIGNED_TWICE'],
]) {
  test(`detect ${code}`, () => { const data = make(); mutate(data); const report = inspect(data); assert.equal(report.status, 'INVALID'); assert.ok(has(report, code)); });
}
test('bye with a null black reference is valid', () => {
  const data = make(); data.rounds[0].pairings[0].blackPlayerId = null; assert.equal(inspect(data).status, 'STRUCTURE_OK');
});
test('the same player may appear again in a later round', () => {
  const data = make(); data.rounds.push({ ...structuredClone(data.rounds[0]), roundNumber: 2 }); assert.equal(inspect(data).status, 'STRUCTURE_OK');
});
// PR #77 review: the preview must not report STRUCTURE_OK for files the backend import rejects
// or silently changes (EnsureUniquePlayerNames, ValidateImportedRounds, CreatedOn default).
test('duplicate display names are errors because the backend import rejects them', () => {
  const data = make(); data.players[1].name = ' synthetic alpha '; const report = inspect(data);
  assert.equal(report.status, 'INVALID'); assert.ok(has(report, 'DUPLICATE_PLAYER_NAME'));
  assert.equal(report.issues.find(issue => issue.code === 'DUPLICATE_PLAYER_NAME').severity, 'error');
});
test('missing createdOn is an error instead of a silent change to today', () => {
  const data = make(); delete data.createdOn; const report = inspect(data);
  assert.equal(report.status, 'INVALID'); assert.ok(has(report, 'MISSING_CREATED_ON'));
});
for (const value of ['2026-13-01', '2026-02-30', '01.10.2026', '2026-10-1', 42, null]) {
  test(`invalid createdOn ${JSON.stringify(value)} is an error`, () => {
    const data = make(); data.createdOn = value; const report = inspect(data);
    assert.equal(report.status, 'INVALID'); assert.ok(has(report, 'INVALID_CREATED_ON') || has(report, 'MISSING_CREATED_ON'));
  });
}
test('a backup that starts with round 2 is rejected like the backend does', () => {
  const data = make(); data.rounds[0].roundNumber = 2; const report = inspect(data);
  assert.equal(report.status, 'INVALID'); assert.ok(has(report, 'ROUND_SEQUENCE_GAP'));
});
test('a gap between rounds is rejected', () => {
  const data = make(); data.rounds.push({ ...structuredClone(data.rounds[0]), roundNumber: 3 }); const report = inspect(data);
  assert.equal(report.status, 'INVALID'); assert.ok(has(report, 'ROUND_SEQUENCE_GAP'));
});
test('more rounds than planned are rejected', () => {
  const data = make(); data.settings = { plannedRounds: 1 }; data.rounds.push({ ...structuredClone(data.rounds[0]), roundNumber: 2 });
  const report = inspect(data); assert.equal(report.status, 'INVALID'); assert.ok(has(report, 'TOO_MANY_ROUNDS'));
});
test('without plannedRounds the backend default of five rounds applies', () => {
  const data = make();
  for (const roundNumber of [2, 3, 4, 5]) data.rounds.push({ ...structuredClone(data.rounds[0]), roundNumber });
  assert.equal(inspect(data).status, 'STRUCTURE_OK');
  data.rounds.push({ ...structuredClone(data.rounds[0]), roundNumber: 6 });
  assert.ok(has(inspect(data), 'TOO_MANY_ROUNDS'));
});
test('IDs are compared case insensitively', () => {
  const data = make(); const key = 'abcdefab-cdef-abcd-abcd-abcdefabcdef';
  data.players[0].id = key; data.rounds[0].pairings[0].whitePlayerId = key.toUpperCase(); assert.equal(inspect(data).status, 'STRUCTURE_OK');
});
test('escaped quotes/braces in text are data, not structure', () => {
  const data = make(); data.name = 'Synthetic "id": 1, { bracket } \\ text'; assert.equal(inspect(data).status, 'STRUCTURE_OK');
});
test('prototype-shaped JSON properties do not modify Object.prototype', () => {
  const data = JSON.stringify(make()).replace('"settings":{}', '"settings":{"__proto__":{"polluted":"yes"}}');
  assert.equal(inspectBackup(data).status, 'STRUCTURE_OK'); assert.equal({}.polluted, undefined);
});
test('diagnostics contain paths/codes, never the offending raw data', () => {
  const data = make(); data.players[0].id = 'DO_NOT_REPORT'; const report = inspect(data);
  assert.ok(!JSON.stringify(report.issues).includes('DO_NOT_REPORT'));
});
test('many issues are bounded and never reported as a clean result', () => {
  const data = make(); data.players = Array.from({ length: 200 }, () => null);
  const report = inspect(data); assert.equal(report.issues.length, 100); assert.equal(report.truncated, true); assert.equal(report.status, 'INVALID');
});
test('preview is deterministic and leaves the caller data unchanged', () => {
  const data = make(); const text = JSON.stringify(data); const first = inspectBackup(text); const second = inspectBackup(text);
  assert.deepEqual(first, second); assert.equal(JSON.stringify(data), text);
});
test('unknown business fields do not become a false business-rule guarantee', () => {
  const data = make(); data.settings.unknownFutureField = true;
  assert.equal(inspect(data).scope, 'STRUCTURAL_PREVIEW_ONLY'); assert.equal(inspect(data).restoreAuthorized, false);
});
test('GUID with trailing newline is not accepted as an exact identifier', () => {
  const data = make(); data.id += '\n'; assert.ok(has(inspect(data), 'INVALID_TOURNAMENT_ID'));
});
