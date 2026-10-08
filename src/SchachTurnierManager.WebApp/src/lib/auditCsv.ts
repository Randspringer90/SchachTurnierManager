import type { AuditJournalEntry } from '../api/contracts';

// Same text/number policy as the backend CsvFieldEncoder. This protects initial
// spreadsheet import; JSON remains lossless and spreadsheet resaves need review.
export function auditCsvCell(value: unknown): string {
  const text = value === null || value === undefined ? '' : String(value);
  let protect = false;
  if (!/^-?\d+(?:\.\d+)?$/.test(text)) {
    for (const character of text) {
      if (/\p{Cc}/u.test(character)) { protect = true; break; }
      if (/[\p{White_Space}\p{Cf}]/u.test(character)) continue;
      protect = '=+-@＝＋－＠'.includes(character);
      break;
    }
  }
  const escaped = (protect ? "'" + text : text).replace(/"/g, '""');
  return protect || /[;"\r\n]/.test(text) ? `"${escaped}"` : escaped;
}

type AuditCsvLabels = {
  date: (value: string) => string;
  severity: (value: number | string) => string;
  action: (value: number | string) => string;
};
export function buildAuditJournalCsv(entries: ReadonlyArray<AuditJournalEntry>, labels: AuditCsvLabels): string {
  const header = 'Zeitpunkt;Schweregrad;Aktion;Akteur;Runde;Brett;Spieler;Zusammenfassung;Details;Grund';
  const rows = entries.map(entry => [
    labels.date(entry.createdAt), labels.severity(entry.severity), labels.action(entry.action),
    entry.actor, entry.roundNumber ?? '', entry.boardNumber ?? '', entry.playerName ?? entry.playerId ?? '',
    entry.summary, entry.details ?? '', entry.reason ?? ''
  ].map(auditCsvCell).join(';'));
  return [header, ...rows].join('\r\n');
}
