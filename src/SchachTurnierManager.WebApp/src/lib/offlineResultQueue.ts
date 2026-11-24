export type ResultMutation = {
  mutationId: string; epoch: string; roundNumber: number; boardNumber: number;
  result: number; expectedPreviousResult: number; whitePlayerId: string; blackPlayerId: string;
  expectedLastChangedAt: string | null;
};
export type QueuedResultEntry = {
  id: string; tournamentId: string; createdAt: string; state: 'pending' | 'conflict'; mutation: ResultMutation;
};
export interface ResultQueueStore {
  list(): Promise<QueuedResultEntry[]>;
  add(entry: QueuedResultEntry): Promise<void>;
  conflict(id: string): Promise<void>;
  remove(id: string): Promise<void>;
}
const maxEntries = 200;
const guid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const emptyGuid = '00000000-0000-0000-0000-000000000000';
const isGuid = (value: unknown, empty = false): value is string => typeof value === 'string' && guid.test(value) && (empty || value !== emptyGuid);
const timestamp = (value: unknown): value is string => typeof value === 'string' && value.length <= 40 &&
  /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d{1,7})?(?:Z|[+-]\d\d:\d\d)$/.test(value) && Number.isFinite(Date.parse(value));
const resultKind = (value: unknown) => Number.isInteger(value) && Number(value) >= 0 && Number(value) <= 9 && value !== 7;
export function captureResultEntry(tournamentId: string, epoch: string | undefined, roundNumber: number,
  pairing: { boardNumber: number; whitePlayerId?: string | null; blackPlayerId?: string | null; lastChangedAt?: string | null },
  result: number, expectedPreviousResult: number): QueuedResultEntry {
  const bytes = crypto.getRandomValues(new Uint8Array(16));
  bytes[6] = (bytes[6] & 15) | 64; bytes[8] = (bytes[8] & 63) | 128;
  const hex = Array.from(bytes, value => value.toString(16).padStart(2, '0')).join('');
  const id = `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
  return validateQueueEntry({ id, tournamentId, createdAt: new Date().toISOString(), state: 'pending',
    mutation: { mutationId: id, epoch: epoch ?? emptyGuid, roundNumber, boardNumber: pairing.boardNumber,
      result, expectedPreviousResult, whitePlayerId: pairing.whitePlayerId, blackPlayerId: pairing.blackPlayerId,
      expectedLastChangedAt: pairing.lastChangedAt ?? null } });
}
function exactKeys(value: unknown, keys: string[]): value is Record<string, any> {
  return value !== null && typeof value === 'object' && !Array.isArray(value) &&
    Object.keys(value).length === keys.length && keys.every(key => Object.hasOwn(value, key));
}
export function validateQueueEntry(value: unknown): QueuedResultEntry {
  if (!exactKeys(value, ['id', 'tournamentId', 'createdAt', 'state', 'mutation']) || !isGuid(value.id) ||
      !isGuid(value.tournamentId) || !timestamp(value.createdAt) || !['pending', 'conflict'].includes(value.state)) throw Error('QUEUE_INVALID');
  const m = value.mutation;
  if (!exactKeys(m, ['mutationId', 'epoch', 'roundNumber', 'boardNumber', 'result', 'expectedPreviousResult', 'whitePlayerId', 'blackPlayerId', 'expectedLastChangedAt']) ||
      m.mutationId !== value.id || !isGuid(m.epoch, true) || !isGuid(m.whitePlayerId) || !isGuid(m.blackPlayerId) ||
      m.whitePlayerId === m.blackPlayerId || !Number.isSafeInteger(m.roundNumber) || m.roundNumber < 1 || m.roundNumber > 10000 ||
      !Number.isSafeInteger(m.boardNumber) || m.boardNumber < 1 || m.boardNumber > 10000 || !resultKind(m.result) ||
      !resultKind(m.expectedPreviousResult) || (m.expectedLastChangedAt !== null && !timestamp(m.expectedLastChangedAt))) throw Error('QUEUE_INVALID');
  return value as QueuedResultEntry;
}
function validatedList(values: unknown[]): QueuedResultEntry[] {
  if (values.length > maxEntries) throw Error('QUEUE_CAPACITY');
  return values.map(validateQueueEntry).sort((a, b) => a.createdAt.localeCompare(b.createdAt) || a.id.localeCompare(b.id));
}

// IndexedDB transactions serialize concurrent tabs. No localStorage read/modify/write,
// cookies, participant names or free text. Failure never falls back to memory.
export function createIndexedDbResultQueueStore(): ResultQueueStore {
  async function transact<T>(mode: IDBTransactionMode, action: (store: IDBObjectStore, done: (value: T) => void, fail: (error: unknown) => void) => void): Promise<T> {
    return new Promise<T>((resolve, reject) => {
      if (!globalThis.indexedDB) { reject(Error('QUEUE_STORAGE_UNAVAILABLE')); return; }
      let settled = false;
      const opening = indexedDB.open('stm-result-queue', 1);
      opening.onupgradeneeded = () => opening.result.createObjectStore('mutations', { keyPath: 'id' });
      opening.onerror = () => { settled = true; reject(Error('QUEUE_STORAGE_UNAVAILABLE')); };
      opening.onblocked = () => { settled = true; reject(Error('QUEUE_STORAGE_BLOCKED')); };
      opening.onsuccess = () => {
        const database = opening.result;
        if (settled) { database.close(); return; }
        let value: T, failure: unknown;
        const transaction = database.transaction('mutations', mode);
        const fail = (error: unknown) => { failure = error; transaction.abort(); };
        transaction.oncomplete = () => { database.close(); settled = true; resolve(value); };
        transaction.onabort = transaction.onerror = () => { database.close(); settled = true; reject(failure ?? Error('QUEUE_STORAGE_FAILED')); };
        try { action(transaction.objectStore('mutations'), result => { value = result; }, fail); }
        catch (error) { fail(error); }
      };
    });
  }
  return {
    list: () => transact<QueuedResultEntry[]>('readonly', (store, done, fail) => {
      const request = store.getAll(undefined, maxEntries + 1);
      request.onsuccess = () => { try { done(validatedList(request.result)); } catch (error) { fail(error); } };
    }),
    add: async entry => {
      validateQueueEntry(entry);
      await transact<void>('readwrite', (store, done, fail) => {
        const request = store.getAll(undefined, maxEntries + 1);
        request.onsuccess = () => {
          try {
            const existing = validatedList(request.result), same = existing.find(item => item.id === entry.id);
            if (same) {
              if (JSON.stringify(same) !== JSON.stringify(entry)) throw Error('QUEUE_DUPLICATE_ID');
              done(); return;
            }
            if (existing.length >= maxEntries) throw Error('QUEUE_CAPACITY');
            if (existing.some(item => item.tournamentId === entry.tournamentId && item.mutation.epoch === entry.mutation.epoch &&
                item.mutation.roundNumber === entry.mutation.roundNumber && item.mutation.boardNumber === entry.mutation.boardNumber)) throw Error('QUEUE_BOARD_PENDING');
            store.add(entry); done();
          } catch (error) { fail(error); }
        };
      });
    },
    conflict: id => transact<void>('readwrite', (store, done, fail) => {
      const request = store.get(id);
      request.onsuccess = () => {
        try { if (request.result) store.put({ ...validateQueueEntry(request.result), state: 'conflict' }); done(); }
        catch (error) { fail(error); }
      };
    }),
    remove: id => transact<void>('readwrite', (store, done) => { if (!isGuid(id)) throw Error('QUEUE_INVALID'); store.delete(id); done(); }),
  };
}

export function createResultQueue(store: ResultQueueStore, send: (entry: QueuedResultEntry) => Promise<unknown>,
  isTransportError: (error: unknown) => boolean, changed: () => void) {
  let active: Promise<void> | null = null;
  return {
    replay(): Promise<void> {
      if (active) return active;
      active = (async () => {
        const entries = validatedList(await store.list());
        for (const entry of entries.filter(item => item.state === 'pending')) {
          try { await send(entry); await store.remove(entry.id); }
          catch (error) {
            const status = typeof error === 'object' && error !== null && 'status' in error ? error.status : null;
            if (!isTransportError(error) && [400, 404, 409, 422].includes(Number(status))) await store.conflict(entry.id);
            else break;
          }
          changed();
        }
      })().finally(() => { active = null; changed(); });
      return active;
    },
  };
}
