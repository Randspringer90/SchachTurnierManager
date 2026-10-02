import { fingerprintFile } from './core.mjs';
export function installFingerprintUi(document, compute = fingerprintFile) {
  const get = id => document.getElementById(id);
  const file = get('file'), expected = get('expected'), start = get('start'), clear = get('clear');
  const status = get('status'), result = get('result'), hash = get('hash');
  let generation = 0;
  function reset() { generation++; start.disabled = false; result.hidden = true; hash.value = ''; status.textContent = 'Bitte Datei und optional eine bekannte SHA-256-Pr\u00fcfsumme ausw\u00e4hlen.'; }
  async function run() {
    if (start.disabled) return;
    reset(); const ticket = generation; start.disabled = true;
    status.textContent = 'Die ausgew\u00e4hlte Datei wird lokal gepr\u00fcft.';
    try {
      const output = await compute(file.files?.[0], expected.value);
      if (ticket !== generation) return;
      hash.value = output.hash; result.hidden = false;
      status.textContent = output.comparison === 'MATCH' ? 'Pr\u00fcfsumme stimmt \u00fcberein.' : output.comparison === 'MISMATCH' ? 'Achtung: Die Pr\u00fcfsumme weicht ab. Diese Datei nicht als identische Kopie verwenden.' : 'Pr\u00fcfsumme berechnet; kein Vergleichswert angegeben.';
    } catch (error) {
      if (ticket !== generation) return;
      const messages = { FILE_REQUIRED: 'Bitte eine Datei ausw\u00e4hlen.', TOO_LARGE: 'Maximal 5 MiB pro Datei.', INVALID_HASH: 'Der Vergleichswert muss genau 64 hexadezimale Zeichen enthalten.', FILE_CHANGED: 'Die Dateigr\u00f6\u00dfe hat sich ge\u00e4ndert. Bitte neu ausw\u00e4hlen.', CRYPTO_UNAVAILABLE: 'Der Browser bietet hier kein Web Crypto. Bitte die Anwendung \u00fcber HTTPS oder direkt am Turnierrechner \u00fcber localhost \u00f6ffnen.' };
      status.textContent = Object.hasOwn(messages, error?.message) ? messages[error.message] : 'Die Datei konnte nicht gepr\u00fcft werden. Bitte erneut ausw\u00e4hlen.';
    } finally { if (ticket === generation) start.disabled = false; }
  }
  function clearAll() { file.value = ''; expected.value = ''; reset(); }
  file.addEventListener('change', reset); expected.addEventListener('input', reset);
  start.addEventListener('click', run); clear.addEventListener('click', clearAll);
  reset();
  return () => { reset(); file.removeEventListener('change', reset); expected.removeEventListener('input', reset); start.removeEventListener('click', run); clear.removeEventListener('click', clearAll); };
}
