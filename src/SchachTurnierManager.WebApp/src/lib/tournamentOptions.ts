// Static option catalogues, form shapes and empty-form defaults for the
// tournament UI. Extracted from main.tsx (STM-FE-014) so that presentation
// modules and the assistant can share one source of truth.
import type { SettingsForm, Tournament } from '../api/contracts';
export type PlayerForm = {
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

export const resultOptions = [
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

export const formatOptions = [
  { value: 1, label: 'Schweizer System' },
  { value: 0, label: 'Jeder gegen Jeden' }
];

export const pairingStrategyOptions = [
  { value: 0, label: 'Optimal V2 (empfohlen)' },
  { value: 1, label: 'FIDE Dutch' }
];

export const swissInitialColourOptions = [
  { value: 1, label: 'Weiß' },
  { value: 2, label: 'Schwarz' }
];

export const buildWeekDemoName = 'Build Week Demo Open';
export const buildWeekDemoMarker = 'STM_BUILD_WEEK_DEMO_V1';

export function isBuildWeekDemoTournament(tournament: Tournament): boolean {
  return tournament.name === buildWeekDemoName
    && tournament.settings.format === 1
    && tournament.settings.pairingStrategy === 1
    && tournament.players.length === 8
    && tournament.players.every((player, index) =>
      player.name === `Demo Player ${String(index + 1).padStart(2, '0')}`
      && player.notes === buildWeekDemoMarker);
}

export const scoringOptions = [
  { value: 0, label: 'Klassisch: Sieg 1 · Remis ½ · Niederlage 0' },
  { value: 1, label: '3-1-0: Sieg 3 · Remis 1 · Niederlage 0' },
  { value: 2, label: 'Norway/Armageddon: Klassiksieg 3 · Armageddon 1½/1' }
];

export const twzSourceOptions = [
  { value: 0, label: 'Manuelle TWZ → DWZ → Elo' },
  { value: 1, label: 'Manuelle TWZ → Elo → DWZ' },
  { value: 2, label: 'Manuelle TWZ → Rapid → Blitz → DWZ → Elo' }
];

export const forfeitPolicyOptions = [
  { value: 0, label: 'Kampflose Partien nicht für Buchholz/SB/Direktwertung' },
  { value: 1, label: 'Kampflose Gegner nur für Buchholz/Gegnerschnitt' },
  { value: 2, label: 'Kampflose Partien wie normale Partien behandeln' }
];

export const unplayedRoundBuchholzOptions = [
  { value: 0, label: 'Eigene ungespielte Runden ignorieren (bisheriges Verhalten)' },
  { value: 1, label: 'FIDE-Modus (Schweizer): Dummy-/VUR-Wertung nach Art. 16' }
];

export const tiebreakOptions = [
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

export const genderOptions = [
  { value: 0, label: 'unbekannt', labelEn: 'unknown' },
  { value: 1, label: 'offen', labelEn: 'open' },
  { value: 2, label: 'weiblich', labelEn: 'female' },
  { value: 3, label: 'männlich', labelEn: 'male' },
  { value: 4, label: 'divers', labelEn: 'diverse' }
];

export const playerStatusOptions = [
  { value: 0, label: 'aktiv', labelEn: 'active' },
  { value: 1, label: 'pausiert', labelEn: 'paused' },
  { value: 2, label: 'zurückgezogen', labelEn: 'withdrawn' }
];

export const externalSourceOptions = [
  { value: 0, label: 'FIDE' },
  { value: 1, label: 'DSB / DeWIS' },
  { value: 2, label: 'ThSB' },
  { value: 3, label: 'Lokal/Import' }
];

export const emptyPlayerForm: PlayerForm = {
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

export const sampleCsvTemplate = `Name;Verein;Geburtsjahr;Geschlecht;DWZ;DWZIndex;Elo;TWZ;FIDE-ID;DSB-ID;Titel;Status;Notizen
Weissbach, Lina;Beispiel SV;1990;männlich;1987;;1968;;99900123;;CM;Active;Beispielzeile bitte vor Import prüfen
Musterfrau, Anna;Beispielverein;2012;weiblich;1200;;1300;;;;Active;U14-Beispiel
`;

export const defaultTiebreaks = [0, 1, 2, 4, 6, 99];

export const emptySettingsForm: SettingsForm = {
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

