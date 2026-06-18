import React from 'react';
import ReactDOM from 'react-dom/client';
import './styles.css';

type Health = {
  status: string;
  app: string;
  version: string;
  time: string;
  database?: string;
};

type RatingProfile = {
  manualTwz?: number | null;
  elo?: number | null;
  rapidElo?: number | null;
  blitzElo?: number | null;
  dwz?: number | null;
  dwzIndex?: number | null;
};

type Player = {
  id: string;
  name: string;
  club?: string | null;
  federation?: string | null;
  country?: string | null;
  birthYear?: number | null;
  gender: number;
  fideId?: string | null;
  nationalId?: string | null;
  title?: string | null;
  startingRank: number;
  rating: RatingProfile;
  status: number;
  notes?: string | null;
};

type GameResult = {
  kind: number;
  isPlayed: boolean;
  isBye: boolean;
};

type Chess960StartPosition = {
  whiteBackRank: string;
  blackBackRank: string;
  positionNumber: number;
  seed?: number | null;
  createdAt: string;
  notation: string;
  displayName: string;
};

type Pairing = {
  boardNumber: number;
  whitePlayerId?: string | null;
  blackPlayerId?: string | null;
  result: GameResult;
  notes?: string | null;
  isBye: boolean;
  isManualOverride: boolean;
  lastChangedAt?: string | null;
  chess960StartPosition?: Chess960StartPosition | null;
};

type PairingAudit = {
  algorithm: string;
  rulesetVersion: string;
  createdAt: string;
  messages: string[];
  scoreGroups: string[];
  floaters: string[];
  colorNotes: string[];
};

type TournamentRound = {
  roundNumber: number;
  pairings: Pairing[];
  audit: PairingAudit;
  isLocked: boolean;
  isVerified: boolean;
  resultStatus: number;
  lockedAt?: string | null;
  verifiedAt?: string | null;
  notes?: string | null;
};

type StandingRow = {
  rank: number;
  playerId: string;
  name: string;
  startingRank: number;
  twz: number;
  points: number;
  wins: number;
  blackWins: number;
  buchholz: number;
  buchholzCutOne: number;
  buchholzCutTwo: number;
  medianBuchholz: number;
  sonnebornBerger: number;
  koyaScore: number;
  progressiveScore: number;
  averageOpponentRating: number;
  tournamentPerformance?: number | null;
  heroScore: number;
  categories: Record<string, boolean>;
};

type Tournament = {
  id: string;
  name: string;
  createdOn: string;
  settings: {
    format: number;
    scoringSystem: number;
    twzSource: number;
    plannedRounds: number;
    seniorBirthYearOrEarlier?: number | null;
    heroCupMinimumRatedGames: number;
    forfeitTiebreakPolicy: number;
    countByeAsWin: boolean;
    allowManualPairingOverrides: boolean;
    tiebreaks: number[];
  };
  players: Player[];
  rounds: TournamentRound[];
};

type AuditJournalEntry = {
  id: string;
  createdAt: string;
  action: number | string;
  severity: number | string;
  actor: string;
  summary: string;
  details?: string | null;
  reason?: string | null;
  roundNumber?: number | null;
  boardNumber?: number | null;
  playerId?: string | null;
  playerName?: string | null;
};

type CategoryStandingTable = {
  category: string;
  rows: StandingRow[];
};

type CrossTable = {
  players: CrossTablePlayer[];
  rows: CrossTableRow[];
};

type CrossTablePlayer = {
  playerId: string;
  name: string;
  rank: number;
  startingRank: number;
  points: number;
};

type CrossTableRow = {
  playerId: string;
  name: string;
  rank: number;
  points: number;
  cells: CrossTableCell[];
};

type CrossTableCell = {
  playerId: string;
  opponentId: string;
  isSelf: boolean;
  roundNumber?: number | null;
  boardNumber?: number | null;
  color: number;
  resultLabel: string;
  points?: number | null;
  isBye: boolean;
  notes?: string | null;
};

type HeroCupRow = {
  rank: number;
  playerId: string;
  name: string;
  twz: number;
  ratedGames: number;
  actualScore: number;
  expectedScore: number;
  overPerformance: number;
  averageOpponentRating: number;
  tournamentPerformance?: number | null;
  reason: string;
};

type BoardDiagnostic = {
  boardNumber: number;
  white: string;
  black: string;
  result: number;
  resultLabel: string;
  isOpen: boolean;
  isForfeit: boolean;
  countsForBuchholz: boolean;
  countsForDirectAndSonneborn: boolean;
  countsForPerformance: boolean;
  note: string;
};

type RoundDiagnostics = {
  roundNumber: number;
  resultStatus: number;
  isComplete: boolean;
  isLocked: boolean;
  isVerified: boolean;
  openBoards: number;
  forfeitBoards: number;
  byeBoards: number;
  warnings: string[];
  boards: BoardDiagnostic[];
};

type PairingQualityBoard = {
  boardNumber: number;
  whitePlayerId?: string | null;
  blackPlayerId?: string | null;
  whiteName: string;
  blackName: string;
  whiteScoreBeforeRound: number;
  blackScoreBeforeRound: number;
  scoreDifference: number;
  isBye: boolean;
  isRematch: boolean;
  isCrossScoreGroupPairing: boolean;
  wouldGiveWhiteThirdSameColor: boolean;
  wouldGiveBlackThirdSameColor: boolean;
  findings: string[];
};

type PairingQualityReport = {
  roundNumber: number;
  boardCount: number;
  gameCount: number;
  byeCount: number;
  rematchCount: number;
  crossScoreGroupPairingCount: number;
  thirdSameColorRiskCount: number;
  maxScoreDifference: number;
  averageScoreDifference: number;
  qualityScore: number;
  severity: number;
  findings: string[];
  boards: PairingQualityBoard[];
  hasCriticalIssues: boolean;
  hasWarnings: boolean;
  findingCount: number;
};

type NextRoundPreview = {
  roundNumber: number;
  boardCount: number;
  isSavable: boolean;
  summary: string;
  round: TournamentRound;
  pairingQuality: PairingQualityReport;
  messages: string[];
};
type ExternalPlayerProviderInfo = {
  source: number;
  name: string;
  supportsIdLookup: boolean;
  supportsNameSearch: boolean;
  description: string;
  url?: string | null;
};

type ExternalPlayerProfile = {
  source: number;
  externalId: string;
  name: string;
  club?: string | null;
  federation?: string | null;
  country?: string | null;
  birthYear?: number | null;
  gender: number;
  fideId?: string | null;
  nationalId?: string | null;
  title?: string | null;
  elo?: number | null;
  rapidElo?: number | null;
  blitzElo?: number | null;
  dwz?: number | null;
  dwzIndex?: number | null;
  profileUrl?: string | null;
  retrievedAt: string;
  confidence: number;
  notes?: string | null;
  warnings: string[];
};

type ExternalPlayerLookupResult = {
  source: number;
  query: string;
  status: number;
  message: string;
  players: ExternalPlayerProfile[];
};

type ExternalPlayerAggregateSourceResult = {
  source: number;
  sourceName: string;
  status: number;
  isActive: boolean;
  message: string;
  count: number;
};

type ExternalPlayerAggregateResult = {
  query: string;
  mode: string;
  message: string;
  players: ExternalPlayerProfile[];
  sources: ExternalPlayerAggregateSourceResult[];
};

type ExternalPlayerDuplicateMatch = {
  playerId: string;
  playerName: string;
  kind: number;
  score: number;
  reason: string;
};

type ExternalPlayerDuplicateCheck = {
  profile: ExternalPlayerProfile;
  matches: ExternalPlayerDuplicateMatch[];
  hasLikelyDuplicate: boolean;
};

type ExternalPlayerApplyResult = {
  player: Player;
  created: boolean;
  updated: boolean;
  duplicateCheck: ExternalPlayerDuplicateCheck;
  changedFields: string[];
  message: string;
};

type PlayerImportPreview = {
  replaceExisting: boolean;
  rows: PlayerImportPreviewRow[];
  globalWarnings: string[];
  totalRows: number;
  importableRows: number;
  warningRows: number;
  blockingRows: number;
  likelyDuplicateRows: number;
  hasBlockingIssues: boolean;
};

type PlayerImportPreviewRow = {
  rowNumber: number;
  player: Player;
  profile: ExternalPlayerProfile;
  duplicateCheck: ExternalPlayerDuplicateCheck;
  warnings: string[];
  blockingIssues: string[];
  status: number;
};

type PairingEdit = { whitePlayerId: string; blackPlayerId: string; notes: string; };

type SettingsForm = {
  format: number;
  scoringSystem: number;
  twzSource: number;
  plannedRounds: string;
  forfeitTiebreakPolicy: number;
  countByeAsWin: boolean;
  allowManualPairingOverrides: boolean;
  seniorBirthYearOrEarlier: string;
  heroCupMinimumRatedGames: string;
  tiebreaks: number[];
};

type PlayerForm = {
  name: string;
  club: string;
  federation: string;
  country: string;
  birthYear: string;
  gender: number;
  dwz: string;
  dwzIndex: string;
  elo: string;
  rapidElo: string;
  blitzElo: string;
  manualTwz: string;
  fideId: string;
  nationalId: string;
  title: string;
  status: number;
  notes: string;
};

const resultOptions = [
  { value: 0, label: 'offen' },
  { value: 1, label: '1-0' },
  { value: 2, label: '½-½' },
  { value: 3, label: '0-1' },
  { value: 4, label: '+/- kampflos Weiß' },
  { value: 5, label: '-/+ kampflos Schwarz' },
  { value: 6, label: '-/- kampflos beide' },
  { value: 7, label: 'Bye' },
  { value: 8, label: 'Armageddon Weiß' },
  { value: 9, label: 'Armageddon Schwarz' }
];

const formatOptions = [
  { value: 1, label: 'Schweizer System' },
  { value: 0, label: 'Jeder gegen Jeden' }
];

const scoringOptions = [
  { value: 0, label: 'Klassisch: Sieg 1 · Remis ½ · Niederlage 0' },
  { value: 1, label: '3-1-0: Sieg 3 · Remis 1 · Niederlage 0' },
  { value: 2, label: 'Norway/Armageddon: Klassiksieg 3 · Armageddon 1½/1' }
];

const twzSourceOptions = [
  { value: 0, label: 'Manuelle TWZ → DWZ → Elo' },
  { value: 1, label: 'Manuelle TWZ → Elo → DWZ' },
  { value: 2, label: 'Manuelle TWZ → Rapid → Blitz → DWZ → Elo' }
];

const forfeitPolicyOptions = [
  { value: 0, label: 'Kampflose Partien nicht für Buchholz/SB/Direktwertung' },
  { value: 1, label: 'Kampflose Gegner nur für Buchholz/Gegnerschnitt' },
  { value: 2, label: 'Kampflose Partien wie normale Partien behandeln' }
];

const tiebreakOptions = [
  { value: 0, label: 'Direkter Vergleich' },
  { value: 1, label: 'Anzahl Siege' },
  { value: 2, label: 'Buchholz' },
  { value: 3, label: 'Buchholz Cut-1' },
  { value: 4, label: 'Sonneborn-Berger' },
  { value: 5, label: 'Gegnerschnitt' },
  { value: 6, label: 'Turnierleistung' },
  { value: 7, label: 'Buchholz Cut-2' },
  { value: 8, label: 'Median-Buchholz' },
  { value: 9, label: 'Progressiv' },
  { value: 10, label: 'Koya' },
  { value: 11, label: 'Schwarzsiege' },
  { value: 99, label: 'Startnummer' }
];

const genderOptions = [
  { value: 0, label: 'unbekannt' },
  { value: 1, label: 'offen' },
  { value: 2, label: 'weiblich' },
  { value: 3, label: 'männlich' },
  { value: 4, label: 'divers' }
];

const playerStatusOptions = [
  { value: 0, label: 'aktiv' },
  { value: 1, label: 'pausiert' },
  { value: 2, label: 'zurückgezogen' }
];

const externalSourceOptions = [
  { value: 0, label: 'FIDE' },
  { value: 1, label: 'DSB / DeWIS' },
  { value: 2, label: 'ThSB' },
  { value: 3, label: 'Lokal/Import' }
];

const emptyPlayerForm: PlayerForm = {
  name: '',
  club: '',
  federation: '',
  country: '',
  birthYear: '',
  gender: 0,
  dwz: '',
  dwzIndex: '',
  elo: '',
  rapidElo: '',
  blitzElo: '',
  manualTwz: '',
  fideId: '',
  nationalId: '',
  title: '',
  status: 0,
  notes: ''
};

const sampleCsvTemplate = `Name;Verein;Geburtsjahr;Geschlecht;DWZ;DWZIndex;Elo;TWZ;FIDE-ID;DSB-ID;Titel;Status;Notizen
Geisshirt, Marco;Ilmenauer SV;1990;männlich;1987;;1968;;4610563;;CM;Active;Beispielzeile bitte vor Import prüfen
Musterfrau, Anna;Beispielverein;2012;weiblich;1200;;1300;;;;Active;U14-Beispiel
`;

const defaultTiebreaks = [0, 1, 2, 4, 6, 99];

const emptySettingsForm: SettingsForm = {
  format: 1,
  scoringSystem: 0,
  twzSource: 0,
  plannedRounds: '5',
  forfeitTiebreakPolicy: 0,
  countByeAsWin: false,
  allowManualPairingOverrides: true,
  seniorBirthYearOrEarlier: '',
  heroCupMinimumRatedGames: '1',
  tiebreaks: defaultTiebreaks
};

async function requestJson<T>(url: string, init?: RequestInit): Promise<T> {
  const response = await fetch(url, {
    headers: { 'Content-Type': 'application/json', ...(init?.headers ?? {}) },
    ...init
  });
  if (!response.ok) {
    let message = `HTTP ${response.status}`;
    try {
      const body = await response.json() as { error?: string };
      message = body.error ?? message;
    } catch {
      // ignore non-json error body
    }
    throw new Error(message);
  }
  return await response.json() as T;
}

