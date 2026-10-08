import test from 'node:test';
import assert from 'node:assert/strict';
import { createRatingApi, RatingReviewError, errorText } from '../../src/SchachTurnierManager.WebApp/public/rating-review/api.js';
import { tournamentOptions, tournamentPlayers, reviewRatings } from '../../src/SchachTurnierManager.WebApp/public/rating-review/core.js';
import { installRatingReview } from '../../src/SchachTurnierManager.WebApp/public/rating-review/ui.js';
import { dom, deferred, guid } from './read-tools-test-dom.mjs';
const tournament = () => ({ id: guid(99), name: 'Synthetic Cup', players: [
  { id: guid(1), name: 'Synthetic 1', fideId: '99900101', rating: { elo: 1500, rapidElo: 1510, blitzElo: 1490 }, notes: 'PRIVATE' },
  { id: guid(2), name: 'Synthetic 2', fideId: '99900102', rating: { elo: 1600, rapidElo: 1610, blitzElo: null }, birthYear: 2000 },
] });
const players = () => tournamentPlayers(tournament(), guid(99));
const found = (id = '99900101', extra = {}) => ({ source: 0, status: 0, query: id, message: 'PRIVATE', players: [
  { source: 0, externalId: id, fideId: id, name: 'Synthetic 1', elo: 1550, rapidElo: 1510, blitzElo: 1490,
    retrievedAt: '2026-01-02T03:04:05Z', notes: 'PRIVATE', ...extra },
] });
const response = value => new Response(JSON.stringify(value), { headers: { 'Content-Type': 'application/json' } });
const take = rows => rows.map(row => row.id);

