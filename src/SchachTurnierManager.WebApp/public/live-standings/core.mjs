import { ReadError, requireId } from '../workflow-common/read-api.mjs';
export function standingsRows(value) {
  if (!Array.isArray(value) || value.length > 5000) throw new ReadError('INVALID_STANDINGS');
  const ids = new Set();
  return value.map(row => {
    const id = requireId(row?.playerId);
    if (ids.has(id) || typeof row?.name !== 'string' || row.name.length > 300 ||
        !Number.isSafeInteger(row.rank) || row.rank < 1) throw new ReadError('INVALID_STANDINGS');
    ids.add(id);
    const result = { id, rank: row.rank, name: row.name };
    for (const key of ['points', 'buchholz', 'sonnebornBerger', 'wins']) {
      if (typeof row[key] !== 'number' || !Number.isFinite(row[key]) || row[key] < 0) throw new ReadError('INVALID_STANDINGS');
      result[key] = row[key];
    }
    return Object.freeze(result);
  });
}
export function pageStandings(rows, query = '', page = 0, size = 20) {
  if (typeof query !== 'string' || query.length > 100 || !Number.isInteger(page) || page < 0 || ![10,20,50].includes(size)) throw new ReadError('INVALID_VIEW');
  const needle = query.trim().normalize('NFKC').toLocaleLowerCase('de');
  const filtered = rows.filter(row => !needle || row.name.normalize('NFKC').toLocaleLowerCase('de').includes(needle));
  const last = Math.max(0, Math.ceil(filtered.length / size) - 1), effective = Math.min(page, last);
  return { rows: filtered.slice(effective * size, (effective + 1) * size), total: filtered.length, page: effective, pages: last + 1 };
}
/** Serial refresh controller: explicit start, pause, visibility suspension and stale results. */
export function createLiveStandings(api, notify, { timers = globalThis, now = Date.now } = {}) {
  let generation = 0, active = null, timer = null, disposed = false, hidden = false;
  let state = { id: null, rows: [], status: 'idle', updatedAt: null, stale: false, interval: 0, running: false, error: null };
  const snapshot = () => ({ ...state, rows: [...state.rows] });
  const emit = () => { if (!disposed) notify(snapshot()); };
  function invalidate() { generation++; if (timer !== null) timers.clearTimeout(timer); timer = null; active?.abort(); active = null; }
  function schedule() {
    if (!disposed && state.running && !hidden && state.interval) timer = timers.setTimeout(() => { timer = null; void refresh(); }, state.interval);
  }
  async function refresh() {
    if (disposed || hidden || !state.id || active) return;
    if (timer !== null) timers.clearTimeout(timer); timer = null;
    const current = generation, controller = new AbortController(); active = controller;
    state.status = 'loading'; state.error = null; emit();
    try {
      const rows = standingsRows(await api.json(`/api/tournaments/${state.id}/standings`, { signal: controller.signal }));
      if (disposed || generation !== current) return;
      state = { ...state, rows, status: 'ready', updatedAt: now(), stale: false, error: null }; emit();
    } catch (error) {
      if (disposed || generation !== current) return;
      state.status = 'error'; state.stale = state.updatedAt !== null; state.error = error instanceof ReadError ? error : new ReadError('NETWORK_ERROR'); emit();
    } finally { if (active === controller) { active = null; schedule(); } }
  }
  function start(id, interval = 0) {
    id = requireId(id);
    if (![0,15000,30000,60000].includes(interval)) throw new ReadError('INVALID_INTERVAL');
    invalidate(); const changed = state.id !== id;
    state = { ...state, id, interval, running: true, error: null,
      rows: changed ? [] : state.rows, updatedAt: changed ? null : state.updatedAt, stale: changed ? false : state.stale,
      status: hidden ? 'hidden' : 'idle' };
    emit(); return refresh();
  }
  function pause() { invalidate(); state.running = false; state.status = 'paused'; emit(); }
  function setHidden(value) {
    if (disposed || hidden === value) return;
    hidden = value; invalidate();
    if (hidden) { state.status = 'hidden'; emit(); }
    else if (state.running) void refresh(); else { state.status = 'paused'; emit(); }
  }
  function clear() { invalidate(); state = { ...state, id: null, rows: [], updatedAt: null, stale: false, running: false, status: 'idle', error: null }; emit(); }
  return { start, refresh, pause, clear, setHidden, state: snapshot, dispose() { invalidate(); disposed = true; state.rows = []; } };
}
