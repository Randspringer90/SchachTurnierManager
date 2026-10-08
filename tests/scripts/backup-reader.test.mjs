import test from 'node:test';
import assert from 'node:assert/strict';
import { readSnapshot, visiblePlayers, RESULT_LABELS, MAX_BACKUP_BYTES } from '../../src/SchachTurnierManager.WebApp/public/backup-reader/core.js';
import { installBackupReader } from '../../src/SchachTurnierManager.WebApp/public/backup-reader/ui.js';
import { dom, deferred, guid } from './read-tools-test-dom.mjs';
const encode = value => new TextEncoder().encode(typeof value === 'string' ? value : JSON.stringify(value));
function fixture(count = 2) {
  return { id: guid(99), name: 'Synthetic Cup', settings: { notes: 'PRIVATE' },
    players: Array.from({ length: count }, (_, i) => ({ id: guid(i + 1), name: `Synthetic ${i + 1}`, status: 0, startingRank: i + 1, notes: 'PRIVATE', birthYear: 2000 })),
    rounds: [{ roundNumber: 1, isLocked: false, isVerified: true,
      pairings: count >= 2 ? [{ boardNumber: 1, whitePlayerId: guid(1), blackPlayerId: guid(2), result: { kind: 2 }, notes: 'PRIVATE' }] : [] }],
    auditJournal: [{ actor: 'PRIVATE', details: 'PRIVATE' }] };
}
const parse = value => readSnapshot(encode(value));
test('native numeric-enum backup becomes a bounded read-only projection', () => {
  const result = parse(fixture()); assert.equal(result.players.length, 2); assert.equal(result.rounds[0].pairings[0].kind, 'Draw');
  assert.equal(result.players[0].status, 'Active'); assert.equal(result.rounds[0].verified, true);
  assert.equal(result.pairingCount, 1); assert.equal(result.unknownValues, 0); assert.equal(result.unresolvedReferences, 0);
  assert.ok(Object.isFrozen(result)); assert.ok(Object.isFrozen(result.players));
});
test('PII fields outside the displayed projection are dropped', () => {
  const result = JSON.stringify(parse(fixture())); assert.equal(result.includes('PRIVATE'), false);
  assert.equal(result.includes('birthYear'), false); assert.equal(result.includes('auditJournal'), false);
});
test('PascalCase field names and string enums are accepted', () => {
  const value = { Id: guid(99), Name: 'Synthetic', Players: [{ Id: guid(1), Name: 'Synthetic 1', StartingRank: 1, Status: 'Withdrawn' }],
    Rounds: [{ RoundNumber: 1, IsLocked: true, Pairings: [{ BoardNumber: 1, WhitePlayerId: guid(1), BlackPlayerId: null, Result: { Kind: 'Bye' } }] }] };
  const result = parse(value); assert.equal(result.players[0].status, 'Withdrawn'); assert.equal(result.rounds[0].pairings[0].kind, 'Bye');
});
test('unknown enum values stay unknown instead of being invented as results', () => {
  const value = fixture(); value.players[0].status = 99; value.rounds[0].pairings[0].result.kind = 'Future';
  const result = parse(value); assert.equal(result.unknownValues, 2); assert.equal(result.rounds[0].pairings[0].kind, null);
});
test('a missing player reference is counted without assigning another player', () => {
  const value = fixture(); value.rounds[0].pairings[0].whitePlayerId = guid(123);
  const result = parse(value); assert.equal(result.unresolvedReferences, 1); assert.equal(result.rounds[0].pairings[0].white, guid(123));
});
for (const [kind, number] of Object.keys(RESULT_LABELS).map((value, i) => [value, i])) {
  test(`enum ${kind} has an explicit result label`, () => {
    const value = fixture(); value.rounds[0].pairings[0].result.kind = number;
    const result = parse(value); assert.equal(result.rounds[0].pairings[0].kind, kind); assert.ok(RESULT_LABELS[kind].length > 0);
  });
}
for (const [label, mutate, code] of [
  ['duplicate player', value => value.players.push(value.players[0]), 'DUPLICATE_PLAYER'],
  ['duplicate round', value => value.rounds.push(value.rounds[0]), 'DUPLICATE_ROUND'],
  ['duplicate board', value => value.rounds[0].pairings.push(value.rounds[0].pairings[0]), 'DUPLICATE_BOARD'],
  ['ambiguous root ID', value => { value.Id = value.id; }, 'AMBIGUOUS_FIELD'],
  ['zero ID', value => { value.id = guid(0); }, 'INVALID_ID'],
  ['invalid name', value => { value.name = 7; }, 'INVALID_TEXT'],
  ['nonboolean lock', value => { value.rounds[0].isLocked = 'false'; }, 'INVALID_BOOLEAN'],
  ['negative board', value => { value.rounds[0].pairings[0].boardNumber = -1; }, 'INVALID_NUMBER'],
  ['missing players', value => { delete value.players; }, 'INVALID_SNAPSHOT'],
]) test(label, () => { const value = fixture(); mutate(value); assert.throws(() => parse(value), new RegExp(code)); });
test('escaped duplicate JSON keys are rejected', () => {
  const source = JSON.stringify(fixture()).replace('"name":"Synthetic Cup"', '"name":"one","\\u006eame":"two"');
  assert.throws(() => parse(source), /DUPLICATE_FIELD/);
});
test('nested duplicate keys are also rejected', () => {
  assert.throws(() => parse('{"x":{"a":1,"a":2}}'), /DUPLICATE_FIELD/);
});
test('prototype-like keys remain passive data', () => {
  const source = JSON.stringify(fixture()).replace('"settings":', '"__proto__":{"polluted":true},"settings":');
  assert.equal(parse(source).players.length, 2); assert.equal({}.polluted, undefined);
});
test('BOM, CRLF and escaped braces in names do not confuse the scanner', () => {
  const value = fixture(); value.name = 'Synthetic { "quoted" } \\ test';
  assert.equal(parse('\uFEFF' + JSON.stringify(value, null, 2).replaceAll('\n', '\r\n')).name, value.name);
});
for (const data of [new Uint8Array(), Uint8Array.of(255), new Uint8Array(MAX_BACKUP_BYTES + 1), encode('{bad'), encode('[]')]) {
  test('invalid input fails without partial records', () => assert.throws(() => readSnapshot(data)));
}
test('deep and extremely token-dense JSON are bounded', () => {
  assert.throws(() => parse('['.repeat(34) + '0' + ']'.repeat(34)), /TOO_COMPLEX/);
  assert.throws(() => parse('[' + Array(200002).fill('0').join(',') + ']'), /TOO_COMPLEX/);
});
test('more than 5000 players are rejected', () => assert.throws(() => parse(fixture(5001)), /INVALID_COLLECTION/));
test('source bytes are not mutated', () => {
  const bytes = encode(fixture()), saved = bytes.slice(); readSnapshot(bytes); assert.deepEqual(bytes, saved);
});
test('player search filters without changing source order or ranks', () => {
  const value = fixture(120); value.players[0].status = 1; const snapshot = parse(value);
  const result = visiblePlayers(snapshot, { query: 'synthetic 1', status: 'Active' });
  assert.equal(result.rows[0].startingRank, 10); assert.equal(visiblePlayers(snapshot, { status: 'Paused' }).total, 1);
  assert.equal(visiblePlayers(snapshot, { offset: 100 }).rows.length, 20);
  assert.equal(snapshot.players[0].startingRank, 1);
});
for (const options of [{ offset: -1 }, { limit: 500 }, { status: 'unknown' }, { query: 'x'.repeat(101) }]) {
  test('invalid view filters are rejected', () => assert.throws(() => visiblePlayers(parse(fixture()), options), /INVALID_FILTER/));
}
function setup(value = fixture()) {
  const d = dom('backup-reader'); const view = installBackupReader(d.document);
  d.nodes.file.files = [new File([JSON.stringify(value)], 'synthetic.json')]; return { ...d, view };
}
test('UI reads a real File only after a click and starts with hidden names', async () => {
  const d = setup(); assert.equal(d.nodes.players.children.length, 0);
  await d.nodes.load.fire('click'); assert.equal(d.nodes.players.children.length, 2);
  assert.equal(d.nodes.players.children[0].children[1].textContent, 'Spieler 1'); assert.equal(d.nodes.query.disabled, true);
  d.nodes.names.checked = true; await d.nodes.names.fire('change');
  assert.equal(d.nodes.players.children[0].children[1].textContent, 'Synthetic 1'); assert.equal(d.nodes.title.textContent, 'Synthetic Cup');
});
test('name hiding also clears name searches and sensitive displayed labels', async () => {
  const d = setup(); await d.nodes.load.fire('click'); d.nodes.names.checked = true; await d.nodes.names.fire('change');
  d.nodes.query.value = '1'; await d.nodes.query.fire('input'); assert.equal(d.nodes.players.children.length, 1);
  d.nodes.names.checked = false; await d.nodes.names.fire('change'); assert.equal(d.nodes.query.value, '');
  assert.equal(d.nodes.players.children.length, 2); assert.equal(d.nodes.title.textContent, 'Lokale Turniersicherung');
});
test('paging and round switching use the loaded snapshot without requests', async () => {
  const value = fixture(70); value.rounds.push({ roundNumber: 2, pairings: [], isLocked: true });
  const d = setup(value); await d.nodes.load.fire('click'); assert.equal(d.nodes.players.children.length, 50);
  await d.nodes.next.fire('click'); assert.equal(d.nodes.players.children.length, 20);
  d.nodes.round.value = '2'; await d.nodes.round.fire('change'); assert.equal(d.nodes.pairings.children.length, 0);
  assert.match(d.nodes['round-status'].textContent, /gesperrt ja/);
});
test('imported markup is displayed literally, not interpreted', async () => {
  const value = fixture(); value.players[0].name = '<img src=x onerror=alert(1)>';
  const d = setup(value); await d.nodes.load.fire('click'); d.nodes.names.checked = true; await d.nodes.names.fire('change');
  assert.equal(d.nodes.players.children[0].children[1].textContent, value.players[0].name);
});
test('changing files invalidates the pending read and prevents double starts', async () => {
  const wait = deferred(), d = setup(); const data = encode(fixture()); let reads = 0;
  d.nodes.file.files = [{ size: data.length, arrayBuffer: () => { reads++; return wait.promise; } }];
  const load = d.nodes.load.fire('click'); await d.nodes.file.fire('change'); await d.nodes.load.fire('click');
  assert.equal(reads, 1); wait.resolve(data.buffer); await load; assert.equal(d.nodes.report.hidden, true);
});
test('a failed new file clears the old successful view', async () => {
  const d = setup(); await d.nodes.load.fire('click'); d.nodes.file.files = [new File(['bad'], 'synthetic.json')];
  await d.nodes.load.fire('click'); assert.equal(d.nodes.report.hidden, true); assert.equal(d.nodes.players.children.length, 0);
});
test('dispose prevents old reads from repopulating the page', async () => {
  const wait = deferred(), d = setup(); const data = encode(fixture());
  d.nodes.file.files = [{ size: data.length, arrayBuffer: () => wait.promise }]; const load = d.nodes.load.fire('click');
  d.view.dispose(); wait.resolve(data.buffer); await load; assert.equal(d.nodes.report.hidden, true); assert.equal(d.nodes.load.disabled, true);
});
test('standalone page forbids network calls and exposes a non-live notice', () => {
  const { html } = dom('backup-reader'); assert.match(html, /connect-src 'none'/); assert.match(html, /kein Live-Stand/); assert.match(html, /scope="col"/);
});
