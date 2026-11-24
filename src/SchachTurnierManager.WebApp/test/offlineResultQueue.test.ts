import test from 'node:test';
import assert from 'node:assert/strict';
import { createResultQueue, validateQueueEntry, type QueuedResultEntry } from '../src/lib/offlineResultQueue.ts';

const guid = (n: number) => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const entry = (n = 1): QueuedResultEntry => ({ id: guid(n), tournamentId: guid(100), state: 'pending',
  createdAt: '2026-10-28T10:00:00.000Z', mutation: { mutationId: guid(n), epoch: guid(101), roundNumber: 1,
    boardNumber: n, result: 1, expectedPreviousResult: 0, whitePlayerId: guid(200), blackPlayerId: guid(201), expectedLastChangedAt: null } });
function memoryStore(initial: QueuedResultEntry[] = []) {
  const items = new Map(initial.map(item => [item.id, structuredClone(item)]));
  return { items, list: async () => [...items.values()], add: async (item: QueuedResultEntry) => { items.set(item.id, structuredClone(item)); },
    conflict: async (id: string) => { const item = items.get(id); if (item) items.set(id, { ...item, state: 'conflict' }); },
    remove: async (id: string) => { items.delete(id); } };
}
test('only a bounded pseudonymous mutation schema is accepted', () => {
  assert.deepEqual(validateQueueEntry(entry()), entry());
  for (const invalid of [null, {}, { ...entry(), id: '../bad' }, { ...entry(), state: 'script' },
    { ...entry(), createdAt: 'yesterday' }, { ...entry(), name: 'unwanted payload' },
    { ...entry(), mutation: { ...entry().mutation, mutationId: guid(9) } },
    { ...entry(), mutation: { ...entry().mutation, roundNumber: -1 } },
    { ...entry(), mutation: { ...entry().mutation, result: 7 } },
    { ...entry(), mutation: { ...entry().mutation, expectedLastChangedAt: 'invalid' } }]) {
    assert.throws(() => validateQueueEntry(invalid));
  }
});
test('successful replay removes an acknowledged request and preserves unrelated drafts', async () => {
  const store = memoryStore([entry(), { ...entry(2), state: 'conflict' }]), sent: unknown[] = [];
  const queue = createResultQueue(store, async item => { sent.push(item); }, () => false, () => undefined);
  await queue.replay(); assert.equal(sent.length, 1); assert.deepEqual([...store.items.keys()], [guid(2)]);
});
test('a lost reply keeps the original mutation ID for idempotent replay after restart', async () => {
  const store = memoryStore([entry()]), sent: string[] = [], transport = new Error('synthetic offline');
  await createResultQueue(store, async item => { sent.push(item.id); throw transport; }, error => error === transport, () => undefined).replay();
  assert.equal(store.items.get(guid(1))?.state, 'pending');
  await createResultQueue(store, async item => { sent.push(item.id); }, () => false, () => undefined).replay();
  assert.deepEqual(sent, [guid(1), guid(1)]); assert.equal(store.items.size, 0);
});
test('a conflict is retained for review and does not block a different board', async () => {
  const store = memoryStore([entry(), entry(2)]), sent: string[] = [];
  await createResultQueue(store, async item => { sent.push(item.id); if (item.id === guid(1)) throw { status: 409 }; },
    () => false, () => undefined).replay();
  assert.deepEqual(sent, [guid(1), guid(2)]); assert.equal(store.items.get(guid(1))?.state, 'conflict');
});
test('auth, server and unknown failures keep pending work and stop replay', async () => {
  for (const status of [401, 403, 429, 500, undefined]) {
    const store = memoryStore([entry(), entry(2)]); let calls = 0;
    await createResultQueue(store, async () => { calls++; throw { status }; }, () => false, () => undefined).replay();
    assert.equal(calls, 1); assert.equal(store.items.size, 2); assert.equal(store.items.get(guid(1))?.state, 'pending');
  }
});
test('concurrent replay calls share one drain operation', async () => {
  const store = memoryStore([entry()]); let release!: () => void, calls = 0;
  const gate = new Promise<void>(resolve => { release = resolve; });
  const queue = createResultQueue(store, async () => { calls++; await gate; }, () => false, () => undefined);
  const first = queue.replay(), second = queue.replay(); await new Promise(resolve => setImmediate(resolve));
  assert.equal(calls, 1); release(); await Promise.all([first, second]); assert.equal(store.items.size, 0);
});
test('invalid persisted content is rejected before any network request', async () => {
  const store = memoryStore([entry()]); store.items.set(guid(2), {} as any); let calls = 0;
  const queue = createResultQueue(store, async () => { calls++; }, () => false, () => undefined);
  await assert.rejects(queue.replay()); assert.equal(calls, 0);
});

test('free text such as a correction reason can never enter the browser queue (STM-FACH-007)', () => {
  const withReason = { ...entry(), mutation: { ...entry().mutation, correctionReason: 'synthetic free text' } };
  assert.throws(() => validateQueueEntry(withReason), /QUEUE_INVALID/);
  assert.throws(() => validateQueueEntry({ ...entry(), correctionReason: 'synthetic free text' }), /QUEUE_INVALID/);
});
