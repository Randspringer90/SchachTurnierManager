import { createReadApi, tournamentChoices, errorText } from '../workflow-common/read-api.mjs';
import { fillChoices, tableRows } from '../workflow-common/dom.mjs';
import { createLiveStandings, pageStandings } from './core.mjs';
export function installLiveStandings(document, api = createReadApi()) {
  const get = id => document.getElementById(id), listeners = [];
  let disposed = false, page = 0, snapshot = null, listRequest = null, choices = [];
  const bind = (id, name, fn) => { const node = get(id); node.addEventListener(name, fn); listeners.push(() => node.removeEventListener(name, fn)); };
  function render() {
    if (!snapshot || disposed) return;
    const visible = pageStandings(snapshot.rows, get('names').checked ? get('search').value : '', page, Number(get('size').value)); page = visible.page;
    tableRows(document, get('rows'), visible.rows.map(row => [row.rank, get('names').checked ? row.name : '(Name ausgeblendet)', row.points, row.buchholz, row.sonnebornBerger, row.wins]));
    get('page').textContent = `Seite ${page + 1}/${visible.pages}; ${visible.total} Spieler. Rangfolge unveraendert vom Server.`;
    get('previous').disabled = page === 0; get('next').disabled = page + 1 >= visible.pages;
    get('board').dataset.stale = String(snapshot.stale);
    const last = snapshot.updatedAt === null ? 'Noch kein erfolgreicher Abruf.' : `Letzter Abruf: ${new Date(snapshot.updatedAt).toLocaleTimeString()}.`;
    const labels = { idle: 'Bereit.', loading: 'Aktualisierung laeuft.', ready: 'Serverrangliste geladen.', paused: 'Aktualisierung pausiert.', hidden: 'Abrufe im unsichtbaren Tab pausiert.' };
    get('status').textContent = `${snapshot.status === 'error' ? errorText(snapshot.error) : labels[snapshot.status]} ${last}${snapshot.stale ? ' ACHTUNG: angezeigter Stand ist veraltet.' : ''}`;
  }
  const model = createLiveStandings(api, value => { snapshot = value; render(); });
  model.setHidden(document.visibilityState !== 'visible');
  bind('list', 'click', async () => {
    if (listRequest || disposed) return;
    const controller = new AbortController(); listRequest = controller; get('list').disabled = true;
    try { const list = tournamentChoices(await api.json('/api/tournaments', { signal: controller.signal, maxBytes: 16 * 1024 * 1024 })); if (!disposed) { choices = list; fillChoices(document, get('tournament'), list); } }
    catch (error) { if (!disposed) get('status').textContent = errorText(error); }
    finally { if (listRequest === controller) { listRequest = null; if (!disposed) get('list').disabled = false; } }
  });
  bind('start', 'click', () => { try { page = 0; get('tournament-name').textContent = choices.find(item => item.id === get('tournament').value)?.name ?? 'Rangliste'; void model.start(get('tournament').value, Number(get('interval').value)); } catch (e) { get('status').textContent = errorText(e); } });
  bind('tournament', 'change', () => { model.clear(); get('rows').replaceChildren(); snapshot = null; get('tournament-name').textContent = 'Rangliste'; get('status').textContent = 'Auswahl geaendert. Anzeige bewusst starten.'; });
  bind('pause', 'click', model.pause);
  bind('refresh', 'click', () => void model.refresh());
  bind('names', 'change', () => { get('search').disabled = !get('names').checked; get('search').value = ''; page = 0; render(); });
  bind('search', 'input', () => { page = 0; render(); }); bind('size', 'change', () => { page = 0; render(); });
  bind('previous', 'click', () => { page = Math.max(0, page - 1); render(); }); bind('next', 'click', () => { page++; render(); });
  bind('presentation', 'change', () => get('screen').classList.toggle('presentation', get('presentation').checked));
  const visibility = () => model.setHidden(document.visibilityState !== 'visible');
  document.addEventListener('visibilitychange', visibility);
  return () => { disposed = true; listRequest?.abort(); model.dispose(); document.removeEventListener('visibilitychange', visibility); listeners.forEach(fn => fn()); get('rows').replaceChildren(); };
}
