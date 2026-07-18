import React from 'react';
import ReactDOM from 'react-dom/client';
import { encodeText, Ecl } from './qrcodegen';
import { I18nProvider, LanguageSwitcher, useI18n } from './i18n';
import rawLocalKnowledgeBase from './knowledge/localKnowledgeBase.json';
import './styles.css';

type Health = {
  status: string;
  app: string;
  version: string;
  time: string;
  database?: string;
};

type BeforeInstallPromptEvent = Event & {
  prompt: () => Promise<void>;
  userChoice: Promise<{ outcome: 'accepted' | 'dismissed'; platform: string }>;
};

type PwaStatus = 'checking' | 'unsupported' | 'ready' | 'installable' | 'installed' | 'update-available' | 'error';

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
    unplayedRoundBuchholzMode: number;
    countByeAsWin: boolean;
    allowManualPairingOverrides: boolean;
    pairingStrategy: number;
    swissInitialColour: number;
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
  unplayedRoundBuchholzMode: number;
  countByeAsWin: boolean;
  allowManualPairingOverrides: boolean;
  pairingStrategy: number;
  swissInitialColour: number;
  seniorBirthYearOrEarlier: string;
  heroCupMinimumRatedGames: string;
  tiebreaks: number[];
};

type TournamentAssistantScenario = 'club-night' | 'youth' | 'open' | 'blitz' | 'chess960' | 'team';

type TournamentAssistantForm = {
  playerCount: string;
  availableMinutes: string;
  boardCount: string;
  scenario: TournamentAssistantScenario;
  rated: boolean;
  chess960: boolean;
  needsQr: boolean;
};

type TournamentAssistantRecommendation = {
  title: string;
  format: number;
  formatLabel: string;
  plannedRounds: number;
  scoringSystem: number;
  scoringLabel: string;
  estimatedRoundMinutes: number;
  estimatedTotalMinutes: number;
  estimatedBoards: number;
  timeFit: 'ok' | 'tight' | 'blocked';
  timeFitLabel: string;
  setupSteps: string[];
  warnings: string[];
  operatorChecklist: string[];
  exportPlan: string[];
  handoffPrompt: string;
};


type KnowledgeChatRole = 'user' | 'assistant';

type KnowledgeChatMessage = {
  id: string;
  role: KnowledgeChatRole;
  text: string;
  sources: string[];
};

type KnowledgeTopic = {
  id: string;
  title: string;
  keywords: string[];
  answer: string;
  steps: string[];
  sources: string[];
};

type KnowledgeBase = {
  sourceVersion: string;
  sourceUpdated: string;
  providerMode: 'local-only';
  privacyNotice: string;
  quickQuestions: string[];
  topics: KnowledgeTopic[];
};

const localKnowledgeBase = rawLocalKnowledgeBase as KnowledgeBase;
const knowledgeQuickQuestions = localKnowledgeBase.quickQuestions;
const knowledgeTopics = localKnowledgeBase.topics;


function normalizeKnowledgeText(value: string): string {
  return value.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '');
}

function topicScore(question: string, topic: KnowledgeTopic): number {
  const normalizedQuestion = normalizeKnowledgeText(question);
  return topic.keywords.reduce((score, keyword) => normalizedQuestion.includes(normalizeKnowledgeText(keyword)) ? score + 2 : score, 0)
    + normalizeKnowledgeText(topic.title).split(/\s+/).filter(part => part.length > 3 && normalizedQuestion.includes(part)).length;
}

function buildKnowledgeContext(tournament: Tournament | undefined, recommendation: TournamentAssistantRecommendation): string[] {
  const context: string[] = [];
  if (tournament) {
    const roundCount = tournament.rounds.length;
    const activePlayers = tournament.players.filter(player => player.status === 0).length;
    context.push(`Aktueller Kontext: „${tournament.name}“ mit ${activePlayers}/${tournament.players.length} aktiven Teilnehmern und ${roundCount} Runde(n).`);
    if (roundCount === 0) {
      context.push('Noch keine Runde ausgelost: zuerst Teilnehmer/Einstellungen prüfen und ein Startbackup erstellen.');
    }
    else {
      const latestRound = tournament.rounds.reduce((max, round) => Math.max(max, round.roundNumber), 0);
      context.push(`Letzte bekannte Runde: ${latestRound}. Nach Ergebniserfassung Backup und Tabelle prüfen.`);
    }
  }
  else {
    context.push('Kein Turnier ausgewählt: Empfehlung bezieht sich auf die aktuelle Assistenten-Eingabe.');
  }

  context.push(`Assistenten-Vorschlag: ${recommendation.formatLabel}, ${recommendation.plannedRounds} Runde(n), ca. ${recommendation.estimatedTotalMinutes} Minuten.`);
  if (recommendation.warnings.length > 0) {
    context.push(`Prüfhinweis: ${recommendation.warnings[0]}`);
  }

  return context;
}

function buildLocalKnowledgeAnswer(question: string, tournament: Tournament | undefined, recommendation: TournamentAssistantRecommendation): KnowledgeChatMessage {
  const scored = knowledgeTopics
    .map(topic => ({ topic, score: topicScore(question, topic) }))
    .sort((left, right) => right.score - left.score);
  const best = scored[0]?.score > 0 ? scored[0].topic : knowledgeTopics[0];
  if (!best) {
    return {
      id: `assistant-${Date.now()}-${Math.random().toString(36).slice(2)}`,
      role: 'assistant',
      text: `Die lokale Wissensbasis ist leer. Bitte src/knowledge/localKnowledgeBase.json pruefen.\n\nHinweis: ${localKnowledgeBase.privacyNotice}`,
      sources: ['src/knowledge/localKnowledgeBase.json']
    };
  }
  const context = buildKnowledgeContext(tournament, recommendation);
  const text = [
    `**${best.title}**`,
    best.answer,
    '',
    ...context.map(item => `• ${item}`),
    '',
    'Nächste Schritte:',
    ...best.steps.map((step, index) => `${index + 1}. ${step}`),
    '',
    `Hinweis: ${localKnowledgeBase.privacyNotice}`
  ].join('\n');

  return {
    id: `assistant-${Date.now()}-${Math.random().toString(36).slice(2)}`,
    role: 'assistant',
    text,
    sources: best.sources
  };
}

const assistantScenarioOptions: Array<{ value: TournamentAssistantScenario; label: string; description: string }> = [
  { value: 'club-night', label: 'Vereinsabend / Schnellturnier', description: 'Robuste Standardempfehlung für 8–30 Spieler und begrenzte Zeit.' },
  { value: 'youth', label: 'Jugendturnier', description: 'Kürzere Runden, klare Checklisten, viele Ausdrucke.' },
  { value: 'open', label: 'Open / großes Feld', description: 'Schweizer System, Audit, Backup und Veröffentlichung im Vordergrund.' },
  { value: 'blitz', label: 'Blitz / Schnellschach', description: 'Viele kurze Runden und einfache Wertung.' },
  { value: 'chess960', label: 'Chess960 / Freestyle', description: 'QR-/Handy-Würfeln und Startstellungs-Audit einplanen.' },
  { value: 'team', label: 'Mannschaft / Teamturnier', description: 'Noch nicht vollständig implementiert; aktuell als Planungshinweis.' }
];

const defaultTournamentAssistantForm: TournamentAssistantForm = {
  playerCount: '12',
  availableMinutes: '180',
  boardCount: '6',
  scenario: 'club-night',
  rated: false,
  chess960: false,
  needsQr: true
};

function assistantNumber(value: string, fallback: number, min: number, max: number): number {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    return fallback;
  }

  return Math.min(max, Math.max(min, Math.round(parsed)));
}

function recommendedSwissRounds(playerCount: number): number {
  if (playerCount <= 4) return 3;
  if (playerCount <= 8) return 5;
  if (playerCount <= 16) return 5;
  if (playerCount <= 32) return 6;
  if (playerCount <= 64) return 7;
  return 9;
}

function assistantScenarioRoundMinutes(form: TournamentAssistantForm): number {
  switch (form.scenario) {
    case 'blitz': return 12;
    case 'youth': return 18;
    case 'chess960': return 22;
    case 'open': return 30;
    case 'team': return 35;
    default: return 20;
  }
}

function buildTournamentAssistantRecommendation(form: TournamentAssistantForm): TournamentAssistantRecommendation {
  const playerCount = assistantNumber(form.playerCount, 12, 2, 512);
  const availableMinutes = assistantNumber(form.availableMinutes, 180, 30, 1440);
  const boardCount = assistantNumber(form.boardCount, Math.max(1, Math.ceil(playerCount / 2)), 1, 256);
  const activeChess960 = form.chess960 || form.scenario === 'chess960';
  const canRoundRobin = playerCount <= 8 && form.scenario !== 'open' && form.scenario !== 'team';
  const formatValue = canRoundRobin && availableMinutes >= Math.max(3, playerCount - 1) * assistantScenarioRoundMinutes(form) ? 0 : 1;
  const plannedRounds = formatValue === 0 ? Math.max(1, playerCount - 1) : recommendedSwissRounds(playerCount);
  const scoringSystem = form.scenario === 'blitz' ? 0 : 0;
  const estimatedRoundMinutes = assistantScenarioRoundMinutes(form);
  const estimatedTotalMinutes = plannedRounds * estimatedRoundMinutes + 20;
  const estimatedBoards = Math.ceil(playerCount / 2);
  const timeFit: TournamentAssistantRecommendation['timeFit'] = estimatedTotalMinutes <= availableMinutes
    ? 'ok'
    : estimatedTotalMinutes <= availableMinutes + 30
      ? 'tight'
      : 'blocked';
  const timeFitLabel = timeFit === 'ok'
    ? 'Zeitfenster passt'
    : timeFit === 'tight'
      ? 'Zeitfenster knapp – Rundenlänge oder Rundenzahl prüfen'
      : 'Zeitfenster reicht voraussichtlich nicht';
  const formatLabel = formatOptions.find(option => option.value === formatValue)?.label ?? 'Schweizer System';
  const scoringLabel = scoringOptions.find(option => option.value === scoringSystem)?.label ?? scoringOptions[0].label;
  const setupSteps = [
    `${formatLabel} mit ${plannedRounds} Runde(n) vorbereiten`,
    `Teilnehmerliste importieren oder erfassen; erwartete Bretter: ${estimatedBoards}`,
    'Vor Runde 1 Backup ziehen und Datenbankpfad prüfen',
    'Auslosungsvorschau öffnen, Pairing-Qualität prüfen und erst dann auslosen',
    'Nach jeder Runde Ergebnisse vollständig erfassen, Runde prüfen und Backup exportieren'
  ];

  if (activeChess960) {
    setupSteps.splice(3, 0, 'Chess960/QR-Würfeln vor Rundenstart testen und WLAN-/Hotspot-Link prüfen');
  }

  const warnings: string[] = [];
  if (boardCount < estimatedBoards) {
    warnings.push(`Nur ${boardCount} Brett(er) angegeben, aber ${estimatedBoards} Brett(er) benötigt. BYE/Schichtbetrieb oder weniger Teilnehmer einplanen.`);
  }
  if (timeFit !== 'ok') {
    warnings.push(timeFitLabel);
  }
  if (playerCount > 20) {
    warnings.push('Großes Schweizer Feld: Paarungsstrategie bewusst wählen und Pairing-Audit besonders prüfen. FIDE Dutch ist integriert, aber nicht als FIDE-zertifizierte Turniersoftware ausgewiesen.');
  }
  if (form.rated) {
    warnings.push('Gewertetes Turnier: Ausschreibung, Bedenkzeit, Bye-/Kampflos-Regeln und Exportformat vorab mit Verband/Turnierordnung abgleichen.');
  }
  if (form.scenario === 'team') {
    warnings.push('Team-/Mannschaftsturniere sind aktuell noch Planungsszenario; vollständige Mehrbrett-Teamlogik folgt in RUN-16.');
  }

  const operatorChecklist = [
    'Laptop am Netzteil betreiben und Energiesparen/Bildschirmsperre deaktivieren',
    'Startdatei/Backend-Fenster offen lassen und Browser nicht schließen',
    'Drucker oder PDF-Export vor Runde 1 testen',
    'Ergebniszettel/QR-Aushang vorbereiten',
    'Nach jeder Runde Audit/Backup sichern'
  ];

  const exportPlan = [
    'Teilnehmerliste vor Turnierstart exportieren',
    'Rundenblatt je Runde drucken oder als PDF ablegen',
    'Tabelle nach jeder Runde veröffentlichen',
    'Abschluss-Backup und finale Tabelle exportieren'
  ];

  const handoffPrompt = `Plane ein ${assistantScenarioOptions.find(option => option.value === form.scenario)?.label ?? 'Turnier'} mit ${playerCount} Teilnehmern, ${availableMinutes} Minuten Zeit, ${boardCount} Brettern, Format ${formatLabel}, ${plannedRounds} Runden${activeChess960 ? ', Chess960/Freestyle mit QR-Würfeln' : ''}. Prüfe Pairing, Wertung, Backup, Druck und Veröffentlichung Schritt für Schritt.`;

  return {
    title: `${formatLabel} · ${plannedRounds} Runde(n) · ca. ${estimatedTotalMinutes} Min.`,
    format: formatValue,
    formatLabel,
    plannedRounds,
    scoringSystem,
    scoringLabel,
    estimatedRoundMinutes,
    estimatedTotalMinutes,
    estimatedBoards,
    timeFit,
    timeFitLabel,
    setupSteps,
    warnings,
    operatorChecklist,
    exportPlan,
    handoffPrompt
  };
}

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
  { value: 0, label: 'offen', labelEn: 'open' },
  { value: 1, label: '1-0', labelEn: '1-0' },
  { value: 2, label: '½-½', labelEn: '½-½' },
  { value: 3, label: '0-1', labelEn: '0-1' },
  { value: 4, label: '+/- kampflos Weiß', labelEn: '+/- White forfeit win' },
  { value: 5, label: '-/+ kampflos Schwarz', labelEn: '-/+ Black forfeit win' },
  { value: 6, label: '-/- kampflos beide', labelEn: '-/- double forfeit' },
  { value: 7, label: 'Bye', labelEn: 'Bye' },
  { value: 8, label: 'Armageddon Weiß', labelEn: 'Armageddon White' },
  { value: 9, label: 'Armageddon Schwarz', labelEn: 'Armageddon Black' }
];

