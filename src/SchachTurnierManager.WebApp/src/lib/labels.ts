// Display formatting for enum-ish backend values (results, audit entries,
// import previews, pairing quality). Extracted from main.tsx (STM-FE-014).
import { externalSourceOptions, genderOptions, playerStatusOptions, resultOptions, tiebreakOptions } from './tournamentOptions';
import type { PwaStatus } from '../api/contracts';
export function pwaStatusLabel(status: PwaStatus): string {
  switch (status) {
    case 'checking': return 'PWA wird geprüft…';
    case 'unsupported': return 'PWA nicht unterstützt';
    case 'ready': return 'PWA bereit';
    case 'installable': return 'PWA installierbar';
    case 'installed': return 'PWA installiert';
    case 'update-available': return 'PWA-Update verfügbar';
    case 'error': return 'PWA-Serviceworker blockiert';
    default: return 'PWA-Status unbekannt';
  }
}

export function backupTimeLabel(iso: string | null, english = false): string {
  if (!iso) {
    return english ? 'no local backup exported yet' : 'noch kein lokaler Backup-Export';
  }
  const parsed = new Date(iso);
  if (Number.isNaN(parsed.getTime())) {
    return english ? 'unknown' : 'unbekannt';
  }
  return parsed.toLocaleString(english ? 'en-US' : 'de-DE');
}

export function resultLabel(kind: number, english = false): string {
  const option = resultOptions.find(item => item.value === kind);
  return (english ? option?.labelEn : option?.label) ?? String(kind);
}

export function genderLabel(kind: number, english = false): string {
  const option = genderOptions.find(item => item.value === kind);
  return (english ? option?.labelEn : option?.label) ?? String(kind);
}

export function statusLabel(kind: number, english = false): string {
  const option = playerStatusOptions.find(item => item.value === kind);
  return (english ? option?.labelEn : option?.label) ?? String(kind);
}

export function roundStatusLabel(kind: number, english = false): string {
  switch (kind) {
    case 1: return english ? 'complete' : 'vollständig';
    case 2: return english ? 'reviewed' : 'geprüft';
    case 3: return english ? 'locked' : 'gesperrt';
    default: return english ? 'open' : 'offen';
  }
}

export function externalSourceLabel(value: number): string {
  return externalSourceOptions.find(option => option.value === value)?.label ?? String(value);
}

export function duplicateKindLabel(kind: number): string {
  switch (kind) {
    case 0: return 'FIDE-ID';
    case 1: return 'DSB-ID/National-ID';
    case 2: return 'Name + Geburtsjahr';
    case 3: return 'Name';
    default: return String(kind);
  }
}

export function approximateAgeLabel(birthYear?: number | null): string {
  if (!birthYear || birthYear < 1900 || birthYear > 2100) {
    return '—';
  }

  const age = new Date().getFullYear() - birthYear;
  if (age < 0 || age > 130) {
    return '—';
  }

  // Nur das Geburtsjahr ist bekannt, daher als ca. markieren.
  return `~${age}`;
}

export function importPreviewStatusLabel(status: number): string {
  switch (status) {
    case 0: return 'bereit';
    case 1: return 'Warnung';
    case 2: return 'blockiert';
    default: return String(status);
  }
}

export function importPreviewStatusClass(status: number): string {
  switch (status) {
    case 0: return 'preview-ready';
    case 1: return 'preview-warning-row';
    case 2: return 'preview-blocked-row';
    default: return '';
  }
}

export function pairingQualitySeverityLabel(severity: number, english = false): string {
  switch (severity) {
    case 0: return english ? 'good' : 'gut';
    case 1: return english ? 'notice' : 'Hinweis';
    case 2: return english ? 'warning' : 'Warnung';
    case 3: return english ? 'critical' : 'kritisch';
    default: return String(severity);
  }
}

export function pairingQualitySeverityClass(severity: number): string {
  switch (severity) {
    case 0: return 'quality-good';
    case 1: return 'quality-notice';
    case 2: return 'quality-warning';
    case 3: return 'quality-critical';
    default: return '';
  }
}

export function auditSeverityKey(severity: number | string): 'info' | 'warning' | 'critical' {
  switch (String(severity)) {
    case '1':
    case 'Warning':
      return 'warning';
    case '2':
    case 'Critical':
      return 'critical';
    default:
      return 'info';
  }
}

export function auditSeverityLabel(severity: number | string): string {
  switch (auditSeverityKey(severity)) {
    case 'warning': return 'Warnung';
    case 'critical': return 'kritisch';
    default: return 'Info';
  }
}

export function auditSeverityClass(severity: number | string): string {
  return `audit-${auditSeverityKey(severity)}`;
}

export function auditActionLabel(action: number | string): string {
  switch (String(action)) {
    case '0':
    case 'TournamentCreated': return 'Turnier angelegt';
    case '1':
    case 'SettingsUpdated': return 'Einstellungen geändert';
    case '2':
    case 'TournamentImported': return 'Turnier importiert';
    case '3':
    case 'ExternalPlayerApplied': return 'Externe Spielerdaten';
    case '4':
    case 'TournamentReset': return 'Turnier zurückgesetzt';
    case '5':
    case 'TournamentDeleted': return 'Turnier gelöscht';
    case '10':
    case 'PlayerAdded': return 'Spieler hinzugefügt';
    case '11':
    case 'PlayerUpdated': return 'Spieler geändert';
    case '12':
    case 'PlayerStatusChanged': return 'Spielerstatus geändert';
    case '13':
    case 'PlayerRemoved': return 'Spieler entfernt';
    case '14':
    case 'PlayerWithdrawn': return 'Spieler zurückgezogen';
    case '20':
    case 'RoundGenerated': return 'Runde ausgelost';
    case '21':
    case 'ResultRecorded': return 'Ergebnis erfasst';
    case '22':
    case 'PairingOverridden': return 'Paarung korrigiert';
    case '23':
    case 'RoundLocked': return 'Runde gesperrt';
    case '24':
    case 'RoundUnlocked': return 'Runde entsperrt';
    case '25':
    case 'RoundVerified': return 'Runde geprüft';
    case '26':
    case 'RoundUnverified': return 'Prüfung zurückgenommen';
    case '27':
    case 'Chess960StartPositionsRolled': return 'Chess960-Startstellungen gewürfelt';
    case '28':
    case 'RoundPreviewGenerated': return 'Runde-Vorschau erzeugt';
    case '29':
    case 'PairingGenerationBlocked': return 'Auslosung blockiert';
    case '30':
    case 'AuditJournalExported': return 'Audit-Bundle exportiert';
    case '31':
    case 'AuditJournalMirrorFailed': return 'Audit-Spiegel fehlgeschlagen';
    default: return String(action);
  }
}

export function auditDateLabel(value: string): string {
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    return value || '—';
  }

  return parsed.toLocaleString('de-DE', { dateStyle: 'short', timeStyle: 'short' });
}

export function auditCsvCell(value: unknown): string {
  const text = value === null || value === undefined ? '' : String(value);
  return /[;"\r\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
}

export function tiebreakLabel(value: number): string {
  return tiebreakOptions.find(option => option.value === value)?.label ?? String(value);
}


