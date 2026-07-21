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
 * Fehlertext fuer die Oberflaeche. Transportfehler bekommen eine verstaendliche
 * Erklaerung mit Handlungsanweisung statt der rohen Browsermeldung; fachliche
 * Fehler des Backends werden unveraendert durchgereicht.
 */
export function describeApiError(error: unknown, lang: string = 'de'): string {
  if (error instanceof ApiUnreachableError) {
    // Wie im uebrigen UI: Englisch nur fuer 'en', sonst Deutsch als Fallback.
    return lang === 'en'
      ? 'The local server is not responding. Please make sure SchachTurnierManager is fully started, then try again.'
      : 'Der lokale Server antwortet nicht. Bitte warten, bis der SchachTurnierManager vollstaendig gestartet ist, und es dann erneut versuchen.';
  }
  return error instanceof Error ? error.message : String(error);
}

async function fetchOrThrow(url: string, init?: RequestInit): Promise<Response> {
  try {
    return await fetch(url, init);
  } catch (cause) {
    // fetch lehnt nur bei Transportfehlern ab; HTTP-Fehlerstatus kommen als Response.
    throw new ApiUnreachableError(url, cause);
  }
}

export async function requestJson<T>(url: string, init?: RequestInit): Promise<T> {
  const response = await fetchOrThrow(url, {
    headers: { 'Content-Type': 'application/json', ...(init?.headers ?? {}) },
    ...init
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

export async function requestText(url: string): Promise<string> {
  const response = await fetchOrThrow(url);
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`);
  }
  return await response.text();
}
