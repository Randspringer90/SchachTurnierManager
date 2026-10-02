import { searchRatingFile } from './core.js';
export function installFideSearch(document, search = searchRatingFile) {
  const get = id => document.getElementById(id);
  const file = get('file'), query = get('query'), federation = get('federation');
  const start = get('start'), cancel = get('cancel'), clear = get('clear'), status = get('status'), rows = get('rows');
  let generation = 0, controller = null;
  const invalidate = () => {
    generation++; controller?.abort(); controller = null;
    start.disabled = false; cancel.disabled = true; rows.replaceChildren();
    status.textContent = 'Liste, Namen oder FIDE-ID ausw\u00e4hlen und die Suche ausdr\u00fccklich starten.';
  };
  const run = async () => {
    if (start.disabled) return;
    invalidate(); const ticket = generation; controller = new AbortController();
    start.disabled = true; cancel.disabled = false;
    status.textContent = 'Die ausgew\u00e4hlte Liste wird nur lokal gelesen.';
    try {
      const result = await search(file.files?.[0], query.value, federation.value, {
        signal: controller.signal,
        onProgress: progress => { if (ticket === generation) status.textContent = `${progress.rows} Datens\u00e4tze gelesen.`; },
      });
      if (ticket !== generation) return;
      for (const item of result.items) {
        const tr = document.createElement('tr');
        for (const value of [item.id, item.name, item.federation, item.standardRating ?? 'ohne Wert', [item.title, item.womanTitle].filter(Boolean).join(' / ')]) {
          const td = document.createElement('td'); td.textContent = String(value); tr.append(td);
        }
        rows.append(tr);
      }
      status.textContent = `${result.matches} passende Zeilen aus ${result.rows} Datens\u00e4tzen; ${result.items.length} angezeigt${result.omitted ? `, ${result.omitted} weitere nicht angezeigt` : ''}. Keine Spielerdaten wurden \u00fcbernommen.`;
    } catch (failure) {
      if (ticket !== generation) return;
      const messages = {
        INVALID_QUERY: 'Mindestens zwei Buchstaben oder eine FIDE-ID eingeben (maximal 100 Zeichen).',
        INVALID_FEDERATION: 'Die F\u00f6deration besteht aus drei Buchstaben, beispielsweise GER.',
        INVALID_FILE: 'Eine entpackte TXT-Datei mit maximal 256 MiB ausw\u00e4hlen.',
        UNSUPPORTED_HEADER: 'Diese Liste hat keinen unterst\u00fctzten Standard-Rating-TXT-Kopf. Kein ZIP, XML oder reines Rapid-/Blitzformat verwenden.',
        INVALID_ROW: 'Die Liste enth\u00e4lt einen unvollst\u00e4ndigen oder unpassenden Datensatz. Es werden keine Teilergebnisse freigegeben.',
        EMPTY_LIST: 'Die Liste enth\u00e4lt keine Spielerdaten.',
        TOO_MANY_ROWS: 'Die Liste \u00fcberschreitet die Grenze von zwei Millionen Datens\u00e4tzen.',
        CANCELLED: 'Suche abgebrochen.',
      };
      status.textContent = Object.hasOwn(messages, failure?.code) ? messages[failure.code] : 'Die Liste konnte nicht vollst\u00e4ndig gelesen werden. Bitte neu ausw\u00e4hlen.';
    } finally {
      if (ticket === generation) { start.disabled = false; cancel.disabled = true; controller = null; }
    }
  };
  const abort = () => { invalidate(); status.textContent = 'Suche abgebrochen.'; };
  const reset = () => { file.value = ''; query.value = ''; federation.value = ''; invalidate(); };
  file.addEventListener('change', invalidate); query.addEventListener('input', invalidate); federation.addEventListener('input', invalidate);
  start.addEventListener('click', run); cancel.addEventListener('click', abort); clear.addEventListener('click', reset);
  invalidate();
  return () => {
    invalidate(); file.removeEventListener('change', invalidate); query.removeEventListener('input', invalidate); federation.removeEventListener('input', invalidate);
    start.removeEventListener('click', run); cancel.removeEventListener('click', abort); clear.removeEventListener('click', reset);
  };
}
