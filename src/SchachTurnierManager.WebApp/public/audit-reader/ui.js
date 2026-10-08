import { readAuditJsonl, filterAudit, MAX_BYTES } from './core.js';
export function installAuditReader(document, parse = readAuditJsonl) {
  const get = id => document.getElementById(id);
  const input = get('file'), load = get('load'), clear = get('clear'), summary = get('show-summary');
  const severity = get('severity'), action = get('action'), round = get('round');
  const previous = get('previous'), next = get('next'), body = get('entries'), status = get('status');
  let report = null, offset = 0, ticket = 0, busy = false, disposed = false;
  const empty = () => { body.replaceChildren(); previous.disabled = true; next.disabled = true; };
  function reset() {
    ticket++; report = null; offset = 0; summary.checked = false; empty();
    severity.value = ''; action.value = ''; round.value = '';
    action.replaceChildren(createOption(document, 'Alle Aktionen', ''));
    status.textContent = 'Keine Datei geladen. Inhalte werden nicht hochgeladen.';
  }
  function render() {
    empty(); if (!report || disposed) return;
    try {
      const filtered = filterAudit(report.events, { severity: severity.value, action: action.value, round: round.value, offset });
      for (const event of filtered.entries) {
        const row = document.createElement('tr');
        const values = [event.createdAt, event.action, event.severity, event.round ?? '-', event.board ?? '-', summary.checked ? event.summary : '(ausgeblendet)'];
        for (const value of values) { const cell = document.createElement('td'); cell.textContent = String(value); row.append(cell); }
        body.append(row);
      }
      previous.disabled = offset === 0; next.disabled = !filtered.hasMore;
      status.textContent = `${filtered.total} Treffer; angezeigt ${filtered.entries.length ? offset + 1 : 0} bis ${offset + filtered.entries.length}. ${report.skippedRecords} Snapshot-/Forensikdatens\u00e4tze ausgeblendet; ${report.unknownRecords} unbekannte Datens\u00e4tze. Keine Echtheitspr\u00fcfung.`;
    } catch { status.textContent = 'Filter ung\u00fcltig. Rundennummer bitte als positive ganze Zahl eingeben.'; }
  }
  async function read() {
    if (busy || disposed) return;
    reset(); const current = ticket; busy = true; load.disabled = true;
    status.textContent = 'Audit-Datei wird lokal gelesen.';
    try {
      const file = input.files?.[0];
      if (!file || !Number.isSafeInteger(file.size) || file.size <= 0 || file.size > MAX_BYTES) throw Error('INVALID_SIZE');
      const buffer = await file.arrayBuffer();
      if (current !== ticket || disposed) return;
      if (!(buffer instanceof ArrayBuffer) || buffer.byteLength !== file.size) throw Error('FILE_CHANGED');
      report = parse(new Uint8Array(buffer));
      for (const name of [...new Set(report.events.map(event => event.action))].sort()) action.append(createOption(document, name, name));
      render();
    } catch (error) {
      if (current !== ticket || disposed) return;
      report = null; empty();
      const known = { INVALID_SIZE: 'Bitte eine nichtleere JSONL-Datei bis 5 MiB ausw\u00e4hlen.', COUNT_MISMATCH: 'Die Ereignisanzahl passt nicht zum Manifest. Keine vollst\u00e4ndige Anzeige.', DUPLICATE_ID: 'Doppelte Ereignis-ID erkannt. Anzeige abgelehnt.' };
      status.textContent = Object.hasOwn(known, error?.message) ? known[error.message] : 'Kein unterst\u00fctzter vollst\u00e4ndiger Audit-JSONL-Export. Die Datei wurde nicht importiert.';
    } finally { busy = false; load.disabled = disposed; }
  }
  const selection = () => { if (!disposed) reset(); };
  const resetAll = () => { if (!disposed) { input.value = ''; reset(); } };
  const changed = () => { if (!disposed) { offset = 0; render(); } };
  const back = () => { if (!disposed && offset > 0) { offset = Math.max(0, offset - 200); render(); } };
  const forward = () => { if (!disposed && !next.disabled) { offset += 200; render(); } };
  const bindings = [[input, 'change', selection], [load, 'click', read], [clear, 'click', resetAll],
    [summary, 'change', changed], [severity, 'change', changed], [action, 'change', changed], [round, 'input', changed],
    [previous, 'click', back], [next, 'click', forward]];
  for (const [target, event, handler] of bindings) target.addEventListener(event, handler);
  reset();
  return () => { if (disposed) return; disposed = true; reset(); load.disabled = true; for (const [target, event, handler] of bindings) target.removeEventListener(event, handler); };
}
function createOption(document, label, value) {
  const option = document.createElement('option'); option.textContent = label; option.value = value; return option;
}
