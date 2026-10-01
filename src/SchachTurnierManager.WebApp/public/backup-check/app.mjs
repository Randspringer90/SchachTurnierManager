import { inspectBackup, MAX_BYTES } from './preflight.mjs';

export function mountBackupCheck(document) {

  const fileInput = document.querySelector('#backup-file');
  const status = document.querySelector('#status');
  const summary = document.querySelector('#summary');
  const issues = document.querySelector('#issues');
  let generation = 0;
  const messages = {
    INVALID_INPUT: 'Unbekannter Dateityp.', TOO_LARGE: 'Die Datei ist groesser als 5 MiB.',
    INVALID_UTF8: 'Die Datei ist kein gueltiges UTF-8.', EMPTY_FILE: 'Die Datei ist leer.',
    TOO_DEEP: 'Die JSON-Struktur ist zu tief verschachtelt.', DUPLICATE_KEY: 'Ein JSON-Feld kommt mehrfach vor.',
    INVALID_JSON: 'Die Datei enthaelt kein gueltiges JSON.', UNSUPPORTED_FORMAT: 'Kein natives Turnier-Backup. Audit- und Turnierpakete sind andere Formate.',
    INVALID_TOURNAMENT_ID: 'Die Turnier-ID fehlt oder ist ungueltig.', MISSING_NAME: 'Ein erforderlicher Name fehlt.',
    MISSING_SETTINGS: 'Die Turniereinstellungen fehlen.', MISSING_ARRAY: 'Eine erforderliche Liste fehlt.',
    TOO_MANY_ITEMS: 'Eine Liste ueberschreitet das Prueflimit von 20000 Eintraegen.',
    INVALID_PLAYER: 'Ungueltiger Spielereintrag.', INVALID_PLAYER_ID: 'Ungueltige Spieler-ID.',
    DUPLICATE_PLAYER_ID: 'Eine Spieler-ID kommt mehrfach vor.', DUPLICATE_PLAYER_NAME: 'Spielernamen sind moeglicherweise doppelt.',
    INVALID_ROUND: 'Ungueltiger Rundeneintrag.', INVALID_ROUND_NUMBER: 'Ungueltige Rundennummer.',
    DUPLICATE_ROUND: 'Eine Rundennummer kommt mehrfach vor.', INVALID_PAIRING: 'Ungueltige Paarung.',
    INVALID_BOARD_NUMBER: 'Ungueltige Brettnummer.', DUPLICATE_BOARD: 'Eine Brettnummer kommt in derselben Runde mehrfach vor.',
    SELF_PAIRING: 'Ein Spieler ist gegen sich selbst gepaart.', INVALID_PLAYER_REFERENCE: 'Ungueltiger Spielerbezug.',
    UNKNOWN_PLAYER: 'Eine Paarung verweist auf einen unbekannten Spieler.', PLAYER_ASSIGNED_TWICE: 'Ein Spieler ist in derselben Runde mehrfach eingeteilt.',
  };
  function clear() { summary.replaceChildren(); issues.replaceChildren(); }
  function render(report) {
    status.textContent = report.status === 'STRUCTURE_OK' ? 'Strukturpruefung ohne Befund. Noch keine Importfreigabe.' :
      report.status === 'WARNINGS' ? 'Bitte die Hinweise vor dem Import klaeren.' : 'Backup nicht freigegeben: Strukturprobleme gefunden.';
    if (report.summary) {
      const text = document.createElement('p');
      const value = report.summary;
      text.textContent = `${value.name}: ${value.players} Spieler, ${value.rounds} Runden, ${value.boards} Bretter, ${value.auditEntries} Audit-Eintraege.`;
      summary.append(text);
    }
    for (const issue of report.issues) {
      const item = document.createElement('li');
      item.textContent = `${issue.severity === 'warning' ? 'Hinweis' : 'Fehler'}: ${messages[issue.code] ?? issue.code} (${issue.location})`;
      issues.append(item);
    }
    if (report.truncated) {
      const item = document.createElement('li'); item.textContent = `Es werden nur die ersten 100 von ${report.issueCount} Befunden angezeigt.`; issues.append(item);
    }
  }
  fileInput.addEventListener('change', async () => {
    const current = ++generation; clear();
    const file = fileInput.files?.[0];
    if (!file) { status.textContent = 'Noch keine Datei ausgewaehlt.'; return; }
    if (file.size > MAX_BYTES) { status.textContent = messages.TOO_LARGE; return; }
    status.textContent = 'Datei wird ausschliesslich in diesem Browser geprueft.';
    try {
      const bytes = new Uint8Array(await file.arrayBuffer());
      if (current !== generation) return;
      render(inspectBackup(bytes));
    } catch {
      if (current === generation) status.textContent = 'Datei konnte nicht gelesen werden. Bitte erneut auswaehlen.';
    }
  });
  document.querySelector('#reset').addEventListener('click', () => {
    generation++; fileInput.value = ''; clear(); status.textContent = 'Ansicht geleert. Die Originaldatei wurde nicht veraendert.'; fileInput.focus();
  });
}

if (typeof document !== 'undefined') mountBackupCheck(document);
