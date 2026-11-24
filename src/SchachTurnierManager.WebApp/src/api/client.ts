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
/** Exceeds the largest configured FIDE search budget, including transport overhead. */
export const pairingRequestTimeoutMs = 130000;

/** Kurzer Zeitausfall fuer die Bereitschaftspruefung, die zyklisch laeuft. */
export const healthProbeTimeoutMs = 3000;

export type ApiRequestInit = RequestInit & {
  /** Ueberschreibt `defaultRequestTimeoutMs` fuer diesen Aufruf. */
  timeoutMs?: number;
};

export class ApiResponseError extends Error {
  readonly status: number;
  readonly code?: string;
  constructor(status: number, message: string, code?: string) {
    super(message);
    this.name = 'ApiResponseError';
    this.status = status;
    this.code = code;
  }
}

const ruleErrorEnglishMessages: Readonly<Record<string, string>> = {
  "AUDIT_ACTION_INVALID": "Choose a supported audit action filter.",
  "AUDIT_SEVERITY_INVALID": "Choose a supported audit severity filter.",
  "EXTERNAL_SOURCE_INVALID": "Choose a supported external player source.",
  "ARMAGEDDON_BID_NEGATIVE": "Bidding times cannot be negative.",
  "BACKUP_AUDIT_ENTRY_INVALID": "The imported audit journal contains an empty entry or missing required text.",
  "BACKUP_AUDIT_MISSING": "The imported tournament has no audit journal. The backup cannot be restored.",
  "BACKUP_BLACK_PLAYER_MISSING": "An imported regular pairing is missing its Black player.",
  "BACKUP_BOARD_DUPLICATE": "An imported round contains a duplicate board number.",
  "BACKUP_BOARD_EMPTY": "An imported round contains an empty board entry.",
  "BACKUP_BOARD_NUMBER_INVALID": "An imported round contains an invalid board number.",
  "BACKUP_CHESS960_TEXT_MISSING": "An imported board is missing required Chess960 text.",
  "BACKUP_EXTERNAL_ID_DUPLICATE": "The imported participants contain a duplicate external player ID. Review the existing participant records.",
  "BACKUP_FORENSIC_BOARDS_INVALID": "An imported round has an incomplete forensic board list.",
  "BACKUP_FORENSIC_TEXT_INVALID": "An imported round has incomplete forensic text.",
  "BACKUP_PAIRING_PLAYER_UNKNOWN": "An imported pairing refers to a player who is not in the participant list.",
  "BACKUP_PAIRINGS_MISSING": "An imported round has no pairing list.",
  "BACKUP_PARTICIPANT_EMPTY": "The imported participant list contains an empty entry.",
  "BACKUP_PARTICIPANT_ID_DUPLICATE": "The imported participant list contains a duplicate participant ID.",
  "BACKUP_PARTICIPANT_ID_INVALID": "An imported participant has no valid ID.",
  "BACKUP_PARTICIPANT_NAME_MISSING": "An imported participant has no name.",
  "BACKUP_PARTICIPANTS_MISSING": "The imported tournament has no participant list. The backup cannot be restored.",
  "BACKUP_RATING_PROFILE_MISSING": "An imported participant has no rating profile.",
  "BACKUP_RESULT_INVALID": "An imported board has a missing or invalid result.",
  "BACKUP_RESULT_RECEIPTS_INVALID": "The imported tournament contains invalid offline-result confirmations. The backup cannot be restored.",
  "BACKUP_ROUND_AUDIT_INVALID": "An imported round has an incomplete audit snapshot.",
  "BACKUP_ROUND_EMPTY": "The imported round list contains an empty round.",
  "BACKUP_ROUND_SEQUENCE_INVALID": "Imported rounds must be numbered consecutively starting at 1. Review the backup before restoring it.",
  "BACKUP_ROUNDS_MISSING": "The imported tournament has no round list. The backup cannot be restored.",
  "BACKUP_SETTINGS_MISSING": "The imported tournament has no settings. The backup cannot be restored.",
  "BACKUP_SNAPSHOT_COPY_FAILED": "The imported tournament snapshot could not be copied. Existing data has not been replaced.",
  "BACKUP_TEXT_LIST_INVALID": "An imported audit or forensic text list is missing or contains an empty text value.",
  "BACKUP_TOO_MANY_ROUNDS": "The imported tournament contains more rounds than its planned round count allows.",
  "BACKUP_TOURNAMENT_ID_INVALID": "The imported tournament has no valid ID. The backup cannot be restored.",
  "BACKUP_TOURNAMENT_NAME_MISSING": "The imported tournament has no name. The backup cannot be restored.",
  "BOARD_NOT_FOUND": "The requested board was not found in the round. Reload the current tournament data.",
  "CHESS960_BACK_RANK_INVALID": "The Chess960 back rank is invalid.",
  "CHESS960_BOARD_OVERWRITE_REQUIRED": "This board already has a saved Chess960 position. Review and explicitly confirm replacement before saving a new position.",
  "CHESS960_BYE_BOARD": "A bye board does not receive a Chess960 starting position.",
  "CHESS960_POSITION_RANGE": "The Chess960 position number must be between 0 and 959.",
  "CHESS960_REGULAR_BOARD_REQUIRED": "The round has no regular board that can receive a Chess960 starting position.",
  "CHESS960_ROUND_LOCKED": "The round is locked or reviewed. Its Chess960 starting positions cannot be changed.",
  "CHESS960_ROUND_OVERWRITE_REQUIRED": "This round already has saved Chess960 positions. Review and explicitly confirm replacement before saving new positions.",
  "CSV_SEPARATOR_INVALID": "The selected CSV separator is not supported.",
  "EXTERNAL_PLAYER_NAME_MISSING": "The external player profile has no name.",
  "EXTERNAL_PLAYER_TARGET_REQUIRED": "Select an existing participant or explicitly allow creating a new one.",
  "FIDE_DOWNFLOAT_COUNT_INVALID": "The FIDE Dutch downfloat count is outside the supported range. Review the pairing configuration.",
  "FIDE_PAIRING_IMPOSSIBLE": "No pairing satisfies the FIDE Dutch criteria for this round (C.04.3 Art. 1.9.3). The arbiter must decide: make manual pairings and record the reason in the audit.",
  "FIDE_PLAYER_LIMIT_INVALID": "The FIDE Dutch player limit must remain within the conservative supported bounds.",
  "FIDE_RECURSION_LIMIT_INVALID": "The FIDE Dutch recursion limit must remain within the conservative supported bounds.",
  "FIDE_RESOURCE_LIMIT_INVALID": "The FIDE Dutch resource limit must be positive. Review the pairing configuration.",
  "FIDE_SEARCH_BUDGET_NEGATIVE": "FIDE Dutch search budgets cannot be negative.",
  "IMPORT_UNICODE_INVALID": "The import file contains invalid Unicode data for its byte-order mark.",
  "MANUAL_PAIRING_DISABLED": "Manual pairing changes are disabled in the tournament settings.",
  "PAIRING_MINIMUM_PLAYERS": "At least two active players are required for pairing.",
  "PAIRING_PLAYER_DUPLICATE": "A player cannot appear more than once in the same round.",
  "PAIRING_PLAYER_REQUIRED": "Select at least one player for the pairing.",
  "PAIRING_SELF_OPPONENT": "A player cannot be paired against themselves.",
  "PAIRING_WHITE_REQUIRED": "A board requires a White player. For a bye, set the player as White and leave Black empty.",
  "PARTICIPANT_REPLACEMENT_LOCKED": "Participants cannot be replaced entirely after rounds have been paired. Add participants or create a new tournament instead.",
  "PLANNED_ROUND_LIMIT": "The planned maximum number of rounds has already been reached.",
  "PLAYER_FIDE_ID_DUPLICATE": "A participant with this FIDE ID already exists. Edit the existing participant instead of creating a duplicate.",
  "PLAYER_INACTIVE": "The selected player is inactive and cannot be paired.",
  "PLAYER_NAME_DUPLICATE": "The same player name appears more than once. Edit the existing participant or correct the import before continuing.",
  "PLAYER_NAME_REQUIRED": "Enter a participant name.",
  "PLAYER_NATIONAL_ID_DUPLICATE": "A participant with this national ID already exists. Edit the existing participant instead of creating a duplicate.",
  "PLAYER_NOT_FOUND": "The requested participant was not found. Reload the current tournament data.",
  "PREVIOUS_ROUND_INCOMPLETE": "The previous round has pending results. Complete or correct them before continuing.",
  "QUEUED_RESULT_INVALID": "The queued result contains invalid required values. Review the entry before replaying it.",
  "RESULT_BYE_MISMATCH": "A bye result is only valid for a board without a Black player, and such a board must be recorded as a bye.",
  "RESULT_CHANGED": "The board result changed since it was loaded. Reload the tournament and review the correction again.",
  "RESULT_REASON_TOO_LONG": "The reason for the correction is too long. Shorten it to at most 500 characters and save again.",
  "RESULT_RECEIPT_LIMIT": "The confirmation limit for offline results has been reached. Contact the tournament director.",
  "RESULT_TIMESTAMP_LIMIT": "The stored result timestamp is at the supported range boundary. Review the data; the change was not saved.",
  "RESULT_VALUE_INVALID": "The result or its expected previous value is invalid.",
  "ROUND_LOCKED": "The round is locked or reviewed and can no longer be changed.",
  "ROUND_NOT_FOUND": "The requested round was not found. Reload the current tournament data.",
  "ROUND_REVIEW_RESULTS_PENDING": "All board results must be entered before the round can be marked as reviewed.",
  "ROUND_ROBIN_COMPLETE": "All rounds of the round-robin schedule have already been generated.",
  "ROUND_ROBIN_HISTORY_INVALID": "The saved round-robin history is inconsistent or cannot be reconstructed unambiguously. Review all existing rounds and preserve a backup before continuing. No automatic replan has been applied.",
  "ROUND_ROBIN_PARTICIPANTS_CHANGED": "The active participant set changed after the round-robin schedule was fixed. Review added or withdrawn players. Any deliberate replanning requires a reset or a new tournament so that played rounds remain unchanged.",
  "ROUND_ROBIN_PARTICIPANTS_MISMATCH": "The active participants do not match the saved round-robin schedule. Review the participant set explicitly before continuing.",
  "ROUND_ROBIN_PLAN_FORMAT_MISMATCH": "A saved round-robin schedule can only belong to a round-robin tournament.",
  "TOURNAMENT_FORMAT_LOCKED": "The tournament format cannot be changed after rounds have been paired.",
  "TOURNAMENT_FORMAT_UNSUPPORTED": "The selected tournament format is not supported.",
  "TOURNAMENT_NAME_REQUIRED": "Enter a tournament name.",
  "TOURNAMENT_NOT_FOUND": "The requested tournament was not found. Reload the tournament list.",
  "TRF_FIELD_OVERLAP": "A TRF16 field would be overwritten by an earlier field that is too long. Review the export data.",
  "TRF_FIELD_TOO_WIDE": "A TRF16 value exceeds the permitted field width. Review the export data.",
};

