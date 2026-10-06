import { RatingReviewError, requireGuid, fideId } from './api.js';
const fail = code => { throw new RatingReviewError(code); };
const object = value => value !== null && typeof value === 'object' && !Array.isArray(value);
const fields = ['elo', 'rapidElo', 'blitzElo'];
function name(value) {
  if (typeof value !== 'string' || value.length > 300 || !value.trim()) fail('INVALID_DATA');
  return value;
}
function rating(value) {
  if (value == null) return null;
  if (!Number.isInteger(value) || value < 0 || value > 5000) fail('INVALID_DATA');
  return value;
}
const cancelled = signal => { if (signal?.aborted) fail('CANCELLED'); };
export function tournamentOptions(value) {
  if (!Array.isArray(value) || value.length > 1000) fail('INVALID_DATA');
  const ids = new Set();
  return value.map(raw => {
    const id = requireGuid(raw?.id);
    if (ids.has(id)) fail('INVALID_DATA');
    ids.add(id); return { id, name: name(raw.name) };
  });
}
export function tournamentPlayers(value, expectedId) {
  const id = requireGuid(value?.id);
  if (id !== requireGuid(expectedId) || !Array.isArray(value.players) || value.players.length > 5000) fail('INVALID_DATA');
  const ids = new Set();
  return Object.freeze(value.players.map(raw => {
    const playerId = requireGuid(raw?.id);
    if (ids.has(playerId) || (raw.rating != null && !object(raw.rating))) fail('INVALID_DATA');
    ids.add(playerId);
    return Object.freeze({ id: playerId, name: name(raw.name), fideId: fideId(raw.fideId),
      ...Object.fromEntries(fields.map(key => [key, rating(raw.rating?.[key])])) });
  }));
}
function selectedPlayers(players, selection) {
  if (!Array.isArray(players) || players.length > 5000 || !Array.isArray(selection) || selection.length < 1 || selection.length > 20) fail('INVALID_SELECTION');
  const byId = new Map(players.map(player => [player.id, player]));
  if (byId.size !== players.length) fail('INVALID_SELECTION');
  const seen = new Set(), fides = new Set();
  return selection.map(value => {
    const id = requireGuid(value), player = byId.get(id);
    if (seen.has(id) || !player || !fideId(player.fideId)) fail('INVALID_SELECTION');
    const normalizedFideId = fideId(player.fideId);
    if (fides.has(normalizedFideId)) fail('DUPLICATE_FIDE_ID');
    seen.add(id); fides.add(normalizedFideId);
    return Object.freeze({ ...player, fideId: normalizedFideId });
  });
}
function sourceResult(value, expectedFideId) {
  if (!object(value) || ![0, 'Fide'].includes(value.source)) fail('INVALID_PROFILE');
  const states = ['Found', 'NotFound', 'Unsupported', 'Unavailable', 'InvalidRequest'];
  const state = Number.isInteger(value.status) ? states[value.status] : states.includes(value.status) ? value.status : null;
  if (!state || !Array.isArray(value.players)) fail('INVALID_PROFILE');
  if (state !== 'Found') {
    if (value.players.length !== 0) fail('INVALID_PROFILE');
    return { state };
  }
  if (value.players.length !== 1) fail('INVALID_PROFILE');
  const raw = value.players[0];
  if (!object(raw) || ![0, 'Fide'].includes(raw.source) || fideId(raw.fideId) !== expectedFideId ||
      (raw.externalId != null && fideId(raw.externalId) !== expectedFideId)) fail('IDENTITY_MISMATCH');
  const retrievedAt = raw.retrievedAt;
  if (typeof retrievedAt !== 'string' || retrievedAt.length > 64 || !/^\d{4}-\d{2}-\d{2}T/.test(retrievedAt) || !Number.isFinite(Date.parse(retrievedAt))) fail('INVALID_PROFILE');
  return { state, name: name(raw.name), retrievedAt,
    ...Object.fromEntries(fields.map(key => [key, rating(raw[key])])) };
}
export async function reviewRatings(players, selection, api, { signal, onProgress } = {}) {
  const chosen = selectedPlayers(players, selection); cancelled(signal);
  const results = [];
  for (const player of chosen) {
    cancelled(signal);
    let row;
    try {
      const response = await api.get(`/api/external-players/fide/${player.fideId}`, { signal, maximumBytes: 65536 });
      cancelled(signal);
      const remote = sourceResult(response, player.fideId);
      if (remote.state !== 'Found') {
        row = { player, status: remote.state, changes: [], unknownFields: [], identityReviewRequired: false, retrievedAt: null };
      } else {
        const changes = [], unknownFields = [];
        for (const key of fields) {
          // A missing or unrated source value never becomes a deletion proposal.
          if (remote[key] === null || remote[key] === 0) unknownFields.push(key);
          else if (remote[key] !== player[key]) changes.push({ field: key, before: player[key], after: remote[key] });
        }
        row = { player, status: changes.length ? 'Changes' : unknownFields.length ? 'Incomplete' : 'Unchanged',
          changes, unknownFields, identityReviewRequired: remote.name.normalize('NFC').trim().toLowerCase() !== player.name.normalize('NFC').trim().toLowerCase(),
          retrievedAt: remote.retrievedAt };
      }
    } catch (error) {
      if (signal?.aborted || error?.code === 'CANCELLED') fail('CANCELLED');
      row = { player, status: error?.code === 'IDENTITY_MISMATCH' ? 'IdentityMismatch' : 'Failed',
        changes: [], unknownFields: [], identityReviewRequired: false, retrievedAt: null };
    }
    results.push(row); onProgress?.({ completed: results.length, total: chosen.length });
  }
  cancelled(signal);
  return results;
}
