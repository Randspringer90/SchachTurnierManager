import { createReadApi, tournamentChoices, errorText } from '../workflow-common/read-api.mjs';
import { element, fillChoices, downloadLink } from '../workflow-common/dom.mjs';
import { collectBackupSet, readBackupSet } from './core.mjs';
export function installBackupSet(document, api = createReadApi(), urlApi = URL) {
  const get = id => document.getElementById(id), bindings = [];
  let active = null, ticket = 0, disposed = false, extracted = [], archiveLink = null, itemLink = null;
  const bind = (id, event, fn) => { const node = get(id); node.addEventListener(event, fn); bindings.push(() => node.removeEventListener(event, fn)); };
  function clearLinks() { archiveLink?.(); itemLink?.(); archiveLink = null; itemLink = null; extracted = []; fillChoices(document, get('member'), []); }
  function cancel() { ticket++; active?.abort(); clearLinks(); get('status').textContent = active ? 'Abbruch angefordert; laufende Operation wird beendet.' : 'Anzeige geleert.'; }
  async function operation(work) {
    if (disposed || active) return;
    clearLinks(); const controller = new AbortController(), current = ++ticket; active = controller;
    for (const id of ['list','collect','read']) get(id).disabled = true;
    const valid = () => !disposed && current === ticket;
    try { await work(controller.signal, valid, progress => { if (valid()) get('status').textContent = `${progress.completed}/${progress.total} verarbeitet.`; }); }
    catch (error) { if (valid()) {
      const codes = { CHECKSUM_MISMATCH: 'Pruefsumme oder Metadaten passen nicht. Keine Datei freigegeben.', CRYPTO_UNAVAILABLE: 'Web Crypto fehlt. HTTPS oder localhost verwenden.', INVALID_SELECTION: 'Bitte 1 bis 10 Turniere auswaehlen.', INVALID_ARCHIVE: 'Kein unterstuetztes Sammelarchiv.', TOTAL_TOO_LARGE: 'Auswahl ist groesser als 10 MiB.' };
      get('status').textContent = Object.hasOwn(codes, error?.code) ? codes[error.code] : errorText(error);
    } }
    finally { if (active === controller) { active = null; if (!disposed) for (const id of ['list','collect','read']) get(id).disabled = false; } }
  }
  bind('list','click', () => operation(async (signal, valid) => {
    get('status').textContent = 'Turnierliste wird gelesen.';
    const items = tournamentChoices(await api.json('/api/tournaments', { signal, maxBytes: 16 * 1024 * 1024 }));
    if (!valid()) return;
    get('choices').replaceChildren();
    for (const item of items) {
      const label = element(document,'label'), box = element(document,'input'); box.type = 'checkbox'; box.value = item.id; box.name = 'tournament';
      label.append(box, element(document,'span',item.name)); get('choices').append(label);
    }
    get('status').textContent = `${items.length} Turniere. Auswahl und Datenschutz bestaetigen.`;
  }));
  bind('collect','click', () => {
    if (!get('consent').checked) { get('status').textContent = 'Bitte bestaetigen: Sicherungen enthalten vertrauliche Turnierdaten.'; return; }
    return operation(async (signal, valid, onProgress) => {
      const ids = Array.from(get('choices').querySelectorAll('input:checked')).map(input => input.value);
      const result = await collectBackupSet(ids, api, { signal, onProgress });
      if (!valid()) return;
      archiveLink = downloadLink(get('archive-download'), result.text, 'stm-sammelsicherung.json', urlApi);
      get('status').textContent = `${result.count} Turniere vorbereitet. Zum Speichern den Download anklicken. Keine gleichzeitige Datenbank-Momentaufnahme.`;
    });
  });
  bind('read','click', () => operation(async (signal, valid, onProgress) => {
    const result = await readBackupSet(get('file').files?.[0], { signal, onProgress });
    if (!valid()) return;
    extracted = result; fillChoices(document, get('member'), result);
    get('status').textContent = `${result.length} enthaltene Exporte geprueft. Turnier fuer Einzeldownload auswaehlen. Kein Import ausgefuehrt.`;
  }));
  bind('member','change', () => {
    itemLink?.(); itemLink = null;
    const item = extracted.find(row => row.id === get('member').value);
    if (item) itemLink = downloadLink(get('item-download'), item.content, `turnier-${item.id}.json`, urlApi);
  });
  bind('file','change', cancel); bind('cancel','click',cancel); bind('choices','change',cancel);
  bind('consent','change',cancel);
  return () => { disposed = true; cancel(); bindings.forEach(fn => fn()); get('choices').replaceChildren(); };
}
