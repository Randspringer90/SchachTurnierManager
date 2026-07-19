// Domain and API contract types for the SchachTurnierManager WebApp.
// Extracted from main.tsx (STM-FE-013) so the API client, feature modules and
// tests can share one typed source of truth. No runtime code lives here.

export type Health = {
  status: string;
  app: string;
  version: string;
  time: string;
  database?: string;
};

export type BeforeInstallPromptEvent = Event & {
  prompt: () => Promise<void>;
  userChoice: Promise<{ outcome: 'accepted' | 'dismissed'; platform: string }>;
};

export type PwaStatus = 'checking' | 'unsupported' | 'ready' | 'installable' | 'installed' | 'update-available' | 'error';

export type RatingProfile = {
  manualTwz?: number | null;
  elo?: number | null;
  rapidElo?: number | null;
  blitzElo?: number | null;
  dwz?: number | null;
  dwzIndex?: number | null;
};

export type Player = {
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

export type GameResult = {
  kind: number;
  isPlayed: boolean;
  isBye: boolean;
};

export type Chess960StartPosition = {
  whiteBackRank: string;
  blackBackRank: string;
  positionNumber: number;
  seed?: number | null;
  createdAt: string;
  notation: string;
  displayName: string;
};

export type Pairing = {
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

export type PairingAudit = {
  algorithm: string;
  rulesetVersion: string;
  createdAt: string;
  messages: string[];
  scoreGroups: string[];
  floaters: string[];
  colorNotes: string[];
};

export type TournamentRound = {
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

export type StandingRow = {
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

export type Tournament = {
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

export type AuditJournalEntry = {
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

export type CategoryStandingTable = {
  category: string;
  rows: StandingRow[];
};

export type CrossTable = {
  players: CrossTablePlayer[];
  rows: CrossTableRow[];
};

export type CrossTablePlayer = {
  playerId: string;
  name: string;
  rank: number;
  startingRank: number;
  points: number;
};

export type CrossTableRow = {
  playerId: string;
  name: string;
  rank: number;
  points: number;
  cells: CrossTableCell[];
};

export type CrossTableCell = {
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

export type HeroCupRow = {
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

export type BoardDiagnostic = {
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

export type RoundDiagnostics = {
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

export type PairingQualityBoard = {
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

export type PairingQualityReport = {
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

export type NextRoundPreview = {
  roundNumber: number;
  boardCount: number;
  isSavable: boolean;
  summary: string;
  round: TournamentRound;
  pairingQuality: PairingQualityReport;
  messages: string[];
};
export type ExternalPlayerProviderInfo = {
  source: number;
  name: string;
  supportsIdLookup: boolean;
  supportsNameSearch: boolean;
  description: string;
  url?: string | null;
};

export type ExternalPlayerProfile = {
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

export type ExternalPlayerLookupResult = {
  source: number;
  query: string;
  status: number;
  message: string;
  players: ExternalPlayerProfile[];
};

export type ExternalPlayerAggregateSourceResult = {
  source: number;
  sourceName: string;
  status: number;
  isActive: boolean;
  message: string;
  count: number;
};

export type ExternalPlayerAggregateResult = {
  query: string;
  mode: string;
  message: string;
  players: ExternalPlayerProfile[];
  sources: ExternalPlayerAggregateSourceResult[];
};

export type ExternalPlayerDuplicateMatch = {
  playerId: string;
  playerName: string;
  kind: number;
  score: number;
  reason: string;
};

export type ExternalPlayerDuplicateCheck = {
  profile: ExternalPlayerProfile;
  matches: ExternalPlayerDuplicateMatch[];
  hasLikelyDuplicate: boolean;
};

export type ExternalPlayerApplyResult = {
  player: Player;
  created: boolean;
  updated: boolean;
  duplicateCheck: ExternalPlayerDuplicateCheck;
  changedFields: string[];
  message: string;
};

export type PlayerImportPreview = {
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

export type PlayerImportPreviewRow = {
  rowNumber: number;
  player: Player;
  profile: ExternalPlayerProfile;
  duplicateCheck: ExternalPlayerDuplicateCheck;
  warnings: string[];
  blockingIssues: string[];
  status: number;
};

export type PairingEdit = { whitePlayerId: string; blackPlayerId: string; notes: string; };

export type SettingsForm = {
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

export type TournamentAssistantScenario = 'club-night' | 'youth' | 'open' | 'blitz' | 'chess960' | 'team';

export type TournamentAssistantForm = {
  playerCount: string;
  availableMinutes: string;
  boardCount: string;
  scenario: TournamentAssistantScenario;
  rated: boolean;
  chess960: boolean;
  needsQr: boolean;
};

export type TournamentAssistantRecommendation = {
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


export type KnowledgeChatRole = 'user' | 'assistant';

export type KnowledgeChatMessage = {
  id: string;
  role: KnowledgeChatRole;
  text: string;
  sources: string[];
};

export type KnowledgeTopic = {
  id: string;
  title: string;
  keywords: string[];
  answer: string;
  steps: string[];
  sources: string[];
};

export type KnowledgeBase = {
  sourceVersion: string;
  sourceUpdated: string;
  providerMode: 'local-only';
  privacyNotice: string;
  quickQuestions: string[];
  topics: KnowledgeTopic[];
};
