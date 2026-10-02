/** One explicit, bounded same-origin health request; no polling or telemetry. */
const MAX_BODY_BYTES = 16384;
class HealthReplyError extends Error { constructor(code) { super(code); this.code = code; } }
const fault = code => new HealthReplyError(code);
async function readReply(response, controller) {
  if (!response.ok) throw fault('HTTP_ERROR');
  if (response.redirected || !/^application\/json(?:\s*;|$)/i.test(response.headers.get('content-type') ?? '')) throw fault('UNEXPECTED_REPLY');
  const length = response.headers.get('content-length');
  if (length && (!/^\d+$/.test(length) || Number(length) > MAX_BODY_BYTES)) throw fault('UNEXPECTED_REPLY');
  if (!response.body || typeof response.body.getReader !== 'function') throw fault('UNEXPECTED_REPLY');
  const reader = response.body.getReader();
  const stop = () => { void reader.cancel().catch(() => {}); };
  controller.signal.addEventListener('abort', stop, { once: true });
  if (controller.signal.aborted) stop();
  let count = 0, text = '';
  const decoder = new TextDecoder('utf-8', { fatal: true });
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (controller.signal.aborted) throw fault('CANCELLED');
      if (done) break;
      if (!(value instanceof Uint8Array)) throw fault('UNEXPECTED_REPLY');
      count += value.byteLength;
      if (count > MAX_BODY_BYTES) throw fault('UNEXPECTED_REPLY');
      text += decoder.decode(value, { stream: true });
    }
    text += decoder.decode();
    const reply = JSON.parse(text);
    if (!reply || reply.app !== 'SchachTurnierManager' || reply.status !== 'ok') throw fault('UNEXPECTED_REPLY');
    // No database paths, logging configuration, raw body or version are returned.
    return { status: 'REACHABLE' };
  } catch (failure) {
    if (failure instanceof HealthReplyError) throw failure;
    throw fault('UNEXPECTED_REPLY');
  } finally {
    controller.signal.removeEventListener('abort', stop);
    void reader.cancel().catch(() => {});
    reader.releaseLock();
  }
}
export async function checkBackend({ fetchImpl = globalThis.fetch, signal, timeoutMs = 5000, schedule = setTimeout, unschedule = clearTimeout } = {}) {
  if (typeof fetchImpl !== 'function' || !Number.isInteger(timeoutMs) || timeoutMs < 1 || timeoutMs > 10000) throw fault('INVALID_OPTIONS');
  if (signal?.aborted) return { status: 'CANCELLED' };
  const controller = new AbortController();
  let timer, rejectStop;
  const stopped = new Promise((_, reject) => { rejectStop = reject; });
  const stop = code => { rejectStop(fault(code)); controller.abort(); };
  const onAbort = () => stop('CANCELLED');
  signal?.addEventListener('abort', onAbort, { once: true });
  try {
    timer = schedule(() => stop('TIMEOUT'), timeoutMs);
    const work = (async () => {
      const response = await fetchImpl('/api/health', {
        method: 'GET', mode: 'same-origin', credentials: 'omit', cache: 'no-store',
        redirect: 'error', referrerPolicy: 'no-referrer', headers: { Accept: 'application/json' }, signal: controller.signal,
      });
      return readReply(response, controller);
    })();
    return await Promise.race([work, stopped]);
  } catch (failure) {
    const known = ['TIMEOUT', 'CANCELLED', 'HTTP_ERROR', 'UNEXPECTED_REPLY'];
    return { status: failure instanceof HealthReplyError && known.includes(failure.code) ? failure.code : 'NETWORK_ERROR' };
  } finally {
    unschedule(timer);
    signal?.removeEventListener('abort', onAbort);
    controller.abort();
  }
}
