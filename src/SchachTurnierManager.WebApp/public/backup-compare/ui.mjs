import { compareBackupFiles } from './core.mjs';
export function installComparisonUi(document, compare = compareBackupFiles) {
  const get = id => document.getElementById(id);
  const before = get('before'), after = get('after'), start = get('start'), clear = get('clear');
  const status = get('status'), result = get('result'), details = get('details');
  let generation = 0;
  function reset() { generation++; start.disabled = false; result.hidden = true; details.textContent = ''; status.textContent = 'Bitte zwei native JSON-Backups desselben Turniers ausw\u00e4hlen.'; }
  async function run() {
    if (start.disabled) return;
    reset(); const ticket = generation; start.disabled = true;
    status.textContent = 'Die Dateien werden nur lokal verglichen.';
    try {
      const output = await compare(before.files?.[0], after.files?.[0]);
      if (ticket !== generation) return;
      const lines = [output.metadataChanged ? 'Turnierdaten/Einstellungen: unterschiedlich.' : 'Turnierdaten/Einstellungen: gleich.'];
      for (const [key, label] of [['players', 'Spieler'], ['rounds', 'Runden'], ['audit', 'Audit-Eintr\u00e4ge']]) {
        const group = output[key];
        lines.push(`\n${label}: links ${group.before}, rechts ${group.after}; neu ${group.added}, entfernt ${group.removed}, ge\u00e4ndert ${group.changed}.`);
        for (const item of group.details) lines.push(`${({ added: 'NEU', removed: 'ENTFERNT', changed: 'GE\u00c4NDERT' })[item.kind]}: ${item.id}`);
        if (group.omitted) lines.push(`Weitere ${group.omitted} Detailzeilen nicht angezeigt; die Summen enthalten alle Eintr\u00e4ge.`);
      }
      details.textContent = lines.join('\n'); result.hidden = false;
      status.textContent = output.sameComparedContent ? 'Keine Unterschiede im verglichenen JSON-Inhalt. Dies ist keine Wiederherstellungsfreigabe.' : 'Unterschiede gefunden (links nach rechts). Es wurden keine Daten ge\u00e4ndert.';
    } catch (error) {
      if (ticket !== generation) return;
      const messages = { DIFFERENT_TOURNAMENT: 'Die Dateien geh\u00f6ren zu unterschiedlichen Turnieren. Kein automatischer Abgleich.', INVALID_SIZE: 'Bitte zwei nichtleere Dateien mit jeweils maximal 5 MiB ausw\u00e4hlen.', DUPLICATE_KEY: 'Mehrdeutiges JSON mit doppelten Schl\u00fcsseln: Vergleich abgelehnt.', DUPLICATE_ID: 'Doppelte Spieler-, Runden- oder Audit-IDs: Vergleich abgelehnt.', TOO_COMPLEX: 'Die Datei ist f\u00fcr diese begrenzte Vergleichsansicht zu komplex.' };
      status.textContent = Object.hasOwn(messages, error?.message) ? messages[error.message] : 'Die Dateien konnten nicht als unterst\u00fctzte UTF-8-Turnierbackups verglichen werden.';
    } finally { if (ticket === generation) start.disabled = false; }
  }
  function clearAll() { before.value = ''; after.value = ''; reset(); }
  before.addEventListener('change', reset); after.addEventListener('change', reset); start.addEventListener('click', run); clear.addEventListener('click', clearAll);
  reset();
  return () => { reset(); before.removeEventListener('change', reset); after.removeEventListener('change', reset); start.removeEventListener('click', run); clear.removeEventListener('click', clearAll); };
}
