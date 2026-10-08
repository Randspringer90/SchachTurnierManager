// Bereitschaftslogik fuer das lokale Backend.
//
// Hintergrund: Die Oberflaeche startet haeufig schneller als der lokale
// WebApi-Prozess (Operator-Start, portables Paket, Kaltstart der SQLite-Datei).
// Vorher hat sie in diesem Fenster bereits alle Schaltflaechen angeboten, den
// ersten fehlgeschlagenen Aufruf als rohen Text angezeigt und danach nie wieder
// geprueft. Diese Datei haelt die Zustandsfolge frei von React, damit sie ohne
// Browser testbar bleibt.

export type BackendReadiness =
  /** Erster Kontakt laeuft noch - die Anwendung startet gerade. */
  | 'starting'
  /** Backend hat geantwortet. */
  | 'online'
  /** Backend hat innerhalb des Startfensters nicht geantwortet. */
  | 'unreachable';

/**
 * Wartezeiten zwischen den Startversuchen (Millisekunden).
 *
 * Kurz beginnen, damit ein schneller Start sofort gruen wird, dann verdoppeln,
 * damit ein wirklich totes Backend keine Dauerlast erzeugt. Die Liste ist
 * endlich: nach dem letzten Eintrag gilt der Startversuch als gescheitert.
 */
export const startupProbeDelaysMs: readonly number[] = [400, 800, 1600, 2400, 3200, 4000];

/** Ruhiger Takt, sobald der Startversuch entschieden ist (gruen oder rot). */
export const steadyProbeIntervalMs = 10000;

/** Gesamtes Startfenster, das `startupProbeDelaysMs` aufspannt. */
export function startupBudgetMs(): number {
  return startupProbeDelaysMs.reduce((sum, delay) => sum + delay, 0);
}

/**
 * Wartezeit vor dem naechsten Versuch.
 *
 * `attempt` ist die Anzahl der bereits fehlgeschlagenen Versuche (0 = noch
 * keiner). Nach dem Startfenster wird auf den ruhigen Takt umgeschaltet, statt
 * aggressiv weiterzupollen.
 */
export function nextProbeDelayMs(attempt: number): number {
  if (attempt < 0) {
    return startupProbeDelaysMs[0];
  }
  return startupProbeDelaysMs[attempt] ?? steadyProbeIntervalMs;
}

/** Ist das Startfenster mit `attempt` fehlgeschlagenen Versuchen ausgeschoepft? */
export function isStartupWindowExhausted(attempt: number): boolean {
  return attempt >= startupProbeDelaysMs.length;
}

/** Zustand nach einem Versuch. Solange das Startfenster laeuft, bleibt es `starting`. */
export function readinessAfterProbe(succeeded: boolean, failedAttempts: number): BackendReadiness {
  if (succeeded) {
    return 'online';
  }
  return isStartupWindowExhausted(failedAttempts) ? 'unreachable' : 'starting';
}

/**
 * Duerfen Bedienschritte angeboten werden?
 *
 * Waehrend `starting` bleibt die Oberflaeche bewusst gesperrt: ein Klick in
 * diesem Fenster fuehrt garantiert in einen halb geladenen Zustand.
 */
export function canOperate(readiness: BackendReadiness): boolean {
  return readiness === 'online';
}

export type ReadinessNotice = {
  tone: 'info' | 'error';
  title: string;
  detail: string;
  /** Nur bei `unreachable`: erneuter Versuch ohne Browserneustart. */
  retryLabel: string | null;
};

/**
 * Nutzertext fuer den Bereitschaftszustand.
 *
 * Bewusst ohne Host, Port, Proxy oder interne Pfade - die technische Ursache
 * gehoert in die Konsole und in die Logdatei, nicht in die Oberflaeche.
 */
export function describeReadiness(readiness: BackendReadiness, lang: string = 'de'): ReadinessNotice | null {
  const english = lang === 'en';

  if (readiness === 'online') {
    return null;
  }

  if (readiness === 'starting') {
    return {
      tone: 'info',
      title: english ? 'Application is starting …' : 'Anwendung wird gestartet …',
      detail: english
        ? 'Waiting for the local server. Tournament actions unlock as soon as it answers.'
        : 'Es wird auf den lokalen Server gewartet. Turnieraktionen werden freigegeben, sobald er antwortet.',
      retryLabel: null
    };
  }

  return {
    tone: 'error',
    title: english ? 'Local server not reachable' : 'Lokaler Server nicht erreichbar',
    detail: english
      ? 'SchachTurnierManager did not answer. Please make sure the server window is still open, then try again.'
      : 'Der SchachTurnierManager hat nicht geantwortet. Bitte pruefen, ob das Serverfenster noch offen ist, und es dann erneut versuchen.',
    retryLabel: english ? 'Try again' : 'Erneut versuchen'
  };
}
