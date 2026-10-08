import { readSnapshot, visiblePlayers, RESULT_LABELS, MAX_BACKUP_BYTES } from './core.js';
const STATUS = { Active: 'Aktiv', Paused: 'Pausiert', Withdrawn: 'Zurueckgezogen' };
export function installBackupReader(document, parse = readSnapshot) {
  const get = id => document.getElementById(id);
  let snapshot = null, generation = 0, loading = false, disposed = false, offset = 0;
  const subscriptions = [];
  const bind = (id, type, fn) => { const target = get(id); target.addEventListener(type, fn); subscriptions.push(() => target.removeEventListener(type, fn)); };
  const node = (tag, text) => { const item = document.createElement(tag); item.textContent = String(text); return item; };
  function rows(target, values) {
    target.replaceChildren();
    for (const valuesOfRow of values) { const row = node('tr', ''); for (const value of valuesOfRow) row.append(node('td', value)); target.append(row); }
  }
  function clear() {
    generation++; snapshot = null; offset = 0;
    get('names').checked = false; get('query').value = ''; get('query').disabled = true;
    get('player-status').value = ''; get('players').replaceChildren(); get('pairings').replaceChildren(); get('round').replaceChildren();
    get('report').hidden = true; get('title').textContent = 'Lokale Turniersicherung';
    get('summary').textContent = ''; get('round-status').textContent = ''; get('page').textContent = '';
    get('previous').disabled = true; get('next').disabled = true;
    get('status').textContent = loading ? 'Laufende Dateiauswahl wird verworfen.' : 'Noch keine Datei geladen.';
  }
  function render() {
    if (!snapshot || disposed) return;
    const names = get('names').checked;
    get('query').disabled = !names;
    if (!names) get('query').value = '';
    get('title').textContent = names ? snapshot.name : 'Lokale Turniersicherung';
    const page = visiblePlayers(snapshot, { query: names ? get('query').value : '', status: get('player-status').value, offset });
    rows(get('players'), page.rows.map(player => [player.startingRank || '-', names ? player.name : `Spieler ${player.index}`, STATUS[player.status] ?? 'Unbekannt']));
    get('previous').disabled = offset === 0; get('next').disabled = !page.hasMore;
    get('page').textContent = `${page.total} Treffer; ${page.rows.length ? offset + 1 : 0} bis ${offset + page.rows.length}. Reihenfolge wie in der Sicherung.`;
    const round = snapshot.rounds.find(value => String(value.number) === get('round').value);
    const players = new Map(snapshot.players.map(player => [player.id, player]));
    const label = id => { if (id === null) return 'Nicht zugeordnet'; const player = players.get(id); return player ? names ? player.name : `Spieler ${player.index}` : 'Spielerbezug fehlt'; };
    rows(get('pairings'), round ? round.pairings.map(pairing => [pairing.board, label(pairing.white),
      pairing.black === null && pairing.kind === 'Bye' ? 'Freilos' : label(pairing.black), RESULT_LABELS[pairing.kind] ?? 'Unbekannte Ergebnisart']) : []);
    get('round-status').textContent = round ? `Runde ${round.number}: gesperrt ${round.locked ? 'ja' : 'nein'}, bestaetigt ${round.verified ? 'ja' : 'nein'} (Angaben aus der Datei).` : 'Keine Runde ausgewaehlt.';
    get('report').hidden = false;
  }
  async function load() {
    if (loading || disposed) return;
    clear(); const ticket = generation, file = get('file').files?.[0];
    if (!file || !Number.isSafeInteger(file.size) || file.size < 1 || file.size > MAX_BACKUP_BYTES) {
      get('status').textContent = 'Bitte eine native JSON-Sicherung bis 5 MiB auswaehlen.'; return;
    }
    const expectedSize = file.size;
    loading = true; get('load').disabled = true; get('status').textContent = 'Sicherung wird lokal gelesen.';
    try {
      const data = await file.arrayBuffer();
      if (ticket !== generation || disposed) return;
      if (!(data instanceof ArrayBuffer) || data.byteLength !== expectedSize) throw Error('file changed');
      snapshot = parse(new Uint8Array(data));
      const options = snapshot.rounds.slice().sort((a, b) => a.number - b.number);
      for (const round of options) { const option = node('option', `Runde ${round.number}`); option.value = String(round.number); get('round').append(option); }
      get('round').value = options.length ? String(options[0].number) : '';
      get('summary').textContent = `${snapshot.players.length} Spieler, ${snapshot.rounds.length} Runden, ${snapshot.pairingCount} Paarungen. Unbekannte Werte: ${snapshot.unknownValues}; fehlende Spielerbezuege: ${snapshot.unresolvedReferences}.`;
      render(); get('status').textContent = 'Lokale Sicherung geladen. Kein Live-Stand und keine Importfreigabe.';
    } catch {
      if (ticket !== generation || disposed) return;
      clear(); get('status').textContent = 'Die Datei ist ungueltig, mehrdeutig, zu komplex oder kein unterstuetztes natives Turnierbackup.';
    } finally { loading = false; get('load').disabled = disposed; }
  }
  bind('load', 'click', load); bind('clear', 'click', () => { get('file').value = ''; clear(); }); bind('file', 'change', clear);
  for (const id of ['names', 'player-status']) bind(id, 'change', () => { offset = 0; render(); });
  bind('query', 'input', () => { offset = 0; render(); }); bind('round', 'change', render);
  bind('previous', 'click', () => { offset = Math.max(0, offset - 50); render(); });
  bind('next', 'click', () => { if (!get('next').disabled) { offset += 50; render(); } });
  clear();
  return { clear, dispose() { if (disposed) return; disposed = true; clear(); get('load').disabled = true; subscriptions.forEach(fn => fn()); } };
}
