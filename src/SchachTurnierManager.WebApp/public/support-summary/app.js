import { summarizeFile } from './core.js';
export function installSupportSummary(document, summarize = summarizeFile) {
  const get = id => document.getElementById(id);
  const file = get('file'), start = get('start'), clear = get('clear'), status = get('status'), output = get('output'), result = get('result');
  let generation = 0;
  const invalidate = () => { generation++; start.disabled = false; result.hidden = true; output.value = ''; status.textContent = 'Eine native JSON-Sicherung ausw\u00e4hlen. Die Datei wird nicht hochgeladen.'; };
  const run = async () => {
    if (start.disabled) return;
    invalidate(); const ticket = generation; start.disabled = true;
    status.textContent = 'Kennzahlen werden lokal ermittelt.';
    try {
      const summary = await summarize(file.files?.[0]);
      if (ticket !== generation) return;
      output.value = JSON.stringify(summary, null, 2); result.hidden = false;
      status.textContent = 'Nur Kennzahlen wurden ausgegeben. Vor Weitergabe selbst pr\u00fcfen; auch Anzahlen k\u00f6nnen vertraulich sein.';
    } catch (failure) {
      if (ticket !== generation) return;
      const messages = { INVALID_SIZE: 'Eine nichtleere Datei mit maximal 5 MiB ausw\u00e4hlen.', DUPLICATE_KEY: 'Doppelte JSON-Schl\u00fcssel: Bericht abgelehnt.', AMBIGUOUS_FIELD: 'Mehrdeutige Feldnamen: Bericht abgelehnt.', TOO_COMPLEX: 'Die Datei ist f\u00fcr diese begrenzte Ansicht zu komplex.' };
      status.textContent = Object.hasOwn(messages, failure?.code) ? messages[failure.code] : 'Die Datei konnte nicht als unterst\u00fctzte UTF-8-Turniersicherung gelesen werden.';
    } finally { if (ticket === generation) start.disabled = false; }
  };
  const reset = () => { file.value = ''; invalidate(); };
  file.addEventListener('change', invalidate); start.addEventListener('click', run); clear.addEventListener('click', reset); invalidate();
  return () => { invalidate(); file.removeEventListener('change', invalidate); start.removeEventListener('click', run); clear.removeEventListener('click', reset); };
}
