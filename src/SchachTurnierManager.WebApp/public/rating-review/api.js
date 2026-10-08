/** Limited GET-only transport for the existing tournament and FIDE-ID routes. */
export class RatingReviewError extends Error {
  constructor(code) { super(code); this.name = 'RatingReviewError'; this.code = code; }
}
export function requireGuid(value) {
  if (typeof value !== 'string' || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value) || /^0{8}-0{4}-0{4}-0{4}-0{12}$/.test(value)) throw new RatingReviewError('INVALID_ID');
  return value.toLowerCase();
}
export function fideId(value) {
  return typeof value === 'string' && /^[1-9][0-9]{0,11}$/.test(value.trim()) ? value.trim() : null;
}
function allowed(path) {
  if (path === '/api/tournaments') return true;
  if (/^\/api\/tournaments\/[0-9a-f-]{36}$/.test(path)) return !!requireGuid(path.slice('/api/tournaments/'.length));
  return /^\/api\/external-players\/fide\/[1-9][0-9]{0,11}$/.test(path);
}
export function createRatingApi(fetcher = globalThis.fetch) {
  if (typeof fetcher !== 'function') throw new RatingReviewError('INVALID_TRANSPORT');
  return { async get(path, { signal, timeoutMs = 8000, maximumBytes = 5 * 1024 * 1024 } = {}) {
    if (typeof path !== 'string' || !allowed(path)) throw new RatingReviewError('UNSUPPORTED_ROUTE');
    if (!Number.isSafeInteger(timeoutMs) || timeoutMs < 1 || timeoutMs > 8000 ||
        !Number.isSafeInteger(maximumBytes) || maximumBytes < 1 || maximumBytes > 5 * 1024 * 1024) throw new RatingReviewError('INVALID_LIMIT');
    if (signal?.aborted) throw new RatingReviewError('CANCELLED');
    const controller = new AbortController(); let reader, reason, rejectInterrupt;
    const interrupted = new Promise((_, reject) => { rejectInterrupt = reject; });
    interrupted.catch(() => {});
    const interrupt = code => {
      if (reason) return;
      reason = code; controller.abort(); rejectInterrupt(new RatingReviewError(code));
    };
    const onAbort = () => interrupt('CANCELLED');
    const timer = setTimeout(() => interrupt('TIMEOUT'), timeoutMs);
    signal?.addEventListener('abort', onAbort, { once: true });
    const race = promise => Promise.race([promise, interrupted]);
    try {
      const response = await race(fetcher(path, { method: 'GET', credentials: 'omit', redirect: 'error', cache: 'no-store',
        referrerPolicy: 'no-referrer', headers: { Accept: 'application/json' }, signal: controller.signal }));
      if (reason) throw new RatingReviewError(reason);
      if (!response.ok) throw new RatingReviewError('HTTP_ERROR');
      if (response.redirected || response.headers.get('content-type')?.split(';')[0].trim().toLowerCase() !== 'application/json' || !response.body) throw new RatingReviewError('INVALID_RESPONSE');
      const declared = response.headers.get('content-length');
      if (declared !== null && (!/^\d+$/.test(declared) || Number(declared) > maximumBytes)) throw new RatingReviewError('RESPONSE_TOO_LARGE');
      reader = response.body.getReader(); const chunks = []; let length = 0;
      for (;;) {
        const item = await race(reader.read());
        if (item.done) break;
        if (!(item.value instanceof Uint8Array)) throw new RatingReviewError('INVALID_RESPONSE');
        length += item.value.length;
        if (length > maximumBytes || chunks.length >= 65536) throw new RatingReviewError('RESPONSE_TOO_LARGE');
        chunks.push(item.value);
      }
      if (reason) throw new RatingReviewError(reason);
      const bytes = new Uint8Array(length); let offset = 0;
      for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
      try { return JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(bytes)); }
      catch { throw new RatingReviewError('INVALID_RESPONSE'); }
    } catch (error) {
      if (reason) throw new RatingReviewError(reason);
      if (error instanceof RatingReviewError) throw error;
      throw new RatingReviewError('NETWORK_ERROR');
    } finally {
      clearTimeout(timer); signal?.removeEventListener('abort', onAbort);
      if (reader) { try { void reader.cancel().catch(() => {}); reader.releaseLock(); } catch { /* Never mask the original failure. */ } }
    }
  } };
}
export function errorText(error) {
  const messages = { INVALID_ID: 'Bitte ein gueltiges Turnier auswaehlen.',
    INVALID_SELECTION: 'Bitte 1 bis 20 Spieler mit eindeutigen gueltigen FIDE-IDs auswaehlen.',
    DUPLICATE_FIDE_ID: 'Die Auswahl enthaelt dieselbe FIDE-ID mehrfach. Identitaeten zuerst pruefen.',
    CANCELLED: 'Vorgang abgebrochen.', TIMEOUT: 'Zeitlimit erreicht.', HTTP_ERROR: 'Server hat die Anfrage abgelehnt.',
    NETWORK_ERROR: 'Turnierserver nicht erreichbar.', RESPONSE_TOO_LARGE: 'Antwort ist zu gross fuer diese Ansicht.' };
  return Object.hasOwn(messages, error?.code) ? messages[error.code] : 'Daten konnten nicht sicher verarbeitet werden.';
}
