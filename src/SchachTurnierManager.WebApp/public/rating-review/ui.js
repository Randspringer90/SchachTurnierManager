import { createRatingApi, errorText } from './api.js';
import { tournamentOptions, tournamentPlayers, reviewRatings } from './core.js';
const LABELS = { Changes: 'Abweichung', Unchanged: 'Gleich', Incomplete: 'Quellwerte unvollstaendig', NotFound: 'Nicht gefunden',
  Unsupported: 'Nicht unterstuetzt', Unavailable: 'Quelle nicht verfuegbar', InvalidRequest: 'Quelle lehnt Anfrage ab',
  IdentityMismatch: 'FIDE-Identitaet widerspruechlich', Failed: 'Abfrage fehlgeschlagen' };
const FIELDS = { elo: 'Standard', rapidElo: 'Schnell', blitzElo: 'Blitz' };
export function installRatingReview(document, api = createRatingApi()) {
  const get = id => document.getElementById(id), bindings = [], choices = new Map();
  let players = null, generation = 0, active = null, disposed = false, choiceBindings = [];
  const element = (tag, text = '') => { const node = document.createElement(tag); node.textContent = String(text); return node; };
  const bind = (id, type, fn) => { get(id).addEventListener(type, fn); bindings.push(() => get(id).removeEventListener(type, fn)); };
  function invalidate() { generation++; active?.abort(); get('results').replaceChildren(); get('summary').textContent = ''; }
  function clearPlayers() {
    invalidate(); players = null; choices.clear(); choiceBindings.forEach(fn => fn()); choiceBindings = [];
    get('players').replaceChildren(); get('consent').checked = false;
  }
  function drawPlayers() {
    for (const player of players) {
      const row = element('tr'), cell = element('td'), input = element('input');
      input.type = 'checkbox'; input.disabled = player.fideId === null; input.setAttribute('aria-label', `FIDE-Abgleich fuer ${player.name}`);
      input.addEventListener('change', invalidate); choiceBindings.push(() => input.removeEventListener('change', invalidate));
      choices.set(player.id, input); cell.append(input); row.append(cell);
      for (const value of [player.name, player.fideId ?? 'ungueltig/fehlt', player.elo ?? '-', player.rapidElo ?? '-', player.blitzElo ?? '-']) row.append(element('td', value));
      get('players').append(row);
    }
  }
  async function operation(task, apply) {
    if (active || disposed) return;
    invalidate(); const ticket = generation, controller = new AbortController(); active = controller;
    for (const id of ['list', 'load', 'review']) get(id).disabled = true;
    get('cancel').disabled = false; get('status').textContent = 'Anfrage laeuft.';
    try {
      const result = await task(controller.signal, progress => {
        if (ticket === generation && !disposed) get('status').textContent = `${progress.completed} von ${progress.total} Profilen geprueft.`;
      });
      if (ticket !== generation || disposed) return;
      apply(result);
    } catch (error) {
      if (ticket === generation && !disposed) get('status').textContent = errorText(error);
    } finally {
      if (active === controller) {
        active = null; for (const id of ['list', 'load', 'review']) get(id).disabled = disposed;
        get('cancel').disabled = true;
        if (ticket !== generation && !disposed) get('status').textContent = 'Alter Vorgang verworfen. Neue Auswahl kann gestartet werden.';
      }
    }
  }
  bind('list', 'click', () => {
    if (active) return;
    clearPlayers(); get('tournament').replaceChildren();
    return operation(async signal => tournamentOptions(await api.get('/api/tournaments', { signal })), options => {
      const empty = element('option', 'Bitte waehlen'); empty.value = ''; get('tournament').append(empty); get('tournament').value = '';
      for (const option of options) { const node = element('option', option.name); node.value = option.id; get('tournament').append(node); }
      get('status').textContent = `${options.length} Turniere verfuegbar. Noch keine FIDE-Anfrage.`;
    });
  });
  bind('load', 'click', () => {
    if (active) return;
    clearPlayers(); const id = get('tournament').value;
    return operation(async signal => tournamentPlayers(await api.get(`/api/tournaments/${id}`, { signal }), id), result => {
      players = result; drawPlayers(); get('status').textContent = 'Spieler geladen. Dies ist ein Auswahlstand, keine dauerhaft aktuelle Ansicht.';
    });
  });
  bind('review', 'click', () => {
    if (!players || !get('consent').checked) { get('status').textContent = 'Spieler laden und den bewussten FIDE-Abruf bestaetigen.'; return; }
    const selected = [...choices].filter(([, input]) => input.checked && !input.disabled).map(([id]) => id);
    const baseline = players;
    return operation((signal, onProgress) => reviewRatings(baseline, selected, api, { signal, onProgress }), result => {
      let changes = 0, unsuccessful = 0;
      for (const item of result) {
        if (item.status === 'Changes') changes++;
        if (!['Changes', 'Unchanged', 'Incomplete'].includes(item.status)) unsuccessful++;
        const row = element('tr');
        const detail = item.changes.map(change => `${FIELDS[change.field]}: ${change.before ?? 'unbekannt'} -> ${change.after}`).join('; ');
        const unknown = item.unknownFields.length ? ` Unbekannt/nicht gewertet: ${item.unknownFields.map(key => FIELDS[key]).join(', ')}.` : '';
        for (const value of [item.player.name, item.player.fideId, LABELS[item.status], detail + unknown,
          item.identityReviewRequired ? 'Name abweichend: Identitaet pruefen' : '-', item.retrievedAt ?? '-']) row.append(element('td', value));
        get('results').append(row);
      }
      get('summary').textContent = `${result.length} Profile; ${changes} mit Ratingabweichung, ${unsuccessful} nicht erfolgreich. Unbekannte Quellwerte loeschen keine vorhandenen Werte.`;
      get('status').textContent = 'Vorschau fertig. Kein Spieler wurde geaendert. Vor spaeterer manueller Uebernahme Turnierstand neu pruefen.';
    });
  });
  bind('tournament', 'change', clearPlayers); bind('consent', 'change', invalidate);
  bind('cancel', 'click', () => { invalidate(); get('status').textContent = 'Abbruch angefordert.'; });
  bind('clear', 'click', () => { clearPlayers(); get('tournament').replaceChildren(); get('status').textContent = 'Ansicht geleert.'; });
  get('cancel').disabled = true;
  return { clear: clearPlayers, dispose() {
    if (disposed) return; disposed = true; clearPlayers(); bindings.forEach(fn => fn());
    for (const id of ['list', 'load', 'review']) get(id).disabled = true;
  } };
}
