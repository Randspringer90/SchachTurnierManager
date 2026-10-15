// STM-SEC-003: operator message for an unreadable backup file. JSON.parse messages
// can quote the file content (for example `"Max" is not valid JSON`), so only the
// location reported by the engine is kept, never any text from the message itself.

const LOCATION = /\(line (\d{1,9}) column (\d{1,9})\)/;

function readSyntaxErrorMessage(error: unknown): string {
  if (!(error instanceof SyntaxError)) return '';
  try {
    return typeof error.message === 'string' ? error.message : '';
  } catch {
    return '';
  }
}

export function describeJsonParseFailure(error: unknown, lang: string = 'de'): string {
  const english = lang === 'en';
  const match = LOCATION.exec(readSyntaxErrorMessage(error));
  if (!match) return english ? 'The file is not valid JSON.' : 'Die Datei ist kein gültiges JSON.';
  const [, line, column] = match;
  return english
    ? `The file is not valid JSON (line ${line}, column ${column}).`
    : `Die Datei ist kein gültiges JSON (Zeile ${line}, Spalte ${column}).`;
}
