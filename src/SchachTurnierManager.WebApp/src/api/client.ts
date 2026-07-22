// Minimal typed HTTP helpers for the WebApp API.
// Extracted from main.tsx (STM-FE-013) so components no longer embed transport
// code and the helpers can be reused and tested in isolation.

/**
 * Das Backend war ueber HTTP nicht erreichbar (Verbindung abgelehnt, Abbruch,
 * DNS, offline). `fetch` meldet das als nacktes `TypeError: NetworkError when
 * attempting to fetch resource`, was fuer Endnutzer unbrauchbar ist.
 */
export class ApiUnreachableError extends Error {
  // Keine Parameter-Properties: die Tests laufen ueber Nodes Type-Stripping,
  // das diese TypeScript-Kurzform nicht unterstuetzt.
  readonly url: string;

  constructor(url: string, cause?: unknown) {
    super(`API nicht erreichbar: ${url}`, { cause });
    this.name = 'ApiUnreachableError';
    this.url = url;
  }
}

/**
 * Die Anfrage lief in den Zeitausfall.
 *
 * Das ist kein theoretischer Fall: wird das lokale Backend beendet, waehrend die
 * Oberflaeche offen bleibt, laesst Firefox das anschliessende `fetch` gegen
 * 127.0.0.1 haengen, statt es abzulehnen. Ohne Zeitausfall kehrt der Handler nie
 * zurueck - kein Fehler, kein Ladezustand, keine Meldung. Fuer den Bediener sieht
 * das exakt wie eine tote Schaltflaeche aus.
 */
export class ApiTimeoutError extends Error {
  readonly url: string;
  readonly timeoutMs: number;

  constructor(url: string, timeoutMs: number, cause?: unknown) {
    super(`Zeitueberschreitung nach ${timeoutMs} ms: ${url}`, { cause });
    this.name = 'ApiTimeoutError';
    this.url = url;
    this.timeoutMs = timeoutMs;
  }
}

/**
 * Obergrenze fuer eine einzelne Anfrage an das lokale Backend.
 *
 * Bewusst grosszuegig: Auslosung und Import rechnen auf schwachen Turnierlaptops
 * durchaus einige Sekunden. Aber endlich, damit ein haengender Aufruf immer in
 * einer sichtbaren Meldung endet.
 */
export const defaultRequestTimeoutMs = 15000;

/** Kurzer Zeitausfall fuer die Bereitschaftspruefung, die zyklisch laeuft. */
export const healthProbeTimeoutMs = 3000;

export type ApiRequestInit = RequestInit & {
  /** Ueberschreibt `defaultRequestTimeoutMs` fuer diesen Aufruf. */
  timeoutMs?: number;
};

/**
 * Fehlertext fuer die Oberflaeche. Transportfehler bekommen eine verstaendliche
 * Erklaerung mit Handlungsanweisung statt der rohen Browsermeldung; fachliche
 * Fehler des Backends werden unveraendert durchgereicht.
 */
export function describeApiError(error: unknown, lang: string = 'de'): string {
  // Wie im uebrigen UI: Englisch nur fuer 'en', sonst Deutsch als Fallback.
  const english = lang === 'en';

  if (error instanceof ApiTimeoutError) {
    return english
      ? 'The local server did not answer in time. Please make sure SchachTurnierManager is still running, then try again.'
      : 'Der lokale Server hat nicht rechtzeitig geantwortet. Bitte pruefen, ob der SchachTurnierManager noch laeuft, und es dann erneut versuchen.';
  }

  if (error instanceof ApiUnreachableError) {
    return english
      ? 'The local server is not responding. Please make sure SchachTurnierManager is fully started, then try again.'
      : 'Der lokale Server antwortet nicht. Bitte warten, bis der SchachTurnierManager vollstaendig gestartet ist, und es dann erneut versuchen.';
  }

  return error instanceof Error ? error.message : String(error);
}

/** True, wenn der Fehler ein Transportproblem ist und nicht eine fachliche Ablehnung. */
export function isApiTransportError(error: unknown): boolean {
  return error instanceof ApiUnreachableError || error instanceof ApiTimeoutError;
}

async function fetchOrThrow(url: string, init?: ApiRequestInit): Promise<Response> {
  const { timeoutMs = defaultRequestTimeoutMs, ...requestInit } = init ?? {};
  const controller = new AbortController();
  // Bewusst AbortController + setTimeout statt AbortSignal.timeout/any: die
  // Kombination aus eigenem und aufrufendem Signal bleibt so ohne Feature-Test
  // in Browser und Node identisch.
  let timedOut = false;
  const timer = setTimeout(() => {
    timedOut = true;
    controller.abort();
  }, timeoutMs);

  const callerSignal = requestInit.signal ?? null;
  const forwardAbort = (): void => controller.abort();
  callerSignal?.addEventListener('abort', forwardAbort);

  try {
    return await fetch(url, { ...requestInit, signal: controller.signal });
  } catch (cause) {
    if (timedOut) {
      throw new ApiTimeoutError(url, timeoutMs, cause);
    }
    if (callerSignal?.aborted) {
      // Der Aufrufer hat selbst abgebrochen - das ist kein Backendproblem.
      throw cause;
    }
    // fetch lehnt nur bei Transportfehlern ab; HTTP-Fehlerstatus kommen als Response.
    throw new ApiUnreachableError(url, cause);
  } finally {
    clearTimeout(timer);
    callerSignal?.removeEventListener('abort', forwardAbort);
  }
}

export async function requestJson<T>(url: string, init?: ApiRequestInit): Promise<T> {
  // Reihenfolge beachten: `...init` zuerst, sonst wuerde ein eigenes `headers`
  // des Aufrufers die zusammengefuehrten Header wieder komplett ersetzen.
  const response = await fetchOrThrow(url, {
    ...init,
    headers: { 'Content-Type': 'application/json', ...(init?.headers ?? {}) }
  });
  if (!response.ok) {
    let message = `HTTP ${response.status}`;
    try {
      const body = await response.json() as { error?: string };
      message = body.error ?? message;
    } catch {
      // ignore non-json error body
    }
    throw new Error(message);
  }
  return await response.json() as T;
}

export async function requestText(url: string, init?: ApiRequestInit): Promise<string> {
  const response = await fetchOrThrow(url, init);
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`);
  }
  return await response.text();
}
