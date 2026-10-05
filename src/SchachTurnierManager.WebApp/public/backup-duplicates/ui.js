import { findIdenticalBackups } from './core.js';
const messages = {
  FILE_COUNT: 'Bitte 2 bis 20 Dateien ausw\u00e4hlen.', INVALID_FILE: 'Die Dateiauswahl ist ung\u00fcltig.',
  FILE_TOO_LARGE: 'Eine Datei ist gr\u00f6\u00dfer als 5 MiB.', TOTAL_TOO_LARGE: 'Zusammen sind maximal 50 MiB erlaubt.',
  CRYPTO_UNAVAILABLE: 'Web Crypto fehlt hier. Bitte HTTPS oder localhost am Turnierrechner verwenden.',
  FILE_CHANGED: 'Eine Datei konnte nicht vollst\u00e4ndig gelesen werden.', CANCELLED: 'Pr\u00fcfung abgebrochen.',
};
export function installDuplicateCheck(document, compute = findIdenticalBackups) {
  const get = id => document.getElementById(id);
  const input = get('files'), start = get('start'), cancel = get('cancel'), clear = get('clear');
  const status = get('status'), result = get('result'), listing = get('selection');
  let ticket = 0, active = null, disposed = false;
  function reset() {
    ticket++;
    active?.abort();
    result.textContent = ''; result.hidden = true;
    start.disabled = active !== null;
    status.textContent = active ? 'Abbruch angefordert; laufenden Dateizugriff abwarten.' : 'Noch keine Pr\u00fcfung.';
  }
  function selection() {
    if (disposed) return;
    reset();
    listing.textContent = Array.from(input.files ?? []).slice(0, 20).map((file, i) =>
      `${i + 1}: ${Array.from(String(file.name ?? '')).slice(0, 120).join('').replace(/[\u0000-\u001f\u007f\u202a-\u202e\u2066-\u2069]/g, '?')}`).join('\n');
  }
  async function run() {
    if (active || disposed) return;
    reset();
    const current = ticket, controller = new AbortController();
    active = controller; start.disabled = true; cancel.disabled = false;
    status.textContent = 'Pr\u00fcfung l\u00e4uft lokal.';
    try {
      const report = await compute(Array.from(input.files ?? []), { signal: controller.signal,
        onProgress: progress => {
          if (current === ticket && !disposed) status.textContent = `Gepr\u00fcft: ${progress.completed} von ${progress.total}.`;
        } });
      if (current !== ticket || disposed) return;
      const lines = report.identicalGroups.map(group => `Gleiche Bytes (Gr\u00f6\u00dfe + SHA-256): Dateien ${group.join(', ')}`);
      if (!lines.length) lines.push('Keine gleichen Gr\u00f6\u00dfen und SHA-256-Werte gefunden.');
      lines.push('', ...report.entries.map(item => `Datei ${item.index}: ${item.bytes} Bytes; SHA-256 ${item.hash}`));
      result.textContent = lines.join('\n'); result.hidden = false;
      status.textContent = 'Pr\u00fcfung abgeschlossen. Es wurde nichts gel\u00f6scht oder importiert.';
    } catch (error) {
      if (current !== ticket || disposed) return;
      status.textContent = Object.hasOwn(messages, error?.message) ? messages[error.message] : 'Die Pr\u00fcfung ist fehlgeschlagen. Keine vollst\u00e4ndige Auswertung.';
    } finally {
      if (active === controller) {
        active = null; start.disabled = disposed; cancel.disabled = true;
        if (current !== ticket && !disposed) status.textContent = 'Vorherige Pr\u00fcfung beendet. Neue Auswahl kann gepr\u00fcft werden.';
      }
    }
  }
  const onCancel = () => { if (!disposed) reset(); };
  const onClear = () => { if (!disposed) { input.value = ''; listing.textContent = ''; reset(); } };
  input.addEventListener('change', selection); start.addEventListener('click', run);
  cancel.addEventListener('click', onCancel); clear.addEventListener('click', onClear);
  cancel.disabled = true; selection();
  return () => {
    if (disposed) return;
    disposed = true; reset(); listing.textContent = ''; start.disabled = true; cancel.disabled = true;
    input.removeEventListener('change', selection); start.removeEventListener('click', run);
    cancel.removeEventListener('click', onCancel); clear.removeEventListener('click', onClear);
  };
}
