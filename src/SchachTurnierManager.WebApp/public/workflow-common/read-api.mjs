/** Read-only, same-origin API transport. No writes, redirects or credential forwarding. */
export class ReadError extends Error {
  constructor(code, status = null) { super(code); this.name = 'ReadError'; this.code = code; this.status = status; }
}
export const GUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export function requireId(value) {
  if (typeof value !== 'string' || !GUID.test(value) || /^0{8}-0{4}-0{4}-0{4}-0{12}$/.test(value)) throw new ReadError('INVALID_ID');
  return value.toLowerCase();
}
function allowedPath(path) {
  if (path === '/api/tournaments' || path === '/api/external-players/providers') return true;
  if (/^\/api\/tournaments\/[0-9a-f-]{36}\/(?:standings|export\/json)$/.test(path)) {
    requireId(path.split('/')[3]); return true;
  }
  return /^\/api\/external-players\/search\?source=Fide&query=(?:[A-Za-z0-9_.!~*'()-]|%[0-9A-F]{2}){1,720}$/.test(path);
}
export function createReadApi(fetcher = globalThis.fetch, { timeoutMs = 8000, timers = globalThis } = {}) {
  if (typeof fetcher !== 'function' || !Number.isInteger(timeoutMs) || timeoutMs < 1 || timeoutMs > 30000) throw new ReadError('INVALID_TRANSPORT');
  async function document(path, { signal, maxBytes = 5 * 1024 * 1024 } = {}) {
    if (typeof path !== 'string' || !allowedPath(path)) throw new ReadError('PATH_NOT_ALLOWED');
    if (!Number.isSafeInteger(maxBytes) || maxBytes < 1 || maxBytes > 16 * 1024 * 1024) throw new ReadError('INVALID_LIMIT');
    const controller = new AbortController();
    let abortCode = 'CANCELLED', reader, timer, onAbort;
    const cancel = () => controller.abort();
    const aborted = new Promise((_, reject) => {
      onAbort = () => reject(new ReadError(abortCode));
      controller.signal.addEventListener('abort', onAbort, { once: true });
    });
    // All awaited transport/body operations share one deadline, including stalled streams.
    const wait = promise => Promise.race([promise, aborted]);
    signal?.addEventListener('abort', cancel, { once: true });
    timer = timers.setTimeout(() => { abortCode = 'TIMEOUT'; controller.abort(); }, timeoutMs);
    try {
      if (signal?.aborted) throw new ReadError('CANCELLED');
      const response = await wait(Promise.resolve().then(() => fetcher(path, {
        method: 'GET', mode: 'same-origin', credentials: 'omit', redirect: 'error',
        cache: 'no-store', referrerPolicy: 'no-referrer', headers: { Accept: 'application/json' }, signal: controller.signal,
      })));
      if (response.redirected || response.type === 'opaqueredirect') throw new ReadError('REDIRECT');
      if (!response.ok) throw new ReadError('HTTP_ERROR', response.status);
      if (!/^application\/json(?:\s*;|$)/i.test(response.headers.get('content-type') ?? '')) throw new ReadError('CONTENT_TYPE');
      const size = response.headers.get('content-length');
      if (size !== null && (!/^\d+$/.test(size) || Number(size) > maxBytes)) throw new ReadError('RESPONSE_TOO_LARGE');
      if (!response.body?.getReader) throw new ReadError('EMPTY_RESPONSE');
      reader = response.body.getReader();
      const decoder = new TextDecoder('utf-8', { fatal: true, ignoreBOM: true });
      let text = '', count = 0;
      for (;;) {
        const { value, done } = await wait(reader.read());
        if (done) break;
        count += value.byteLength;
        if (count > maxBytes) throw new ReadError('RESPONSE_TOO_LARGE');
        try { text += decoder.decode(value, { stream: true }); } catch { throw new ReadError('INVALID_UTF8'); }
      }
      try { text += decoder.decode(); } catch { throw new ReadError('INVALID_UTF8'); }
      let value;
      try { value = JSON.parse(text.replace(/^\uFEFF/, '')); } catch { throw new ReadError('INVALID_JSON'); }
      return { text, value, bytes: count };
    } catch (error) {
      if (controller.signal.aborted) throw new ReadError(abortCode);
      throw error instanceof ReadError ? error : new ReadError('NETWORK_ERROR');
    } finally {
      timers.clearTimeout(timer); signal?.removeEventListener('abort', cancel);
      controller.signal.removeEventListener('abort', onAbort);
      controller.abort();
      try { Promise.resolve(reader?.cancel()).catch(() => {}); } catch { /* Best-effort transport cleanup. */ }
    }
  }
  return { document, json: async (path, options) => (await document(path, options)).value };
}
export function tournamentChoices(value) {
  if (!Array.isArray(value) || value.length > 1000) throw new ReadError('INVALID_TOURNAMENT_LIST');
  const seen = new Set();
  return value.map(item => {
    const id = requireId(item?.id);
    if (seen.has(id) || typeof item?.name !== 'string' || item.name.length > 300) throw new ReadError('INVALID_TOURNAMENT_LIST');
    seen.add(id); return Object.freeze({ id, name: item.name });
  });
}
export function errorText(error) {
  const messages = { CANCELLED: 'Vorgang abgebrochen.', TIMEOUT: 'Zeitlimit erreicht. Bitte Verbindung pruefen.',
    NETWORK_ERROR: 'Turnierserver nicht erreichbar.', HTTP_ERROR: 'Der Turnierserver hat die Anfrage abgelehnt.',
    RESPONSE_TOO_LARGE: 'Antwort zu gross fuer diese Ansicht.' };
  return Object.hasOwn(messages, error?.code) ? messages[error.code] : 'Daten konnten nicht sicher verarbeitet werden.';
}