/**
 * Fehlertext fuer die Oberflaeche. Transportfehler bekommen eine verstaendliche
 * Erklaerung mit Handlungsanweisung statt der rohen Browsermeldung. Bekannte
 * fachliche Codes erhalten englische Texte; sonst bleibt der Backendtext erhalten.
 */
export function describeApiError(error: unknown, lang: string = 'de'): string {
  // Wie im uebrigen UI: Englisch nur fuer 'en', sonst Deutsch als Fallback.
  const english = lang === 'en';

  if (error instanceof ApiResponseError) {
    const ruleMessage = error.code && Object.hasOwn(ruleErrorEnglishMessages, error.code)
      ? ruleErrorEnglishMessages[error.code] : undefined;
    if (english && ruleMessage) return ruleMessage;
    const messages: Record<string, [string, string]> = {
      FIDE_LIST_INVALID: ['Die Standard-TXT-Liste ist ungültig oder zu groß. Die bisherige Liste bleibt erhalten.', 'The standard TXT list is invalid or too large. The previous list is preserved.'],
      FIDE_LIST_FORMAT: ['Eine entpackte Standard-TXT-Liste auswählen.', 'Choose an unpacked standard TXT list.'],
      FIDE_LIST_TIMEOUT: ['Der Listenimport dauerte zu lange. Die bisherige Liste bleibt erhalten.', 'The list import took too long. The previous list is preserved.'],
      EXTERNAL_PLAYER_STALE: ['Der Zielspieler wurde seit der Vorschau geändert. Aktuelle Werte laden und Felder erneut bestätigen.', 'The target player changed since the review. Load the current values and confirm the fields again.'],
    };
    if (error.code && messages[error.code]) return messages[error.code][english ? 1 : 0];
    if (error.status === 403) return english
      ? 'This connection is not allowed by the local server. Open the app on its computer or ask the operator to authorize secure network access.'
      : 'Diese Verbindung ist am lokalen Server nicht erlaubt. Die App auf ihrem Computer öffnen oder den Betreiber um sicheren Netzwerkzugriff bitten.';
  }

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

/**
 * Fuehrt die Anfrage aus und liest die Antwort unter DERSELBEN Frist: Ein Server, der
 * die Header schickt und dann mitten im Koerper stockt, darf eine Bedienaktion nicht
 * unbegrenzt haengen lassen. Der Abbruch des Signals bricht auch das Lesen ab.
 */
async function fetchAndRead<T>(url: string, init: ApiRequestInit | undefined, read: (response: Response) => Promise<T>): Promise<T> {
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
  if (callerSignal?.aborted) forwardAbort();

  try {
    let response: Response;
    try {
      response = await fetch(url, { ...requestInit, signal: controller.signal });
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
    }
    try {
      return await read(response);
    } catch (cause) {
      if (timedOut) {
        throw new ApiTimeoutError(url, timeoutMs, cause);
      }
      throw cause;
    }
  } finally {
    clearTimeout(timer);
    callerSignal?.removeEventListener('abort', forwardAbort);
  }
}

export async function requestJson<T>(url: string, init?: ApiRequestInit): Promise<T> {
  // Reihenfolge beachten: `...init` zuerst, sonst wuerde ein eigenes `headers`
  // des Aufrufers die zusammengefuehrten Header wieder komplett ersetzen.
  return fetchAndRead(url, {
    ...init,
    headers: { 'Content-Type': 'application/json', ...(init?.headers ?? {}) }
  }, async response => {
    if (!response.ok) {
      let message = `HTTP ${response.status}`;
      let code: string | undefined;
      try {
        const body = await response.json() as { error?: unknown; code?: unknown };
        if (typeof body.error === 'string' && body.error.length <= 2048) message = body.error;
        if (typeof body.code === 'string' && /^[A-Z][A-Z0-9_]{0,79}$/.test(body.code)) code = body.code;
      } catch (cause) {
        // A non-JSON error body is ignored, but a deadline hit while reading it is not.
        if (cause instanceof DOMException && cause.name === 'AbortError') {
          throw cause;
        }
      }
      throw new ApiResponseError(response.status, message, code);
    }
    return await response.json() as T;
  });
}

export async function requestText(url: string, init?: ApiRequestInit): Promise<string> {
  return fetchAndRead(url, init, async response => {
    if (!response.ok) {
      throw new ApiResponseError(response.status, `HTTP ${response.status}`);
    }
    return await response.text();
  });
}
