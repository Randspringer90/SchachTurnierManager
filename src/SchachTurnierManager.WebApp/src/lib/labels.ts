// Display formatting for enum-ish backend values (results, audit entries,
// import previews, pairing quality). Extracted from main.tsx (STM-FE-014).
import { optionLabel, externalSourceOptions, genderOptions, playerStatusOptions, resultOptions, tiebreakOptions } from './tournamentOptions';
import type { PwaStatus } from '../api/contracts';
export function pwaStatusLabel(status: PwaStatus, english = false): string {
  switch (status) {
    case 'checking': return english ? "Checking PWA…" : 'PWA wird geprüft…';
    case 'unsupported': return english ? "PWA unsupported" : 'PWA nicht unterstützt';
    case 'ready': return english ? "PWA ready" : 'PWA bereit';
    case 'installable': return english ? "PWA installable" : 'PWA installierbar';
    case 'installed': return english ? "PWA installed" : 'PWA installiert';
    case 'update-available': return english ? "PWA update available" : 'PWA-Update verfügbar';
    case 'error': return english ? "PWA service worker blocked" : 'PWA-Serviceworker blockiert';
    default: return english ? "PWA status unknown" : 'PWA-Status unbekannt';
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

export function duplicateKindLabel(kind: number, english = false): string {
  switch (kind) {
    case 0: return 'FIDE-ID';
    case 1: return 'DSB-ID/National-ID';
    case 2: return english ? "Name + birth year" : 'Name + Geburtsjahr';
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

export function importPreviewStatusLabel(status: number, english = false): string {
  switch (status) {
    case 0: return english ? "ready" : 'bereit';
    case 1: return english ? "Warning" : 'Warnung';
    case 2: return english ? "blocked" : 'blockiert';
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

export function auditSeverityLabel(severity: number | string, english = false): string {
  switch (auditSeverityKey(severity)) {
    case 'warning': return english ? "Warning" : 'Warnung';
    case 'critical': return english ? "critical" : 'kritisch';
    default: return 'Info';
  }
}

export function auditSeverityClass(severity: number | string): string {
  return `audit-${auditSeverityKey(severity)}`;
}

export function auditActionLabel(action: number | string, english = false): string {
  switch (String(action)) {
    case '0':
    case 'TournamentCreated': return english ? "Tournament created" : 'Turnier angelegt';
    case '1':
    case 'SettingsUpdated': return english ? "Settings changed" : 'Einstellungen geändert';
    case '2':
    case 'TournamentImported': return english ? "Tournament imported" : 'Turnier importiert';
    case '3':
    case 'ExternalPlayerApplied': return english ? "External player data" : 'Externe Spielerdaten';
    case '4':
    case 'TournamentReset': return english ? "Tournament reset" : 'Turnier zurückgesetzt';
    case '5':
    case 'TournamentDeleted': return english ? "Tournament deleted" : 'Turnier gelöscht';
    case '10':
    case 'PlayerAdded': return english ? "Player added" : 'Spieler hinzugefügt';
    case '11':
    case 'PlayerUpdated': return english ? "Player updated" : 'Spieler geändert';
    case '12':
    case 'PlayerStatusChanged': return english ? "Player status changed" : 'Spielerstatus geändert';
    case '13':
    case 'PlayerRemoved': return english ? "Player removed" : 'Spieler entfernt';
    case '14':
    case 'PlayerWithdrawn': return english ? "Player withdrawn" : 'Spieler zurückgezogen';
    case '20':
    case 'RoundGenerated': return english ? "Round paired" : 'Runde ausgelost';
    case '21':
    case 'ResultRecorded': return english ? "Result recorded" : 'Ergebnis erfasst';
    case '22':
    case 'PairingOverridden': return english ? "Pairing corrected" : 'Paarung korrigiert';
    case '23':
    case 'RoundLocked': return english ? "Round locked" : 'Runde gesperrt';
    case '24':
    case 'RoundUnlocked': return english ? "Round unlocked" : 'Runde entsperrt';
    case '25':
    case 'RoundVerified': return english ? "Round reviewed" : 'Runde geprüft';
    case '26':
    case 'RoundUnverified': return english ? "Review revoked" : 'Prüfung zurückgenommen';
    case '27':
    case 'Chess960StartPositionsRolled': return english ? "Chess960 starting positions rolled" : 'Chess960-Startstellungen gewürfelt';
    case '28':
    case 'RoundPreviewGenerated': return english ? "Round preview generated" : 'Runde-Vorschau erzeugt';
    case '29':
    case 'PairingGenerationBlocked': return english ? "Pairing blocked" : 'Auslosung blockiert';
    case '30':
    case 'AuditJournalExported': return english ? "Audit bundle exported" : 'Audit-Bundle exportiert';
    case '31':
    case 'AuditJournalMirrorFailed': return english ? "Audit mirror failed" : 'Audit-Spiegel fehlgeschlagen';
    case '32':
    case 'ResultCorrected': return english ? "Result corrected" : 'Ergebnis korrigiert';
    default: return String(action);
  }
}

export function auditDateLabel(value: string, locale = 'de-DE'): string {
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    return value || '—';
  }

  return parsed.toLocaleString(locale, { dateStyle: 'short', timeStyle: 'short' });
}

export { auditCsvCell } from './auditCsv';

export function tiebreakLabel(value: number, english = false): string {
  const option = tiebreakOptions.find(option => option.value === value);
  return option ? optionLabel(option, english) : String(value);
}
