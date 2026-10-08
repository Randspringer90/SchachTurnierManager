import { encryptBackup, decryptBackup, MAX_PLAIN_BYTES, HEADER_BYTES } from './core.js';
const messages = {
  INVALID_SIZE: 'Bitte eine nichtleere Sicherung bis 24 MiB auswaehlen.',
  INVALID_PASSPHRASE: 'Mindestens 12 Zeichen, hoechstens 1024 UTF-8-Bytes; kein leeres Kennwort.',
  CRYPTO_UNAVAILABLE: 'Web Crypto fehlt. Bitte HTTPS oder localhost am Turnierrechner verwenden.',
  UNSUPPORTED_ENVELOPE: 'Kein unterstuetztes STMENC01-Archiv.',
  INVALID_ENVELOPE: 'Das Archiv ist beschaedigt oder unvollstaendig.',
  DECRYPTION_FAILED: 'Kennwort falsch oder Datei veraendert. Es wird kein Klartext freigegeben.',
  CANCELLED: 'Vorgang abgebrochen. Es wurde kein Ergebnis gespeichert.',
};
export function installBackupLock(document, operations = { encrypt: encryptBackup, decrypt: decryptBackup }, urls = URL) {
  const get = id => document.getElementById(id);
  const input = get('file'), password = get('password'), confirmation = get('confirmation');
  const encrypt = get('encrypt'), decrypt = get('decrypt'), clear = get('clear'), cancel = get('cancel');
  const status = get('status'), link = get('download');
  let generation = 0, running = null, objectUrl = null, disposed = false;
  function discard() {
    if (objectUrl !== null) urls.revokeObjectURL(objectUrl);
    objectUrl = null; link.removeAttribute('href'); link.hidden = true;
  }
  function invalidate() {
    generation++; running?.abort(); discard();
    status.textContent = running ? 'Abbruch angefordert; laufende Kryptografie kann noch zu Ende laufen.' : 'Noch kein Ergebnis.';
  }
  function clearAll() { invalidate(); input.value = ''; password.value = ''; confirmation.value = ''; }
  async function run(mode) {
    if (disposed || running) return;
    invalidate();
    const phrase = password.value;
    if (mode === 'encrypt' && phrase !== confirmation.value) {
      status.textContent = 'Die beiden Kennwoerter stimmen nicht ueberein.'; return;
    }
    const file = input.files?.[0];
    const maximum = MAX_PLAIN_BYTES + (mode === 'decrypt' ? HEADER_BYTES + 16 : 0);
    if (!file || !Number.isSafeInteger(file.size) || file.size < 1 || file.size > maximum) {
      status.textContent = messages.INVALID_SIZE; return;
    }
    const expectedSize = file.size, token = generation, controller = new AbortController();
    running = controller; encrypt.disabled = true; decrypt.disabled = true; cancel.disabled = false;
    password.value = ''; confirmation.value = '';
    let inputBytes, result;
    try {
      status.textContent = 'Datei wird lokal gelesen.';
      const buffer = await file.arrayBuffer();
      if (token !== generation || disposed) return;
      if (!(buffer instanceof ArrayBuffer) || buffer.byteLength !== expectedSize) throw Error('file size changed');
      inputBytes = new Uint8Array(buffer);
      status.textContent = mode === 'encrypt' ? 'Sicherung wird verschluesselt.' : 'Sicherung wird entschluesselt und authentifiziert.';
      result = await operations[mode](inputBytes, phrase, { signal: controller.signal });
      if (token !== generation || disposed) return;
      if (!(result instanceof Uint8Array) || result.length === 0) throw Error('invalid result');
      objectUrl = urls.createObjectURL(new Blob([result], { type: 'application/octet-stream' }));
      link.href = objectUrl;
      link.download = mode === 'encrypt' ? 'turnier-sicherung.stmenc' : 'wiederhergestellte-sicherung.json';
      link.textContent = mode === 'encrypt' ? 'Verschluesselte Sicherung speichern' : 'Entschluesselte JSON-Sicherung speichern';
      link.hidden = false;
      status.textContent = 'Ergebnis bereit. Zum Speichern den Link selbst anklicken; die Originaldatei ist unveraendert.';
    } catch (error) {
      if (token !== generation || disposed) return;
      discard(); status.textContent = Object.hasOwn(messages, error?.code) ? messages[error.code] : 'Vorgang fehlgeschlagen. Kein Ergebnis freigegeben.';
    } finally {
      inputBytes?.fill(0); result?.fill(0);
      if (running === controller) {
        running = null; encrypt.disabled = disposed; decrypt.disabled = disposed; cancel.disabled = true;
        if (token !== generation && !disposed) status.textContent = 'Vorheriger Vorgang beendet. Kein Ergebnis gespeichert.';
      }
    }
  }
  const bindings = [[encrypt, 'click', () => run('encrypt')], [decrypt, 'click', () => run('decrypt')],
    [input, 'change', invalidate], [password, 'input', invalidate], [confirmation, 'input', invalidate],
    [clear, 'click', clearAll], [cancel, 'click', clearAll]];
  for (const [target, event, handler] of bindings) target.addEventListener(event, handler);
  cancel.disabled = true; discard();
  return { clear: clearAll, dispose() {
    if (disposed) return;
    disposed = true; clearAll(); encrypt.disabled = true; decrypt.disabled = true;
    for (const [target, event, handler] of bindings) target.removeEventListener(event, handler);
  } };
}
