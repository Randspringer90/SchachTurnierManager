import { checkBackend } from './core.js';
export function installConnectionCheck(document, browser, check = checkBackend) {
  const get = id => document.getElementById(id);
  const start = get('start'), cancel = get('cancel'), status = get('status'), hint = get('hint');
  let generation = 0, controller = null;
  const updateHint = () => {
    hint.textContent = browser.navigator?.onLine === false
      ? 'Der Browser meldet offline. Das beweist nicht, ob der Turnierrechner im lokalen Netz erreichbar ist.'
      : 'Eine Netzwerkverbindung laut Browser ist kein Nachweis f\u00fcr ein erreichbares Backend.';
  };
  const cancelRun = () => {
    generation++; controller?.abort(); controller = null; start.disabled = false; cancel.disabled = true; status.textContent = 'Pr\u00fcfung abgebrochen.';
  };
  const run = async () => {
    if (start.disabled) return;
    const ticket = ++generation; controller = new AbortController(); start.disabled = true; cancel.disabled = false;
    status.textContent = 'Pr\u00fcfe ausschlie\u00dflich /api/health dieser Anwendung (maximal 5 Sekunden).';
    try {
      const reply = await check({ signal: controller.signal });
      if (ticket !== generation) return;
      const messages = {
        REACHABLE: 'Die bekannte SchachTurnierManager-Healthantwort wurde empfangen. Dies ist kein Schreib- oder Datenbanktest.',
        TIMEOUT: 'Innerhalb von 5 Sekunden kam keine vollst\u00e4ndige Antwort. Backendstart und lokale Verbindung pr\u00fcfen.',
        HTTP_ERROR: 'Der Server meldet einen HTTP-Fehler. Anmeldung, Backend und Serverprotokoll pr\u00fcfen.',
        UNEXPECTED_REPLY: 'Der Server lieferte keine passende Healthantwort. M\u00f6glicherweise ist die falsche Anwendung oder Adresse ge\u00f6ffnet.',
        NETWORK_ERROR: 'Keine verwertbare Verbindung. Backendstart, Adresse und lokale Netzwerkverbindung pr\u00fcfen.',
        CANCELLED: 'Pr\u00fcfung abgebrochen.',
      };
      status.textContent = Object.hasOwn(messages, reply?.status) ? messages[reply.status] : 'Die Pr\u00fcfung konnte nicht ausgewertet werden.';
    } catch { if (ticket === generation) status.textContent = 'Die Pr\u00fcfung konnte nicht ausgef\u00fchrt werden.'; }
    finally { if (ticket === generation) { start.disabled = false; cancel.disabled = true; controller = null; } }
  };
  browser.addEventListener('online', updateHint); browser.addEventListener('offline', updateHint);
  start.addEventListener('click', run); cancel.addEventListener('click', cancelRun);
  cancel.disabled = true; status.textContent = 'Noch keine Pr\u00fcfung. Erst der Klick stellt eine Anfrage.'; updateHint();
  return () => { cancelRun(); browser.removeEventListener('online', updateHint); browser.removeEventListener('offline', updateHint); start.removeEventListener('click', run); cancel.removeEventListener('click', cancelRun); };
}
