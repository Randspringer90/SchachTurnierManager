import { createReadApi, errorText } from '../workflow-common/read-api.mjs';
import { element, tableRows } from '../workflow-common/dom.mjs';
import { createFideWorkbench, compareCandidates } from './core.mjs';
export function installFideWorkbench(document, api = createReadApi()) {
  const get = id => document.getElementById(id), work = createFideWorkbench(api), bindings = [];
  let disposed = false, ticket = 0;
  const bind = (id, event, fn) => { const node = get(id); node.addEventListener(event, fn); bindings.push(() => node.removeEventListener(event, fn)); };
  function clearResults() { get('results').replaceChildren(); get('query-status').textContent = ''; }
  function error(error) {
    const labels = { UNSUPPORTED_SEARCH: 'Diese Suchart ist beim Server nicht aktiv. Ggf. FIDE-ID verwenden.',
      INVALID_QUERY: 'Bitte 2 bis 80 Zeichen oder eine FIDE-ID eingeben.', COMPARE_LIMIT: 'Maximal vier Kandidaten vergleichen.', ID_MISMATCH: 'Antwort passt nicht zur angefragten FIDE-ID.' };
    get('query-status').textContent = Object.hasOwn(labels,error?.code) ? labels[error.code] : errorText(error);
  }
  function comparison() {
    const candidates = work.candidates(); get('compare-region').hidden = candidates.length === 0;
    get('candidates').replaceChildren();
    for (const candidate of candidates) {
      const row = element(document,'p',`${candidate.name} (${candidate.fideId}) `), button = element(document,'button','Entfernen');
      button.type = 'button'; button.addEventListener('click', () => { if (!disposed) { work.remove(candidate.fideId); comparison(); } }); row.append(button); get('candidates').append(row);
    }
    const labels = { name:'Name',fideId:'FIDE-ID',title:'Titel',federation:'Foederation',elo:'Standard-Elo',rapidElo:'Schnellschach-Elo',blitzElo:'Blitz-Elo',retrievedAt:'Zeitangabe der Quelle' };
    tableRows(document, get('comparison'), compareCandidates(candidates).map(row => [labels[row.key], ...Array.from({ length: 4 }, (_, i) => row.values[i] ?? '-'), row.different ? 'verschieden' : 'gleich/unbekannt']));
  }
  bind('providers','click', async () => {
    const current = ++ticket; clearResults(); get('search').disabled = true;
    try { const capabilities = await work.initialize(); if (disposed || current !== ticket) return;
      get('capabilities').textContent = `FIDE-ID: ${capabilities.byId ? 'aktiv' : 'nicht aktiv'}; Name: ${capabilities.byName ? 'aktiv' : 'nicht aktiv'}.`;
      get('search').disabled = !(capabilities.byId || capabilities.byName);
    } catch (e) { if (!disposed && current === ticket) error(e); }
  });
  bind('search','click', async () => {
    const current = ++ticket; clearResults(); get('query-status').textContent = 'Suche laeuft.';
    try { const result = await work.search(get('query').value, get('fresh').checked); if (disposed || ticket !== current) return;
      const statuses = { Found:'Treffer',NotFound:'Keine Treffer',Unsupported:'Suchart nicht unterstuetzt',Unavailable:'Quelle nicht erreichbar',InvalidRequest:'Quelle lehnt Anfrage ab' };
      get('query-status').textContent = `${statuses[result.status]}. ${result.cached ? 'Sitzungscache' : 'Serverabfrage'}: ${new Date(result.fetchedAt).toLocaleTimeString()}. Keine Aktualitaetsgarantie der Quelldaten.`;
      for (const player of result.players) {
        const row = element(document,'tr');
        for (const value of [player.name,player.fideId,player.federation,player.elo,player.rapidElo,player.blitzElo]) row.append(element(document,'td',value ?? '-'));
        const cell = element(document,'td'), button = element(document,'button','Vergleichen'); button.type = 'button';
        button.addEventListener('click', () => { if (disposed) return; try { work.pin(player.fideId); comparison(); } catch (e) { error(e); } }); cell.append(button); row.append(cell); get('results').append(row);
      }
    } catch (e) { if (!disposed && current === ticket) error(e); }
  });
  bind('query','input', () => { ticket++; work.cancel(); clearResults(); });
  bind('cancel','click', () => { ticket++; work.cancel(); clearResults(); get('query-status').textContent = 'Suche abgebrochen.'; });
  bind('clear','click', () => { ticket++; work.clear(); clearResults(); comparison(); get('query').value = ''; });
  comparison();
  return () => { disposed = true; ticket++; work.dispose(); bindings.forEach(fn => fn()); clearResults(); get('comparison').replaceChildren(); get('candidates').replaceChildren(); };
}