async function requestText(url: string): Promise<string> {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`);
  }
  return await response.text();
}

function resultLabel(kind: number): string {
  return resultOptions.find(option => option.value === kind)?.label ?? String(kind);
}

function genderLabel(kind: number): string {
  return genderOptions.find(option => option.value === kind)?.label ?? String(kind);
}

function statusLabel(kind: number): string {
  return playerStatusOptions.find(option => option.value === kind)?.label ?? String(kind);
}

function roundStatusLabel(kind: number): string {
  switch (kind) {
    case 1: return 'vollständig';
    case 2: return 'geprüft';
    case 3: return 'gesperrt';
    default: return 'offen';
  }
}

function twzOf(player: Player): number {
  return player.rating.manualTwz ?? player.rating.dwz ?? player.rating.elo ?? 0;
}

function numberOrNull(value: string): number | null {
  const trimmed = value.trim();
  return trimmed.length === 0 ? null : Number(trimmed);
}

function playerToForm(player: Player): PlayerForm {
  return {
    name: player.name,
    club: player.club ?? '',
    federation: player.federation ?? '',
    country: player.country ?? '',
    birthYear: player.birthYear?.toString() ?? '',
    gender: player.gender,
    dwz: player.rating.dwz?.toString() ?? '',
    dwzIndex: player.rating.dwzIndex?.toString() ?? '',
    elo: player.rating.elo?.toString() ?? '',
    rapidElo: player.rating.rapidElo?.toString() ?? '',
    blitzElo: player.rating.blitzElo?.toString() ?? '',
    manualTwz: player.rating.manualTwz?.toString() ?? '',
    fideId: player.fideId ?? '',
    nationalId: player.nationalId ?? '',
    title: player.title ?? '',
    status: player.status,
    notes: player.notes ?? ''
  };
}

function formToRequest(form: PlayerForm, startingRank?: number): unknown {
  return {
    name: form.name,
    club: form.club || null,
    federation: form.federation || null,
    country: form.country || null,
    birthYear: numberOrNull(form.birthYear),
    gender: form.gender,
    elo: numberOrNull(form.elo),
    rapidElo: numberOrNull(form.rapidElo),
    blitzElo: numberOrNull(form.blitzElo),
    dwz: numberOrNull(form.dwz),
    dwzIndex: numberOrNull(form.dwzIndex),
    manualTwz: numberOrNull(form.manualTwz),
    fideId: form.fideId || null,
    nationalId: form.nationalId || null,
    title: form.title || null,
    status: form.status,
    notes: form.notes || null,
    startingRank: startingRank ?? null
  };
}

function applyExternalProfileToForm(profile: ExternalPlayerProfile): PlayerForm {
  return {
    ...emptyPlayerForm,
    name: profile.name ?? '',
    club: profile.club ?? '',
    federation: profile.federation ?? '',
    country: profile.country ?? '',
    birthYear: profile.birthYear?.toString() ?? '',
    gender: profile.gender ?? 0,
    dwz: profile.dwz?.toString() ?? '',
    dwzIndex: profile.dwzIndex?.toString() ?? '',
    elo: profile.elo?.toString() ?? '',
    rapidElo: profile.rapidElo?.toString() ?? '',
    blitzElo: profile.blitzElo?.toString() ?? '',
    manualTwz: '',
    fideId: profile.fideId ?? (profile.source === 0 ? profile.externalId : ''),
    nationalId: profile.nationalId ?? '',
    title: profile.title ?? '',
    status: 0,
    notes: profile.notes ?? ''
  };
}

function externalSourceLabel(value: number): string {
  return externalSourceOptions.find(option => option.value === value)?.label ?? String(value);
}

function externalProfileKey(profile: ExternalPlayerProfile): string {
  return `${profile.source}-${profile.externalId || profile.fideId || profile.nationalId || profile.name}`;
}

function duplicateKindLabel(kind: number): string {
  switch (kind) {
    case 0: return 'FIDE-ID';
    case 1: return 'DSB-ID/National-ID';
    case 2: return 'Name + Geburtsjahr';
    case 3: return 'Name';
    default: return String(kind);
  }
}

function approximateAgeLabel(birthYear?: number | null): string {
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

function importPreviewStatusLabel(status: number): string {
  switch (status) {
    case 0: return 'bereit';
    case 1: return 'Warnung';
    case 2: return 'blockiert';
    default: return String(status);
  }
}

function importPreviewStatusClass(status: number): string {
  switch (status) {
    case 0: return 'preview-ready';
    case 1: return 'preview-warning-row';
    case 2: return 'preview-blocked-row';
    default: return '';
  }
}

function importPreviewMessages(row: PlayerImportPreviewRow): string[] {
  return [...row.blockingIssues, ...row.warnings];
}

function pairingQualitySeverityLabel(severity: number): string {
  switch (severity) {
    case 0: return 'gut';
    case 1: return 'Hinweis';
    case 2: return 'Warnung';
    case 3: return 'kritisch';
    default: return String(severity);
  }
}

function pairingQualitySeverityClass(severity: number): string {
  switch (severity) {
    case 0: return 'quality-good';
    case 1: return 'quality-notice';
    case 2: return 'quality-warning';
    case 3: return 'quality-critical';
    default: return '';
  }
}

function auditSeverityKey(severity: number | string): 'info' | 'warning' | 'critical' {
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

function auditSeverityLabel(severity: number | string): string {
  switch (auditSeverityKey(severity)) {
    case 'warning': return 'Warnung';
    case 'critical': return 'kritisch';
    default: return 'Info';
  }
}

function auditSeverityClass(severity: number | string): string {
  return `audit-${auditSeverityKey(severity)}`;
}

function auditActionLabel(action: number | string): string {
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
    default: return String(action);
  }
}

function auditDateLabel(value: string): string {
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    return value || '—';
  }

  return parsed.toLocaleString('de-DE', { dateStyle: 'short', timeStyle: 'short' });
}

function auditCsvCell(value: unknown): string {
  const text = value === null || value === undefined ? '' : String(value);
  return /[;"\r\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
}

function settingsToForm(tournament?: Tournament): SettingsForm {
  if (!tournament) {
    return emptySettingsForm;
  }

  const settings = tournament.settings;
  return {
    format: settings.format,
    scoringSystem: settings.scoringSystem,
    twzSource: settings.twzSource,
    plannedRounds: settings.plannedRounds.toString(),
    forfeitTiebreakPolicy: settings.forfeitTiebreakPolicy,
    countByeAsWin: settings.countByeAsWin,
    allowManualPairingOverrides: settings.allowManualPairingOverrides,
    seniorBirthYearOrEarlier: settings.seniorBirthYearOrEarlier?.toString() ?? '',
    heroCupMinimumRatedGames: settings.heroCupMinimumRatedGames.toString(),
    tiebreaks: settings.tiebreaks?.length ? settings.tiebreaks : defaultTiebreaks
  };
}

function formToSettings(form: SettingsForm) {
  const tiebreaks = Array.from(new Set([...form.tiebreaks, 99]));
  return {
    format: form.format,
    scoringSystem: form.scoringSystem,
    twzSource: form.twzSource,
    plannedRounds: Math.max(1, numberOrNull(form.plannedRounds) ?? 1),
    forfeitTiebreakPolicy: form.forfeitTiebreakPolicy,
    countByeAsWin: form.countByeAsWin,
    allowManualPairingOverrides: form.allowManualPairingOverrides,
    seniorBirthYearOrEarlier: numberOrNull(form.seniorBirthYearOrEarlier),
    heroCupMinimumRatedGames: Math.max(1, numberOrNull(form.heroCupMinimumRatedGames) ?? 1),
    tiebreaks
  };
}

function moveTiebreak(list: number[], index: number, direction: -1 | 1): number[] {
  const target = index + direction;
  if (target < 0 || target >= list.length) {
    return list;
  }

  const copy = [...list];
  const [item] = copy.splice(index, 1);
  copy.splice(target, 0, item);
  return copy;
}

function tiebreakLabel(value: number): string {
  return tiebreakOptions.find(option => option.value === value)?.label ?? String(value);
}

function downloadText(filename: string, content: string, type: string): void {
  const blob = new Blob([content], { type });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  link.remove();
  URL.revokeObjectURL(url);
}

const diceFaceGlyphs = ['♔', '♕', '♖', '♗', '♘', '♙'];
const diceFaceNames = ['König', 'Dame', 'Turm', 'Läufer', 'Springer', 'Bauer'];
const diceRestTransforms = [
  'rotateX(-18deg) rotateY(24deg)',
  'rotateY(-90deg)',
  'rotateY(180deg)',
  'rotateY(90deg)',
  'rotateX(-90deg)',
  'rotateX(90deg)'
];

function ChessDie({ rolling, spin, face }: { rolling: boolean; spin: number; face: number }): React.ReactElement {
  // Sichtbarer Holz-D6: tumbelt/fliegt beim Würfeln und legt sich danach auf die Ergebnisfigur.
  // Rein visuell – die tatsächliche, gültige Chess960-Stellung erzeugt der Backend-Service.
  const restStyle = rolling ? undefined : { transform: diceRestTransforms[face] ?? diceRestTransforms[0] };
  return (
    <div className="dice-stage">
      <div className={`dice-cube${rolling ? ' rolling' : ''}`} key={spin} style={restStyle}>
        {diceFaceGlyphs.map((glyph, index) => (
          <div key={index} className={`dice-face dice-face-${index}`}>{glyph}</div>
        ))}
      </div>
    </div>
  );
}

function App() {
  const [health, setHealth] = React.useState<Health | null>(null);
  const [tournaments, setTournaments] = React.useState<Tournament[]>([]);
  const [selectedId, setSelectedId] = React.useState<string>('');
  const [standings, setStandings] = React.useState<StandingRow[]>([]);
  const [categories, setCategories] = React.useState<CategoryStandingTable[]>([]);
  const [crossTable, setCrossTable] = React.useState<CrossTable | null>(null);
  const [heroCup, setHeroCup] = React.useState<HeroCupRow[]>([]);
  const [roundDiagnostics, setRoundDiagnostics] = React.useState<RoundDiagnostics[]>([]);
  const [auditJournal, setAuditJournal] = React.useState<AuditJournalEntry[]>([]);
  const [pairingQualityReports, setPairingQualityReports] = React.useState<Record<number, PairingQualityReport>>({});
  const [nextRoundPreview, setNextRoundPreview] = React.useState<NextRoundPreview | null>(null);
  const [isNextRoundPreviewDialogOpen, setIsNextRoundPreviewDialogOpen] = React.useState(false);
  const [chess960DialogRound, setChess960DialogRound] = React.useState<TournamentRound | null>(null);
  const [chess960Rolling, setChess960Rolling] = React.useState(false);
  const [chess960HasRolled, setChess960HasRolled] = React.useState(false);
  const [diceSpin, setDiceSpin] = React.useState(0);
  const [diceFace, setDiceFace] = React.useState(0);
  const [newTournamentName, setNewTournamentName] = React.useState('Vereinsturnier');
  const [format, setFormat] = React.useState(1);
  const [settingsForm, setSettingsForm] = React.useState<SettingsForm>(emptySettingsForm);
  const [playerForm, setPlayerForm] = React.useState<PlayerForm>(emptyPlayerForm);
  const [externalQuery, setExternalQuery] = React.useState('');
  const [externalLookup, setExternalLookup] = React.useState<ExternalPlayerAggregateResult | null>(null);
  const [externalSearching, setExternalSearching] = React.useState(false);
  const [externalDuplicateChecks, setExternalDuplicateChecks] = React.useState<Record<string, ExternalPlayerDuplicateCheck>>({});
  const [editingPlayerId, setEditingPlayerId] = React.useState<string | null>(null);
  const [csvContent, setCsvContent] = React.useState('Name;Verein;Geburtsjahr;Geschlecht;DWZ;DWZIndex;Elo;TWZ;FIDE-ID;DSB-ID;Titel;Status;Notizen\n');
  const [replacePlayers, setReplacePlayers] = React.useState(false);
  const [importPreview, setImportPreview] = React.useState<PlayerImportPreview | null>(null);
  const [confirmWarningImport, setConfirmWarningImport] = React.useState(false);
  const [backupJson, setBackupJson] = React.useState('');
  const [pairingEdits, setPairingEdits] = React.useState<Record<string, PairingEdit>>({});
  const [status, setStatus] = React.useState('Bereit.');
  const [error, setError] = React.useState<string | null>(null);
  const selectedTournament = tournaments.find(tournament => tournament.id === selectedId) ?? tournaments[0];
  const auditJournalRecentEntries = auditJournal.slice(0, 15);
  const auditJournalWarningCount = auditJournal.filter(entry => auditSeverityKey(entry.severity) === 'warning').length;
  const auditJournalCriticalCount = auditJournal.filter(entry => auditSeverityKey(entry.severity) === 'critical').length;
  const auditJournalInfoCount = auditJournal.length - auditJournalWarningCount - auditJournalCriticalCount;
  const auditJournalRoundEntryCount = auditJournal.filter(entry => entry.roundNumber !== null && entry.roundNumber !== undefined).length;
  const auditJournalPlayerEntryCount = auditJournal.filter(entry => Boolean(entry.playerId || entry.playerName)).length;

  const loadTournaments = React.useCallback(async (): Promise<Tournament[]> => {
    const data = await requestJson<Tournament[]>('/api/tournaments');
    setTournaments(data);
    if (!selectedId && data.length > 0) {
      setSelectedId(data[0].id);
    }
    return data;
  }, [selectedId]);

  const loadDerived = React.useCallback(async (id: string) => {
    if (!id) {
      setStandings([]);
      setCategories([]);
      setCrossTable(null);
      setHeroCup([]);
      setRoundDiagnostics([]);
      setAuditJournal([]);
      setPairingQualityReports({});
      setNextRoundPreview(null);
      setChess960DialogRound(null);
      return;
    }

    const [standingData, categoryData, crossTableData, heroCupData, diagnosticsData, auditJournalData] = await Promise.all([
      requestJson<StandingRow[]>(`/api/tournaments/${id}/standings`),
      requestJson<CategoryStandingTable[]>(`/api/tournaments/${id}/categories`),
      requestJson<CrossTable>(`/api/tournaments/${id}/cross-table`),
      requestJson<HeroCupRow[]>(`/api/tournaments/${id}/hero-cup`),
      requestJson<RoundDiagnostics[]>(`/api/tournaments/${id}/round-diagnostics`),
      requestJson<AuditJournalEntry[]>(`/api/tournaments/${id}/audit-journal`)
    ]);
    setStandings(standingData);
    setCategories(categoryData);
    setCrossTable(crossTableData);
    setHeroCup(heroCupData);
    setRoundDiagnostics(diagnosticsData);
    setAuditJournal(auditJournalData);
  }, []);

  const refresh = React.useCallback(async (preferredId?: string) => {
    const data = await loadTournaments();
    const id = preferredId ?? selectedTournament?.id ?? selectedId ?? data[0]?.id ?? '';
    if (id) {
      await loadDerived(id);
    }
  }, [loadDerived, loadTournaments, selectedId, selectedTournament?.id]);

  React.useEffect(() => {
    requestJson<Health>('/api/health')
      .then(setHealth)
      .catch((err: unknown) => setError(err instanceof Error ? err.message : String(err)));
    loadTournaments().catch((err: unknown) => setError(err instanceof Error ? err.message : String(err)));
  }, [loadTournaments]);

  React.useEffect(() => {
    if (selectedTournament?.id) {
      loadDerived(selectedTournament.id).catch((err: unknown) => setError(err instanceof Error ? err.message : String(err)));
    }
  }, [loadDerived, selectedTournament?.id]);

  React.useEffect(() => {
    setSettingsForm(settingsToForm(selectedTournament));
  }, [selectedTournament?.id]);

  React.useEffect(() => {
    setPairingQualityReports({});
    setNextRoundPreview(null);
    setIsNextRoundPreviewDialogOpen(false);
    setChess960DialogRound(null);
  }, [selectedTournament?.id]);

  React.useEffect(() => {
    if (!isNextRoundPreviewDialogOpen && !chess960DialogRound) {
      return undefined;
    }

    function closeOnEscape(event: KeyboardEvent): void {
      if (event.key === 'Escape') {
        setIsNextRoundPreviewDialogOpen(false);
        setChess960DialogRound(null);
      }
    }

    window.addEventListener('keydown', closeOnEscape);
    return () => window.removeEventListener('keydown', closeOnEscape);
  }, [isNextRoundPreviewDialogOpen, chess960DialogRound]);

  async function createTournament(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);
    const created = await requestJson<Tournament>('/api/tournaments', {
      method: 'POST',
      body: JSON.stringify({
        name: newTournamentName,
        settings: {
          ...formToSettings(emptySettingsForm),
          format
        }
      })
    });
    setSelectedId(created.id);
    setStatus(`Turnier angelegt: ${created.name}`);
    await refresh(created.id);
  }

  async function saveSettings(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!selectedTournament) {
      return;
    }

    setError(null);
    const updated = await requestJson<Tournament>(`/api/tournaments/${selectedTournament.id}/settings`, {
      method: 'PUT',
      body: JSON.stringify({ settings: formToSettings(settingsForm) })
    });
    setSelectedId(updated.id);
    setStatus('Turniereinstellungen gespeichert. Tabelle und Wertungen wurden neu berechnet.');
    await refresh(updated.id);
  }

  async function resetSelectedTournament() {
    if (!selectedTournament) {
      return;
    }

    const target = selectedTournament;
    const confirmed = window.confirm(`Turnier "${target.name}" wirklich auf Start zurücksetzen? Alle Runden und Ergebnisse werden entfernt, Teilnehmer und Einstellungen bleiben erhalten.`);
    if (!confirmed) {
      return;
    }

    setError(null);
    try {
      const updated = await requestJson<Tournament>(`/api/tournaments/${target.id}/reset`, { method: 'POST' });
      setNextRoundPreview(null);
      setIsNextRoundPreviewDialogOpen(false);
      setChess960DialogRound(null);
      setPairingQualityReports({});
      setStatus(`Turnier zurückgesetzt: ${updated.name}. Teilnehmer und Einstellungen wurden behalten.`);
      await refresh(updated.id);
    } catch (ex) {
      setError(`Zurücksetzen fehlgeschlagen: ${ex instanceof Error ? ex.message : String(ex)}`);
    }
  }

  async function deleteSelectedTournament() {
    if (!selectedTournament) {
      return;
    }

    const target = selectedTournament;
    const confirmed = window.confirm(`Turnier "${target.name}" wirklich löschen? Diese Aktion entfernt das Turnier aus der lokalen Datenbank.`);
    if (!confirmed) {
      return;
    }

    setError(null);
    try {
      await requestJson<{ deleted: boolean; id: string }>(`/api/tournaments/${target.id}`, { method: 'DELETE' });
      setStatus(`Turnier gelöscht: ${target.name}.`);
      setSelectedId('');
      setNextRoundPreview(null);
      setIsNextRoundPreviewDialogOpen(false);
      setChess960DialogRound(null);
      setPairingQualityReports({});
      const data = await loadTournaments();
      const nextId = data.find(item => item.id !== target.id)?.id ?? data[0]?.id ?? '';
      setSelectedId(nextId);
      await loadDerived(nextId);
    } catch (ex) {
      setError(`Löschen fehlgeschlagen: ${ex instanceof Error ? ex.message : String(ex)}`);
    }
  }

  function toggleTiebreak(value: number, enabled: boolean): void {
    setSettingsForm(previous => {
      const without = previous.tiebreaks.filter(item => item !== value);
      const next = enabled ? [...without, value] : without;
      return { ...previous, tiebreaks: next.length === 0 ? [99] : next };
    });
  }

  async function savePlayer(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!selectedTournament) {
      return;
    }

    setError(null);
    const existing = editingPlayerId ? selectedTournament.players.find(player => player.id === editingPlayerId) : undefined;
    const body = JSON.stringify(formToRequest(playerForm, existing?.startingRank));
    try {
      if (editingPlayerId) {
        await requestJson<Player>(`/api/tournaments/${selectedTournament.id}/players/${editingPlayerId}`, { method: 'PUT', body });
        setStatus('Teilnehmer aktualisiert.');
      } else {
        await requestJson<Player>(`/api/tournaments/${selectedTournament.id}/players`, { method: 'POST', body });
        setStatus('Teilnehmer gespeichert.');
      }

      setPlayerForm(emptyPlayerForm);
      setEditingPlayerId(null);
      await refresh(selectedTournament.id);
    } catch (ex) {
      setError(ex instanceof Error ? ex.message : String(ex));
    }
  }

  async function deleteOrWithdrawPlayer(player: Player) {
    if (!selectedTournament) {
      return;
    }

    setError(null);
    await requestJson<Player>(`/api/tournaments/${selectedTournament.id}/players/${player.id}`, { method: 'DELETE' });
    setStatus('Teilnehmer gelöscht oder zurückgezogen.');
    if (editingPlayerId === player.id) {
      setEditingPlayerId(null);
      setPlayerForm(emptyPlayerForm);
    }
    await refresh(selectedTournament.id);
  }

  async function setPlayerStatus(player: Player, newStatus: number) {
    if (!selectedTournament) {
      return;
    }

    setError(null);
    await requestJson<Player>(`/api/tournaments/${selectedTournament.id}/players/${player.id}/status`, {
      method: 'PATCH',
      body: JSON.stringify({ status: newStatus })
    });
    setStatus(`Status für ${player.name} geändert.`);
    await refresh(selectedTournament.id);
  }

  async function previewNextRound() {
    if (!selectedTournament) {
      return;
    }

    setError(null);
    const preview = await requestJson<NextRoundPreview>(`/api/tournaments/${selectedTournament.id}/pairings/preview-next-round`);
    setNextRoundPreview(preview);
    setIsNextRoundPreviewDialogOpen(true);
    setStatus(`Auslosungsvorschau Runde ${preview.roundNumber}: ${preview.pairingQuality.qualityScore}/100 · ${pairingQualitySeverityLabel(preview.pairingQuality.severity)}.`);
  }
  async function generateRound() {
    if (!selectedTournament) {
      return;
    }

    if (nextRoundPreview?.pairingQuality.hasCriticalIssues) {
      const confirmed = window.confirm('Die Vorschau enthält kritische Hinweise. Bei kleinen Turnieren können Rematches/Scoregruppen-Abweichungen unvermeidbar sein. Trotzdem Runde auslosen?');
      if (!confirmed) {
        return;
      }
    }

    setError(null);
    try {
      await requestJson<TournamentRound>(`/api/tournaments/${selectedTournament.id}/pairings/next-round`, { method: 'POST' });
      setStatus('Neue Runde ausgelost.');
      setNextRoundPreview(null);
      setIsNextRoundPreviewDialogOpen(false);
      await refresh(selectedTournament.id);
    } catch (ex) {
      setError(ex instanceof Error ? ex.message : String(ex));
    }
  }

  function openChess960Dice(round: TournamentRound) {
    // Aktuellsten Rundenstand aus dem geladenen Turnier nehmen (zeigt vorhandene Stellungen).
    const freshRound = selectedTournament?.rounds.find(item => item.roundNumber === round.roundNumber) ?? round;
    setChess960DialogRound(freshRound);
    setChess960Rolling(false);
    setChess960HasRolled(false);
  }

  async function performChess960Roll(round: TournamentRound) {
    if (!selectedTournament || chess960Rolling) {
      return;
    }

    const hasExistingPositions = round.pairings.some(pairing => pairing.chess960StartPosition);
    if (hasExistingPositions) {
      const confirmed = window.confirm('Vorhandene Startstellungen überschreiben?');
      if (!confirmed) {
        return;
      }
    }

    setError(null);
    setChess960Rolling(true);
    setDiceSpin(previous => previous + 1);

    // Sichtbare Wurfanimation; die gültige Stellung kommt anschließend vom validierten Backend-Service.
    const animation = new Promise<void>(resolve => setTimeout(resolve, 1250));
    try {
      const rollRequest = requestJson<TournamentRound>(`/api/tournaments/${selectedTournament.id}/rounds/${round.roundNumber}/chess960/start-positions`, {
        method: 'POST',
        body: JSON.stringify({ overwriteExisting: hasExistingPositions })
      });
      const [updated] = await Promise.all([rollRequest, animation]);
      setDiceFace(Math.floor(Math.random() * diceFaceGlyphs.length));
      setChess960DialogRound(updated);
      setChess960HasRolled(true);
      setStatus(`Chess960-Startstellungen für Runde ${updated.roundNumber} gewürfelt.`);
      await refresh(selectedTournament.id);
    } catch (ex) {
      setError(ex instanceof Error ? ex.message : String(ex));
    } finally {
      setChess960Rolling(false);
    }
  }

  async function recordResult(roundNumber: number, boardNumber: number, result: number) {
    if (!selectedTournament) {
      return;
    }
    setError(null);
    await requestJson<TournamentRound>(`/api/tournaments/${selectedTournament.id}/results`, {
      method: 'POST',
      body: JSON.stringify({ roundNumber, boardNumber, result })
    });
    setStatus(`Ergebnis Runde ${roundNumber}, Brett ${boardNumber} gespeichert.`);
    await refresh(selectedTournament.id);
  }

  function editKey(roundNumber: number, boardNumber: number): string {
    return `${roundNumber}-${boardNumber}`;
  }

  function pairingEdit(round: TournamentRound, pairing: Pairing): PairingEdit {
    const key = editKey(round.roundNumber, pairing.boardNumber);
    return pairingEdits[key] ?? {
      whitePlayerId: pairing.whitePlayerId ?? '',
      blackPlayerId: pairing.blackPlayerId ?? '',
      notes: pairing.notes ?? ''
    };
  }

  function updatePairingEdit(roundNumber: number, boardNumber: number, patch: Partial<PairingEdit>): void {
    const key = editKey(roundNumber, boardNumber);
    setPairingEdits(previous => ({
      ...previous,
      [key]: { ...(previous[key] ?? { whitePlayerId: '', blackPlayerId: '', notes: '' }), ...patch }
    }));
  }

  async function saveManualPairing(round: TournamentRound, pairing: Pairing) {
    if (!selectedTournament) {
      return;
    }
    const edit = pairingEdit(round, pairing);
    setError(null);
    await requestJson<TournamentRound>(`/api/tournaments/${selectedTournament.id}/rounds/${round.roundNumber}/boards/${pairing.boardNumber}/pairing`, {
      method: 'PUT',
      body: JSON.stringify({
        whitePlayerId: edit.whitePlayerId || null,
        blackPlayerId: edit.blackPlayerId || null,
        notes: edit.notes || null
      })
    });
    setStatus(`Paarung Runde ${round.roundNumber}, Brett ${pairing.boardNumber} manuell gespeichert.`);
    setPairingEdits(previous => {
      const copy = { ...previous };
      delete copy[editKey(round.roundNumber, pairing.boardNumber)];
      return copy;
    });
    await refresh(selectedTournament.id);
  }

  async function setRoundLock(round: TournamentRound, isLocked: boolean) {
    if (!selectedTournament) {
      return;
    }
    setError(null);
    await requestJson<TournamentRound>(`/api/tournaments/${selectedTournament.id}/rounds/${round.roundNumber}/lock`, {
      method: 'PATCH',
      body: JSON.stringify({ isLocked })
    });
    setStatus(isLocked ? `Runde ${round.roundNumber} gesperrt.` : `Runde ${round.roundNumber} entsperrt.`);
    await refresh(selectedTournament.id);
  }

  async function setRoundVerified(round: TournamentRound, isVerified: boolean) {
    if (!selectedTournament) {
      return;
    }
    setError(null);
    await requestJson<TournamentRound>(`/api/tournaments/${selectedTournament.id}/rounds/${round.roundNumber}/verify`, {
      method: 'PATCH',
      body: JSON.stringify({ isVerified })
    });
    setStatus(isVerified ? `Runde ${round.roundNumber} geprüft.` : `Runde ${round.roundNumber} wieder geöffnet.`);
    await refresh(selectedTournament.id);
  }

  async function searchExternalPlayers(event?: React.FormEvent<HTMLFormElement>) {
    event?.preventDefault();
    setError(null);
    const query = externalQuery.trim();
    if (!query) {
      setError('Bitte einen Namen oder eine FIDE-ID eingeben.');
      return;
    }

    setExternalSearching(true);
    try {
      const result = await requestJson<ExternalPlayerAggregateResult>(`/api/external-players/search-all?query=${encodeURIComponent(query)}`);
      setExternalLookup(result);
      setExternalDuplicateChecks({});
      setStatus(result.message);
    } catch (ex) {
      setError(`Spielersuche fehlgeschlagen: ${ex instanceof Error ? ex.message : String(ex)}`);
    } finally {
      setExternalSearching(false);
    }
  }

  function applyExternalPlayer(profile: ExternalPlayerProfile): void {
    setPlayerForm(applyExternalProfileToForm(profile));
    setEditingPlayerId(null);
    setStatus(`${profile.name} aus ${externalSourceLabel(profile.source)} in das Teilnehmerformular übernommen.`);
  }

  // Findet einen bereits im aktuellen Turnier vorhandenen Teilnehmer mit gleicher FIDE-/DSB-ID.
  // Grundlage für "Bereits Teilnehmer" und das Deaktivieren von "Als neuen Teilnehmer speichern".
  function existingParticipantForProfile(profile: ExternalPlayerProfile): Player | undefined {
    if (!selectedTournament) {
      return undefined;
    }
    const normId = (value?: string | null): string => (value ? value.replace(/[^a-z0-9]/gi, '').toUpperCase() : '');
    const fide = normId(profile.fideId);
    const national = normId(profile.nationalId);
    if (!fide && !national) {
      return undefined;
    }
    return selectedTournament.players.find(player =>
      (fide && normId(player.fideId) === fide) || (national && normId(player.nationalId) === national));
  }

  function editExistingFromProfile(player: Player): void {
    setEditingPlayerId(player.id);
    setPlayerForm(playerToForm(player));
    setStatus(`Vorhandenen Teilnehmer ${player.name} zum Bearbeiten geladen.`);
  }

  async function checkExternalDuplicates(profile: ExternalPlayerProfile): Promise<ExternalPlayerDuplicateCheck | null> {
    if (!selectedTournament) {
      setError('Bitte zuerst ein Turnier auswählen.');
      return null;
    }

    setError(null);
    const duplicateCheck = await requestJson<ExternalPlayerDuplicateCheck>(`/api/tournaments/${selectedTournament.id}/external-players/check-duplicates`, {
      method: 'POST',
      body: JSON.stringify({ profile })
    });
    setExternalDuplicateChecks(previous => ({ ...previous, [externalProfileKey(profile)]: duplicateCheck }));
    setStatus(duplicateCheck.hasLikelyDuplicate
      ? `${duplicateCheck.matches.length} mögliche Dublette(n) für ${profile.name} gefunden.`
      : `Keine sichere Dublette für ${profile.name} gefunden.`);
    return duplicateCheck;
  }

  async function applyExternalProfile(profile: ExternalPlayerProfile, targetPlayerId?: string, overwriteExistingValues = false): Promise<void> {
    if (!selectedTournament) {
      setError('Bitte zuerst ein Turnier auswählen.');
      return;
    }

    setError(null);
    try {
      const result = await requestJson<ExternalPlayerApplyResult>(`/api/tournaments/${selectedTournament.id}/external-players/apply`, {
        method: 'POST',
        body: JSON.stringify({
          profile,
          targetPlayerId: targetPlayerId || null,
          createIfNoTarget: !targetPlayerId,
          overwriteExistingValues
        })
      });
      setExternalDuplicateChecks(previous => ({ ...previous, [externalProfileKey(profile)]: result.duplicateCheck }));
      setEditingPlayerId(result.player.id);
      setPlayerForm(playerToForm(result.player));
      setStatus(`${result.message} Geänderte Felder: ${result.changedFields.length ? result.changedFields.join(', ') : 'keine'}.`);
      await refresh(selectedTournament.id);
    } catch (ex) {
      setError(ex instanceof Error ? ex.message : String(ex));
    }
  }

  function useSampleCsvTemplate(): void {
    setCsvContent(sampleCsvTemplate);
    setReplacePlayers(false);
    setImportPreview(null);
    setConfirmWarningImport(false);
    setStatus('CSV-Beispielvorlage eingefügt. Bitte Daten anpassen und danach Import prüfen.');
  }

  async function previewPlayersImport() {
    if (!selectedTournament) {
      setError('Bitte zuerst ein Turnier auswählen.');
      return;
    }

    setError(null);
    const preview = await requestJson<PlayerImportPreview>(`/api/tournaments/${selectedTournament.id}/players/preview-import.csv`, {
      method: 'POST',
      body: JSON.stringify({ content: csvContent, replaceExisting: replacePlayers })
    });
    setImportPreview(preview);
    setConfirmWarningImport(false);
    const blockerText = preview.hasBlockingIssues ? ' Blockierende Probleme müssen vor dem Import behoben werden.' : '';
    setStatus(`CSV geprüft: ${preview.totalRows} Zeilen · ${preview.importableRows} importierbar · ${preview.warningRows} Warnung(en) · ${preview.blockingRows} blockiert.${blockerText}`);
  }

  function pairingQualityFor(roundNumber: number): PairingQualityReport | undefined {
    return pairingQualityReports[roundNumber];
  }

  async function loadPairingQuality(roundNumber: number) {
    if (!selectedTournament) {
      setError('Bitte zuerst ein Turnier auswählen.');
      return;
    }

    setError(null);
    const report = await requestJson<PairingQualityReport>(`/api/tournaments/${selectedTournament.id}/rounds/${roundNumber}/pairing-quality`);
    setPairingQualityReports(previous => ({ ...previous, [roundNumber]: report }));
    setStatus(`Pairing-Qualität Runde ${roundNumber}: ${report.qualityScore}/100 · ${pairingQualitySeverityLabel(report.severity)}.`);
  }
  async function importPlayers() {
    if (!selectedTournament) {
      return;
    }

    if (!importPreview) {
      setError('Bitte CSV zuerst prüfen.');
      return;
    }

    if (importPreview.replaceExisting !== replacePlayers) {
      setError('Die Importoption wurde seit der Vorschau geändert. Bitte CSV erneut prüfen.');
      return;
    }

    if (importPreview.hasBlockingIssues) {
      setError('CSV enthält blockierende Probleme. Bitte zuerst korrigieren und erneut prüfen.');
      return;
    }

    if (importPreview.warningRows > 0 && !confirmWarningImport) {
      setError('CSV enthält Warnungen oder mögliche Dubletten. Bitte Warnungen bewusst bestätigen oder CSV korrigieren und erneut prüfen.');
      return;
    }

    setError(null);
    const imported = await requestJson<Player[]>(`/api/tournaments/${selectedTournament.id}/players/import.csv`, {
      method: 'POST',
      body: JSON.stringify({ content: csvContent, replaceExisting: replacePlayers })
    });
    setImportPreview(null);
    setConfirmWarningImport(false);
    setStatus(`${imported.length} Teilnehmer importiert.`);
    await refresh(selectedTournament.id);
  }

  async function exportPlayers() {
    if (!selectedTournament) {
      return;
    }

    const csv = await requestText(`/api/tournaments/${selectedTournament.id}/players/export.csv`);
    downloadText(`${selectedTournament.name}-teilnehmer.csv`, csv, 'text/csv;charset=utf-8');
  }

  function openNextRoundPreviewCsv() {
    if (!selectedTournament) {
      return;
    }
    window.open(`/api/tournaments/${selectedTournament.id}/pairings/preview-next-round/export.csv`, '_blank', 'noopener,noreferrer');
  }

  function openNextRoundPreviewPrint() {
    if (!selectedTournament) {
      return;
    }
    window.open(`/api/tournaments/${selectedTournament.id}/pairings/preview-next-round/print/html`, '_blank', 'noopener,noreferrer');
  }

  function openTournamentExport(path: string) {
    if (!selectedTournament) {
      return;
    }

    window.open(`/api/tournaments/${selectedTournament.id}/${path}`, '_blank', 'noopener,noreferrer');
  }

  function latestRoundNumber(): number | null {
    if (!selectedTournament || selectedTournament.rounds.length === 0) {
      return null;
    }
    return selectedTournament.rounds.reduce((max, round) => Math.max(max, round.roundNumber), 0);
  }

  function activePlayerCount(): number {
    return selectedTournament?.players.filter(player => player.status === 0).length ?? 0;
  }

  function inactivePlayerCount(): number {
    return selectedTournament?.players.filter(player => player.status !== 0).length ?? 0;
  }

  function totalOpenBoardCount(): number {
    return roundDiagnostics.reduce((sum, item) => sum + item.openBoards, 0);
  }

  function totalForfeitBoardCount(): number {
    return roundDiagnostics.reduce((sum, item) => sum + item.forfeitBoards, 0);
  }

  function openLatestRoundPrint() {
    const roundNumber = latestRoundNumber();
    if (roundNumber === null) {
      setError('Es gibt noch keine Runde für den Rundenaushang.');
      return;
    }
    openRoundPrint(roundNumber);
  }

  function openLatestPairingsCsv() {
    const roundNumber = latestRoundNumber();
    if (!selectedTournament || roundNumber === null) {
      setError('Es gibt noch keine Runde für den Paarungsexport.');
      return;
    }
    window.open(`/api/tournaments/${selectedTournament.id}/pairings/export.csv?roundNumber=${roundNumber}`, '_blank', 'noopener,noreferrer');
  }

  function exportAuditJournalCsv(): void {
    if (!selectedTournament) {
      return;
    }

    const header = ['Zeitpunkt', 'Schweregrad', 'Aktion', 'Akteur', 'Runde', 'Brett', 'Spieler', 'Zusammenfassung', 'Details', 'Grund'];
    const rows = auditJournal.map(entry => [
      auditDateLabel(entry.createdAt),
      auditSeverityLabel(entry.severity),
      auditActionLabel(entry.action),
      entry.actor,
      entry.roundNumber ?? '',
      entry.boardNumber ?? '',
      entry.playerName ?? entry.playerId ?? '',
      entry.summary,
      entry.details ?? '',
      entry.reason ?? ''
    ].map(auditCsvCell).join(';'));

    downloadText(`${selectedTournament.name}-auditjournal.csv`, [header.join(';'), ...rows].join('\r\n'), 'text/csv;charset=utf-8');
  }

  function exportAuditJournalJson(): void {
    if (!selectedTournament) {
      return;
    }

    downloadText(`${selectedTournament.name}-auditjournal.json`, JSON.stringify(auditJournal, null, 2), 'application/json;charset=utf-8');
  }

function openRoundPrint(roundNumber: number) {
    if (!selectedTournament) {
      return;
    }

    window.open(`/api/tournaments/${selectedTournament.id}/rounds/${roundNumber}/print/html`, '_blank', 'noopener,noreferrer');
  }

  async function exportTournamentJson() {
    if (!selectedTournament) {
      return;
    }

    const text = await requestText(`/api/tournaments/${selectedTournament.id}/export/json`);
    setBackupJson(JSON.stringify(JSON.parse(text), null, 2));
    downloadText(`${selectedTournament.name}-backup.json`, JSON.stringify(JSON.parse(text), null, 2), 'application/json;charset=utf-8');
  }

  async function importTournamentJson() {
    const parsed = JSON.parse(backupJson) as Tournament;
    const imported = await requestJson<Tournament>('/api/tournaments/import', {
      method: 'POST',
      body: JSON.stringify({ tournament: parsed, overwriteExisting: true })
    });
    setSelectedId(imported.id);
    setStatus(`Turnier importiert: ${imported.name}`);
    await refresh(imported.id);
  }

  function playerNameById(id?: string | null): string {
    if (!id || !selectedTournament) {
      return '—';
    }
    return selectedTournament.players.find(player => player.id === id)?.name ?? id.slice(0, 8);
  }

  function chess960Display(pairing: Pairing): string {
    if (!pairing.chess960StartPosition) {
      return pairing.isBye ? 'spielfrei' : 'noch nicht gewürfelt';
    }

    return `${pairing.chess960StartPosition.whiteBackRank} · SP ${pairing.chess960StartPosition.positionNumber}`;
  }

  function chess960SeedDisplay(pairing: Pairing): string {
    return pairing.chess960StartPosition?.seed === null || pairing.chess960StartPosition?.seed === undefined
      ? ''
      : `Seed ${pairing.chess960StartPosition.seed}`;
  }

  function chess960PositionCount(round: TournamentRound): number {
    return round.pairings.filter(pairing => pairing.chess960StartPosition).length;
  }

  function chess960GameBoardCount(round: TournamentRound): number {
    return round.pairings.filter(pairing => !pairing.isBye).length;
  }

  function editPlayer(player: Player): void {
    setEditingPlayerId(player.id);
    setPlayerForm(playerToForm(player));
  }

  function diagnosticsFor(roundNumber: number): RoundDiagnostics | undefined {
    return roundDiagnostics.find(item => item.roundNumber === roundNumber);
  }

  function completedRoundCount(): number {
    return roundDiagnostics.filter(item => item.isComplete).length;
  }

  function unverifiedCompleteRoundCount(): number {
    return roundDiagnostics.filter(item => item.isComplete && !item.isVerified).length;
  }

  function lockedRoundCount(): number {
    return selectedTournament?.rounds.filter(round => round.isLocked).length ?? 0;
  }

  function diagnosticWarningCount(): number {
    return roundDiagnostics.reduce((sum, item) => sum + item.warnings.length, 0);
  }

  function resultReviewRows() {
    return roundDiagnostics
      .flatMap(round => round.boards
        .filter(board => board.isOpen || board.isForfeit || board.note.trim().length > 0)
        .map(board => ({
          roundNumber: round.roundNumber,
          boardNumber: board.boardNumber,
          white: board.white,
          black: board.black,
          resultLabel: board.resultLabel,
          note: board.note,
          kind: board.isOpen ? 'offen' : board.isForfeit ? 'kampflos' : 'Hinweis'
        })))
      .slice(0, 12);
  }

  function resultReviewStatusLabel(): string {
    if (!selectedTournament || selectedTournament.rounds.length === 0) {
      return 'noch keine Runde';
    }
    if (totalOpenBoardCount() > 0) {
      return 'offene Ergebnisse';
    }
    if (unverifiedCompleteRoundCount() > 0) {
      return 'Prüfung offen';
    }
    if (diagnosticWarningCount() > 0) {
      return 'Hinweise prüfen';
    }
    return 'bereit';
  }

  function resultReviewStatusClass(): string {
    const label = resultReviewStatusLabel();
    if (label === 'bereit') {
      return 'result-review-status ok';
    }
    if (label === 'offene Ergebnisse') {
      return 'result-review-status danger';
    }
    return 'result-review-status warn';
  }
  function totalByeBoardCount(): number {
    return roundDiagnostics.reduce((sum, item) => sum + item.byeBoards, 0);
  }

  function byeForfeitAffectedRoundCount(): number {
    return new Set(roundDiagnostics
      .filter(item => item.byeBoards > 0 || item.forfeitBoards > 0)
      .map(item => item.roundNumber)).size;
  }

  function byeForfeitRows() {
    return roundDiagnostics
      .flatMap(round => round.boards
        .filter(board => board.isForfeit
          || board.note.toLowerCase().includes('bye')
          || board.note.toLowerCase().includes('spielfrei')
          || board.black.toLowerCase().includes('spielfrei'))
        .map(board => ({
          roundNumber: round.roundNumber,
          boardNumber: board.boardNumber,
          white: board.white,
          black: board.black,
          resultLabel: board.resultLabel,
          note: board.note,
          isForfeit: board.isForfeit,
          countsForBuchholz: board.countsForBuchholz,
          countsForDirectAndSonneborn: board.countsForDirectAndSonneborn,
          countsForPerformance: board.countsForPerformance,
          kind: board.note.toLowerCase().includes('bye') || board.note.toLowerCase().includes('spielfrei') || board.black.toLowerCase().includes('spielfrei') ? 'Bye/spielfrei' : 'kampflos'
        })))
      .slice(0, 20);
  }

  function byeForfeitAuditStatusLabel(): string {
    if (!selectedTournament || selectedTournament.rounds.length === 0) {
      return 'noch keine Runde';
    }
    if (totalForfeitBoardCount() > 0) {
      return 'kampflos prüfen';
    }
    if (totalByeBoardCount() > 0) {
      return 'Bye sichtbar';
    }
    return 'keine Fälle';
  }

  function byeForfeitAuditStatusClass(): string {
    const label = byeForfeitAuditStatusLabel();
    if (label === 'keine Fälle') {
      return 'bye-forfeit-status ok';
    }
    if (label === 'kampflos prüfen') {
      return 'bye-forfeit-status warn';
    }
    return 'bye-forfeit-status info';
  }
  function pairingReadinessOpenResultCount(): number {
    return totalOpenBoardCount();
  }

  function pairingReadinessUnverifiedRoundCount(): number {
    if (!selectedTournament) {
      return 0;
    }

    return selectedTournament.rounds.filter(round => {
      const diagnostics = diagnosticsFor(round.roundNumber);
      return diagnostics !== undefined && diagnostics.openBoards === 0 && !round.isVerified;
    }).length;
  }

  function pairingReadinessIssues(): string[] {
    const issues = pairingReadinessBlockingIssues();

    if (!selectedTournament) {
      return issues;
    }

    const unverifiedRounds = pairingReadinessUnverifiedRoundCount();
    if (unverifiedRounds > 0) {
      issues.push(`${unverifiedRounds} vollständige Runde(n) sind noch nicht als geprüft markiert.`);
    }

    if (nextRoundPreview?.pairingQuality.hasCriticalIssues) {
      issues.push('Die aktuelle Auslosungsvorschau enthält kritische Hinweise. Bei kleinen Turnieren kann das unvermeidbar sein; nach bewusster Prüfung darf trotzdem ausgelost werden.');
    }

    return issues;
  }

  function pairingReadinessBlockingIssues(): string[] {
    const issues: string[] = [];

    if (!selectedTournament) {
      issues.push('Kein Turnier ausgewählt.');
      return issues;
    }

    const activePlayers = activePlayerCount();
    if (activePlayers < 2) {
      issues.push('Für eine Auslosung werden mindestens zwei aktive Spieler benötigt.');
    }

    const openResults = pairingReadinessOpenResultCount();
    if (openResults > 0) {
      issues.push(`${openResults} offene Ergebnis(se) müssen vor der nächsten Auslosung geklärt werden.`);
    }

    if (selectedTournament.rounds.length >= selectedTournament.settings.plannedRounds) {
      issues.push(`Die geplante Rundenzahl (${selectedTournament.settings.plannedRounds}) ist bereits erreicht.`);
    }

    return issues;
  }

  function pairingReadinessStatusLabel(): string {
    if (!selectedTournament) {
      return 'kein Turnier';
    }

    if (pairingReadinessBlockingIssues().length > 0) {
      return 'blockiert';
    }

    if (pairingReadinessUnverifiedRoundCount() > 0 || nextRoundPreview?.pairingQuality.hasCriticalIssues) {
      return 'prüfen';
    }

    return 'bereit';
  }

  function pairingReadinessStatusClass(): string {
    const label = pairingReadinessStatusLabel();
    if (label === 'bereit') {
      return 'pairing-readiness-status ok';
    }
    if (label === 'prüfen') {
      return 'pairing-readiness-status warn';
    }
    if (label === 'blockiert') {
      return 'pairing-readiness-status danger';
    }
    return 'pairing-readiness-status neutral';
  }

  function pairingReadinessCanCreatePreview(): boolean {
    return pairingReadinessBlockingIssues().length === 0;
  }

  function pairingReadinessCanGenerateRound(): boolean {
    // Kleine Turniere können unvermeidbare Rematches, Scoregruppen-Abweichungen
    // und ungeprüfte Warnhinweise haben. Diese Punkte sollen warnen, aber die
    // Auslosung nach bewusster Turnierleiter-Entscheidung nicht hart blockieren.
    return pairingReadinessCanCreatePreview();
  }
  function correctionJournalItems() {
    if (!selectedTournament) {
      return [];
    }

    const items: Array<{
      key: string;
      scope: string;
      severity: 'info' | 'warning' | 'critical';
      title: string;
      detail: string;
      action: string;
    }> = [];

    for (const player of selectedTournament.players.filter(player => player.status !== 0)) {
      items.push({
        key: `player-status-${player.id}`,
        scope: 'Teilnehmer',
        severity: 'warning',
        title: `${player.name} ist ${statusLabel(player.status).toLowerCase()}`,
        detail: `${player.name}${player.club ? ` · ${player.club}` : ''}${player.notes ? ` · ${player.notes}` : ''}`,
        action: 'Teilnehmerstatus vor der nächsten Auslosung und vor Aushängen bewusst prüfen.'
      });
    }

    for (const round of selectedTournament.rounds) {
      const diagnostics = diagnosticsFor(round.roundNumber);
      const openBoards = diagnostics?.openBoards ?? 0;
      const roundStatus = roundStatusLabel(round.resultStatus);

      if (round.isLocked) {
        items.push({
          key: `round-locked-${round.roundNumber}`,
          scope: 'Runde',
          severity: 'info',
          title: `Runde ${round.roundNumber} ist gesperrt`,
          detail: `${roundStatus} · ${round.pairings.length} Brett(er)`,
          action: 'Gesperrte Runde nur für bewusste Turnierleiter-Korrekturen wieder öffnen.'
        });
      }

      if (round.isVerified) {
        items.push({
          key: `round-verified-${round.roundNumber}`,
          scope: 'Runde',
          severity: 'info',
          title: `Runde ${round.roundNumber} ist geprüft`,
          detail: `${roundStatus} · ${round.pairings.length} Brett(er)`,
          action: 'Geprüfte Runde vor Änderungen nur nach Rücksprache/Turnierleiterentscheidung öffnen.'
        });
      } else if (round.pairings.length > 0 && openBoards === 0) {
        items.push({
          key: `round-unverified-${round.roundNumber}`,
          scope: 'Runde',
          severity: 'warning',
          title: `Runde ${round.roundNumber} ist vollständig, aber nicht geprüft`,
          detail: `${roundStatus} · keine offenen Bretter laut Diagnose`,
          action: 'Vor nächster Auslosung Ergebniszettel prüfen und Runde als geprüft markieren.'
        });
      }

      for (const pairing of round.pairings) {
        const resultText = resultLabel(pairing.result.kind);
        const lowerResult = resultText.toLowerCase();
        const whiteName = playerNameById(pairing.whitePlayerId);
        const blackName = pairing.isBye ? 'spielfrei' : playerNameById(pairing.blackPlayerId);
        const hasSpecialResult = pairing.isBye || lowerResult.includes('kampflos') || lowerResult.includes('bye') || lowerResult.includes('spielfrei');

        if (pairing.isManualOverride) {
          items.push({
            key: `manual-pairing-${round.roundNumber}-${pairing.boardNumber}`,
            scope: 'Paarung',
            severity: 'critical',
            title: `Manuelle Paarung R${round.roundNumber}/B${pairing.boardNumber}`,
            detail: `${whiteName} – ${blackName}${pairing.notes ? ` · ${pairing.notes}` : ''}`,
            action: 'Manuelle Paarung vor Veröffentlichung, Auslosung und Export gegen Turnierleiterentscheidung prüfen.'
          });
        }

        if (hasSpecialResult) {
          items.push({
            key: `special-result-${round.roundNumber}-${pairing.boardNumber}`,
            scope: 'Ergebnis',
            severity: pairing.isBye ? 'info' : 'warning',
            title: `${pairing.isBye ? 'Bye/spielfrei' : 'Sonderergebnis'} R${round.roundNumber}/B${pairing.boardNumber}`,
            detail: `${whiteName} – ${blackName} · ${resultText}`,
            action: 'Wertungsauswirkung in Bye-/Kampflos-Audit und Tabelle kontrollieren.'
          });
        }
      }
    }

    return items.slice(0, 60);
  }

  const correctionJournal = correctionJournalItems();
  const correctionJournalCriticalCount = correctionJournal.filter(item => item.severity === 'critical').length;
  const correctionJournalWarningCount = correctionJournal.filter(item => item.severity === 'warning').length;
  const correctionJournalInfoCount = correctionJournal.filter(item => item.severity === 'info').length;
  const correctionJournalStatusClass = !selectedTournament
    ? 'blocked'
    : correctionJournalCriticalCount > 0
      ? 'blocked'
      : correctionJournalWarningCount > 0
        ? 'warning'
        : 'ready';
  const correctionJournalStatusLabel = !selectedTournament
    ? 'kein Turnier'
    : correctionJournalCriticalCount > 0
      ? 'kritisch'
      : correctionJournalWarningCount > 0
        ? 'prüfen'
        : 'unauffällig';

  return (
    <main className="shell">
      <header className="hero">
        <div>
          <p className="eyebrow">Lokaler Turnierleiter · v0.38.5</p>
          <h1>SchachTurnierManager</h1>
          <p>Persistenter Turnierleiter mit SQLite, Schweizer-System-Audit, manuellen Paarungskorrekturen, Rundensperren, kampflose Ergebnisse, Kategorien, Kreuztabelle und Im-/Export.</p>
        </div>
        <div className="status-card">
          <strong>Backend</strong>
          {health && <span className="ok">{health.app} {health.version}: {health.status}</span>}
          {!health && !error && <span>Prüfe API…</span>}
          {health?.database && <small>{health.database}</small>}
        </div>
      </header>

      <section className="status-line">
        <span>{status}</span>
        {error && <strong className="error">{error}</strong>}
      </section>

      {nextRoundPreview && isNextRoundPreviewDialogOpen && (
        <div className="modal-backdrop" role="dialog" aria-modal="true" aria-label={`Auslosungsvorschau Runde ${nextRoundPreview.roundNumber}`}>
          <article className={`card preview-card preview-modal ${pairingQualitySeverityClass(nextRoundPreview.pairingQuality.severity)}`}>
            <div className="preview-card-header">
              <div>
                <p className="eyebrow">Popup-Vorschau · noch nicht gespeichert</p>
                <h3>Auslosungsvorschau Runde {nextRoundPreview.roundNumber}</h3>
                <p className="muted">{nextRoundPreview.summary}</p>
              </div>
              <div className="preview-score">
                <strong>{nextRoundPreview.pairingQuality.qualityScore}/100</strong>
                <span>{pairingQualitySeverityLabel(nextRoundPreview.pairingQuality.severity)}</span>
              </div>
            </div>
            <div className="preview-metrics">
              <span>{nextRoundPreview.boardCount} Bretter</span>
              <span>{nextRoundPreview.pairingQuality.rematchCount} Rematches</span>
              <span>{nextRoundPreview.pairingQuality.crossScoreGroupPairingCount} Scoregruppen-Hinweise</span>
              <span>{nextRoundPreview.pairingQuality.thirdSameColorRiskCount} Farbfolge-Risiken</span>
              <span>{nextRoundPreview.pairingQuality.byeCount} Bye</span>
            </div>
            {nextRoundPreview.pairingQuality.hasCriticalIssues && (
              <div className="preview-warning critical">
                <strong>Hinweise prüfen, aber nicht automatisch blockieren:</strong> Bei kleinen Turnieren sind Rematches und Scoregruppen-Abweichungen häufig unvermeidbar.
              </div>
            )}
            {nextRoundPreview.messages.length > 0 && <ul className="message-list preview-message-list">{nextRoundPreview.messages.map((message, index) => <li key={`preview-modal-message-${index}`}>{message}</li>)}</ul>}
            {nextRoundPreview.pairingQuality.findings.length > 0 && <ul className="message-list preview-message-list">{nextRoundPreview.pairingQuality.findings.map((finding, index) => <li key={`preview-modal-quality-${index}`}>{finding}</li>)}</ul>}
            <div className="table-scroll compact preview-pairings preview-modal-table">
              <table>
                <thead><tr><th>Brett</th><th>Weiß</th><th>Schwarz</th><th>Score vor Runde</th><th>Hinweise</th></tr></thead>
                <tbody>
                  {nextRoundPreview.pairingQuality.boards.map(board => (
                    <tr key={`preview-modal-board-${board.boardNumber}`} className={board.isRematch ? 'quality-board-critical' : board.wouldGiveWhiteThirdSameColor || board.wouldGiveBlackThirdSameColor ? 'quality-board-warning' : board.isCrossScoreGroupPairing || board.isBye ? 'quality-board-notice' : ''}>
                      <td>{board.boardNumber}</td>
                      <td>{board.whiteName}</td>
                      <td>{board.isBye ? 'spielfrei' : board.blackName}</td>
                      <td>{board.isBye ? 'Bye' : `${board.whiteScoreBeforeRound} : ${board.blackScoreBeforeRound}`}</td>
                      <td>{board.findings.length === 0 ? <span className="ok">ok</span> : <ul className="message-list">{board.findings.map((finding, index) => <li key={`preview-modal-board-${board.boardNumber}-${index}`}>{finding}</li>)}</ul>}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <div className="actions preview-actions">
              <button type="button" onClick={() => void generateRound()} disabled={!pairingReadinessCanGenerateRound()}>Diese Runde jetzt auslosen</button>
              <button type="button" className="secondary" onClick={openNextRoundPreviewPrint}>Druckansicht öffnen</button>
              <button type="button" className="secondary" onClick={openNextRoundPreviewCsv}>CSV exportieren</button>
              <button type="button" className="secondary" onClick={() => setIsNextRoundPreviewDialogOpen(false)}>Schließen</button>
            </div>
          </article>
        </div>
      )}

      {chess960DialogRound && (
        <div className="modal-backdrop" role="dialog" aria-modal="true" aria-label={`Schachwürfel Runde ${chess960DialogRound.roundNumber}`}>
          <article className="card chess960-modal">
            <div className="preview-card-header">
              <div>
                <p className="eyebrow">Schachwürfel · Chess960</p>
                <h3>Schachwürfel Runde {chess960DialogRound.roundNumber}</h3>
                <p className="muted">Pro regulärem Brett wird eine gültige Chess960-Startstellung ausgewürfelt (Läufer verschiedenfarbig, König zwischen den Türmen). Sie wird am Brett gespeichert und bleibt nach Reload/Backup erhalten.</p>
              </div>
              <div className="preview-score">
                <strong>{chess960PositionCount(chess960DialogRound)}</strong>
                <span>von {chess960GameBoardCount(chess960DialogRound)} Brettern</span>
              </div>
            </div>

            <ChessDie rolling={chess960Rolling} spin={diceSpin} face={diceFace} />
            <p className="dice-result-line">
              {chess960Rolling
                ? 'Der Würfel rollt …'
                : chess960HasRolled
                  ? `Gewürfelt: ${diceFaceNames[diceFace]} ${diceFaceGlyphs[diceFace]} · ${chess960PositionCount(chess960DialogRound)} gültige Startstellung(en) gespeichert.`
                  : 'Bereit zum Würfeln. Eine komplette Chess960-Auslosung pro Brett wird erzeugt.'}
            </p>
            <div className="dice-modal-actions">
              <button type="button" onClick={() => void performChess960Roll(chess960DialogRound)} disabled={chess960Rolling || chess960DialogRound.isLocked || chess960DialogRound.isVerified || chess960GameBoardCount(chess960DialogRound) === 0}>
                {chess960Rolling ? 'Würfelt …' : chess960PositionCount(chess960DialogRound) > 0 ? '🎲 Neu würfeln' : '🎲 Würfeln'}
              </button>
            </div>

            {chess960PositionCount(chess960DialogRound) > 0 && (
              <div className="table-scroll compact chess960-modal-table">
                <table>
                  <thead><tr><th>Brett</th><th>Paarung</th><th>Startstellung Weiß</th><th>Startstellung Schwarz</th><th>ID / Seed</th></tr></thead>
                  <tbody>
                    {chess960DialogRound.pairings.map(pairing => (
                      <tr key={`chess960-modal-${chess960DialogRound.roundNumber}-${pairing.boardNumber}`}>
                        <td>{pairing.boardNumber}</td>
                        <td>{playerNameById(pairing.whitePlayerId)} – {pairing.isBye ? 'spielfrei' : playerNameById(pairing.blackPlayerId)}</td>
                        <td><strong>{pairing.chess960StartPosition?.whiteBackRank ?? '—'}</strong></td>
                        <td>{pairing.chess960StartPosition?.blackBackRank ?? '—'}</td>
                        <td>{pairing.chess960StartPosition ? `SP ${pairing.chess960StartPosition.positionNumber}${chess960SeedDisplay(pairing) ? ` · ${chess960SeedDisplay(pairing)}` : ''}` : '—'}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
            <div className="actions preview-actions">
              <button type="button" className="secondary" onClick={() => openRoundPrint(chess960DialogRound.roundNumber)} disabled={chess960PositionCount(chess960DialogRound) === 0}>Rundenblatt drucken</button>
              <button type="button" onClick={() => setChess960DialogRound(null)} disabled={chess960Rolling}>Schließen</button>
            </div>
          </article>
        </div>
      )}

      <section className="layout">
        <aside className="panel">
          <h2>Turniere</h2>
          <form onSubmit={(event) => void createTournament(event)} className="stack">
            <input value={newTournamentName} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setNewTournamentName(event.target.value)} placeholder="Turniername" />
            <select value={format} onChange={(event: React.ChangeEvent<HTMLSelectElement>) => setFormat(Number(event.target.value))}>
              {formatOptions.map(option => <option key={option.value} value={option.value}>{option.label}</option>)}
            </select>
            <button type="submit">Turnier anlegen</button>
          </form>
          <div className="list">
            {tournaments.map(tournament => (
              <button
                type="button"
                key={tournament.id}
                className={tournament.id === selectedTournament?.id ? 'selected' : ''}
                onClick={() => setSelectedId(tournament.id)}
              >
                {tournament.name}<small>{tournament.players.length} Teilnehmer · {tournament.rounds.length} Runden</small>
              </button>
            ))}
          </div>
        </aside>

        <section className="panel main-panel">
          <div className="panel-header">
            <div>
              <h2>{selectedTournament?.name ?? 'Noch kein Turnier'}</h2>
              <p>{selectedTournament ? `${selectedTournament.players.length} Teilnehmer · ${selectedTournament.rounds.length} Runden` : 'Lege zuerst ein Turnier an.'}</p>
            </div>
            <div className="actions">
              <button type="button" className="secondary" onClick={() => void previewNextRound()} disabled={!pairingReadinessCanCreatePreview()}>Auslosungsvorschau</button>
              <button type="button" onClick={() => void generateRound()} disabled={!pairingReadinessCanGenerateRound()}>Nächste Runde auslosen</button>
              <button type="button" className="secondary" onClick={() => void resetSelectedTournament()} disabled={!selectedTournament}>Turnier zurücksetzen</button>
              <button type="button" className="danger" onClick={() => void deleteSelectedTournament()} disabled={!selectedTournament}>Turnier löschen</button>
            </div>
          </div>

          {nextRoundPreview && (
            <article className={`card preview-card ${pairingQualitySeverityClass(nextRoundPreview.pairingQuality.severity)}`}>
              <div className="preview-card-header">
                <div>
                  <p className="eyebrow">Vorschau · noch nicht gespeichert</p>
                  <h3>Auslosungsvorschau Runde {nextRoundPreview.roundNumber}</h3>
                  <p className="muted">{nextRoundPreview.summary}</p>
                </div>
                <div className="preview-score">
                  <strong>{nextRoundPreview.pairingQuality.qualityScore}/100</strong>
                  <span>{pairingQualitySeverityLabel(nextRoundPreview.pairingQuality.severity)}</span>
                </div>
              </div>
              <div className="preview-metrics">
                <span>{nextRoundPreview.boardCount} Bretter</span>
                <span>{nextRoundPreview.pairingQuality.rematchCount} Rematches</span>
                <span>{nextRoundPreview.pairingQuality.crossScoreGroupPairingCount} Scoregruppen-Abweichungen</span>
                <span>{nextRoundPreview.pairingQuality.thirdSameColorRiskCount} Farbfolge-Risiken</span>
                <span>{nextRoundPreview.pairingQuality.byeCount} Bye</span>
              </div>
              {nextRoundPreview.pairingQuality.hasCriticalIssues && <div className="preview-warning critical"><strong>Kritische Vorschau:</strong> Bitte Paarungen, Rematches und Farbfolge prüfen. Bei kleinen Turnieren kann das unvermeidbar sein; nach Bestätigung darf trotzdem ausgelost werden.</div>}
              {!nextRoundPreview.isSavable && <div className="preview-warning critical"><strong>Nicht speicherbar:</strong> Diese Vorschau darf nicht übernommen werden. Bitte Hinweise prüfen.</div>}
              {nextRoundPreview.messages.length > 0 && <ul className="message-list preview-message-list">{nextRoundPreview.messages.map((message, index) => <li key={`preview-message-${index}`}>{message}</li>)}</ul>}
              {nextRoundPreview.pairingQuality.findings.length > 0 && <ul className="message-list preview-message-list">{nextRoundPreview.pairingQuality.findings.map((finding, index) => <li key={`preview-quality-${index}`}>{finding}</li>)}</ul>}
              <div className="table-scroll compact preview-pairings">
                <table>
                  <thead><tr><th>Brett</th><th>Weiß</th><th>Schwarz</th><th>Score vor Runde</th><th>Hinweise</th></tr></thead>
                  <tbody>
                    {nextRoundPreview.pairingQuality.boards.map(board => (
                      <tr key={`preview-board-${board.boardNumber}`} className={board.isRematch ? 'quality-board-critical' : board.wouldGiveWhiteThirdSameColor || board.wouldGiveBlackThirdSameColor ? 'quality-board-warning' : board.isCrossScoreGroupPairing || board.isBye ? 'quality-board-notice' : ''}>
                        <td>{board.boardNumber}</td>
                        <td>{board.whiteName}</td>
                        <td>{board.isBye ? 'spielfrei' : board.blackName}</td>
                        <td>{board.isBye ? 'Bye' : `${board.whiteScoreBeforeRound} : ${board.blackScoreBeforeRound}`}</td>
                        <td>{board.findings.length === 0 ? <span className="ok">ok</span> : <ul className="message-list">{board.findings.map((finding, index) => <li key={`preview-board-${board.boardNumber}-${index}`}>{finding}</li>)}</ul>}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <details className="audit-box preview-audit">
                <summary>Audit der Vorschau anzeigen</summary>
                <div className="audit-grid">
                  <section><strong>Hinweise</strong><ul>{nextRoundPreview.round.audit.messages.map((message, index) => <li key={`preview-audit-message-${index}`}>{message}</li>)}</ul></section>
                  <section><strong>Scoregruppen</strong><ul>{nextRoundPreview.round.audit.scoreGroups.map((message, index) => <li key={`preview-audit-score-${index}`}>{message}</li>)}</ul></section>
                  <section><strong>Floater</strong><ul>{nextRoundPreview.round.audit.floaters.length === 0 ? <li>keine</li> : nextRoundPreview.round.audit.floaters.map((message, index) => <li key={`preview-audit-floater-${index}`}>{message}</li>)}</ul></section>
                  <section><strong>Farben</strong><ul>{nextRoundPreview.round.audit.colorNotes.map((message, index) => <li key={`preview-audit-color-${index}`}>{message}</li>)}</ul></section>
                </div>
              </details>
              <div className="actions preview-actions">
                <button type="button" onClick={() => void generateRound()} disabled={!pairingReadinessCanGenerateRound()}>Diese Runde jetzt auslosen</button>
                <button type="button" className="secondary" onClick={openNextRoundPreviewPrint}>Druckansicht öffnen</button>
                <button type="button" className="secondary" onClick={openNextRoundPreviewCsv}>CSV exportieren</button>
                <button type="button" className="secondary" onClick={() => setIsNextRoundPreviewDialogOpen(true)}>Als Popup öffnen</button>
                <button type="button" className="secondary" onClick={() => { setNextRoundPreview(null); setIsNextRoundPreviewDialogOpen(false); }}>Vorschau schließen</button>
              </div>
            </article>
          )}
          <article className="card settings-card">
            <h3>Turniereinstellungen</h3>
            <form onSubmit={(event) => void saveSettings(event)} className="settings-form">
              <div className="settings-grid">
                <label>Format
                  <select value={settingsForm.format} onChange={(event: React.ChangeEvent<HTMLSelectElement>) => setSettingsForm({ ...settingsForm, format: Number(event.target.value) })} disabled={(selectedTournament?.rounds.length ?? 0) > 0}>
                    {formatOptions.map(option => <option key={option.value} value={option.value}>{option.label}</option>)}
                  </select>
                </label>
                <label>Punktesystem
                  <select value={settingsForm.scoringSystem} onChange={(event: React.ChangeEvent<HTMLSelectElement>) => setSettingsForm({ ...settingsForm, scoringSystem: Number(event.target.value) })}>
                    {scoringOptions.map(option => <option key={option.value} value={option.value}>{option.label}</option>)}
                  </select>
                </label>
                <label>TWZ-Quelle
                  <select value={settingsForm.twzSource} onChange={(event: React.ChangeEvent<HTMLSelectElement>) => setSettingsForm({ ...settingsForm, twzSource: Number(event.target.value) })}>
                    {twzSourceOptions.map(option => <option key={option.value} value={option.value}>{option.label}</option>)}
                  </select>
                </label>
                <label>Geplante Runden
                  <input type="number" min="1" max="99" value={settingsForm.plannedRounds} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setSettingsForm({ ...settingsForm, plannedRounds: event.target.value })} />
                </label>
                <label>Kampflose Partien
                  <select value={settingsForm.forfeitTiebreakPolicy} onChange={(event: React.ChangeEvent<HTMLSelectElement>) => setSettingsForm({ ...settingsForm, forfeitTiebreakPolicy: Number(event.target.value) })}>
                    {forfeitPolicyOptions.map(option => <option key={option.value} value={option.value}>{option.label}</option>)}
                  </select>
                </label>
                <label>Senioren: Geburtsjahr oder älter
                  <input type="number" min="1900" max="2100" value={settingsForm.seniorBirthYearOrEarlier} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setSettingsForm({ ...settingsForm, seniorBirthYearOrEarlier: event.target.value })} placeholder="z. B. 1966" />
                </label>
                <label>Heldenpokal: Mindestpartien
                  <input type="number" min="1" max="99" value={settingsForm.heroCupMinimumRatedGames} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setSettingsForm({ ...settingsForm, heroCupMinimumRatedGames: event.target.value })} />
                </label>
              </div>
              <div className="checkbox-row">
                <label className="checkbox"><input type="checkbox" checked={settingsForm.countByeAsWin} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setSettingsForm({ ...settingsForm, countByeAsWin: event.target.checked })} /> Bye als Sieg zählen</label>
                <label className="checkbox"><input type="checkbox" checked={settingsForm.allowManualPairingOverrides} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setSettingsForm({ ...settingsForm, allowManualPairingOverrides: event.target.checked })} /> manuelle Paarungen erlauben</label>
              </div>
              <div className="tiebreak-editor">
                <strong>Wertungskette</strong>
                <p className="muted">Die Reihenfolge entscheidet nach Punkten über die Platzierung. Startnummer bleibt als letzter Notanker enthalten.</p>
                <div className="tiebreak-list">
                  {settingsForm.tiebreaks.map((value, index) => (
                    <div key={`${value}-${index}`} className="tiebreak-item">
                      <span>{index + 1}. {tiebreakLabel(value)}</span>
                      <button type="button" className="small secondary" onClick={() => setSettingsForm({ ...settingsForm, tiebreaks: moveTiebreak(settingsForm.tiebreaks, index, -1) })} disabled={index === 0}>↑</button>
                      <button type="button" className="small secondary" onClick={() => setSettingsForm({ ...settingsForm, tiebreaks: moveTiebreak(settingsForm.tiebreaks, index, 1) })} disabled={index === settingsForm.tiebreaks.length - 1}>↓</button>
                      <button type="button" className="small danger" onClick={() => toggleTiebreak(value, false)} disabled={value === 99 && settingsForm.tiebreaks.length === 1}>Entfernen</button>
                    </div>
                  ))}
                </div>
                <div className="tiebreak-add">
                  {tiebreakOptions.filter(option => !settingsForm.tiebreaks.includes(option.value)).map(option => (
                    <button key={option.value} type="button" className="small" onClick={() => toggleTiebreak(option.value, true)}>+ {option.label}</button>
                  ))}
                </div>
              </div>
              <button type="submit" disabled={!selectedTournament}>Einstellungen speichern</button>
            </form>
          </article>

          <div className="grid two">
            <article className="card external-lookup-card">
              <h3>Spieler suchen</h3>
              <p className="muted">Eine Suche – alle verfügbaren Quellen werden automatisch geprüft und Treffer zusammengeführt. FIDE-ID-Abruf ist aktiv; DSB/DeWIS und ThSB sind vorbereitet und werden klar als „aktuell nicht aktiv" markiert.</p>
              <form onSubmit={(event) => void searchExternalPlayers(event)} className="external-lookup-form single">
                <input value={externalQuery} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setExternalQuery(event.target.value)} placeholder="Name oder FIDE-ID (z. B. 4610563)" />
                <button type="submit" disabled={externalSearching}>{externalSearching ? 'Suche läuft …' : 'Spieler suchen'}</button>
              </form>
              {externalLookup && (
                <div className="lookup-results">
                  <strong>{externalLookup.message}</strong>
                  {externalLookup.sources.length > 0 && (
                    <ul className="source-status-list">
                      {externalLookup.sources.map(source => (
                        <li key={source.source} className={source.isActive ? 'source-active' : 'source-prepared'}>
                          <span className="source-badge">{source.isActive ? 'durchsucht' : 'vorbereitet'}</span>
                          <strong>{source.sourceName}</strong>
                          {source.isActive ? ` · ${source.count} Treffer` : ' · aktuell nicht aktiv'}
                        </li>
                      ))}
                    </ul>
                  )}
                  {externalLookup.players.length === 0 && <p className="muted">Keine übernehmbaren Treffer. {externalLookup.mode === 'name' ? 'Tipp: FIDE-ID eingeben für direkten Abruf.' : ''}</p>}
                  {externalLookup.players.map(profile => {
                    const existingParticipant = existingParticipantForProfile(profile);
                    return (
                    <div key={`${profile.source}-${profile.externalId}`} className={`lookup-result${existingParticipant ? ' lookup-result-existing' : ''}`}>
                      <div>
                        <strong>{profile.name}{existingParticipant && <span className="participant-badge">bereits im Turnier</span>}</strong>
                        <small>{profile.fideId ? `FIDE ${profile.fideId}` : profile.externalId} · {profile.federation ?? profile.country ?? 'ohne Verband'} · Elo {profile.elo ?? '—'} · DWZ {profile.dwz ?? '—'} · {profile.birthYear ?? 'Jahr ?'}</small>
                        {profile.profileUrl && <small><a href={profile.profileUrl} target="_blank" rel="noreferrer">Profil öffnen</a></small>}
                        {externalDuplicateChecks[externalProfileKey(profile)] && (
                          <div className="duplicate-box">
                            <strong>{externalDuplicateChecks[externalProfileKey(profile)].hasLikelyDuplicate ? 'Mögliche Dubletten' : 'Keine sichere Dublette'}</strong>
                            {externalDuplicateChecks[externalProfileKey(profile)].matches.length === 0 && <small>Kein bestehender Teilnehmer passt sicher zu diesem externen Treffer.</small>}
                            {externalDuplicateChecks[externalProfileKey(profile)].matches.map(match => (
                              <div key={`${profile.source}-${profile.externalId}-${match.playerId}`} className="duplicate-match">
                                <span>{match.playerName} · {duplicateKindLabel(match.kind)} · Score {match.score}</span>
                                <small>{match.reason}</small>
                                <div className="actions">
                                  <button type="button" className="small" onClick={() => void applyExternalProfile(profile, match.playerId, false)}>Teilnehmer ergänzen</button>
                                  <button type="button" className="small secondary" onClick={() => void applyExternalProfile(profile, match.playerId, true)}>mit externen Daten überschreiben</button>
                                </div>
                              </div>
                            ))}
                          </div>
                        )}
                      </div>
                      <div className="lookup-actions">
                        <button type="button" className="small" onClick={() => applyExternalPlayer(profile)}>Ins Formular</button>
                        <button type="button" className="small secondary" onClick={() => void checkExternalDuplicates(profile)} disabled={!selectedTournament}>Dubletten prüfen</button>
                        {existingParticipant ? (
                          <button type="button" className="small secondary" onClick={() => editExistingFromProfile(existingParticipant)}>Vorhandenen öffnen/bearbeiten</button>
                        ) : (
                          <button type="button" className="small" onClick={() => void applyExternalProfile(profile)} disabled={!selectedTournament}>Als neuen Teilnehmer speichern</button>
                        )}
                      </div>
                    </div>
                    );
                  })}
                </div>
              )}
            </article>

            <article className="card">
              <h3>{editingPlayerId ? 'Teilnehmer bearbeiten' : 'Teilnehmer erfassen'}</h3>
              <form onSubmit={(event) => void savePlayer(event)} className="player-form wide">
                <input value={playerForm.name} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setPlayerForm({ ...playerForm, name: event.target.value })} placeholder="Name *" />
                <input value={playerForm.club} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setPlayerForm({ ...playerForm, club: event.target.value })} placeholder="Verein" />
                <input value={playerForm.federation} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setPlayerForm({ ...playerForm, federation: event.target.value })} placeholder="Verband/Federation" />
                <input value={playerForm.country} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setPlayerForm({ ...playerForm, country: event.target.value })} placeholder="Land" />
                <input value={playerForm.birthYear} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setPlayerForm({ ...playerForm, birthYear: event.target.value })} placeholder="Geburtsjahr" type="number" min="1900" max="2100" />
                <select value={playerForm.gender} onChange={(event: React.ChangeEvent<HTMLSelectElement>) => setPlayerForm({ ...playerForm, gender: Number(event.target.value) })}>
                  {genderOptions.map(option => <option key={option.value} value={option.value}>{option.label}</option>)}
                </select>
                <input value={playerForm.dwz} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setPlayerForm({ ...playerForm, dwz: event.target.value })} placeholder="DWZ" type="number" min="0" />
                <input value={playerForm.dwzIndex} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setPlayerForm({ ...playerForm, dwzIndex: event.target.value })} placeholder="DWZ-Index" type="number" min="0" />
                <input value={playerForm.elo} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setPlayerForm({ ...playerForm, elo: event.target.value })} placeholder="Elo Standard" type="number" min="0" />
                <input value={playerForm.rapidElo} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setPlayerForm({ ...playerForm, rapidElo: event.target.value })} placeholder="Elo Rapid" type="number" min="0" />
                <input value={playerForm.blitzElo} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setPlayerForm({ ...playerForm, blitzElo: event.target.value })} placeholder="Elo Blitz" type="number" min="0" />
                <input value={playerForm.manualTwz} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setPlayerForm({ ...playerForm, manualTwz: event.target.value })} placeholder="TWZ manuell" type="number" min="0" />
                <input value={playerForm.fideId} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setPlayerForm({ ...playerForm, fideId: event.target.value })} placeholder="FIDE-ID" />
                <input value={playerForm.nationalId} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setPlayerForm({ ...playerForm, nationalId: event.target.value })} placeholder="DSB-ID" />
                <input value={playerForm.title} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setPlayerForm({ ...playerForm, title: event.target.value })} placeholder="Titel" />
                <select value={playerForm.status} onChange={(event: React.ChangeEvent<HTMLSelectElement>) => setPlayerForm({ ...playerForm, status: Number(event.target.value) })}>
                  {playerStatusOptions.map(option => <option key={option.value} value={option.value}>{option.label}</option>)}
                </select>
                <input value={playerForm.notes} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setPlayerForm({ ...playerForm, notes: event.target.value })} placeholder="Notizen" />
                <button type="submit" disabled={!selectedTournament}>{editingPlayerId ? 'Aktualisieren' : 'Speichern'}</button>
                {editingPlayerId && <button type="button" className="secondary" onClick={() => { setEditingPlayerId(null); setPlayerForm(emptyPlayerForm); }}>Abbrechen</button>}
              </form>
            </article>
          </div>

          <article className="card participant-card">
            <h3>Teilnehmerliste <small className="muted">{selectedTournament?.players.length ?? 0} Teilnehmer · horizontal scrollbar</small></h3>
            <div className="table-scroll participant-scroll">
              <table className="participant-table">
                <thead><tr><th>#</th><th>Name</th><th>Verein</th><th>FIDE</th><th>TWZ/DWZ</th><th>Jg.</th><th>Alter ca.</th><th>Kat.</th><th>Status</th><th>Aktion</th></tr></thead>
                <tbody>
                  {(selectedTournament?.players.length ?? 0) === 0 && (
                    <tr><td colSpan={10} className="muted">Noch keine Teilnehmer erfasst.</td></tr>
                  )}
                  {selectedTournament?.players.map(player => (
                    <tr key={player.id} className={player.status === 2 ? 'muted-row' : ''}>
                      <td>{player.startingRank}</td>
                      <td className="col-name">{player.name}</td>
                      <td className="col-club">{player.club ?? '—'}</td>
                      <td>{player.fideId ?? '—'}</td>
                      <td>{twzOf(player)}</td>
                      <td>{player.birthYear ?? '—'}</td>
                      <td>{approximateAgeLabel(player.birthYear)}</td>
                      <td>{genderLabel(player.gender)}</td>
                      <td>{statusLabel(player.status)}</td>
                      <td className="actions col-actions">
                        <button type="button" className="small" onClick={() => editPlayer(player)}>Bearbeiten</button>
                        {player.status === 0
                          ? <button type="button" className="small" onClick={() => void setPlayerStatus(player, 2)}>Zurückziehen</button>
                          : <button type="button" className="small" onClick={() => void setPlayerStatus(player, 0)}>Aktivieren</button>}
                        <button type="button" className="small danger" onClick={() => void deleteOrWithdrawPlayer(player)}>Löschen</button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </article>

          <div className="grid two">
            <article className="card">
              <h3>Live-Tabelle</h3>
              <div className="table-scroll">
                <table>
                  <thead><tr><th>Rang</th><th>Name</th><th>Punkte</th><th>Siege</th><th>Schwarz</th><th>BH</th><th>BH-1</th><th>BH-2</th><th>Median</th><th>SB</th><th>Koya</th><th>Prog.</th><th>TPR</th></tr></thead>
                  <tbody>
                    {standings.map(row => (
                      <tr key={row.playerId}>
                        <td>{row.rank}</td>
                        <td>{row.name}</td>
                        <td>{row.points}</td>
                        <td>{row.wins}</td>
                        <td>{row.blackWins}</td>
                        <td>{row.buchholz}</td>
                        <td>{row.buchholzCutOne}</td>
                        <td>{row.buchholzCutTwo}</td>
                        <td>{row.medianBuchholz}</td>
                        <td>{row.sonnebornBerger}</td>
                        <td>{row.koyaScore}</td>
                        <td>{row.progressiveScore}</td>
                        <td>{row.tournamentPerformance ?? '—'}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </article>

            <article className="card">
              <h3>Heldenpokal</h3>
              <div className="table-scroll">
                <table>
                  <thead><tr><th>Rang</th><th>Name</th><th>Über Erwartung</th><th>Ist</th><th>Erwartet</th><th>Ø Gegner</th></tr></thead>
                  <tbody>
                    {heroCup.map(row => (
                      <tr key={row.playerId}>
                        <td>{row.rank}</td>
                        <td title={row.reason}>{row.name}</td>
                        <td>{row.overPerformance}</td>
                        <td>{row.actualScore}/{row.ratedGames}</td>
                        <td>{row.expectedScore}</td>
                        <td>{row.averageOpponentRating}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </article>
          </div>

          <article className="card">
            <h3>Kategorieauswertungen</h3>
            {categories.length === 0 && <p>Noch keine Kategorie mit passenden Spielern.</p>}
            <div className="category-grid">
              {categories.map(category => (
                <section key={category.category} className="mini-table">
                  <h4>{category.category}</h4>
                  <table>
                    <tbody>
                      {category.rows.map(row => <tr key={row.playerId}><td>{row.rank}</td><td>{row.name}</td><td>{row.points}</td></tr>)}
                    </tbody>
                  </table>
                </section>
              ))}
            </div>
          </article>

          <article className="card">
            <h3>Kreuztabelle</h3>
            <div className="table-scroll">
              <table className="cross-table">
                <thead>
                  <tr><th>Spieler</th>{crossTable?.players.map(player => <th key={player.playerId}>{player.rank}</th>)}<th>Pkt.</th></tr>
                </thead>
                <tbody>
                  {crossTable?.rows.map(row => (
                    <tr key={row.playerId}>
                      <th>{row.rank}. {row.name}</th>
                      {row.cells.map(cell => <td key={cell.opponentId} title={cell.roundNumber ? `R${cell.roundNumber}, Brett ${cell.boardNumber}` : undefined}>{cell.resultLabel}</td>)}
                      <td>{row.points}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </article>

          <article className="card">
            <h3>Runden und Ergebnisse</h3>
            {selectedTournament?.rounds.length === 0 && <p>Noch keine Runde ausgelost.</p>}
            {selectedTournament?.rounds.map(round => (
              <section key={round.roundNumber} className="round-box">
                <div className="round-header">
                  <div>
                    <h4>Runde {round.roundNumber}</h4>
                    <p className="muted">Status: {roundStatusLabel(round.resultStatus)}{round.isLocked ? ' · gesperrt' : ''}{round.isVerified ? ' · geprüft' : ''}</p>
                  </div>
                  <div className="actions">
                    <button type="button" className="small" onClick={() => void setRoundLock(round, !round.isLocked)} disabled={round.isVerified}>{round.isLocked ? 'Entsperren' : 'Sperren'}</button>
                    <button type="button" className="small secondary" onClick={() => void setRoundVerified(round, !round.isVerified)}>{round.isVerified ? 'Prüfung zurücknehmen' : 'Als geprüft markieren'}</button>
                  </div>
                </div>
                {round.audit && (
                  <details className="audit-box">
                    <summary>{round.audit.algorithm} · {round.audit.rulesetVersion}</summary>
                    <div className="audit-grid">
                      <section>
                        <strong>Hinweise</strong>
                        <ul>{round.audit.messages.map((message, index) => <li key={`m-${index}`}>{message}</li>)}</ul>
                      </section>
                      <section>
                        <strong>Scoregruppen</strong>
                        <ul>{round.audit.scoreGroups.map((message, index) => <li key={`s-${index}`}>{message}</li>)}</ul>
                      </section>
                      <section>
                        <strong>Floater</strong>
                        <ul>{round.audit.floaters.length === 0 ? <li>keine</li> : round.audit.floaters.map((message, index) => <li key={`f-${index}`}>{message}</li>)}</ul>
                      </section>
                      <section>
                        <strong>Farben</strong>
                        <ul>{round.audit.colorNotes.map((message, index) => <li key={`c-${index}`}>{message}</li>)}</ul>
                      </section>
                    </div>
                  </details>
                )}
                {diagnosticsFor(round.roundNumber) && (
                  <details className="diagnostics-box" open={diagnosticsFor(round.roundNumber)?.warnings.length !== 0}>
                    <summary>Rundenprüfung · {diagnosticsFor(round.roundNumber)?.openBoards ?? 0} offen · {diagnosticsFor(round.roundNumber)?.forfeitBoards ?? 0} kampflos · {diagnosticsFor(round.roundNumber)?.byeBoards ?? 0} Bye</summary>
                    {(diagnosticsFor(round.roundNumber)?.warnings.length ?? 0) === 0 && <p className="ok">Keine Warnungen.</p>}
                    <ul>{diagnosticsFor(round.roundNumber)?.warnings.map((warning, index) => <li key={`w-${round.roundNumber}-${index}`}>{warning}</li>)}</ul>
                    <div className="table-scroll compact">
                      <table>
                        <thead><tr><th>Brett</th><th>Ergebnis</th><th>BH</th><th>SB/Direkt</th><th>TPR</th><th>Hinweis</th></tr></thead>
                        <tbody>
                          {diagnosticsFor(round.roundNumber)?.boards.map(board => (
                            <tr key={`d-${round.roundNumber}-${board.boardNumber}`} className={board.isForfeit ? 'manual-row' : board.isOpen ? 'warning-row' : ''}>
                              <td>{board.boardNumber}</td>
                              <td>{board.resultLabel}</td>
                              <td>{board.countsForBuchholz ? 'ja' : 'nein'}</td>
                              <td>{board.countsForDirectAndSonneborn ? 'ja' : 'nein'}</td>
                              <td>{board.countsForPerformance ? 'ja' : 'nein'}</td>
                              <td>{board.note}</td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  </details>
                )}
                <div className={`quality-box ${pairingQualityFor(round.roundNumber) ? pairingQualitySeverityClass(pairingQualityFor(round.roundNumber)!.severity) : 'quality-empty'}`}>
                  <div className="quality-header">
                    <div>
                      <strong>Pairing-Qualität</strong>
                      {pairingQualityFor(round.roundNumber)
                        ? <span>{pairingQualityFor(round.roundNumber)!.qualityScore}/100 · {pairingQualitySeverityLabel(pairingQualityFor(round.roundNumber)!.severity)}</span>
                        : <span>noch nicht berechnet</span>}
                    </div>
                    <button type="button" className="small secondary" onClick={() => void loadPairingQuality(round.roundNumber)}>Qualität prüfen</button>
                  </div>
                  {pairingQualityFor(round.roundNumber) && (
                    <details open={pairingQualityFor(round.roundNumber)!.severity >= 2}>
                      <summary>{pairingQualityFor(round.roundNumber)!.findingCount} Hinweis(e) · {pairingQualityFor(round.roundNumber)!.rematchCount} Rematch · {pairingQualityFor(round.roundNumber)!.crossScoreGroupPairingCount} Scoregruppen-Abweichung(en) · {pairingQualityFor(round.roundNumber)!.thirdSameColorRiskCount} Farbfolge-Risiko/Risiken</summary>
                      <ul className="message-list">
                        {pairingQualityFor(round.roundNumber)!.findings.map((finding, index) => <li key={`quality-finding-${round.roundNumber}-${index}`}>{finding}</li>)}
                      </ul>
                      <div className="table-scroll compact">
                        <table>
                          <thead><tr><th>Brett</th><th>Paarung</th><th>Score vor Runde</th><th>Hinweise</th></tr></thead>
                          <tbody>
                            {pairingQualityFor(round.roundNumber)!.boards.map(board => (
                              <tr key={`quality-board-${round.roundNumber}-${board.boardNumber}`} className={board.isRematch ? 'quality-board-critical' : board.wouldGiveWhiteThirdSameColor || board.wouldGiveBlackThirdSameColor ? 'quality-board-warning' : board.isCrossScoreGroupPairing || board.isBye ? 'quality-board-notice' : ''}>
                                <td>{board.boardNumber}</td>
                                <td>{board.whiteName} – {board.blackName}</td>
                                <td>{board.isBye ? 'Bye' : `${board.whiteScoreBeforeRound} : ${board.blackScoreBeforeRound}`}</td>
                                <td>{board.findings.length === 0 ? <span className="ok">ok</span> : <ul className="message-list">{board.findings.map((finding, index) => <li key={`quality-board-finding-${round.roundNumber}-${board.boardNumber}-${index}`}>{finding}</li>)}</ul>}</td>
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>
                    </details>
                  )}
                </div>
                <div className="chess960-dice-panel">
                  <div className="chess960-dice-header">
                    <div>
                      <strong>Schachwürfel / Chess960</strong>
                      <span>{chess960PositionCount(round)} von {chess960GameBoardCount(round)} regulären Brettern haben eine Startstellung.</span>
                    </div>
                    <button type="button" className="secondary" onClick={() => openChess960Dice(round)} disabled={round.isLocked || round.isVerified || chess960GameBoardCount(round) === 0}>🎲 Schachwürfel öffnen</button>
                  </div>
                  {chess960PositionCount(round) > 0 && (
                    <div className="table-scroll compact chess960-table">
                      <table>
                        <thead><tr><th>Brett</th><th>Paarung</th><th>Startstellung</th><th>ID / Seed</th></tr></thead>
                        <tbody>
                          {round.pairings.map(pairing => (
                            <tr key={`chess960-${round.roundNumber}-${pairing.boardNumber}`}>
                              <td>{pairing.boardNumber}</td>
                              <td>{playerNameById(pairing.whitePlayerId)} – {pairing.isBye ? 'spielfrei' : playerNameById(pairing.blackPlayerId)}</td>
                              <td><strong>{chess960Display(pairing)}</strong></td>
                              <td>{pairing.chess960StartPosition ? `SP ${pairing.chess960StartPosition.positionNumber}${chess960SeedDisplay(pairing) ? ` · ${chess960SeedDisplay(pairing)}` : ''}` : '—'}</td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  )}
                </div>
                <div className="table-scroll">
                  <table>
                    <thead><tr><th>Brett</th><th>Weiß</th><th>Schwarz</th><th>Chess960</th><th>Ergebnis</th><th>Manuelle Paarung</th></tr></thead>
                    <tbody>
                      {round.pairings.map(pairing => {
                        const edit = pairingEdit(round, pairing);
                        const roundClosed = round.isLocked || round.isVerified;
                        return (
                          <tr key={`${round.roundNumber}-${pairing.boardNumber}`} className={pairing.isManualOverride ? 'manual-row' : ''}>
                            <td>{pairing.boardNumber}{pairing.isManualOverride ? <small>manuell</small> : null}</td>
                            <td>{playerNameById(pairing.whitePlayerId)}</td>
                            <td>{pairing.isBye ? 'spielfrei' : playerNameById(pairing.blackPlayerId)}</td>
                            <td>
                              <strong>{chess960Display(pairing)}</strong>
                              {chess960SeedDisplay(pairing) && <small>{chess960SeedDisplay(pairing)}</small>}
                            </td>
                            <td>
                              <select
                                value={pairing.result.kind}
                                onChange={(event: React.ChangeEvent<HTMLSelectElement>) => void recordResult(round.roundNumber, pairing.boardNumber, Number(event.target.value))}
                                disabled={pairing.isBye || roundClosed}
                              >
                                {resultOptions.map(option => <option key={option.value} value={option.value}>{option.label}</option>)}
                              </select>
                              <small>{resultLabel(pairing.result.kind)}</small>
                            </td>
                            <td>
                              <div className="manual-pairing">
                                <select value={edit.whitePlayerId} onChange={(event: React.ChangeEvent<HTMLSelectElement>) => updatePairingEdit(round.roundNumber, pairing.boardNumber, { whitePlayerId: event.target.value })} disabled={roundClosed}>
                                  <option value="">Weiß wählen</option>
                                  {selectedTournament.players.filter(player => player.status === 0).map(player => <option key={player.id} value={player.id}>{player.name}</option>)}
                                </select>
                                <select value={edit.blackPlayerId} onChange={(event: React.ChangeEvent<HTMLSelectElement>) => updatePairingEdit(round.roundNumber, pairing.boardNumber, { blackPlayerId: event.target.value })} disabled={roundClosed}>
                                  <option value="">Schwarz/Bye leer</option>
                                  {selectedTournament.players.filter(player => player.status === 0).map(player => <option key={player.id} value={player.id}>{player.name}</option>)}
                                </select>
                                <input value={edit.notes} onChange={(event: React.ChangeEvent<HTMLInputElement>) => updatePairingEdit(round.roundNumber, pairing.boardNumber, { notes: event.target.value })} placeholder="Notiz" disabled={roundClosed} />
                                <button type="button" className="small" onClick={() => void saveManualPairing(round, pairing)} disabled={roundClosed || !edit.whitePlayerId}>Paarung speichern</button>
                              </div>
                            </td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>
                <div className="round-bottom-actions">
                  <div>
                    <strong>Direkt weiterarbeiten</strong>
                    <span>Nach der Ergebniseingabe ohne Scrollen Vorschau erzeugen oder nächste Runde auslosen. Kritische Hinweise blockieren nicht, sondern werden vor dem Auslosen bestätigt.</span>
                  </div>
                  <button type="button" className="secondary" onClick={() => void previewNextRound()} disabled={!pairingReadinessCanCreatePreview()}>Auslosungsvorschau erzeugen</button>
                  <button type="button" onClick={() => void generateRound()} disabled={!pairingReadinessCanGenerateRound()}>Nächste Runde auslosen</button>
                  {pairingReadinessBlockingIssues().length > 0 && (
                    <ul className="message-list round-bottom-blockers">
                      {pairingReadinessBlockingIssues().map((issue, index) => <li key={`round-bottom-blocker-${index}`}>{issue}</li>)}
                    </ul>
                  )}
                </div>
              </section>
            ))}
          </article>

                                                          <article className="card pairing-readiness-card">
              <div className="pairing-readiness-header">
                <div>
                  <h3>Auslosungsfreigabe</h3>
                  <p className="muted">Prüft vor der nächsten Auslosung, ob Ergebnisse, Rundenprüfung und Vorschauqualität zusammenpassen.</p>
                </div>
                <span className={pairingReadinessStatusClass()}>{pairingReadinessStatusLabel()}</span>
              </div>

              <div className="pairing-readiness-metrics">
                <div><strong>{pairingReadinessOpenResultCount()}</strong><span>offene Ergebnisse</span></div>
                <div><strong>{pairingReadinessUnverifiedRoundCount()}</strong><span>ungeprüfte Runden</span></div>
                <div><strong>{selectedTournament?.players.filter(player => player.status === 0).length ?? 0}</strong><span>aktive Spieler</span></div>
                <div><strong>{nextRoundPreview ? nextRoundPreview.pairingQuality.qualityScore : '—'}</strong><span>Vorschauqualität</span></div>
              </div>

              {pairingReadinessIssues().length === 0 ? (
                <div className="pairing-readiness-ok"><strong>Bereit:</strong> Es sind keine blockierenden Punkte für die nächste Auslosung sichtbar.</div>
              ) : (
                <div className="pairing-readiness-warning">
                  <strong>Vor der nächsten Auslosung prüfen:</strong>
                  <ul>
                    {pairingReadinessIssues().map((issue, index) => <li key={index}>{issue}</li>)}
                  </ul>
                </div>
              )}

              <div className="pairing-readiness-actions">
                <button type="button" onClick={() => void previewNextRound()} disabled={!pairingReadinessCanCreatePreview()}>Auslosungsvorschau erzeugen</button>
                <button type="button" onClick={() => void generateRound()} disabled={!pairingReadinessCanGenerateRound()}>Nächste Runde auslosen</button>
                <button type="button" className="secondary" onClick={openLatestRoundPrint} disabled={!selectedTournament || selectedTournament.rounds.length === 0}>Aktuelle Runde drucken</button>
                <button type="button" className="secondary" onClick={() => openTournamentExport('print/html')} disabled={!selectedTournament}>Turnierbericht öffnen</button>
              </div>

              <p className="muted small">Hinweis: Diese Freigabe ergänzt die bestehenden Aktionen im Kopfbereich. Sie ist als bewusster Turnierleiter-Check vor der nächsten Runde gedacht.</p>
            </article>

<article className="card bye-forfeit-card">
              <div className="bye-forfeit-header">
                <div>
                  <h3>Bye- und Kampflos-Audit</h3>
                  <p className="muted">Macht spielfreie und kampflose Bretter inklusive Wertungswirkung sichtbar. Das hilft vor Tabelle, Export und nächster Auslosung.</p>
                </div>
                <span className={byeForfeitAuditStatusClass()}>{byeForfeitAuditStatusLabel()}</span>
              </div>

              <div className="bye-forfeit-metrics">
                <div><strong>{totalByeBoardCount()}</strong><span>Bye/spielfrei</span></div>
                <div><strong>{totalForfeitBoardCount()}</strong><span>kampflos</span></div>
                <div><strong>{byeForfeitAffectedRoundCount()}</strong><span>betroffene Runden</span></div>
                <div><strong>{byeForfeitRows().length}</strong><span>sichtbare Fälle</span></div>
              </div>

              {!selectedTournament && <p className="muted">Bitte zuerst ein Turnier auswählen.</p>}
              {selectedTournament && selectedTournament.rounds.length === 0 && <div className="bye-forfeit-empty">Noch keine Runde vorhanden. Bye- und Kampflos-Fälle werden nach der ersten Auslosung angezeigt.</div>}
              {selectedTournament && selectedTournament.rounds.length > 0 && byeForfeitRows().length === 0 && <div className="bye-forfeit-ok">Keine Bye- oder kampflosen Bretter in den aktuellen Diagnosen gefunden.</div>}
              {totalForfeitBoardCount() > 0 && <div className="bye-forfeit-warning"><strong>Kampflos-Fälle prüfen:</strong> Bitte vor Veröffentlichung kontrollieren, ob Buchholz, Sonneborn-Berger, Direktwertung und Performance korrekt behandelt werden.</div>}
              {totalByeBoardCount() > 0 && <div className="bye-forfeit-warning info"><strong>Bye/spielfrei vorhanden:</strong> Aushänge und Exporte sollten eindeutig zeigen, wer spielfrei war und wie dies gewertet wurde.</div>}

              {byeForfeitRows().length > 0 && (
                <div className="table-wrap bye-forfeit-table-wrap">
                  <table>
                    <thead>
                      <tr><th>Runde</th><th>Brett</th><th>Weiß</th><th>Schwarz</th><th>Art</th><th>Ergebnis</th><th>BH</th><th>Direkt/SB</th><th>Perf.</th><th>Hinweis</th></tr>
                    </thead>
                    <tbody>
                      {byeForfeitRows().map(row => (
                        <tr key={`${row.roundNumber}-${row.boardNumber}-${row.kind}`}>
                          <td>{row.roundNumber}</td>
                          <td>{row.boardNumber}</td>
                          <td>{row.white}</td>
                          <td>{row.black}</td>
                          <td><span className={`bye-forfeit-chip ${row.isForfeit ? 'warn' : 'info'}`}>{row.kind}</span></td>
                          <td>{row.resultLabel}</td>
                          <td>{row.countsForBuchholz ? 'ja' : 'nein'}</td>
                          <td>{row.countsForDirectAndSonneborn ? 'ja' : 'nein'}</td>
                          <td>{row.countsForPerformance ? 'ja' : 'nein'}</td>
                          <td>{row.note || '—'}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}

              <div className="bye-forfeit-actions">
                <button type="button" onClick={openLatestRoundPrint} disabled={!selectedTournament || selectedTournament.rounds.length === 0}>Aktuelle Runde drucken</button>
                <button type="button" className="secondary" onClick={() => openTournamentExport('pairings/export.csv')} disabled={!selectedTournament}>Paarungen CSV</button>
                <button type="button" className="secondary" onClick={() => openTournamentExport('print/html')} disabled={!selectedTournament}>Turnierbericht öffnen</button>
              </div>
            </article>

<article className="card result-review-card">
              <div className="result-review-header">
                <div>
                  <h3>Rundenabschluss-Checkliste</h3>
                  <p className="muted">Prüft offene Ergebnisse, kampflose Bretter, ungeprüfte Runden und Diagnosehinweise vor Aushang oder nächster Auslosung.</p>
                </div>
                <span className={resultReviewStatusClass()}>{resultReviewStatusLabel()}</span>
              </div>

              <div className="result-review-metrics">
                <div><strong>{selectedTournament?.rounds.length ?? 0}</strong><span>Runden</span></div>
                <div><strong>{completedRoundCount()}</strong><span>vollständig</span></div>
                <div><strong>{totalOpenBoardCount()}</strong><span>offen</span></div>
                <div><strong>{totalForfeitBoardCount()}</strong><span>kampflos</span></div>
                <div><strong>{unverifiedCompleteRoundCount()}</strong><span>ungeprüft</span></div>
                <div><strong>{lockedRoundCount()}</strong><span>gesperrt</span></div>
                <div><strong>{diagnosticWarningCount()}</strong><span>Hinweise</span></div>
              </div>

              {!selectedTournament && <p className="muted">Bitte zuerst ein Turnier auswählen.</p>}
              {selectedTournament && selectedTournament.rounds.length === 0 && <div className="result-review-empty">Noch keine Runde ausgelost. Die Checkliste wird aktiv, sobald Paarungen vorhanden sind.</div>}
              {selectedTournament && selectedTournament.rounds.length > 0 && totalOpenBoardCount() === 0 && unverifiedCompleteRoundCount() === 0 && diagnosticWarningCount() === 0 && <div className="result-review-ok">Alle bekannten Runden sind vollständig, geprüft oder ohne Diagnosewarnung. Der Turnierbericht kann veröffentlicht werden.</div>}
              {totalOpenBoardCount() > 0 && <div className="result-review-warning danger"><strong>Offene Ergebnisse:</strong> Vor Tabelle, Aushang oder nächster Auslosung bitte alle offenen Bretter erfassen.</div>}
              {unverifiedCompleteRoundCount() > 0 && totalOpenBoardCount() === 0 && <div className="result-review-warning"><strong>Prüfung offen:</strong> Mindestens eine vollständige Runde ist noch nicht als geprüft markiert.</div>}

              {resultReviewRows().length > 0 && (
                <div className="table-wrap result-review-table-wrap">
                  <table>
                    <thead>
                      <tr><th>Runde</th><th>Brett</th><th>Weiß</th><th>Schwarz</th><th>Status</th><th>Hinweis</th></tr>
                    </thead>
                    <tbody>
                      {resultReviewRows().map(row => (
                        <tr key={`${row.roundNumber}-${row.boardNumber}-${row.kind}`}>
                          <td>{row.roundNumber}</td>
                          <td>{row.boardNumber}</td>
                          <td>{row.white}</td>
                          <td>{row.black}</td>
                          <td><span className={`result-review-chip ${row.kind === 'offen' ? 'danger' : row.kind === 'kampflos' ? 'warn' : ''}`}>{row.kind}</span></td>
                          <td>{row.note || row.resultLabel}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}

              <div className="result-review-actions">
                <button type="button" onClick={openLatestRoundPrint} disabled={!selectedTournament || selectedTournament.rounds.length === 0}>Aktuelle Runde drucken</button>
                <button type="button" className="secondary" onClick={() => openTournamentExport('print/html')} disabled={!selectedTournament}>Turnierbericht öffnen</button>
                <button type="button" className="secondary" onClick={() => openTournamentExport('standings/export.csv')} disabled={!selectedTournament}>Tabelle CSV</button>
              </div>
            </article>


          <article className="card correction-journal-card">
            <div className="card-heading-row">
              <div>
                <h3>Korrektur- und Eingriffsübersicht</h3>
                <p className="muted">Zeigt manuelle Paarungen, gesperrte/geprüfte Runden, inaktive Teilnehmer und Sonderergebnisse als Turnierleiter-Prüfliste.</p>
              </div>
              <span className={`status-pill ${correctionJournalStatusClass}`}>{correctionJournalStatusLabel}</span>
            </div>
            <div className="review-metrics correction-metrics">
              <div><strong>{correctionJournal.length}</strong><span>Einträge</span></div>
              <div><strong>{correctionJournalCriticalCount}</strong><span>kritisch</span></div>
              <div><strong>{correctionJournalWarningCount}</strong><span>prüfen</span></div>
              <div><strong>{correctionJournalInfoCount}</strong><span>Info</span></div>
            </div>
            {!selectedTournament && <p className="muted">Bitte zuerst ein Turnier auswählen.</p>}
            {selectedTournament && correctionJournal.length === 0 && (
              <div className="notice success">Keine manuellen Eingriffe, Sonderergebnisse oder offenen Prüfpunkte erkannt.</div>
            )}
            {selectedTournament && correctionJournalCriticalCount > 0 && (
              <div className="notice danger">Kritische Eingriffe erkannt: Manuelle Paarungen vor Aushang oder nächster Auslosung bewusst prüfen.</div>
            )}
            {selectedTournament && correctionJournalWarningCount > 0 && (
              <div className="notice warning">Prüfpunkte vorhanden: Teilnehmerstatus, ungeprüfte Runden oder Sonderergebnisse kontrollieren.</div>
            )}
            {selectedTournament && correctionJournal.length > 0 && (
              <div className="table-scroll compact correction-journal-table">
                <table>
                  <thead>
                    <tr>
                      <th>Bereich</th>
                      <th>Status</th>
                      <th>Eintrag</th>
                      <th>Details</th>
                      <th>Aktion</th>
                    </tr>
                  </thead>
                  <tbody>
                    {correctionJournal.map(item => (
                      <tr key={item.key} className={`journal-row ${item.severity}`}>
                        <td>{item.scope}</td>
                        <td><span className={`status-pill ${item.severity === 'critical' ? 'blocked' : item.severity === 'warning' ? 'warning' : 'ready'}`}>{item.severity === 'critical' ? 'kritisch' : item.severity === 'warning' ? 'prüfen' : 'Info'}</span></td>
                        <td>{item.title}</td>
                        <td>{item.detail}</td>
                        <td>{item.action}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
            <div className="actions">
              <button type="button" onClick={() => openLatestRoundPrint()} disabled={!selectedTournament || selectedTournament.rounds.length === 0}>Letzte Runde drucken</button>
              <button type="button" className="secondary" onClick={() => openTournamentExport('print/html')} disabled={!selectedTournament}>Turnierbericht öffnen</button>
              <button type="button" className="secondary" onClick={() => openTournamentExport('pairings/export.csv')} disabled={!selectedTournament}>Paarungen CSV</button>
            </div>
          </article><article className="card export-center-card">
              <div className="export-center-header">
                <div>
                  <h3>Turnierleiter-Exportcenter</h3>
                  <p className="muted">Schnellzugriff auf Aushänge, Tabellen, Paarungen, Vorschau und Backup. Ideal vor, während und nach einer Runde.</p>
                </div>
                <span className="export-center-badge">v0.25</span>
              </div>

              <div className="export-center-metrics">
                <div><strong>{selectedTournament?.players.length ?? 0}</strong><span>Teilnehmer</span></div>
                <div><strong>{activePlayerCount()}</strong><span>aktiv</span></div>
                <div><strong>{inactivePlayerCount()}</strong><span>inaktiv</span></div>
                <div><strong>{selectedTournament?.rounds.length ?? 0}</strong><span>Runden</span></div>
                <div><strong>{totalOpenBoardCount()}</strong><span>offene Bretter</span></div>
                <div><strong>{totalForfeitBoardCount()}</strong><span>kampflos</span></div>
              </div>

              {totalOpenBoardCount() > 0 && <div className="export-center-warning"><strong>Offene Ergebnisse:</strong> Vor Finaltabellen oder Veröffentlichungen bitte offene Bretter prüfen.</div>}
              {nextRoundPreview?.pairingQuality.hasCriticalIssues && <div className="export-center-warning critical"><strong>Kritische Vorschau:</strong> Pairing-Hinweise vor Aushang oder Auslosung prüfen.</div>}

              <div className="export-center-grid">
                <section>
                  <h4>Aushänge</h4>
                  <div className="export-center-actions">
                    <button type="button" onClick={() => openTournamentExport('print/html')} disabled={!selectedTournament}>Gesamt-Druckansicht</button>
                    <button type="button" onClick={openLatestRoundPrint} disabled={!selectedTournament || selectedTournament.rounds.length === 0}>Aktuelle Runde drucken</button>
                    <button type="button" onClick={openNextRoundPreviewPrint} disabled={!selectedTournament || activePlayerCount() < 2}>Vorschau drucken</button>
                  </div>
                </section>
                <section>
                  <h4>CSV / Daten</h4>
                  <div className="export-center-actions">
                    <button type="button" className="secondary" onClick={() => void exportPlayers()} disabled={!selectedTournament}>Teilnehmer CSV</button>
                    <button type="button" className="secondary" onClick={() => openTournamentExport('standings/export.csv')} disabled={!selectedTournament}>Tabelle CSV</button>
                    <button type="button" className="secondary" onClick={() => openTournamentExport('pairings/export.csv')} disabled={!selectedTournament}>Alle Paarungen CSV</button>
                    <button type="button" className="secondary" onClick={openLatestPairingsCsv} disabled={!selectedTournament || selectedTournament.rounds.length === 0}>Aktuelle Paarungen CSV</button>
                    <button type="button" className="secondary" onClick={openNextRoundPreviewCsv} disabled={!selectedTournament || activePlayerCount() < 2}>Vorschau CSV</button>
                    <button type="button" className="secondary" onClick={() => void exportTournamentJson()} disabled={!selectedTournament}>Backup JSON</button>
                  </div>
                </section>
              </div>

              <p className="muted export-center-note">Hinweis: Vorschau-Exports speichern keine Runde. Erst „Diese Runde jetzt auslosen“ übernimmt die Paarungen ins Turnier.</p>
            </article>
          <article className="card audit-journal-card">
            <div className="audit-journal-heading">
              <div>
                <h3>Audit-Journal</h3>
                <p>Persistentes Protokoll wichtiger Turnierleiter-Aktionen. Hilft bei Ergebnis-Korrekturen, Rundenprüfung und späteren Nachfragen.</p>
              </div>
              <span className={`status-pill ${auditJournalCriticalCount > 0 ? 'audit-critical' : auditJournalWarningCount > 0 ? 'audit-warning' : 'audit-info'}`}>
                {auditJournal.length} Einträge
              </span>
            </div>
            <div className="audit-journal-summary">
              <div><strong>{auditJournalInfoCount}</strong><span>Info</span></div>
              <div><strong>{auditJournalWarningCount}</strong><span>Warnung</span></div>
              <div><strong>{auditJournalCriticalCount}</strong><span>kritisch</span></div>
              <div><strong>{auditJournalRoundEntryCount}</strong><span>Rundenbezug</span></div>
              <div><strong>{auditJournalPlayerEntryCount}</strong><span>Spielerbezug</span></div>
            </div>
            {!selectedTournament && <p>Bitte zuerst ein Turnier auswählen.</p>}
            {selectedTournament && auditJournal.length === 0 && <p className="ok">Noch keine Audit-Einträge vorhanden.</p>}
            {auditJournalCriticalCount > 0 && <p className="warning-text">Kritische Audit-Einträge vorhanden: Bitte vor Veröffentlichung oder nächster Auslosung prüfen.</p>}
            {selectedTournament && auditJournal.length > 0 && (
              <>
                <div className="table-scroll compact audit-journal-table">
                  <table>
                    <thead><tr><th>Zeit</th><th>Stufe</th><th>Aktion</th><th>Bezug</th><th>Zusammenfassung</th><th>Details</th><th>Grund</th></tr></thead>
                    <tbody>
                      {auditJournalRecentEntries.map(entry => (
                        <tr key={entry.id} className={auditSeverityClass(entry.severity)}>
                          <td>{auditDateLabel(entry.createdAt)}</td>
                          <td><span className={`audit-pill ${auditSeverityClass(entry.severity)}`}>{auditSeverityLabel(entry.severity)}</span></td>
                          <td>{auditActionLabel(entry.action)}<small>{entry.actor}</small></td>
                          <td>{entry.roundNumber ? `R${entry.roundNumber}` : '—'}{entry.boardNumber ? ` · Brett ${entry.boardNumber}` : ''}{entry.playerName ? <small>{entry.playerName}</small> : null}</td>
                          <td>{entry.summary}</td>
                          <td>{entry.details || '—'}</td>
                          <td>{entry.reason || '—'}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
                {auditJournal.length > auditJournalRecentEntries.length && <p className="muted">Anzeige begrenzt auf die letzten {auditJournalRecentEntries.length} von {auditJournal.length} Einträgen. Für vollständige Auswertung bitte CSV/JSON exportieren.</p>}
              </>
            )}
            <div className="actions">
              <button type="button" onClick={() => exportAuditJournalCsv()} disabled={!selectedTournament || auditJournal.length === 0}>Audit CSV</button>
              <button type="button" className="secondary" onClick={() => exportAuditJournalJson()} disabled={!selectedTournament || auditJournal.length === 0}>Audit JSON</button>
            </div>
          </article>
<article className="card">
            <h3>Import / Export</h3>
            <div className="grid two">
              <section>
                <h4>Teilnehmer-CSV</h4>
                <textarea value={csvContent} onChange={(event: React.ChangeEvent<HTMLTextAreaElement>) => { setCsvContent(event.target.value); setImportPreview(null); setConfirmWarningImport(false); }} rows={7} />
                <label className="checkbox"><input type="checkbox" checked={replacePlayers} onChange={(event: React.ChangeEvent<HTMLInputElement>) => { setReplacePlayers(event.target.checked); setImportPreview(null); setConfirmWarningImport(false); }} /> vorhandene Teilnehmer ersetzen</label>
                <div className="actions">
                  <button type="button" className="secondary" onClick={() => useSampleCsvTemplate()}>CSV-Vorlage einsetzen</button>
                  <button type="button" onClick={() => void previewPlayersImport()} disabled={!selectedTournament || !csvContent.trim()}>Import prüfen</button>
                  <button type="button" onClick={() => void importPlayers()} disabled={!selectedTournament || !importPreview || importPreview.hasBlockingIssues || (importPreview.warningRows > 0 && !confirmWarningImport)}>CSV importieren</button>
                  <button type="button" className="secondary" onClick={() => void exportPlayers()} disabled={!selectedTournament}>CSV exportieren</button>
                </div>
                {importPreview && (
                  <div className="import-preview">
                    <div className={`preview-summary ${importPreview.hasBlockingIssues ? 'blocked' : importPreview.warningRows > 0 ? 'warning' : 'ready'}`}>
                      <strong>{importPreview.hasBlockingIssues ? 'Import blockiert' : importPreview.warningRows > 0 ? 'Import mit Warnungen möglich' : 'Import bereit'}</strong>
                      <span>{importPreview.totalRows} Zeilen · {importPreview.importableRows} importierbar · {importPreview.warningRows} Warnung(en) · {importPreview.blockingRows} blockiert · {importPreview.likelyDuplicateRows} mögliche Dublette(n)</span>
                    </div>
                    {importPreview.globalWarnings.length > 0 && (
                      <ul className="message-list critical">
                        {importPreview.globalWarnings.map((warning, index) => <li key={`import-global-${index}`}>{warning}</li>)}
                      </ul>
                    )}
                    {importPreview.warningRows > 0 && !importPreview.hasBlockingIssues && (
                      <label className="checkbox import-confirm">
                        <input type="checkbox" checked={confirmWarningImport} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setConfirmWarningImport(event.target.checked)} />
                        Ich habe Warnungen und mögliche Dubletten geprüft und möchte den Import trotzdem ausführen.
                      </label>
                    )}
                    {importPreview.hasBlockingIssues && <p className="error">Blockierende Probleme müssen vor dem Import behoben werden.</p>}
                    <div className="table-scroll compact import-preview-table">
                      <table>
                        <thead><tr><th>Zeile</th><th>Teilnehmer</th><th>Status</th><th>Dubletten</th><th>Hinweise</th></tr></thead>
                        <tbody>
                          {importPreview.rows.map(row => (
                            <tr key={`import-preview-${row.rowNumber}`} className={importPreviewStatusClass(row.status)}>
                              <td>{row.rowNumber}</td>
                              <td>{row.player.name}<small>{row.player.fideId ? `FIDE ${row.player.fideId}` : row.player.nationalId ? `DSB ${row.player.nationalId}` : row.player.club ?? ''}</small></td>
                              <td>{importPreviewStatusLabel(row.status)}</td>
                              <td>{row.duplicateCheck.matches.length === 0 ? '—' : row.duplicateCheck.matches.map(match => `${match.playerName} (${duplicateKindLabel(match.kind)}, ${match.score})`).join('; ')}</td>
                              <td>{importPreviewMessages(row).length === 0 ? <span className="ok">ok</span> : <ul className="message-list">{importPreviewMessages(row).map((message, index) => <li key={`import-row-${row.rowNumber}-${index}`}>{message}</li>)}</ul>}</td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  </div>
                )}
              </section>
              <section>
                <h4>JSON-Backup</h4>
                <textarea value={backupJson} onChange={(event: React.ChangeEvent<HTMLTextAreaElement>) => setBackupJson(event.target.value)} rows={7} placeholder="Backup-JSON hier einfügen oder exportieren" />
                <div className="actions">
                  <button type="button" onClick={() => void exportTournamentJson()} disabled={!selectedTournament}>Backup exportieren</button>
                  <button type="button" className="secondary" onClick={() => void importTournamentJson()} disabled={!backupJson.trim()}>Backup importieren</button>
                </div>
              </section>
              <section>
                <h4>Druck / Aushang</h4>
                <p className="muted">Erzeugt lokale CSV-/HTML-Dateien für Tabelle, Paarungen, Rundenblatt und kompletten Turnierbericht.</p>
                <div className="actions vertical-actions">
                  <button type="button" onClick={() => openTournamentExport('standings/export.csv')} disabled={!selectedTournament}>Tabelle als CSV</button>
                  <button type="button" onClick={() => openTournamentExport('pairings/export.csv')} disabled={!selectedTournament}>Alle Paarungen als CSV</button>
                  <button type="button" onClick={() => openTournamentExport('print/html')} disabled={!selectedTournament}>Turnier-Druckansicht</button>
                </div>
                <div className="round-print-list">
                  {selectedTournament?.rounds.map(round => (
                    <button key={`print-${round.roundNumber}`} type="button" className="small secondary" onClick={() => openRoundPrint(round.roundNumber)}>Runde {round.roundNumber} drucken</button>
                  ))}
                </div>
              </section>
            </div>
          </article>
        </section>
      </section>
    </main>
  );
}

ReactDOM.createRoot(document.getElementById('root')!).render(<App />);
