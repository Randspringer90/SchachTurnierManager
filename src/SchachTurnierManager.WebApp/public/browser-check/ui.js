import { inspectBrowser } from './core.js';

const CHECK_LABELS = {
  secureContext: 'Sicherer Browserkontext (HTTPS oder geeigneter lokaler Ursprung)',
  fileObjects: 'Lokale Dateiauswahl (File-Schnittstelle)',
  arrayBuffer: 'Dateien als Bytepuffer lesen',
  fileStream: 'Dateien abschnittsweise lesen',
  textEncoder: 'Text in UTF-8 kodieren',
  textDecoder: 'UTF-8-Text dekodieren',
  readableStream: 'Datenströme lesen',
  abortController: 'Laufende Vorgänge abbrechen',
  sha256Interface: 'Web-Crypto-Digest-Schnittstelle',
  serviceWorkerInterface: 'Service-Worker-Schnittstelle',
};
const FEATURE_LABELS = {
  localBackupTools: 'Lokale Backup-Vorschau und Vergleiche',
  backupChecksum: 'Lokale Backup-Prüfsumme',
  streamingRatingSearch: 'Große Ratinglisten abschnittsweise durchsuchen',
  serviceWorkerPrerequisites: 'Service-Worker-Grundvoraussetzungen',
};
const STATES = { available: 'Schnittstelle sichtbar', missing: 'Voraussetzung fehlt', unknown: 'Nicht feststellbar' };

export function installBrowserCheck(document, environment, inspect = inspectBrowser) {
  const get = id => document.getElementById(id);
  const start = get('check'), resetButton = get('reset'), output = get('output');
  const rows = get('checks'), features = get('features'), status = get('status');
  let disposed = false;
  const reset = () => {
    rows.replaceChildren(); features.replaceChildren(); output.hidden = true;
    status.textContent = 'Noch keine Prüfung. Es werden weder Berechtigungen angefordert noch Verbindungen aufgebaut.';
  };
  const show = () => {
    if (disposed) return;
    reset();
    try {
      const report = inspect(environment);
      for (const [id, label] of Object.entries(CHECK_LABELS)) {
        const row = document.createElement('tr');
        for (const value of [label, Object.hasOwn(STATES, report.checks?.[id]) ? STATES[report.checks[id]] : STATES.unknown]) {
          const cell = document.createElement('td'); cell.textContent = value; row.append(cell);
        }
        rows.append(row);
      }
      for (const [id, label] of Object.entries(FEATURE_LABELS)) {
        const item = document.createElement('li');
        const state = report.features?.[id];
        const explanation = state === 'available' ? 'sichtbare Voraussetzungen vorhanden, Ausführung nicht geprüft'
          : state === 'missing' ? 'mindestens eine Voraussetzung fehlt' : 'Voraussetzungen nicht vollständig feststellbar';
        item.textContent = label + ': ' + explanation + '.'; features.append(item);
      }
      output.hidden = false;
      status.textContent = 'Browser-Schnittstellen geprüft. Dies ist keine Funktions-, Sicherheits- oder Installationsfreigabe.';
    } catch {
      reset(); status.textContent = 'Die Browser-Voraussetzungen konnten nicht ermittelt werden. Es wurden keine Einstellungen geändert.';
    }
  };
  start.addEventListener('click', show); resetButton.addEventListener('click', reset); reset();
  return () => {
    if (disposed) return;
    disposed = true; start.removeEventListener('click', show); resetButton.removeEventListener('click', reset); reset();
  };
}