const formatOptions = [
  { value: 1, label: 'Schweizer System' },
  { value: 0, label: 'Jeder gegen Jeden' }
];

const pairingStrategyOptions = [
  { value: 0, label: 'Optimal V2 (empfohlen)' },
  { value: 1, label: 'FIDE Dutch' }
];

const swissInitialColourOptions = [
  { value: 1, label: 'Weiß' },
  { value: 2, label: 'Schwarz' }
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

const unplayedRoundBuchholzOptions = [
  { value: 0, label: 'Eigene ungespielte Runden ignorieren (bisheriges Verhalten)' },
  { value: 1, label: 'FIDE-Modus (Schweizer): Dummy-/VUR-Wertung nach Art. 16' }
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
Weissbach, Lina;Beispiel SV;1990;männlich;1987;;1968;;99900123;;CM;Active;Beispielzeile bitte vor Import prüfen
Musterfrau, Anna;Beispielverein;2012;weiblich;1200;;1300;;;;Active;U14-Beispiel
`;

const defaultTiebreaks = [0, 1, 2, 4, 6, 99];

const emptySettingsForm: SettingsForm = {
  format: 1,
  scoringSystem: 0,
  twzSource: 0,
  plannedRounds: '5',
  forfeitTiebreakPolicy: 0,
  unplayedRoundBuchholzMode: 0,
  countByeAsWin: false,
  allowManualPairingOverrides: true,
  pairingStrategy: 0,
  swissInitialColour: 1,
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

function readLocalStorage(key: string): string | null {
  try {
    return window.localStorage.getItem(key);
  } catch {
    return null;
  }
}

function writeLocalStorage(key: string, value: string): void {
  try {
    window.localStorage.setItem(key, value);
  } catch {
    // localStorage kann im Privatmodus blockiert sein – Bedienung darf trotzdem weiterlaufen.
  }
}

function isStandaloneDisplayMode(): boolean {
  const navigatorWithStandalone = navigator as Navigator & { standalone?: boolean };
  return Boolean(navigatorWithStandalone.standalone) || window.matchMedia?.('(display-mode: standalone)').matches === true;
}

function pwaStatusLabel(status: PwaStatus): string {
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

function backupTimestampSlug(date: Date): string {
  const pad = (value: number) => String(value).padStart(2, '0');
  return `${date.getFullYear()}${pad(date.getMonth() + 1)}${pad(date.getDate())}_${pad(date.getHours())}${pad(date.getMinutes())}${pad(date.getSeconds())}`;
}

function safeFileNamepart(value: string): string {
  return value.replace(/[^A-Za-z0-9_\-]+/g, '_').replace(/^_+|_+$/g, '') || 'turnier';
}

function backupTimeLabel(iso: string | null): string {
  if (!iso) {
    return 'noch kein lokaler Backup-Export';
  }
  const parsed = new Date(iso);
  if (Number.isNaN(parsed.getTime())) {
    return 'unbekannt';
  }
  return parsed.toLocaleString('de-DE');
}

function resultLabel(kind: number, english = false): string {
  const option = resultOptions.find(item => item.value === kind);
  return (english ? option?.labelEn : option?.label) ?? String(kind);
}

function genderLabel(kind: number): string {
  return genderOptions.find(option => option.value === kind)?.label ?? String(kind);
}

function statusLabel(kind: number): string {
  return playerStatusOptions.find(option => option.value === kind)?.label ?? String(kind);
}

function roundStatusLabel(kind: number, english = false): string {
  switch (kind) {
    case 1: return english ? 'complete' : 'vollständig';
    case 2: return english ? 'reviewed' : 'geprüft';
    case 3: return english ? 'locked' : 'gesperrt';
    default: return english ? 'open' : 'offen';
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
    unplayedRoundBuchholzMode: settings.unplayedRoundBuchholzMode ?? 0,
    countByeAsWin: settings.countByeAsWin,
    allowManualPairingOverrides: settings.allowManualPairingOverrides,
    pairingStrategy: settings.pairingStrategy ?? 0,
    swissInitialColour: settings.swissInitialColour ?? 1,
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
    unplayedRoundBuchholzMode: form.unplayedRoundBuchholzMode,
    countByeAsWin: form.countByeAsWin,
    allowManualPairingOverrides: form.allowManualPairingOverrides,
    pairingStrategy: form.pairingStrategy,
    swissInitialColour: form.swissInitialColour,
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

function ChessDie({ rolling, spin, face, quick, compact }: { rolling: boolean; spin: number; face: number; quick?: boolean; compact?: boolean }): React.ReactElement {
  // Sichtbarer Holz-D6: tumbelt/fliegt beim Würfeln und legt sich danach auf die Ergebnisfigur.
  // Rein visuell – die tatsächliche, gültige Chess960-Stellung erzeugt der Backend-Service.
  const restStyle = rolling ? undefined : { transform: diceRestTransforms[face] ?? diceRestTransforms[0] };
  const rollClass = rolling ? (quick ? ' rolling-quick' : ' rolling') : '';
  return (
    <div className={`dice-stage${compact ? ' compact' : ''}`}>
      <div className={`dice-cube${rollClass}`} key={spin} style={restStyle}>
        {diceFaceGlyphs.map((glyph, index) => (
          <div key={index} className={`dice-face dice-face-${index}`}>{glyph}</div>
        ))}
      </div>
    </div>
  );
}

// Spiegelt exakt die Domain-Logik Chess960PositionService.FromPositionNumber wider, damit die
// links-nach-rechts-Animation dieselbe Stellung zeigt, die das Backend aus derselben
// Positionsnummer (0..959) erneut ableitet und speichert.
const chess960LightSquares = [1, 3, 5, 7];
const chess960DarkSquares = [0, 2, 4, 6];
const chess960KnightCombinations: Array<[number, number]> = (() => {
  const combinations: Array<[number, number]> = [];
  for (let first = 0; first < 5; first++) {
    for (let second = first + 1; second < 5; second++) {
      combinations.push([first, second]);
    }
  }
  return combinations;
})();

function chess960BackRankFromNumber(positionNumber: number): string {
  let remaining = positionNumber;
  const backRank: string[] = new Array(8).fill('');
  const emptySquares = (): number[] =>
    backRank.map((piece, index) => (piece === '' ? index : -1)).filter(index => index >= 0);

  const lightBishopIndex = remaining % 4;
  remaining = Math.floor(remaining / 4);
  backRank[chess960LightSquares[lightBishopIndex]] = 'B';

  const darkBishopIndex = remaining % 4;
  remaining = Math.floor(remaining / 4);
  backRank[chess960DarkSquares[darkBishopIndex]] = 'B';

  let squares = emptySquares();
  const queenIndex = remaining % 6;
  remaining = Math.floor(remaining / 6);
  backRank[squares[queenIndex]] = 'Q';

  squares = emptySquares();
  const knight = chess960KnightCombinations[remaining % 10];
  backRank[squares[knight[0]]] = 'N';
  backRank[squares[knight[1]]] = 'N';

  squares = emptySquares();
  backRank[squares[0]] = 'R';
  backRank[squares[1]] = 'K';
  backRank[squares[2]] = 'R';

  return backRank.join('');
}

const chess960PieceToFace: Record<string, number> = { K: 0, Q: 1, R: 2, B: 3, N: 4 };

function chess960PieceFace(piece: string): number {
  return chess960PieceToFace[piece] ?? 0;
}

type BoardDiceParams = { tournamentId: string; roundNumber: number; boardNumber: number };

function parseBoardDiceParams(search: string): BoardDiceParams | null {
  const params = new URLSearchParams(search);
  const tournamentId = params.get('dice');
  const roundNumber = Number(params.get('round'));
  const boardNumber = Number(params.get('board'));
  if (!tournamentId || !Number.isInteger(roundNumber) || !Number.isInteger(boardNumber) || roundNumber < 1 || boardNumber < 1) {
    return null;
  }
  return { tournamentId, roundNumber, boardNumber };
}

function defaultLanHost(): string {
  const host = window.location.hostname;
  return host === 'localhost' || host === '127.0.0.1' || host === '::1' ? '' : host;
}

// Schritt-für-Schritt-Würfel für genau ein Brett. Wird im Modal (Reiter „Browser würfeln")
// und auf der mobilen QR-Seite verwendet. Die Animation ist Visualisierung; gespeichert wird
// die exakt vorgewürfelte Positionsnummer, die das Backend über den Domain-Service ableitet.
function BoardDiceRoller({
  tournamentId,
  roundNumber,
  boardNumber,
  currentPosition,
  disabled,
  onSaved
}: {
  tournamentId: string;
  roundNumber: number;
  boardNumber: number;
  currentPosition: Chess960StartPosition | null;
  disabled: boolean;
  onSaved: (round: TournamentRound) => void;
}): React.ReactElement {
  const [phase, setPhase] = React.useState<'idle' | 'rolling' | 'revealed'>('idle');
  const [previewNumber, setPreviewNumber] = React.useState<number | null>(null);
  const [previewBackRank, setPreviewBackRank] = React.useState<string>('');
  const [revealStep, setRevealStep] = React.useState(0);
  const [rolling, setRolling] = React.useState(false);
  const [quick, setQuick] = React.useState(false);
  const [face, setFace] = React.useState(0);
  const [spin, setSpin] = React.useState(0);
  const [saving, setSaving] = React.useState(false);
  const [localError, setLocalError] = React.useState<string | null>(null);
  const [localStatus, setLocalStatus] = React.useState<string | null>(null);
  const timers = React.useRef<number[]>([]);

  React.useEffect(() => () => {
    timers.current.forEach(id => window.clearTimeout(id));
  }, []);

  const schedule = (callback: () => void, delay: number): void => {
    const id = window.setTimeout(callback, delay);
    timers.current.push(id);
  };

  function revealNext(rank: string, step: number): void {
    if (step >= 8) {
      setRolling(false);
      setPhase('revealed');
      return;
    }
    setFace(chess960PieceFace(rank[step]));
    setQuick(true);
    setRolling(true);
    setSpin(previous => previous + 1);
    schedule(() => {
      setRolling(false);
      setRevealStep(step + 1);
      schedule(() => revealNext(rank, step + 1), 170);
    }, 300);
  }

  function startRoll(): void {
    if (rolling || saving || disabled) {
      return;
    }
    setLocalError(null);
    setLocalStatus(null);
    const number = Math.floor(Math.random() * 960);
    const rank = chess960BackRankFromNumber(number);
    setPreviewNumber(number);
    setPreviewBackRank(rank);
    setRevealStep(0);
    setPhase('rolling');
    setQuick(false);
    setRolling(true);
    setSpin(previous => previous + 1);
    schedule(() => {
      setRolling(false);
      revealNext(rank, 0);
    }, 1100);
  }

  async function save(): Promise<void> {
    if (previewNumber === null || saving) {
      return;
    }
    if (currentPosition) {
      const confirmed = window.confirm(`Brett ${boardNumber}: vorhandene Startstellung (SP ${currentPosition.positionNumber}) überschreiben?`);
      if (!confirmed) {
        return;
      }
    }
    setSaving(true);
    setLocalError(null);
    try {
      const updated = await requestJson<TournamentRound>(
        `/api/tournaments/${tournamentId}/rounds/${roundNumber}/chess960/start-positions/${boardNumber}`,
        {
          method: 'POST',
          body: JSON.stringify({ overwriteExisting: Boolean(currentPosition), positionNumber: previewNumber })
        }
      );
      setLocalStatus(`Gespeichert: SP ${previewNumber} für Brett ${boardNumber}.`);
      setPhase('idle');
      setPreviewNumber(null);
      setPreviewBackRank('');
      setRevealStep(0);
      onSaved(updated);
    } catch (ex) {
      setLocalError(ex instanceof Error ? ex.message : String(ex));
    } finally {
      setSaving(false);
    }
  }

  const revealedRank = previewBackRank
    .split('')
    .map((piece, index) => (index < revealStep ? piece : ''));

  return (
    <div className="board-dice-roller">
      <ChessDie rolling={rolling} spin={spin} face={face} quick={quick} compact />
      <div className="board-dice-squares" aria-label="Chess960-Grundreihe Feld für Feld">
        {revealedRank.map((piece, index) => (
          <div
            key={index}
            className={`board-dice-square${index < revealStep ? ' filled' : ''}${index === revealStep && phase === 'rolling' ? ' active' : ''}`}
          >
            {piece ? diceFaceGlyphs[chess960PieceFace(piece)] : index + 1}
          </div>
        ))}
      </div>
      <p className="dice-result-line">
        {phase === 'rolling'
          ? 'Der Würfel arbeitet sich Feld für Feld nach rechts …'
          : phase === 'revealed' && previewNumber !== null
            ? `Ergebnis: ${previewBackRank} · SP ${previewNumber}`
            : currentPosition
              ? `Aktuell gespeichert: ${currentPosition.whiteBackRank} · SP ${currentPosition.positionNumber}`
              : 'Bereit zum Würfeln für dieses Brett.'}
      </p>
      {phase === 'revealed' && previewNumber !== null && (
        <p className="board-dice-black muted">Schwarz spiegelbildlich: {previewBackRank.toLowerCase()}</p>
      )}
      <div className="dice-modal-actions">
        {phase !== 'revealed' && (
          <button type="button" onClick={startRoll} disabled={rolling || saving || disabled}>
            {rolling ? 'Würfelt …' : currentPosition ? '🎲 Neu würfeln' : '🎲 Würfeln'}
          </button>
        )}
        {phase === 'revealed' && (
          <>
            <button type="button" onClick={() => void save()} disabled={saving || disabled}>
              {saving ? 'Speichert …' : '💾 Für Brett speichern'}
            </button>
            <button type="button" className="secondary" onClick={startRoll} disabled={saving}>🎲 Nochmal würfeln</button>
            <button type="button" className="secondary" onClick={() => { setPhase('idle'); setPreviewNumber(null); setRevealStep(0); }} disabled={saving}>Abbrechen</button>
          </>
        )}
      </div>
      {localStatus && <p className="board-dice-ok">{localStatus}</p>}
      {localError && <p className="board-dice-error">⚠ {localError}</p>}
    </div>
  );
}

function QrPanel({ url }: { url: string }): React.ReactElement {
  const rendered = React.useMemo(() => {
    try {
      const qr = encodeText(url, Ecl.Medium);
      const border = 4;
      const dimension = qr.size + border * 2;
      let path = '';
      for (let y = 0; y < qr.size; y++) {
        for (let x = 0; x < qr.size; x++) {
          if (qr.getModule(x, y)) {
            path += `M${x + border} ${y + border}h1v1h-1z`;
          }
        }
      }
      return { ok: true as const, dimension, path };
    } catch {
      return { ok: false as const, dimension: 0, path: '' };
    }
  }, [url]);

  if (!rendered.ok) {
    return <p className="board-dice-error">QR-Code konnte für diese URL nicht erzeugt werden. Bitte die URL unten manuell am Handy eintippen.</p>;
  }

  return (
    <svg
      className="qr-svg"
      viewBox={`0 0 ${rendered.dimension} ${rendered.dimension}`}
      role="img"
      aria-label="QR-Code zur lokalen Würfelseite"
      shapeRendering="crispEdges"
    >
      <rect width={rendered.dimension} height={rendered.dimension} fill="#ffffff" />
      <path d={rendered.path} fill="#0f172a" />
    </svg>
  );
}

// Eigenständige, schlanke Würfelseite für das Handy (Aufruf per QR / LAN-URL ?dice=...&round=...&board=...).
// Lädt nur das eine Turnier, zeigt nur dieses Brett und nutzt denselben Backend-Endpunkt.
function MobileDicePage({ params }: { params: BoardDiceParams }): React.ReactElement {
  const [tournament, setTournament] = React.useState<Tournament | null>(null);
  const [error, setError] = React.useState<string | null>(null);
  const [loading, setLoading] = React.useState(true);

  const load = React.useCallback(async () => {
    try {
      const data = await requestJson<Tournament>(`/api/tournaments/${params.tournamentId}`);
      setTournament(data);
      setError(null);
    } catch (ex) {
      setError(ex instanceof Error ? ex.message : String(ex));
    } finally {
      setLoading(false);
    }
  }, [params.tournamentId]);

  React.useEffect(() => {
    void load();
  }, [load]);

  const round = tournament?.rounds.find(item => item.roundNumber === params.roundNumber) ?? null;
  const pairing = round?.pairings.find(item => item.boardNumber === params.boardNumber) ?? null;
  const playerName = (id?: string | null): string => tournament?.players.find(player => player.id === id)?.name ?? '—';

  return (
    <div className="mobile-dice">
      <header className="mobile-dice-header">
        <p className="eyebrow">Schachwürfel · Chess960</p>
        <h1>{tournament?.name ?? 'Turnier wird geladen …'}</h1>
        <p className="muted">Runde {params.roundNumber} · Brett {params.boardNumber}</p>
      </header>

      {loading && <p className="muted">Lädt …</p>}
      {error && <p className="board-dice-error">⚠ {error}</p>}

      {!loading && !error && (!round || !pairing) && (
        <p className="board-dice-error">Dieses Brett wurde nicht gefunden. Bitte am Laptop prüfen, ob Runde und Brett existieren.</p>
      )}

      {pairing && round && (
        <>
          <p className="mobile-dice-pairing">
            <strong>{playerName(pairing.whitePlayerId)}</strong> – {pairing.isBye ? 'spielfrei' : <strong>{playerName(pairing.blackPlayerId)}</strong>}
          </p>
          {pairing.isBye ? (
            <p className="board-dice-error">Spielfreies Brett – keine Startstellung nötig.</p>
          ) : round.isLocked || round.isVerified ? (
            <p className="board-dice-error">Runde ist gesperrt/geprüft. Startstellung kann nicht mehr geändert werden.</p>
          ) : (
            <BoardDiceRoller
              tournamentId={params.tournamentId}
              roundNumber={params.roundNumber}
              boardNumber={params.boardNumber}
              currentPosition={pairing.chess960StartPosition ?? null}
              disabled={false}
              onSaved={() => void load()}
            />
          )}
        </>
      )}
      <p className="mobile-dice-foot muted">Funktioniert nur im gleichen WLAN/Hotspot wie der Laptop.</p>
    </div>
  );
}

const mainTabs = [
  { id: 'overview', labelKey: 'nav.overview', secondary: false },
  { id: 'participants', labelKey: 'nav.participants', secondary: false },
  { id: 'rounds', labelKey: 'nav.round', secondary: false },
  { id: 'standings', labelKey: 'nav.standings', secondary: false },
  { id: 'more', labelKey: 'nav.more', secondary: false },
  { id: 'assistant', labelKey: 'more.assistant', secondary: true },
  { id: 'print', labelKey: 'more.exports', secondary: true },
  { id: 'admin', labelKey: 'more.admin', secondary: true }
] as const;

type MainTab = typeof mainTabs[number]['id'];

function isMainTab(value: string | null): value is MainTab {
  return value !== null && mainTabs.some(tab => tab.id === value);
}

function App() {
  const { t, lang } = useI18n();
  const [health, setHealth] = React.useState<Health | null>(null);
  const [pwaStatus, setPwaStatus] = React.useState<PwaStatus>(() => isStandaloneDisplayMode() ? 'installed' : 'checking');
  const [pwaInstallPrompt, setPwaInstallPrompt] = React.useState<BeforeInstallPromptEvent | null>(null);
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
  const [boardDiceModal, setBoardDiceModal] = React.useState<{ roundNumber: number; boardNumber: number } | null>(null);
  const [boardDiceTab, setBoardDiceTab] = React.useState<'browser' | 'qr'>('browser');
  const [laptopIp, setLaptopIp] = React.useState<string>(() => readLocalStorage('stm.laptopIp') ?? defaultLanHost());
  const [diceUrlCopied, setDiceUrlCopied] = React.useState(false);
  const [newTournamentName, setNewTournamentName] = React.useState('Vereinsturnier');
  const [format, setFormat] = React.useState(1);
  const [pairingStrategy, setPairingStrategy] = React.useState(0);
  const [swissInitialColour, setSwissInitialColour] = React.useState(1);
  const [isCreateTournamentOpen, setIsCreateTournamentOpen] = React.useState(false);
  const [demoBusy, setDemoBusy] = React.useState(false);
  const [participantSearch, setParticipantSearch] = React.useState('');
  const [showAdvancedStandings, setShowAdvancedStandings] = React.useState(false);
  const [assistantForm, setAssistantForm] = React.useState<TournamentAssistantForm>(defaultTournamentAssistantForm);
  const assistantRecommendation = React.useMemo(() => buildTournamentAssistantRecommendation(assistantForm), [assistantForm]);
  const [knowledgeChatInput, setKnowledgeChatInput] = React.useState('Wie starte ich ein Turnier?');
  const [knowledgeChatMessages, setKnowledgeChatMessages] = React.useState<KnowledgeChatMessage[]>(() => [{
    id: 'knowledge-welcome',
    role: 'assistant',
    text: 'Ich bin die lokale Turnierhilfe. Frag mich zu Turnierstart, Auslosung, Wertungen, Backup, QR/Handy, Import/Export oder KI-Datenschutz. Ich nutze nur lokale Regeln und sende keine Daten an externe Anbieter.',
    sources: ['Lokale Wissensbasis']
  }]);
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
  const [formatImportResult, setFormatImportResult] = React.useState<{ added: number; errors: string[] } | null>(null);
  const [confirmWarningImport, setConfirmWarningImport] = React.useState(false);
  const [backupJson, setBackupJson] = React.useState('');
  const [pairingEdits, setPairingEdits] = React.useState<Record<string, PairingEdit>>({});
  const [pendingResultChange, setPendingResultChange] = React.useState<{ roundNumber: number; boardNumber: number; result: number; previousResult: number } | null>(null);
  const [lastResultChange, setLastResultChange] = React.useState<{ roundNumber: number; boardNumber: number; previousResult: number } | null>(null);
  const [status, setStatus] = React.useState('Bereit.');
  const [error, setError] = React.useState<string | null>(null);
  const [outdoorMode, setOutdoorMode] = React.useState<boolean>(() => readLocalStorage('stm.outdoorMode') === '1');
  const [theme, setTheme] = React.useState<'dark' | 'light'>(() => readLocalStorage('stm.theme') === 'light' ? 'light' : 'dark');
  const [lastBackupAt, setLastBackupAt] = React.useState<string | null>(null);
  const [backupRecommended, setBackupRecommended] = React.useState<boolean>(false);
  const [activeMainTab, setActiveMainTab] = React.useState<MainTab>(() => {
    const stored = readLocalStorage('stm.activeMainTab');
    return isMainTab(stored) ? stored : 'overview';
  });
  const [activeRoundNumber, setActiveRoundNumber] = React.useState<number | null>(null);
  const selectedTournament = tournaments.find(tournament => tournament.id === selectedId) ?? tournaments[0];
  const auditJournalRecentEntries = auditJournal.slice(0, 15);
  const auditJournalWarningCount = auditJournal.filter(entry => auditSeverityKey(entry.severity) === 'warning').length;
  const auditJournalCriticalCount = auditJournal.filter(entry => auditSeverityKey(entry.severity) === 'critical').length;
  const auditJournalInfoCount = auditJournal.length - auditJournalWarningCount - auditJournalCriticalCount;
  const auditJournalRoundEntryCount = auditJournal.filter(entry => entry.roundNumber !== null && entry.roundNumber !== undefined).length;
  const auditJournalPlayerEntryCount = auditJournal.filter(entry => Boolean(entry.playerId || entry.playerName)).length;
  const visiblePlayers = (selectedTournament?.players ?? []).filter(player => {
    const query = participantSearch.trim().toLocaleLowerCase();
    if (!query) {
      return true;
    }
    return [player.name, player.club, player.fideId, player.nationalId]
      .some(value => value?.toLocaleLowerCase().includes(query));
  });

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
    if (!('serviceWorker' in navigator)) {
      setPwaStatus('unsupported');
      return undefined;
    }

    let isCancelled = false;
    const beforeInstallPrompt = (event: Event) => {
      event.preventDefault();
      setPwaInstallPrompt(event as BeforeInstallPromptEvent);
      setPwaStatus('installable');
    };
    const appInstalled = () => {
      setPwaInstallPrompt(null);
      setPwaStatus('installed');
    };

    window.addEventListener('beforeinstallprompt', beforeInstallPrompt);
    window.addEventListener('appinstalled', appInstalled);

    navigator.serviceWorker.register('/service-worker.js')
      .then(registration => {
        if (isCancelled) {
          return;
        }

        if (registration.waiting) {
          setPwaStatus('update-available');
        } else {
          setPwaStatus(isStandaloneDisplayMode() ? 'installed' : 'ready');
        }

        registration.addEventListener('updatefound', () => {
          const installing = registration.installing;
          installing?.addEventListener('statechange', () => {
            if (installing.state === 'installed' && navigator.serviceWorker.controller) {
              setPwaStatus('update-available');
            }
          });
        });
      })
      .catch((err: unknown) => {
        console.warn('PWA-Serviceworker konnte nicht registriert werden.', err);
        if (!isCancelled) {
          setPwaStatus('error');
        }
      });

    return () => {
      isCancelled = true;
      window.removeEventListener('beforeinstallprompt', beforeInstallPrompt);
      window.removeEventListener('appinstalled', appInstalled);
    };
  }, []);

  React.useEffect(() => {
    if (selectedTournament?.id) {
      loadDerived(selectedTournament.id).catch((err: unknown) => setError(err instanceof Error ? err.message : String(err)));
    }
  }, [loadDerived, selectedTournament?.id]);

  React.useEffect(() => {
    setSettingsForm(settingsToForm(selectedTournament));
  }, [selectedTournament?.id]);

  React.useEffect(() => {
    writeLocalStorage('stm.outdoorMode', outdoorMode ? '1' : '0');
  }, [outdoorMode]);

  React.useEffect(() => {
    writeLocalStorage('stm.theme', theme);
  }, [theme]);

  React.useEffect(() => {
    writeLocalStorage('stm.activeMainTab', activeMainTab);
  }, [activeMainTab]);

  // Hält den aktiven Runden-Unterreiter immer auf eine real existierende Runde.
  // Greift nach Reset/Delete (keine Runden → null) und beim Turnierwechsel.
  React.useEffect(() => {
    const rounds = selectedTournament?.rounds ?? [];
    if (rounds.length === 0) {
      if (activeRoundNumber !== null) {
        setActiveRoundNumber(null);
      }
      return;
    }

    const exists = rounds.some(round => round.roundNumber === activeRoundNumber);
    if (!exists) {
      setActiveRoundNumber(rounds[rounds.length - 1].roundNumber);
    }
  }, [selectedTournament?.id, selectedTournament?.rounds.length, activeRoundNumber]);

  React.useEffect(() => {
    if (!selectedTournament?.id) {
      setLastBackupAt(null);
      setBackupRecommended(false);
      return;
    }
    setLastBackupAt(readLocalStorage(`stm.lastBackup.${selectedTournament.id}`));
    setBackupRecommended(false);
  }, [selectedTournament?.id]);

  React.useEffect(() => {
    setPairingQualityReports({});
    setNextRoundPreview(null);
    setIsNextRoundPreviewDialogOpen(false);
    setChess960DialogRound(null);
  }, [selectedTournament?.id]);

  React.useEffect(() => {
    writeLocalStorage('stm.laptopIp', laptopIp);
  }, [laptopIp]);

  React.useEffect(() => {
    if (!isNextRoundPreviewDialogOpen && !chess960DialogRound && !boardDiceModal) {
      return undefined;
    }

    function closeOnEscape(event: KeyboardEvent): void {
      if (event.key === 'Escape') {
        setIsNextRoundPreviewDialogOpen(false);
        setChess960DialogRound(null);
        setBoardDiceModal(null);
      }
    }

    window.addEventListener('keydown', closeOnEscape);
    return () => window.removeEventListener('keydown', closeOnEscape);
  }, [isNextRoundPreviewDialogOpen, chess960DialogRound, boardDiceModal]);

  async function installPwa(): Promise<void> {
    if (!pwaInstallPrompt) {
      setStatus('Der Browser bietet aktuell keinen Installationsdialog an. Nutze ggf. das Browser-Menü „App installieren“ bzw. „Zum Startbildschirm hinzufügen“.');
      return;
    }

    try {
      await pwaInstallPrompt.prompt();
      const choice = await pwaInstallPrompt.userChoice;
      setPwaInstallPrompt(null);
      setPwaStatus(choice.outcome === 'accepted' ? 'installed' : 'ready');
      setStatus(choice.outcome === 'accepted' ? 'PWA-Installation gestartet.' : 'PWA-Installation abgebrochen.');
    } catch (ex) {
      setError(ex instanceof Error ? ex.message : String(ex));
      setPwaStatus('error');
    }
  }

  async function createTournament(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);
    try {
      const created = await requestJson<Tournament>('/api/tournaments', {
        method: 'POST',
        body: JSON.stringify({
          name: newTournamentName.trim(),
          settings: {
            ...formToSettings(emptySettingsForm),
            format,
            pairingStrategy: format === 1 ? pairingStrategy : 0,
            swissInitialColour: format === 1 && pairingStrategy === 1 ? swissInitialColour : 1
          }
        })
      });
      setSelectedId(created.id);
      setIsCreateTournamentOpen(false);
      setActiveMainTab('overview');
      setStatus(lang === 'en' ? `Tournament created: ${created.name}` : `Turnier angelegt: ${created.name}`);
      await refresh(created.id);
    } catch (ex) {
      setError(`${lang === 'en' ? 'Tournament could not be created' : 'Turnier konnte nicht angelegt werden'}: ${ex instanceof Error ? ex.message : String(ex)}`);
    }
  }

  async function createDemoTournament(): Promise<void> {
    const demoName = 'Build Week Demo Open';
    const existing = tournaments.find(tournament => tournament.name === demoName);
    if (existing) {
      setSelectedId(existing.id);
      setActiveMainTab('overview');
      setStatus(lang === 'en'
        ? 'The existing synthetic demo was opened. It can be reset safely under More → Administration.'
        : 'Das vorhandene synthetische Demo-Turnier wurde geöffnet. Unter Mehr → Verwaltung kann es sicher zurückgesetzt werden.');
      return;
    }

    setDemoBusy(true);
    setError(null);
    setStatus(lang === 'en' ? 'Creating the synthetic demo locally …' : 'Synthetisches Demo-Turnier wird lokal angelegt …');
    let createdDemoId: string | null = null;
    try {
      const created = await requestJson<Tournament>('/api/tournaments', {
        method: 'POST',
        body: JSON.stringify({
          name: demoName,
          settings: {
            ...formToSettings(emptySettingsForm),
            format: 1,
            plannedRounds: 3,
            pairingStrategy: 1,
            swissInitialColour: 1
          }
        })
      });
      createdDemoId = created.id;

      const ratings = [2010, 1930, 1850, 1770, 1690, 1610, 1530, 1450];
      for (const [index, rating] of ratings.entries()) {
        await requestJson<Player>(`/api/tournaments/${created.id}/players`, {
          method: 'POST',
          body: JSON.stringify({
          name: `Demo Player ${String(index + 1).padStart(2, '0')}`,
          club: index % 2 === 0 ? 'Example Knights' : 'Sample Rooks',
          federation: 'SYN',
          country: 'XX',
          birthYear: 1988 + index,
          gender: 0,
          elo: rating,
          rapidElo: null,
          blitzElo: null,
          dwz: null,
          dwzIndex: null,
          manualTwz: null,
          fideId: null,
          nationalId: null,
          title: null,
          status: 0,
          notes: 'Synthetic Build Week demo data',
          startingRank: null
          })
        });
      }

      const firstRound = await requestJson<TournamentRound>(`/api/tournaments/${created.id}/pairings/next-round`, { method: 'POST' });
      const demoResults = [1, 2, 3, 1];
      for (const [index, pairing] of firstRound.pairings.filter(pairing => !pairing.isBye).entries()) {
        await requestJson<TournamentRound>(`/api/tournaments/${created.id}/results`, {
          method: 'POST',
          body: JSON.stringify({
            roundNumber: firstRound.roundNumber,
            boardNumber: pairing.boardNumber,
            result: demoResults[index % demoResults.length]
          })
        });
      }

      setSelectedId(created.id);
      setIsCreateTournamentOpen(false);
      setActiveMainTab('overview');
      await refresh(created.id);
      setStatus(lang === 'en'
        ? 'Demo ready: eight synthetic players, one completed round and FIDE Dutch. The next round is ready to pair.'
        : 'Demo bereit: acht synthetische Spieler, eine abgeschlossene Runde und FIDE-Dutch. Die nächste Runde kann ausgelost werden.');
    } catch (ex) {
      if (createdDemoId) {
        try {
          await requestJson<{ deleted: boolean }>(`/api/tournaments/${createdDemoId}`, { method: 'DELETE' });
        } catch {
          // Keep the original failure visible. A partial demo can still be removed in Administration.
        }
      }
      setError(`${lang === 'en' ? 'The demo could not be created completely' : 'Demo-Turnier konnte nicht vollständig angelegt werden'}: ${ex instanceof Error ? ex.message : String(ex)}`);
    } finally {
      setDemoBusy(false);
    }
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
    const confirmed = window.confirm(
      `Turnier "${target.name}" wirklich auf Start zurücksetzen?\n\n` +
      `• Teilnehmer und Einstellungen BLEIBEN erhalten.\n` +
      `• Alle Runden, Ergebnisse und Chess960-Startstellungen werden GELÖSCHT.\n\n` +
      `Empfehlung: Vorher unten "Jetzt Backup erstellen" nutzen.`
    );
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
    const confirmed = window.confirm(
      `Turnier "${target.name}" wirklich LÖSCHEN?\n\n` +
      `Das gesamte Turnier inkl. Teilnehmer, Runden und Ergebnisse wird endgültig aus der lokalen Datenbank entfernt.\n` +
      `Dies ist NICHT dasselbe wie Zurücksetzen.\n\n` +
      `Empfehlung: Vorher unten "Jetzt Backup erstellen" nutzen.`
    );
    if (!confirmed) {
      return;
    }
    const confirmedName = window.prompt(`Zur Sicherheit den Turniernamen exakt eingeben, um das Löschen zu bestätigen:\n\n${target.name}`);
    if (confirmedName !== target.name) {
      setStatus('Löschen abgebrochen: Turniername wurde nicht exakt bestätigt.');
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
      const created = await requestJson<TournamentRound>(`/api/tournaments/${selectedTournament.id}/pairings/next-round`, { method: 'POST' });
      setStatus('Neue Runde ausgelost. Tipp: Jetzt ein lokales Backup ziehen.');
      setBackupRecommended(true);
      setNextRoundPreview(null);
      setIsNextRoundPreviewDialogOpen(false);
      setActiveRoundNumber(created.roundNumber);
      setActiveMainTab('rounds');
      await refresh(selectedTournament.id);
    } catch (ex) {
      setError(ex instanceof Error ? ex.message : String(ex));
    }
  }

  function openBoardDice(roundNumber: number, boardNumber: number) {
    setBoardDiceModal({ roundNumber, boardNumber });
    setBoardDiceTab('browser');
    setDiceUrlCopied(false);
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
      setBackupRecommended(true);
      setStatus(`Chess960-Startstellungen für Runde ${updated.roundNumber} gewürfelt. Tipp: Jetzt ein lokales Backup ziehen.`);
      await refresh(selectedTournament.id);
    } catch (ex) {
      setError(ex instanceof Error ? ex.message : String(ex));
    } finally {
      setChess960Rolling(false);
    }
  }

  async function recordResult(roundNumber: number, boardNumber: number, result: number): Promise<boolean> {
    if (!selectedTournament) {
      return false;
    }
    setError(null);
    setStatus(`Speichere Ergebnis Runde ${roundNumber}, Brett ${boardNumber} …`);
    try {
      await requestJson<TournamentRound>(`/api/tournaments/${selectedTournament.id}/results`, {
        method: 'POST',
        body: JSON.stringify({ roundNumber, boardNumber, result })
      });
      await refresh(selectedTournament.id);
      setStatus(`✓ Ergebnis gespeichert: Runde ${roundNumber}, Brett ${boardNumber}.`);
      return true;
    } catch (ex) {
      setError(`Ergebnis Runde ${roundNumber}, Brett ${boardNumber} konnte NICHT gespeichert werden: ${ex instanceof Error ? ex.message : String(ex)}`);
      return false;
    }
  }

  function requestResultChange(roundNumber: number, boardNumber: number, result: number, previousResult: number): void {
    if (result === previousResult) {
      return;
    }
    setPendingResultChange({ roundNumber, boardNumber, result, previousResult });
  }

  async function confirmResultChange(): Promise<void> {
    if (!pendingResultChange) {
      return;
    }
    const change = pendingResultChange;
    const saved = await recordResult(change.roundNumber, change.boardNumber, change.result);
    if (saved) {
      setLastResultChange({ roundNumber: change.roundNumber, boardNumber: change.boardNumber, previousResult: change.previousResult });
      setPendingResultChange(null);
    }
  }

  async function undoLastResultChange(): Promise<void> {
    if (!lastResultChange) {
      return;
    }
    const undo = lastResultChange;
    if (await recordResult(undo.roundNumber, undo.boardNumber, undo.previousResult)) {
      setLastResultChange(null);
      setStatus(`Ergebniskorrektur rückgängig gemacht: Runde ${undo.roundNumber}, Brett ${undo.boardNumber}.`);
    }
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

  // STM-IE-002: Datei als Bytes lesen (nicht als Text), damit der Server echte
  // UTF-8-/Windows-1252-Erkennung durchfuehren kann statt einer vom Browser geratenen Dekodierung.
  async function importPlayerFile(file: File, endpoint: string) {
    if (!selectedTournament) {
      return;
    }

    const buffer = await file.arrayBuffer();
    const bytes = new Uint8Array(buffer);
    let binary = '';
    for (let i = 0; i < bytes.length; i++) {
      binary += String.fromCharCode(bytes[i]);
    }
    const base64 = btoa(binary);

    setError(null);
    const outcome = await requestJson<{ added: Player[]; formatErrors: string[] }>(
      `/api/tournaments/${selectedTournament.id}/${endpoint}`,
      { method: 'POST', body: JSON.stringify({ fileBytes: base64, replaceExisting: replacePlayers }) }
    );
    setFormatImportResult({ added: outcome.added.length, errors: outcome.formatErrors });
    setStatus(`${outcome.added.length} Teilnehmer importiert${outcome.formatErrors.length > 0 ? ` · ${outcome.formatErrors.length} Hinweis(e)` : ''}.`);
    await refresh(selectedTournament.id);
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

  function openExportManifest(): void {
    openTournamentExport('exports/manifest.json');
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

    setError(null);
    try {
      const text = await requestText(`/api/tournaments/${selectedTournament.id}/export/json`);
      const pretty = JSON.stringify(JSON.parse(text), null, 2);
      setBackupJson(pretty);
      const now = new Date();
      const roundLabel = latestRoundNumber() === null ? 'start' : `r${latestRoundNumber()}`;
      const fileName = `${safeFileNamepart(selectedTournament.name)}_${roundLabel}_${backupTimestampSlug(now)}.json`;
      downloadText(fileName, pretty, 'application/json;charset=utf-8');
      const iso = now.toISOString();
      setLastBackupAt(iso);
      setBackupRecommended(false);
      writeLocalStorage(`stm.lastBackup.${selectedTournament.id}`, iso);
      setStatus(`✓ Lokales Backup gespeichert: ${fileName}`);
    } catch (ex) {
      setError(`Backup konnte NICHT erstellt werden: ${ex instanceof Error ? ex.message : String(ex)}`);
    }
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

  function resultReviewStatusDisplayLabel(): string {
    const label = resultReviewStatusLabel();
    if (lang !== 'en') {
      return label;
    }
    switch (label) {
      case 'noch keine Runde': return 'no round yet';
      case 'offene Ergebnisse': return 'open results';
      case 'Prüfung offen': return 'review pending';
      case 'Hinweise prüfen': return 'review notices';
      case 'bereit': return 'ready';
      default: return label;
    }
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

  function operatorRoundLabel(): string {
    const planned = selectedTournament?.settings.plannedRounds ?? 0;
    const current = selectedTournament?.rounds.length ?? 0;
    if (!selectedTournament) {
      return '–';
    }
    if (current === 0) {
      return lang === 'en' ? `none yet · ${planned} planned` : `noch keine · geplant ${planned}`;
    }
    return lang === 'en' ? `Round ${current} of ${planned}` : `Runde ${current} von ${planned}`;
  }

  type OperatorStep = {
    tone: 'ok' | 'warn' | 'danger' | 'neutral';
    title: string;
    detail: string;
    actionLabel?: string;
    action?: () => void;
  };

  function nextOperatorStep(): OperatorStep {
    if (!selectedTournament) {
      return {
        tone: 'neutral',
        title: lang === 'en' ? 'Create or select a tournament' : 'Turnier anlegen oder auswählen',
        detail: lang === 'en' ? 'Create a tournament or choose one from the list.' : 'Links ein Turnier anlegen oder aus der Liste wählen.'
      };
    }

    if (activePlayerCount() < 2) {
      return {
        tone: 'warn',
        title: lang === 'en' ? 'Add participants' : 'Teilnehmer erfassen',
        detail: lang === 'en' ? `At least two active players are required (${activePlayerCount()} now).` : `Mindestens zwei aktive Spieler nötig (aktuell ${activePlayerCount()}). Manuell oder per CSV/FIDE-Suche.`
      };
    }

    const rounds = selectedTournament.rounds.length;
    const planned = selectedTournament.settings.plannedRounds;

    if (rounds === 0) {
      return {
        tone: 'ok',
        title: t('rounds.firstTitle'),
        detail: lang === 'en' ? 'Review the preview, then create the pairings.' : 'Vorschau ansehen, prüfen, dann auslosen.',
        actionLabel: t('rounds.preview'),
        action: () => void previewNextRound()
      };
    }

    const openResults = totalOpenBoardCount();
    if (openResults > 0) {
      return {
        tone: 'danger',
        title: lang === 'en' ? `Enter results (${openResults} open)` : `Ergebnisse eintragen (${openResults} offen)`,
        detail: lang === 'en' ? `Round ${latestRoundNumber()} is active. Complete every board before pairing the next round.` : `Runde ${latestRoundNumber()} läuft. Erst wenn alle Bretter ein Ergebnis haben, lässt sich die nächste Runde auslosen.`,
        actionLabel: lang === 'en' ? 'Print round sheet' : 'Rundenblatt drucken',
        action: () => openLatestRoundPrint()
      };
    }

    if (rounds >= planned) {
      return {
        tone: 'ok',
        title: lang === 'en' ? 'Review final standings' : 'Abschluss / Tabelle prüfen',
        detail: lang === 'en' ? `All ${planned} planned rounds are complete. Review, print and back up the final standings.` : `Alle ${planned} geplanten Runden sind gespielt. Finale Tabelle prüfen, drucken und Abschluss-Backup ziehen.`,
        actionLabel: lang === 'en' ? 'Tournament print view' : 'Turnier-Druckansicht',
        action: () => openTournamentExport('print/html')
      };
    }

    const unverified = pairingReadinessUnverifiedRoundCount();
    const detail = unverified > 0
      ? (lang === 'en' ? `All results are entered. ${unverified} complete round(s) are not marked reviewed.` : `Alle Ergebnisse eingetragen. ${unverified} vollständige Runde(n) noch nicht als geprüft markiert.`)
      : (lang === 'en' ? 'All results are entered. Review the preview, then pair the next round.' : 'Alle Ergebnisse eingetragen. Vorschau ansehen, prüfen, dann auslosen.');
    return {
      tone: unverified > 0 ? 'warn' : 'ok',
      title: lang === 'en' ? `Preview / pair round ${rounds + 1}` : `Vorschau erzeugen / Runde ${rounds + 1} auslosen`,
      detail,
      actionLabel: t('rounds.preview'),
      action: () => void previewNextRound()
    };
  }
  function applyAssistantRecommendation(): void {
    setFormat(assistantRecommendation.format);
    setSettingsForm({
      ...settingsForm,
      format: assistantRecommendation.format,
      scoringSystem: assistantRecommendation.scoringSystem,
      plannedRounds: assistantRecommendation.plannedRounds.toString(),
      tiebreaks: assistantRecommendation.format === 0 ? [4, 0, 1, 99] : defaultTiebreaks
    });
    setNewTournamentName(`${assistantScenarioOptions.find(option => option.value === assistantForm.scenario)?.label ?? 'Turnier'} ${new Date().getFullYear()}`);
    setStatus('Assistenten-Empfehlung in Neuanlage und Einstellungen übernommen. Bei bestehendem Turnier bitte Einstellungen speichern.');
    setActiveMainTab('admin');
  }


  function askKnowledgeChat(questionOverride?: string): void {
    const question = (questionOverride ?? knowledgeChatInput).trim();
    if (!question) {
      setError('Bitte eine Frage für die lokale Turnierhilfe eingeben.');
      return;
    }

    const userMessage: KnowledgeChatMessage = {
      id: `user-${Date.now()}-${Math.random().toString(36).slice(2)}`,
      role: 'user',
      text: question,
      sources: []
    };
    const answer = buildLocalKnowledgeAnswer(question, selectedTournament, assistantRecommendation);
    setKnowledgeChatMessages(previous => [...previous, userMessage, answer]);
    setKnowledgeChatInput('');
    setStatus('Lokale Turnierhilfe hat geantwortet. Keine externen KI-Dienste verwendet.');
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
    <main className={`shell theme-${theme}${outdoorMode ? ' outdoor' : ''}`}>
      <header className="hero">
        <div>
          <p className="eyebrow">{t('hero.eyebrow')}{health?.version ? ` · v${health.version}` : ''}</p>
          <h1>{t('app.title')}</h1>
          <p>{t('hero.subtitle')}</p>
        </div>
        <div className="status-card">
          <strong>{t('backend.title')}</strong>
          {health && <span className="ok">{health.app} {health.version}: {health.status}</span>}
          {!health && !error && <span>{t('backend.checking')}</span>}
          {health?.database && <small>Lokale Datenbank: {health.database}</small>}
          <LanguageSwitcher />
          <button type="button" className="small secondary theme-toggle" onClick={() => setTheme(previous => previous === 'dark' ? 'light' : 'dark')} aria-pressed={theme === 'light'}>
            {theme === 'dark' ? t('theme.light') : t('theme.dark')}
          </button>
          <div className={`pwa-status ${pwaStatus}`}>
            <span>{pwaStatusLabel(pwaStatus)}</span>
            {pwaInstallPrompt && <button type="button" className="small secondary" onClick={() => void installPwa()}>Installieren</button>}
          </div>
        </div>
      </header>

      <section className="status-line">
        <span>{status}</span>
        {error && <strong className="error">{error}</strong>}
      </section>

      {selectedTournament && (() => {
        const step = nextOperatorStep();
        return (
          <section className="operator-bar" aria-label="Operator-Status">
            <div className="operator-chips">
              <div className="operator-chip">
                <span className="operator-chip-label">{t('operator.round')}</span>
                <strong>{operatorRoundLabel()}</strong>
              </div>
              <div className={`operator-chip ${totalOpenBoardCount() > 0 ? 'danger' : 'ok'}`}>
                <span className="operator-chip-label">{t('operator.openResults')}</span>
                <strong>{totalOpenBoardCount()}</strong>
                {selectedTournament && <small>{activePlayerCount()} {t('operator.active')} · {inactivePlayerCount()} {t('operator.inactive')}</small>}
              </div>
              <div className={`operator-chip ${backupRecommended ? 'danger' : lastBackupAt ? 'ok' : ''}`}>
                <span className="operator-chip-label">{t('operator.lastBackup')}</span>
                <strong>{backupRecommended ? t('operator.backupRecommended') : lastBackupAt ? t('operator.backupCurrent') : t('operator.backupNone')}</strong>
                <small>{backupTimeLabel(lastBackupAt)}</small>
              </div>
            </div>
            <div className={`operator-next tone-${step.tone}`}>
              <div>
                <span className="operator-next-eyebrow">{t('operator.nextStep')}</span>
                <strong>{step.title}</strong>
                <p>{step.detail}</p>
              </div>
              {step.action && step.actionLabel && (
                <button type="button" onClick={step.action}>{step.actionLabel}</button>
              )}
            </div>
            <div className="operator-tools">
              <button
                type="button"
                className={outdoorMode ? '' : 'secondary'}
                aria-pressed={outdoorMode}
                onClick={() => setOutdoorMode(previous => !previous)}
                title="Größere Schrift, größere Buttons und höherer Kontrast für den Einsatz draußen. Wird lokal gespeichert."
              >
                {outdoorMode ? '☀ Turniertag-Modus AN' : '☀ Turniertag-Modus AUS'}
              </button>
              <button
                type="button"
                className={backupRecommended ? '' : 'secondary'}
                onClick={() => void exportTournamentJson()}
                disabled={!selectedTournament}
                title="Lädt einen lokalen JSON-Snapshot mit Turniername, Runde und Zeitstempel herunter. Keine Cloud."
              >
                💾 Jetzt Backup erstellen
              </button>
            </div>
          </section>
        );
      })()}

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

      {boardDiceModal && selectedTournament && (() => {
        const round = selectedTournament.rounds.find(item => item.roundNumber === boardDiceModal.roundNumber);
        const pairing = round?.pairings.find(item => item.boardNumber === boardDiceModal.boardNumber);
        if (!round || !pairing) {
          return null;
        }
        const roundClosed = round.isLocked || round.isVerified;
        const port = window.location.port ? `:${window.location.port}` : '';
        const host = laptopIp.trim() || window.location.hostname;
        const diceUrl = `http://${host}${port}/?dice=${selectedTournament.id}&round=${round.roundNumber}&board=${pairing.boardNumber}`;
        const hostIsLocal = host === 'localhost' || host === '127.0.0.1' || host === '::1';
        return (
          <div className="modal-backdrop" role="dialog" aria-modal="true" aria-label={`Würfeln Brett ${pairing.boardNumber}`} onClick={() => setBoardDiceModal(null)}>
            <article className="card chess960-modal board-dice-modal" onClick={(event: React.MouseEvent) => event.stopPropagation()}>
              <div className="preview-card-header">
                <div>
                  <p className="eyebrow">Schachwürfel · Chess960 · Einzelbrett</p>
                  <h3>{selectedTournament.name}</h3>
                  <p className="muted">Runde {round.roundNumber} · Brett {pairing.boardNumber}</p>
                  <p className="board-dice-pairing"><strong>{playerNameById(pairing.whitePlayerId)}</strong> – {pairing.isBye ? 'spielfrei' : <strong>{playerNameById(pairing.blackPlayerId)}</strong>}</p>
                </div>
                <button type="button" className="secondary" onClick={() => setBoardDiceModal(null)}>Schließen</button>
              </div>

              {pairing.chess960StartPosition
                ? <p className="board-dice-warning">⚠ Bereits gespeichert: {pairing.chess960StartPosition.whiteBackRank} · SP {pairing.chess960StartPosition.positionNumber}. Neu würfeln überschreibt diese Stellung nach Rückfrage.</p>
                : <p className="muted">Für dieses Brett ist noch keine Startstellung gespeichert.</p>}

              <div className="tab-bar board-dice-tabs">
                <button type="button" className={`tab-button${boardDiceTab === 'browser' ? ' active' : ''}`} onClick={() => setBoardDiceTab('browser')}>Browser würfeln</button>
                <button type="button" className={`tab-button${boardDiceTab === 'qr' ? ' active' : ''}`} onClick={() => setBoardDiceTab('qr')}>QR / Handy</button>
              </div>

              {boardDiceTab === 'browser' && (
                roundClosed
                  ? <p className="board-dice-error">Runde ist gesperrt/geprüft – keine Änderung der Startstellung möglich.</p>
                  : <BoardDiceRoller
                      tournamentId={selectedTournament.id}
                      roundNumber={round.roundNumber}
                      boardNumber={pairing.boardNumber}
                      currentPosition={pairing.chess960StartPosition ?? null}
                      disabled={roundClosed}
                      onSaved={() => { setBackupRecommended(true); void refresh(selectedTournament.id); }}
                    />
              )}

              {boardDiceTab === 'qr' && (
                <div className="qr-tab">
                  <p className="muted">Teilnehmer/Schiedsrichter können dieses Brett am Handy auswürfeln. Funktioniert nur im gleichen WLAN/Hotspot wie der Laptop.</p>
                  <div className="qr-tab-grid">
                    <div className="qr-tab-code"><QrPanel url={diceUrl} /></div>
                    <div className="qr-tab-info">
                      <label className="qr-ip-label">
                        Laptop-IP im WLAN/Hotspot
                        <input
                          type="text"
                          value={laptopIp}
                          placeholder="z. B. 192.168.0.42"
                          onChange={(event: React.ChangeEvent<HTMLInputElement>) => { setLaptopIp(event.target.value); setDiceUrlCopied(false); }}
                        />
                      </label>
                      {hostIsLocal && <p className="board-dice-warning">⚠ Aktuell zeigt die URL auf „{host}". Auf dem Handy zeigt <code>localhost</code> auf das Handy selbst. Bitte die LAN-IP des Laptops eintragen (Windows: <code>ipconfig</code> → IPv4-Adresse).</p>}
                      <div className="qr-url-row">
                        <code className="qr-url">{diceUrl}</code>
                        <button
                          type="button"
                          className="small"
                          onClick={() => {
                            void navigator.clipboard?.writeText(diceUrl).then(() => setDiceUrlCopied(true)).catch(() => setDiceUrlCopied(false));
                          }}
                        >{diceUrlCopied ? '✓ Kopiert' : 'URL kopieren'}</button>
                      </div>
                      <ul className="qr-hints muted">
                        <li>Handy und Laptop im selben WLAN/Hotspot.</li>
                        <li>Eine evtl. Windows-Firewall kann den Zugriff auf Port {window.location.port || '5173'} blockieren – dann am Laptop würfeln.</li>
                        <li>Gleichzeitiges Würfeln (Laptop + Handy) überschreibt nur nach Rückfrage; die zuletzt gespeicherte Stellung gilt.</li>
                      </ul>
                    </div>
                  </div>
                </div>
              )}
            </article>
          </div>
        );
      })()}

      <section className="layout">
        <aside className="panel">
          <h2>{t('tournaments.title')}</h2>
          <div className="tournament-start-actions">
            <button type="button" onClick={() => setIsCreateTournamentOpen(previous => !previous)} aria-expanded={isCreateTournamentOpen}>
              {isCreateTournamentOpen ? t('tournaments.closeCreate') : t('tournaments.create')}
            </button>
            <button type="button" className="secondary" onClick={() => void createDemoTournament()} disabled={demoBusy}>
              {demoBusy ? t('tournaments.demoPreparing') : t('tournaments.openDemo')}
            </button>
          </div>
          {isCreateTournamentOpen && (
            <form onSubmit={(event) => void createTournament(event)} className="stack create-tournament-form">
              <label>{t('tournaments.name')}
                <input value={newTournamentName} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setNewTournamentName(event.target.value)} placeholder={t('tournaments.namePlaceholder')} required />
              </label>
              <label>{t('tournaments.format')}
                <select value={format} onChange={(event: React.ChangeEvent<HTMLSelectElement>) => setFormat(Number(event.target.value))}>
                  {formatOptions.map(option => <option key={option.value} value={option.value}>{lang === 'en' ? (option.value === 1 ? 'Swiss system' : 'Round robin') : option.label}</option>)}
                </select>
              </label>
              {format === 1 && (
                <details className="advanced-settings">
                  <summary>{t('tournaments.advancedPairing')}</summary>
                  <label>{t('tournaments.pairing')}
                    <select value={pairingStrategy} onChange={(event: React.ChangeEvent<HTMLSelectElement>) => setPairingStrategy(Number(event.target.value))}>
                      {pairingStrategyOptions.map(option => <option key={option.value} value={option.value}>{lang === 'en' && option.value === 0 ? 'Optimal V2 (recommended)' : option.label}</option>)}
                    </select>
                  </label>
                  <p className="muted">Optimal V2 bleibt der bewährte Standard. FIDE Dutch nutzt die implementierten Dutch-Kriterien und erzeugt einen detaillierten Audit-Hinweis; dies ist keine FIDE-Zertifizierung.</p>
                  {pairingStrategy === 1 && (
                    <label>{t('tournaments.initialColour')}
                      <select value={swissInitialColour} onChange={(event: React.ChangeEvent<HTMLSelectElement>) => setSwissInitialColour(Number(event.target.value))}>
                        {swissInitialColourOptions.map(option => <option key={option.value} value={option.value}>{lang === 'en' ? (option.value === 1 ? 'White' : 'Black') : option.label}</option>)}
                      </select>
                    </label>
                  )}
                </details>
              )}
              <div className="create-summary" aria-live="polite">
                <strong>{t('tournaments.summary')}</strong>
                <span>{newTournamentName.trim() || (lang === 'en' ? 'Untitled' : 'Unbenannt')} · {lang === 'en' ? (format === 1 ? 'Swiss system' : 'Round robin') : formatOptions.find(option => option.value === format)?.label}</span>
                {format === 1 && <span>{lang === 'en' && pairingStrategy === 0 ? 'Optimal V2 (recommended)' : pairingStrategyOptions.find(option => option.value === pairingStrategy)?.label}</span>}
              </div>
              <button type="submit" disabled={!newTournamentName.trim()}>{t('tournaments.createNow')}</button>
            </form>
          )}
          <div className="list">
            {tournaments.length === 0 && <p className="muted">{t('tournaments.none')}</p>}
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
              <h2>{selectedTournament?.name ?? t('tournaments.noSelection')}</h2>
              <p>{selectedTournament ? `${selectedTournament.players.length} Teilnehmer · ${selectedTournament.rounds.length} Runden` : 'Lege zuerst ein Turnier an.'}</p>
            </div>
            {activeMainTab === 'rounds' && <div className="actions">
              <button type="button" className="secondary" onClick={() => void previewNextRound()} disabled={!pairingReadinessCanCreatePreview()}>{t('rounds.preview')}</button>
              <button type="button" onClick={() => void generateRound()} disabled={!pairingReadinessCanGenerateRound()}>{t('rounds.pairNext')}</button>
            </div>}
          </div>

          <nav className="tab-bar" role="tablist" aria-label="Turnierbereiche">
            {mainTabs.filter(tab => !tab.secondary).map(tab => (
              <button
                key={tab.id}
                type="button"
                role="tab"
                aria-selected={activeMainTab === tab.id || (tab.id === 'more' && ['assistant', 'print', 'admin'].includes(activeMainTab))}
                className={`tab-button${activeMainTab === tab.id || (tab.id === 'more' && ['assistant', 'print', 'admin'].includes(activeMainTab)) ? ' active' : ''}`}
                onClick={() => setActiveMainTab(tab.id)}
              >
                {t(tab.labelKey)}
              </button>
            ))}
          </nav>

          {activeMainTab === 'overview' && (
            <article className="card overview-card">
              <h3>{t('overview.title')}</h3>
              {!selectedTournament && (
                <div className="empty-state">
                  <p className="eyebrow">{t('overview.readyEyebrow')}</p>
                  <h4>{t('overview.readyTitle')}</h4>
                  <p>{t('overview.readyText')}</p>
                  <div className="actions">
                    <button type="button" onClick={() => setIsCreateTournamentOpen(true)}>{t('tournaments.create')}</button>
                    <button type="button" className="secondary" onClick={() => void createDemoTournament()} disabled={demoBusy}>{demoBusy ? t('tournaments.demoPreparing') : t('tournaments.openDemo')}</button>
                  </div>
                  <small>{t('overview.demoPrivacy')}</small>
                </div>
              )}
              {selectedTournament && (
                <>
                  <div className="overview-grid">
                    <div><span>{t('operator.tournament')}</span><strong>{selectedTournament.name}</strong></div>
                    <div><span>{t('tournaments.format')}</span><strong>{lang === 'en' ? (selectedTournament.settings.format === 1 ? 'Swiss system' : 'Round robin') : formatOptions.find(option => option.value === selectedTournament.settings.format)?.label ?? '–'}</strong></div>
                    {selectedTournament.settings.format === 1 && <div><span>{t('tournaments.pairing')}</span><strong>{lang === 'en' && (selectedTournament.settings.pairingStrategy ?? 0) === 0 ? 'Optimal V2 (recommended)' : pairingStrategyOptions.find(option => option.value === (selectedTournament.settings.pairingStrategy ?? 0))?.label ?? 'Optimal V2'}</strong></div>}
                    <div><span>{t('operator.round')}</span><strong>{operatorRoundLabel()}</strong></div>
                    <div><span>{t('rounds.status')}</span><strong>{resultReviewStatusDisplayLabel()}</strong></div>
                    <div><span>{t('operator.openResults')}</span><strong>{totalOpenBoardCount()}</strong></div>
                    <div><span>{t('nav.participants')}</span><strong>{activePlayerCount()} {t('operator.active')} · {inactivePlayerCount()} {t('operator.inactive')}</strong></div>
                    <div><span>{t('backend.title')}</span><strong>{health ? `${t('backend.online')} · ${health.version}` : t('backend.offline')}</strong></div>
                    <div><span>{t('operator.lastBackup')}</span><strong>{backupRecommended ? t('operator.backupRecommended') : lastBackupAt ? t('operator.backupCurrent') : t('operator.backupNone')}</strong><small>{backupTimeLabel(lastBackupAt)}</small></div>
                  </div>
                  {(() => {
                    const step = nextOperatorStep();
                    return (
                      <div className={`overview-next tone-${step.tone}`}>
                        <div>
                          <span className="operator-next-eyebrow">{t('operator.nextStep')}</span>
                          <strong>{step.title}</strong>
                          <p>{step.detail}</p>
                        </div>
                        {step.action && step.actionLabel && (
                          <button type="button" onClick={step.action}>{step.actionLabel}</button>
                        )}
                      </div>
                    );
                  })()}
                  <details className="operator-checklist">
                    <summary>✅ Vor-Ort-Checkliste &amp; Laptop-Hinweise</summary>
                    <div className="operator-checklist-body">
                      <ul>
                        <li>Backend grün (Chip „Backend“ oben muss <strong>online</strong> sein)</li>
                        <li>Backup ziehen, bevor Runde 1 ausgelost wird</li>
                        <li>Teilnehmerliste prüfen (Anzahl, Namen, FIDE-ID)</li>
                        <li>Wasser / Schatten / Sonnenschutz bereitstellen</li>
                        <li>Rundenblatt der aktuellen Runde drucken</li>
                        <li>Chess960 würfeln (falls Chess960-Turnier)</li>
                        <li>Ergebnisse nach jeder Runde sofort eintragen und Speicher-Bestätigung abwarten</li>
                        <li>Backup nach jeder Runde ziehen</li>
                      </ul>
                      <p className="operator-power-note">
                        <strong>Strom &amp; Energie:</strong> Laptop am Netzteil betreiben · Energiesparen und Bildschirmsperre vermeiden ·
                        Browser-Tab offen lassen · das Backend-Fenster NICHT schließen.
                      </p>
                    </div>
                  </details>
                </>
              )}
            </article>
          )}

          {activeMainTab === 'more' && (
            <article className="card more-card">
              <p className="eyebrow">{t('more.eyebrow')}</p>
              <h3>{t('more.title')}</h3>
              <p className="muted">{t('more.intro')}</p>
              <div className="more-grid">
                <button type="button" className="more-link" onClick={() => setActiveMainTab('assistant')}>
                  <strong>{t('more.assistant')}</strong><span>{t('more.assistantDetail')}</span>
                </button>
                <button type="button" className="more-link" onClick={() => setActiveMainTab('print')}>
                  <strong>{t('more.exports')}</strong><span>{t('more.exportsDetail')}</span>
                </button>
                <button type="button" className="more-link" onClick={() => setActiveMainTab('admin')}>
                  <strong>{t('more.admin')}</strong><span>{t('more.adminDetail')}</span>
                </button>
              </div>
              <div className="privacy-note">{t('more.privacy')}</div>
            </article>
          )}

          {activeMainTab === 'assistant' && (
            <article className="card assistant-card">
              <div className="assistant-header">
                <div>
                  <p className="eyebrow">Turnierassistent · lokal &amp; ohne KI-API</p>
                  <h3>Welches Format passt?</h3>
                  <p className="muted">Der Assistent empfiehlt auf Basis von Teilnehmerzahl, Zeit, Brettern und Szenario eine robuste Turnier-Konfiguration. Er sendet keine Daten an externe Dienste.</p>
                </div>
                <div className={`assistant-fit ${assistantRecommendation.timeFit}`}>
                  <strong>{assistantRecommendation.timeFitLabel}</strong>
                  <span>{assistantRecommendation.estimatedTotalMinutes} Min. geschätzt</span>
                </div>
              </div>
              <div className="assistant-grid">
                <section className="assistant-form">
                  <label>Szenario
                    <select value={assistantForm.scenario} onChange={(event: React.ChangeEvent<HTMLSelectElement>) => setAssistantForm({ ...assistantForm, scenario: event.target.value as TournamentAssistantScenario })}>
                      {assistantScenarioOptions.map(option => <option key={option.value} value={option.value}>{option.label}</option>)}
                    </select>
                  </label>
                  <p className="muted">{assistantScenarioOptions.find(option => option.value === assistantForm.scenario)?.description}</p>
                  <div className="settings-grid compact">
                    <label>Teilnehmer
                      <input type="number" min="2" max="512" value={assistantForm.playerCount} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setAssistantForm({ ...assistantForm, playerCount: event.target.value })} />
                    </label>
                    <label>Zeit in Minuten
                      <input type="number" min="30" max="1440" value={assistantForm.availableMinutes} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setAssistantForm({ ...assistantForm, availableMinutes: event.target.value })} />
                    </label>
                    <label>Bretter
                      <input type="number" min="1" max="256" value={assistantForm.boardCount} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setAssistantForm({ ...assistantForm, boardCount: event.target.value })} />
                    </label>
                  </div>
                  <div className="checkbox-row">
                    <label className="checkbox"><input type="checkbox" checked={assistantForm.rated} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setAssistantForm({ ...assistantForm, rated: event.target.checked })} /> gewertetes Turnier geplant</label>
                    <label className="checkbox"><input type="checkbox" checked={assistantForm.chess960} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setAssistantForm({ ...assistantForm, chess960: event.target.checked })} /> Chess960/Freestyle</label>
                    <label className="checkbox"><input type="checkbox" checked={assistantForm.needsQr} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setAssistantForm({ ...assistantForm, needsQr: event.target.checked })} /> QR/Handy am Brett nutzen</label>
                  </div>
                  <div className="actions">
                    <button type="button" onClick={applyAssistantRecommendation}>Empfehlung übernehmen</button>
                    <button type="button" className="secondary" onClick={() => downloadText(`turnierassistent-${backupTimestampSlug(new Date())}.txt`, assistantRecommendation.handoffPrompt, 'text/plain;charset=utf-8')}>Prompt/Plan exportieren</button>
                  </div>
                </section>
                <section className="assistant-result">
                  <h4>{assistantRecommendation.title}</h4>
                  <div className="overview-grid assistant-metrics">
                    <div><span>Format</span><strong>{assistantRecommendation.formatLabel}</strong></div>
                    <div><span>Runden</span><strong>{assistantRecommendation.plannedRounds}</strong></div>
                    <div><span>Bretter</span><strong>{assistantRecommendation.estimatedBoards}</strong></div>
                    <div><span>Punkte</span><strong>{assistantRecommendation.scoringLabel}</strong></div>
                  </div>
                  {assistantRecommendation.warnings.length > 0 && (
                    <div className="assistant-warning">
                      <strong>Prüfen</strong>
                      <ul>{assistantRecommendation.warnings.map((warning, index) => <li key={`assistant-warning-${index}`}>{warning}</li>)}</ul>
                    </div>
                  )}
                  <div className="assistant-columns">
                    <section>
                      <strong>Setup-Schritte</strong>
                      <ol>{assistantRecommendation.setupSteps.map((step, index) => <li key={`assistant-step-${index}`}>{step}</li>)}</ol>
                    </section>
                    <section>
                      <strong>Turniertag-Check</strong>
                      <ul>{assistantRecommendation.operatorChecklist.map((item, index) => <li key={`assistant-check-${index}`}>{item}</li>)}</ul>
                    </section>
                    <section>
                      <strong>Export/Veröffentlichung</strong>
                      <ul>{assistantRecommendation.exportPlan.map((item, index) => <li key={`assistant-export-${index}`}>{item}</li>)}</ul>
                    </section>
                  </div>
                  <details className="audit-box assistant-handoff">
                    <summary>Handoff-Prompt anzeigen</summary>
                    <p>{assistantRecommendation.handoffPrompt}</p>
                  </details>
                </section>
              </div>
              <section className="knowledge-chat-card">
                <div className="assistant-header compact-header">
                  <div>
                    <p className="eyebrow">Lokale Chat-Hilfe · RUN-10/11 Fundament</p>
                    <h4>Frag die Turnierhilfe</h4>
                    <p className="muted">Regelbasierte Wissensbasis für Bedienung, Pairing, Wertung, Backup und Datenschutz. Keine Provider-Anbindung, keine externen Requests, keine Secrets.</p>
                    <small className="knowledge-source-meta">Wissensbasis {localKnowledgeBase.sourceVersion} · Stand {localKnowledgeBase.sourceUpdated}</small>
                  </div>
                  <span className="knowledge-privacy-pill" title={localKnowledgeBase.privacyNotice}>offline/lokal</span>
                </div>
                <div className="knowledge-quick-actions">
                  {knowledgeQuickQuestions.map(question => (
                    <button key={question} type="button" className="small secondary" onClick={() => askKnowledgeChat(question)}>{question}</button>
                  ))}
                </div>
                <div className="knowledge-chat-log" aria-live="polite">
                  {knowledgeChatMessages.map(message => (
                    <article key={message.id} className={`knowledge-message ${message.role}`}>
                      <strong>{message.role === 'user' ? 'Du' : 'Turnierhilfe'}</strong>
                      {message.text.split('\n').map((line, index) => line ? <p key={`${message.id}-${index}`}>{line}</p> : <br key={`${message.id}-${index}`} />)}
                      {message.sources.length > 0 && <small>Quellen: {message.sources.join(' · ')}</small>}
                    </article>
                  ))}
                </div>
                <div className="knowledge-chat-input">
                  <input
                    type="text"
                    value={knowledgeChatInput}
                    onChange={(event: React.ChangeEvent<HTMLInputElement>) => setKnowledgeChatInput(event.target.value)}
                    onKeyDown={(event: React.KeyboardEvent<HTMLInputElement>) => {
                      if (event.key === 'Enter') {
                        event.preventDefault();
                        askKnowledgeChat();
                      }
                    }}
                    placeholder="Frage stellen, z.B. Was muss ich nach Runde 3 tun?"
                  />
                  <button type="button" onClick={() => askKnowledgeChat()} disabled={!knowledgeChatInput.trim()}>Antwort</button>
                  <button type="button" className="secondary" onClick={() => downloadText(`lokale-turnierhilfe-${backupTimestampSlug(new Date())}.txt`, knowledgeChatMessages.map(message => `${message.role === 'user' ? 'Du' : 'Turnierhilfe'}:\n${message.text}`).join('\n\n---\n\n'), 'text/plain;charset=utf-8')}>Chat exportieren</button>
                </div>
              </section>
            </article>
          )}

          {activeMainTab === 'rounds' && pendingResultChange && (
            <article className="card result-confirm" role="alertdialog" aria-labelledby="result-confirm-title">
              <div>
                <p className="eyebrow">{t('result.confirmEyebrow')}</p>
                <h3 id="result-confirm-title">{t('result.confirmTitle')}</h3>
                <p>{t('rounds.round')} {pendingResultChange.roundNumber}, {t('rounds.board')} {pendingResultChange.boardNumber}: <strong>{resultLabel(pendingResultChange.previousResult, lang === 'en')}</strong> → <strong>{resultLabel(pendingResultChange.result, lang === 'en')}</strong></p>
              </div>
              <div className="actions">
                <button type="button" className="secondary" onClick={() => setPendingResultChange(null)}>{t('common.cancel')}</button>
                <button type="button" onClick={() => void confirmResultChange()}>{t('result.save')}</button>
              </div>
            </article>
          )}
          {activeMainTab === 'rounds' && !pendingResultChange && lastResultChange && (
            <div className="undo-bar" role="status">
              <span>Ergebnis gespeichert: Runde {lastResultChange.roundNumber}, Brett {lastResultChange.boardNumber}.</span>
              <button type="button" className="small secondary" onClick={() => void undoLastResultChange()}>{t('result.undo')}</button>
            </div>
          )}

          {activeMainTab === 'rounds' && nextRoundPreview && (
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
          {activeMainTab === 'admin' && (
            <article className="card admin-danger-card">
              <h3>Gefährliche Aktionen</h3>
              <p className="muted">Zurücksetzen behält Teilnehmer und Einstellungen, löscht aber alle Runden, Ergebnisse und Chess960-Startstellungen. Löschen entfernt das gesamte Turnier und verlangt die exakte Eingabe des Turniernamens.</p>
              <div className="actions">
                <button type="button" className="secondary" onClick={() => void resetSelectedTournament()} disabled={!selectedTournament}>Turnier zurücksetzen</button>
                <button type="button" className="danger" onClick={() => void deleteSelectedTournament()} disabled={!selectedTournament}>Turnier löschen</button>
              </div>
            </article>
          )}
          {activeMainTab === 'admin' && (
          <article className="card settings-card">
            <h3>Turniereinstellungen</h3>
            <form onSubmit={(event) => void saveSettings(event)} className="settings-form">
              <div className="settings-grid">
                <label>Format
                  <select value={settingsForm.format} onChange={(event: React.ChangeEvent<HTMLSelectElement>) => setSettingsForm({ ...settingsForm, format: Number(event.target.value) })} disabled={(selectedTournament?.rounds.length ?? 0) > 0}>
                    {formatOptions.map(option => <option key={option.value} value={option.value}>{option.label}</option>)}
                  </select>
                </label>
                {settingsForm.format === 1 && <label>Paarungsverfahren
                  <select value={settingsForm.pairingStrategy} onChange={(event: React.ChangeEvent<HTMLSelectElement>) => setSettingsForm({ ...settingsForm, pairingStrategy: Number(event.target.value) })} disabled={(selectedTournament?.rounds.length ?? 0) > 0}>
                    {pairingStrategyOptions.map(option => <option key={option.value} value={option.value}>{option.label}</option>)}
                  </select>
                  <small className="field-help">Optimal V2 bleibt Standard. Die Wahl gilt ab Runde 1 und ändert bestehende Turniere nicht still.</small>
                </label>}
                {settingsForm.format === 1 && settingsForm.pairingStrategy === 1 && <label>Anfangsfarbe
                  <select value={settingsForm.swissInitialColour} onChange={(event: React.ChangeEvent<HTMLSelectElement>) => setSettingsForm({ ...settingsForm, swissInitialColour: Number(event.target.value) })} disabled={(selectedTournament?.rounds.length ?? 0) > 0}>
                    {swissInitialColourOptions.map(option => <option key={option.value} value={option.value}>{option.label}</option>)}
                  </select>
                  <small className="field-help">Wird nur bei FIDE Dutch verwendet, wenn beide Spieler die gleiche Farberwartung haben.</small>
                </label>}
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
                <label>Ungespielte Runden (Buchholz)
                  <select value={settingsForm.unplayedRoundBuchholzMode} onChange={(event: React.ChangeEvent<HTMLSelectElement>) => setSettingsForm({ ...settingsForm, unplayedRoundBuchholzMode: Number(event.target.value) })}>
                    {unplayedRoundBuchholzOptions.map(option => <option key={option.value} value={option.value}>{option.label}</option>)}
                  </select>
                </label>
                <label>Senioren: Geburtsjahr oder älter
                  <input type="number" min="1900" max="2100" value={settingsForm.seniorBirthYearOrEarlier} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setSettingsForm({ ...settingsForm, seniorBirthYearOrEarlier: event.target.value })} placeholder="z. B. 1966" />
                </label>
                <label>Heldenpokal: Mindestpartien
                  <input type="number" min="1" max="99" value={settingsForm.heroCupMinimumRatedGames} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setSettingsForm({ ...settingsForm, heroCupMinimumRatedGames: event.target.value })} />
                </label>
              </div>
              <p className="muted">Im FIDE-Modus gilt die Einstellung „Kampflose Partien“ zuerst: Zählt sie den realen Gegner für Buchholz, wird kein zusätzlicher Dummy erzeugt. Offene Ergebnisse werden nicht vorzeitig gewertet.</p>
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
          )}

          {activeMainTab === 'participants' && (
          <div className="grid two">
            <article className="card external-lookup-card">
              <h3>Spieler suchen</h3>
              <p className="muted">Eine Suche – alle verfügbaren Quellen werden automatisch geprüft und Treffer zusammengeführt. FIDE-ID-Abruf ist aktiv; DSB/DeWIS und ThSB sind vorbereitet und werden klar als „aktuell nicht aktiv" markiert.</p>
              <form onSubmit={(event) => void searchExternalPlayers(event)} className="external-lookup-form single">
                <input value={externalQuery} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setExternalQuery(event.target.value)} placeholder="Name oder FIDE-ID (z. B. 99900123)" />
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
          )}

          {activeMainTab === 'participants' && (
          <article className="card participant-card">
            <div className="participant-heading">
              <div><h3>{t('participants.list')}</h3><small className="muted">{visiblePlayers.length} / {selectedTournament?.players.length ?? 0}</small></div>
              <label className="participant-search">{t('participants.filter')}
                <input type="search" value={participantSearch} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setParticipantSearch(event.target.value)} placeholder={t('participants.filterPlaceholder')} />
              </label>
            </div>
            <div className="table-scroll participant-scroll">
              <table className="participant-table">
                <thead><tr><th>#</th><th>{t('standings.name')}</th><th>{lang === 'en' ? 'Club' : 'Verein'}</th><th>FIDE</th><th>TWZ/DWZ</th><th>{lang === 'en' ? 'Year' : 'Jg.'}</th><th>{lang === 'en' ? 'Age' : 'Alter ca.'}</th><th>{lang === 'en' ? 'Category' : 'Kat.'}</th><th>{t('rounds.status')}</th><th>{lang === 'en' ? 'Actions' : 'Aktion'}</th></tr></thead>
                <tbody>
                  {(selectedTournament?.players.length ?? 0) === 0 && (
                    <tr><td colSpan={10} className="muted">{lang === 'en' ? 'No participants yet.' : 'Noch keine Teilnehmer erfasst.'}</td></tr>
                  )}
                  {(selectedTournament?.players.length ?? 0) > 0 && visiblePlayers.length === 0 && (
                    <tr><td colSpan={10} className="muted">{lang === 'en' ? 'No participants match the filter.' : 'Keine Teilnehmer passen zum Filter.'}</td></tr>
                  )}
                  {visiblePlayers.map(player => (
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
                        <button type="button" className="small" onClick={() => editPlayer(player)}>{t('common.edit')}</button>
                        {player.status === 0
                          ? <button type="button" className="small" onClick={() => void setPlayerStatus(player, 2)}>{lang === 'en' ? 'Withdraw' : 'Zurückziehen'}</button>
                          : <button type="button" className="small" onClick={() => void setPlayerStatus(player, 0)}>{lang === 'en' ? 'Activate' : 'Aktivieren'}</button>}
                        <button type="button" className="small danger" onClick={() => void deleteOrWithdrawPlayer(player)}>{t('common.delete')}</button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </article>
          )}

          {activeMainTab === 'standings' && (
          <div className="grid two">
            <article className="card">
              <div className="standings-heading">
                <div><h3>{t('standings.live')}</h3><p className="muted">{t('standings.intro')}</p></div>
                <button type="button" className="secondary" aria-expanded={showAdvancedStandings} onClick={() => setShowAdvancedStandings(previous => !previous)}>{showAdvancedStandings ? t('standings.less') : t('standings.more')}</button>
              </div>
              <div className="table-scroll">
                <table>
                  <thead><tr><th>{t('standings.rank')}</th><th>{t('standings.name')}</th><th>{t('standings.points')}</th><th>{t('standings.wins')}</th><th>BH</th><th>SB</th>{showAdvancedStandings && <><th>{t('rounds.black')}</th><th>BH-1</th><th>BH-2</th><th>Median</th><th>Koya</th><th>Prog.</th><th>TPR</th></>}</tr></thead>
                  <tbody>
                    {standings.map(row => (
                      <tr key={row.playerId}>
                        <td>{row.rank}</td>
                        <td>{row.name}</td>
                        <td>{row.points}</td>
                        <td>{row.wins}</td>
                        <td>{row.buchholz}</td>
                        <td>{row.sonnebornBerger}</td>
                        {showAdvancedStandings && <><td>{row.blackWins}</td><td>{row.buchholzCutOne}</td><td>{row.buchholzCutTwo}</td><td>{row.medianBuchholz}</td><td>{row.koyaScore}</td><td>{row.progressiveScore}</td><td>{row.tournamentPerformance ?? '—'}</td></>}
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

          )}

          {activeMainTab === 'standings' && (
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

          )}

          {activeMainTab === 'standings' && (
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

          )}

          {activeMainTab === 'rounds' && (
          <article className="card">
            <h3>{t('rounds.title')}</h3>
            {(!selectedTournament || selectedTournament.rounds.length === 0) ? (
              <div className="round-start">
                <h4>{t('rounds.firstTitle')}</h4>
                <p className="muted">{t('rounds.firstHelp')}</p>
                <div className="actions">
                  <button type="button" className="secondary" onClick={() => void previewNextRound()} disabled={!pairingReadinessCanCreatePreview()}>{t('rounds.preview')}</button>
                  <button type="button" onClick={() => void generateRound()} disabled={!pairingReadinessCanGenerateRound()}>{t('rounds.pairFirst')}</button>
                </div>
                {pairingReadinessBlockingIssues().length > 0 && (
                  <ul className="message-list round-bottom-blockers">
                    {pairingReadinessBlockingIssues().map((issue, index) => <li key={`round-start-blocker-${index}`}>{issue}</li>)}
                  </ul>
                )}
              </div>
            ) : (
              <>
                <div className="round-tab-bar" role="tablist" aria-label={t('rounds.title')}>
                  {selectedTournament.rounds.map(round => (
                    <button
                      key={`round-tab-${round.roundNumber}`}
                      type="button"
                      role="tab"
                      aria-selected={round.roundNumber === activeRoundNumber}
                      className={`round-tab-button${round.roundNumber === activeRoundNumber ? ' active' : ''}`}
                      onClick={() => setActiveRoundNumber(round.roundNumber)}
                    >
                      {t('rounds.round')} {round.roundNumber}
                    </button>
                  ))}
                  {pairingReadinessCanCreatePreview() && (
                    <button type="button" className="round-tab-button round-tab-next" onClick={() => void previewNextRound()}>＋ {t('rounds.next')}</button>
                  )}
                </div>
                {selectedTournament.rounds.filter(round => round.roundNumber === activeRoundNumber).map(round => (
              <section key={round.roundNumber} className="round-box">
                <div className="round-header">
                  <div>
                    <h4>{t('rounds.round')} {round.roundNumber}</h4>
                    <p className="muted">{t('rounds.status')}: {roundStatusLabel(round.resultStatus, lang === 'en')}{round.isLocked ? ` · ${lang === 'en' ? 'locked' : 'gesperrt'}` : ''}{round.isVerified ? ` · ${lang === 'en' ? 'reviewed' : 'geprüft'}` : ''}</p>
                  </div>
                  <div className="actions">
                    <button type="button" className="small" onClick={() => void setRoundLock(round, !round.isLocked)} disabled={round.isVerified}>{round.isLocked ? t('rounds.unlock') : t('rounds.lock')}</button>
                    <button type="button" className="small secondary" onClick={() => void setRoundVerified(round, !round.isVerified)}>{round.isVerified ? t('rounds.unverify') : t('rounds.verify')}</button>
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
                    <thead><tr><th>{t('rounds.board')}</th><th>{t('rounds.white')}</th><th>{t('rounds.black')}</th><th>Chess960</th><th>{t('rounds.result')}</th><th>{t('rounds.manual')}</th></tr></thead>
                    <tbody>
                      {round.pairings.map(pairing => {
                        const edit = pairingEdit(round, pairing);
                        const roundClosed = round.isLocked || round.isVerified;
                        return (
                          <tr key={`${round.roundNumber}-${pairing.boardNumber}`} className={pairing.isManualOverride ? 'manual-row' : ''}>
                            <td>{pairing.boardNumber}{pairing.isManualOverride ? <small>manuell</small> : null}</td>
                            <td>{playerNameById(pairing.whitePlayerId)}</td>
                            <td>{pairing.isBye ? t('rounds.bye') : playerNameById(pairing.blackPlayerId)}</td>
                            <td>
                              <strong>{chess960Display(pairing)}</strong>
                              {chess960SeedDisplay(pairing) && <small>{chess960SeedDisplay(pairing)}</small>}
                              {!pairing.isBye && (
                                <button
                                  type="button"
                                  className="small board-dice-button"
                                  title={`Chess960 für Brett ${pairing.boardNumber} würfeln`}
                                  onClick={() => openBoardDice(round.roundNumber, pairing.boardNumber)}
                                  disabled={roundClosed}
                                >🎲 Würfeln</button>
                              )}
                            </td>
                            <td>
                              <select
                                value={pairing.result.kind}
                                onChange={(event: React.ChangeEvent<HTMLSelectElement>) => requestResultChange(round.roundNumber, pairing.boardNumber, Number(event.target.value), pairing.result.kind)}
                                disabled={pairing.isBye || roundClosed}
                                aria-label={`${t('rounds.result')}: ${t('rounds.round')} ${round.roundNumber}, ${t('rounds.board')} ${pairing.boardNumber}`}
                              >
                                {resultOptions.map(option => <option key={option.value} value={option.value}>{lang === 'en' ? option.labelEn : option.label}</option>)}
                              </select>
                              <small>{resultLabel(pairing.result.kind, lang === 'en')}</small>
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
                    <strong>{t('rounds.continue')}</strong>
                    <span>{t('rounds.continueHelp')}</span>
                  </div>
                  <button type="button" className="secondary" onClick={() => void previewNextRound()} disabled={!pairingReadinessCanCreatePreview()}>{t('rounds.createPreview')}</button>
                  <button type="button" onClick={() => void generateRound()} disabled={!pairingReadinessCanGenerateRound()}>{t('rounds.pairNext')}</button>
                  {pairingReadinessBlockingIssues().length > 0 && (
                    <ul className="message-list round-bottom-blockers">
                      {pairingReadinessBlockingIssues().map((issue, index) => <li key={`round-bottom-blocker-${index}`}>{issue}</li>)}
                    </ul>
                  )}
                </div>
              </section>
                ))}
              </>
            )}
          </article>
          )}

          {activeMainTab === 'rounds' && (
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
          )}

          {activeMainTab === 'standings' && (
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
          )}

          {activeMainTab === 'rounds' && (
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
          )}

          {activeMainTab === 'overview' && (
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
          </article>
          )}

          {activeMainTab === 'print' && (
          <article className="card export-center-card">
              <div className="export-center-header">
                <div>
                  <h3>Turnierleiter-Exportcenter</h3>
                  <p className="muted">Schnellzugriff auf Aushänge, Tabellen, Paarungen, Vorschau und Backup. Ideal vor, während und nach einer Runde.</p>
                </div>
                <span className="export-center-badge">RUN-15 · v0.49</span>
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
                    <button type="button" className="secondary" onClick={() => openTournamentExport('standings/export.trf16')} disabled={!selectedTournament}>TRF16 (FIDE-Turnierbericht)</button>
                    <button type="button" className="secondary" onClick={() => openTournamentExport('pairings/export.csv')} disabled={!selectedTournament}>Alle Paarungen CSV</button>
                    <button type="button" className="secondary" onClick={openLatestPairingsCsv} disabled={!selectedTournament || selectedTournament.rounds.length === 0}>Aktuelle Paarungen CSV</button>
                    <button type="button" className="secondary" onClick={openNextRoundPreviewCsv} disabled={!selectedTournament || activePlayerCount() < 2}>Vorschau CSV</button>
                    <button type="button" className="secondary" onClick={openExportManifest} disabled={!selectedTournament}>Exportmanifest JSON</button>
                    <button type="button" className="secondary" onClick={() => void exportTournamentJson()} disabled={!selectedTournament}>Backup JSON</button>
                  </div>
                </section>
              </div>

              <p className="muted export-center-note">Hinweis: Vorschau-Exports speichern keine Runde. Erst „Diese Runde jetzt auslosen“ übernimmt die Paarungen ins Turnier.</p>
            </article>
          )}

          {activeMainTab === 'admin' && (
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
              <button type="button" onClick={() => openTournamentExport('audit-journal/export.jsonl')} disabled={!selectedTournament} title="Forensisches Bundle: Manifest, Turnier-Snapshot, Pairing-Forensik je Runde und alle Audit-Ereignisse als JSONL.">Audit-Bundle (JSONL)</button>
              <button type="button" className="secondary" onClick={() => openTournamentExport('audit-journal/export.json')} disabled={!selectedTournament} title="Gleiches Forensik-Bundle als strukturiertes JSON-Dokument.">Audit-Bundle (JSON)</button>
            </div>
            <p className="muted">Nach jeder Runde und nach Turnierende ein Audit-Bundle exportieren und lokal sichern – das schließt die Forensik-Lücke aus dem Bergfest-Postmortem.</p>
          </article>
          )}

          {activeMainTab === 'print' && (
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
                <h4>Swiss-Manager / TRF16 (Spieler-Stammdaten)</h4>
                <p className="muted">Import/Export von Spieler-Stammdaten fuer den Austausch mit Swiss-Manager, Chess-Results.com oder FIDE. Nur Name, Rating, Foederation, FIDE-ID u. ae. - keine Paarungen/Ergebnisse.</p>
                <div className="actions">
                  <button type="button" className="secondary" onClick={() => openTournamentExport('players/export-swissmanager.csv')} disabled={!selectedTournament}>Swiss-Manager CSV exportieren</button>
                  <button type="button" className="secondary" onClick={() => openTournamentExport('standings/export.trf16')} disabled={!selectedTournament}>TRF16 exportieren</button>
                </div>
                <div className="actions">
                  <label className="file-import-label">
                    Swiss-Manager CSV importieren
                    <input type="file" accept=".csv,.txt" disabled={!selectedTournament} onChange={(event: React.ChangeEvent<HTMLInputElement>) => {
                      const file = event.target.files?.[0];
                      event.target.value = '';
                      if (file) { void importPlayerFile(file, 'players/import-swissmanager.csv'); }
                    }} />
                  </label>
                  <label className="file-import-label">
                    TRF16 importieren
                    <input type="file" accept=".txt,.trf" disabled={!selectedTournament} onChange={(event: React.ChangeEvent<HTMLInputElement>) => {
                      const file = event.target.files?.[0];
                      event.target.value = '';
                      if (file) { void importPlayerFile(file, 'players/import-trf16'); }
                    }} />
                  </label>
                </div>
                {formatImportResult && (
                  <div className="import-preview">
                    <div className={`preview-summary ${formatImportResult.errors.length > 0 ? 'warning' : 'ready'}`}>
                      <strong>{formatImportResult.added} Teilnehmer importiert</strong>
                      {formatImportResult.errors.length > 0 && <span>{formatImportResult.errors.length} Hinweis(e)</span>}
                    </div>
                    {formatImportResult.errors.length > 0 && (
                      <ul className="message-list">
                        {formatImportResult.errors.map((message, index) => <li key={`format-import-error-${index}`}>{message}</li>)}
                      </ul>
                    )}
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
                  <button type="button" className="secondary" onClick={openExportManifest} disabled={!selectedTournament}>Exportmanifest JSON</button>
                </div>
                <div className="round-print-list">
                  {selectedTournament?.rounds.map(round => (
                    <button key={`print-${round.roundNumber}`} type="button" className="small secondary" onClick={() => openRoundPrint(round.roundNumber)}>Runde {round.roundNumber} drucken</button>
                  ))}
                </div>
              </section>
            </div>
          </article>
          )}
        </section>
      </section>
    </main>
  );
}

const boardDiceParams = parseBoardDiceParams(window.location.search);
ReactDOM.createRoot(document.getElementById('root')!).render(
  <I18nProvider>
    {boardDiceParams ? <MobileDicePage params={boardDiceParams} /> : <App />}
  </I18nProvider>
);