test('transport is limited to three existing GET-only route families', async () => {
  const calls = []; const api = createRatingApi(async (path, options) => { calls.push([path, options]); return response([]); });
  await api.get('/api/tournaments'); await api.get(`/api/tournaments/${guid(99)}`); await api.get('/api/external-players/fide/99900101');
  assert.equal(calls.length, 3);
  for (const [, options] of calls) {
    assert.equal(options.method, 'GET'); assert.equal(options.credentials, 'omit'); assert.equal(options.redirect, 'error');
    assert.equal(options.cache, 'no-store'); assert.equal(options.body, undefined); assert.equal(options.referrerPolicy, 'no-referrer');
  }
});
for (const route of ['https://example.org/api/tournaments', '//example.org/api/tournaments', '/api/tournaments/import',
  '/api/tournaments?x=1', '/api/external-players/fide/123?secret=x', '/api/external-players/fide/../123',
  `/api/tournaments/${guid(1)}/external-players/apply`]) {
  test('disallowed route cannot reach fetch', async () => {
    let called = false; const api = createRatingApi(async () => { called = true; });
    await assert.rejects(api.get(route)); assert.equal(called, false);
  });
}
for (const status of [400, 401, 404, 500]) test(`HTTP ${status} is not a successful no-hit result`, async () => {
  const api = createRatingApi(async () => new Response('PRIVATE', { status }));
  await assert.rejects(api.get('/api/tournaments'), error => error.code === 'HTTP_ERROR' && !error.message.includes('PRIVATE'));
});
test('redirected response and wrong MIME are rejected', async () => {
  const redirected = response([]); Object.defineProperty(redirected, 'redirected', { value: true });
  await assert.rejects(createRatingApi(async () => redirected).get('/api/tournaments'), /INVALID_RESPONSE/);
  await assert.rejects(createRatingApi(async () => new Response('[]')).get('/api/tournaments'), /INVALID_RESPONSE/);
});
test('body bytes enforce the limit even without a length header', async () => {
  const api = createRatingApi(async () => response('x'.repeat(30)));
  await assert.rejects(api.get('/api/tournaments', { maximumBytes: 20 }), /RESPONSE_TOO_LARGE/);
});
test('invalid UTF-8 and malformed JSON are not decoded as success', async () => {
  const api = createRatingApi(async () => new Response(Uint8Array.of(255), { headers: { 'content-type': 'application/json' } }));
  await assert.rejects(api.get('/api/tournaments'), /INVALID_RESPONSE/);
  await assert.rejects(createRatingApi(async () => new Response('{bad', { headers: { 'content-type': 'application/json' } })).get('/api/tournaments'), /INVALID_RESPONSE/);
});
test('deadline covers a fetch implementation that never settles', async () => {
  const api = createRatingApi(() => new Promise(() => {}));
  await assert.rejects(api.get('/api/tournaments', { timeoutMs: 10 }), /TIMEOUT/);
});
test('deadline also covers a stalled body and cancels the reader', async () => {
  let cancelled = false;
  const body = new ReadableStream({ pull() {}, cancel() { cancelled = true; } });
  const api = createRatingApi(async () => new Response(body, { headers: { 'content-type': 'application/json' } }));
  await assert.rejects(api.get('/api/tournaments', { timeoutMs: 10 }), /TIMEOUT/);
  await new Promise(resolve => setImmediate(resolve)); assert.equal(cancelled, true);
});
test('caller cancellation interrupts pending transport and preserves its meaning', async () => {
  const c = new AbortController(), wait = deferred(); const api = createRatingApi(() => wait.promise);
  const request = api.get('/api/tournaments', { signal: c.signal }); c.abort();
  await assert.rejects(request, /CANCELLED/); wait.resolve(response([]));
});
test('pre-cancel and invalid limits perform no fetch', async () => {
  let calls = 0; const api = createRatingApi(async () => { calls++; return response([]); });
  const c = new AbortController(); c.abort(); await assert.rejects(api.get('/api/tournaments', { signal: c.signal }), /CANCELLED/);
  await assert.rejects(api.get('/api/tournaments', { timeoutMs: 9000 }), /INVALID_LIMIT/); assert.equal(calls, 0);
});
test('raw transport errors are not exposed', async () => {
  await assert.rejects(createRatingApi(async () => { throw Error('PRIVATE detail'); }).get('/api/tournaments'), error => error.code === 'NETWORK_ERROR' && !error.message.includes('PRIVATE'));
  assert.equal(errorText(new RatingReviewError('PRIVATE')).includes('PRIVATE'), false);
});
test('options and players use only explicitly needed fields', () => {
  assert.deepEqual(Object.keys(tournamentOptions([tournament()])[0]), ['id', 'name']);
  const rows = players(); assert.ok(Object.isFrozen(rows)); assert.ok(Object.isFrozen(rows[0]));
  assert.equal(JSON.stringify(rows).includes('PRIVATE'), false); assert.equal(JSON.stringify(rows).includes('birthYear'), false);
});
test('wrong tournament identity and duplicate player IDs are rejected', () => {
  assert.throws(() => tournamentPlayers(tournament(), guid(12)), /INVALID_DATA/);
  const value = tournament(); value.players.push(value.players[0]); assert.throws(() => tournamentPlayers(value, guid(99)), /INVALID_DATA/);
});
test('invalid or missing FIDE IDs remain unselectable', () => {
  const value = tournament(); value.players[0].fideId = 'abc123'; value.players[1].fideId = null;
  assert.deepEqual(tournamentPlayers(value, guid(99)).map(row => row.fideId), [null, null]);
});
test('one requested profile produces specific proposals but never mutates the baseline', async () => {
  const source = players(), saved = JSON.stringify(source);
  const result = await reviewRatings(source, [guid(1)], { get: async () => found() });
  assert.equal(result[0].status, 'Changes'); assert.deepEqual(result[0].changes, [{ field: 'elo', before: 1500, after: 1550 }]);
  assert.equal(result[0].identityReviewRequired, false); assert.equal(JSON.stringify(source), saved);
  assert.equal(JSON.stringify(result).includes('PRIVATE'), false);
});
test('null and unrated source values never become deletion proposals', async () => {
  const result = await reviewRatings(players(), [guid(1)], { get: async () => found('99900101', { elo: null, rapidElo: 0, blitzElo: 1490 }) });
  assert.equal(result[0].status, 'Incomplete'); assert.deepEqual(result[0].changes, []);
  assert.deepEqual(result[0].unknownFields, ['elo', 'rapidElo']);
});
test('known identical values are marked unchanged', async () => {
  const result = await reviewRatings(players(), [guid(1)], { get: async () => found('99900101', { elo: 1500 }) });
  assert.equal(result[0].status, 'Unchanged');
});
test('different names require human identity review even with a matching FIDE ID', async () => {
  const result = await reviewRatings(players(), [guid(1)], { get: async () => found('99900101', { name: 'Different synthetic name' }) });
  assert.equal(result[0].identityReviewRequired, true);
});
for (const extra of [{ fideId: '99900199' }, { externalId: '99900199' }, { source: 1 }]) test('conflicting provider identity releases no rating proposal', async () => {
  const result = await reviewRatings(players(), [guid(1)], { get: async () => found('99900101', extra) });
  assert.equal(result[0].status, 'IdentityMismatch'); assert.deepEqual(result[0].changes, []);
});
for (const [status, label] of [[1, 'NotFound'], [2, 'Unsupported'], [3, 'Unavailable'], [4, 'InvalidRequest'], ['NotFound', 'NotFound']]) {
  test(`source state ${status} remains distinct`, async () => {
    const result = await reviewRatings(players(), [guid(1)], { get: async () => ({ source: 'Fide', status, players: [] }) });
    assert.equal(result[0].status, label); assert.deepEqual(result[0].changes, []);
  });
}
test('invalid profile values become failures, not seemingly valid updates', async () => {
  const result = await reviewRatings(players(), [guid(1)], { get: async () => found('99900101', { elo: -1 }) });
  assert.equal(result[0].status, 'Failed'); assert.deepEqual(result[0].changes, []);
});
test('sequential reads report per-player failures without hiding later success', async () => {
  let busy = 0, max = 0; const progress = [];
  const result = await reviewRatings(players(), [guid(1), guid(2)], { get: async path => {
    busy++; max = Math.max(max, busy); await Promise.resolve(); busy--;
    if (path.endsWith('101')) throw Error('PRIVATE'); return found('99900102', { name: 'Synthetic 2' });
  } }, { onProgress: value => progress.push(value.completed) });
  assert.equal(max, 1); assert.equal(result[0].status, 'Failed'); assert.equal(result[1].status, 'Changes'); assert.deepEqual(progress, [1, 2]);
});
test('cancellation after the first result prevents a second lookup and returns no completed batch', async () => {
  const c = new AbortController(); let calls = 0;
  await assert.rejects(reviewRatings(players(), [guid(1), guid(2)], { get: async () => { calls++; return found(); } },
    { signal: c.signal, onProgress: () => c.abort() }), /CANCELLED/); assert.equal(calls, 1);
});
for (const selection of [[], [guid(42)], [guid(1), guid(1)], Array(21).fill(guid(1))]) test('invalid batch selection makes no requests', async () => {
  let calls = 0; await assert.rejects(reviewRatings(players(), selection, { get: async () => { calls++; return found(); } })); assert.equal(calls, 0);
});
test('same FIDE ID assigned to two selected players is rejected before any request', async () => {
  const value = tournament(); value.players[1].fideId = value.players[0].fideId;
  const rows = tournamentPlayers(value, guid(99)); let calls = 0;
  await assert.rejects(reviewRatings(rows, take(rows), { get: async () => { calls++; } }), /DUPLICATE_FIDE_ID/); assert.equal(calls, 0);
});
function setup() {
  const d = dom('rating-review'), calls = [];
  const api = { get: async path => { calls.push(path); return path === '/api/tournaments' ? [tournament()] : path.includes('/api/tournaments/') ? tournament() : found(path.split('/').at(-1)); } };
  const view = installRatingReview(d.document, api); return { ...d, view, calls, api };
}
async function load(d) { await d.nodes.list.fire('click'); d.nodes.tournament.value = guid(99); await d.nodes.load.fire('click'); }
test('UI does no eager request and requires consent for external lookups', async () => {
  const d = setup(); assert.equal(d.calls.length, 0); await load(d);
  d.nodes.players.children[0].children[0].children[0].checked = true; await d.nodes.review.fire('click');
  assert.equal(d.calls.length, 2); d.nodes.consent.checked = true; await d.nodes.review.fire('click');
  assert.equal(d.calls.length, 3); assert.equal(d.nodes.results.children.length, 1); assert.match(d.nodes.summary.textContent, /1 mit Ratingabweichung/);
});
test('selection and consent changes immediately invalidate prior proposals', async () => {
  const d = setup(); await load(d); const box = d.nodes.players.children[0].children[0].children[0];
  box.checked = true; d.nodes.consent.checked = true; await d.nodes.review.fire('click');
  await box.fire('change'); assert.equal(d.nodes.results.children.length, 0);
  await d.nodes.review.fire('click'); await d.nodes.consent.fire('change'); assert.equal(d.nodes.results.children.length, 0);
});
test('late replies cannot restore the previous tournament selection', async () => {
  const d = setup(); await load(d); const wait = deferred(); d.api.get = () => wait.promise;
  d.nodes.players.children[0].children[0].children[0].checked = true; d.nodes.consent.checked = true;
  const run = d.nodes.review.fire('click'); d.nodes.tournament.value = guid(100); await d.nodes.tournament.fire('change');
  wait.resolve(found()); await run; assert.equal(d.nodes.results.children.length, 0); assert.equal(d.nodes.players.children.length, 0);
});
test('clear and dispose remove selected private data and do not start follow-up calls', async () => {
  const d = setup(); await load(d); const before = d.calls.length; d.view.dispose();
  await d.nodes.review.fire('click'); assert.equal(d.calls.length, before); assert.equal(d.nodes.players.children.length, 0);
  assert.equal(d.nodes.review.disabled, true);
});
test('HTML labels the preview and never provides an apply/import operation', () => {
  const { html } = dom('rating-review'); assert.match(html, /keinen Anwenden- oder Importknopf/);
  assert.match(html, /form-action 'none'/); assert.match(html, /scope="col"/);
});
