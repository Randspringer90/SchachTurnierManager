import { ReadError } from '../workflow-common/read-api.mjs';
const fail = code => { throw new ReadError(code); };
const fields = ['name','fideId','title','federation','elo','rapidElo','blitzElo','retrievedAt'];
export function fideCapabilities(value) {
  if (!Array.isArray(value) || value.length > 20) fail('INVALID_PROVIDER');
  const fide = value.filter(row => row?.source === 0 || row?.source === 'Fide');
  if (fide.length !== 1 || typeof fide[0].supportsIdLookup !== 'boolean' || typeof fide[0].supportsNameSearch !== 'boolean') fail('INVALID_PROVIDER');
  return Object.freeze({ byId: fide[0].supportsIdLookup, byName: fide[0].supportsNameSearch });
}
export function queryPlan(query, capabilities) {
  if (typeof query !== 'string') fail('INVALID_QUERY');
  const normalized = query.trim();
  if (normalized.length < 2 || normalized.length > 80 || /[\u0000-\u001f\u007f]/.test(normalized)) fail('INVALID_QUERY');
  const idMode = /^[0-9]+$/.test(normalized);
  if (idMode && normalized.length > 12) fail('INVALID_QUERY');
  if (!capabilities || !(idMode ? capabilities.byId : capabilities.byName)) fail('UNSUPPORTED_SEARCH');
  let encoded; try { encoded = encodeURIComponent(normalized); } catch { fail('INVALID_QUERY'); }
  return { query: normalized, key: (idMode ? 'id:' : 'name:') + normalized,
    path: `/api/external-players/search?source=Fide&query=${encoded}` };
}
function profile(row) {
  if (!row || (row.source !== 0 && row.source !== 'Fide')) fail('INVALID_PROFILE');
  const id = row.fideId ?? row.externalId;
  if (typeof id !== 'string' || !/^[0-9]{1,12}$/.test(id) || typeof row.name !== 'string' || row.name.length < 1 || row.name.length > 200) fail('INVALID_PROFILE');
  const result = { name: row.name, fideId: id };
  if (row.externalId && row.externalId !== id) fail('INVALID_PROFILE');
  for (const key of ['title','federation','retrievedAt']) {
    if (row[key] !== null && row[key] !== undefined && (typeof row[key] !== 'string' || row[key].length > 80)) fail('INVALID_PROFILE');
    result[key] = row[key] ?? null;
  }
  for (const key of ['elo','rapidElo','blitzElo']) {
    if (row[key] !== null && row[key] !== undefined && (!Number.isInteger(row[key]) || row[key] < 0 || row[key] > 5000)) fail('INVALID_PROFILE');
    result[key] = row[key] ?? null;
  }
  // Metadata, URLs, notes, birth years and raw backend messages are deliberately not copied.
  return Object.freeze(result);
}
export function lookupResult(value) {
  const states = ['Found','NotFound','Unsupported','Unavailable','InvalidRequest'];
  const status = Number.isInteger(value?.status) ? states[value.status] : value?.status;
  if ((value?.source !== 0 && value?.source !== 'Fide') || !states.includes(status) || !Array.isArray(value.players) || value.players.length > 100) fail('INVALID_LOOKUP');
  if (status !== 'Found' && value.players.length !== 0) fail('INVALID_LOOKUP');
  const players = value.players.map(profile), ids = new Set();
  for (const player of players) { if (ids.has(player.fideId)) fail('DUPLICATE_PROFILE'); ids.add(player.fideId); }
  return Object.freeze({ status, players: Object.freeze(players) });
}
export function compareCandidates(candidates) {
  if (!Array.isArray(candidates) || candidates.length > 4) fail('COMPARE_LIMIT');
  return fields.map(key => ({ key, values: candidates.map(item => item[key] ?? null),
    different: new Set(candidates.map(item => item[key] ?? null)).size > 1 }));
}
/** Bounded, in-memory lookup workspace. No automatic search, merging or field updates. */
export function createFideWorkbench(api, { now = Date.now } = {}) {
  let capabilities = null, current = null, generation = 0, active = null;
  const cache = new Map(), pinned = new Map();
  const cancel = () => { generation++; active?.abort(); active = null; current = null; };
  async function initialize() {
    cancel(); capabilities = null; cache.clear();
    const ticket = generation, controller = new AbortController(); active = controller;
    try { const result = fideCapabilities(await api.json('/api/external-players/providers', { signal: controller.signal }));
      if (ticket !== generation) fail('CANCELLED'); capabilities = result; return result;
    } finally { if (active === controller) active = null; }
  }
  async function search(query, force = false) {
    const plan = queryPlan(query, capabilities); cancel(); const ticket = generation, time = now();
    const saved = cache.get(plan.key);
    if (!force && saved && time >= saved.fetchedAt && time - saved.fetchedAt <= 300000) {
      current = saved; return { ...saved, cached: true };
    }
    cache.delete(plan.key);
    const controller = new AbortController(); active = controller;
    try {
      const result = lookupResult(await api.json(plan.path, { signal: controller.signal, maxBytes: 1024 * 1024 }));
      if (generation !== ticket) fail('CANCELLED');
      if (/^id:/.test(plan.key) && result.players.some(row => row.fideId !== plan.query)) fail('ID_MISMATCH');
      current = Object.freeze({ ...result, fetchedAt: now(), query: plan.query });
      if (result.status === 'Found' || result.status === 'NotFound') {
        cache.set(plan.key, current); while (cache.size > 10) cache.delete(cache.keys().next().value);
      }
      return { ...current, cached: false };
    } finally { if (active === controller) active = null; }
  }
  function pin(id) {
    const item = current?.players.find(player => player.fideId === id);
    if (!item) fail('NO_CANDIDATE');
    if (pinned.has(id)) return;
    if (pinned.size >= 4) fail('COMPARE_LIMIT');
    pinned.set(id, Object.freeze({ ...item }));
  }
  return { initialize, search, cancel, pin, remove: id => pinned.delete(id),
    candidates: () => [...pinned.values()], clear() { cancel(); cache.clear(); pinned.clear(); },
    dispose() { cancel(); cache.clear(); pinned.clear(); capabilities = null; } };
}
