// Mapping between backend contracts and the editable UI form shapes for
// players and tournament settings. Extracted from main.tsx (STM-FE-014).
import { defaultTiebreaks, emptyPlayerForm, emptySettingsForm } from './tournamentOptions';
import type { PlayerForm } from './tournamentOptions';
import type {
  ExternalPlayerProfile,
  Player,
  PlayerImportPreviewRow,
  SettingsForm,
  Tournament,
} from '../api/contracts';
export function twzOf(player: Player): number {
  return player.rating.manualTwz ?? player.rating.dwz ?? player.rating.elo ?? 0;
}

export function numberOrNull(value: string): number | null {
  const trimmed = value.trim();
  return trimmed.length === 0 ? null : Number(trimmed);
}

export function playerToForm(player: Player): PlayerForm {
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

export function formToRequest(form: PlayerForm, startingRank?: number): unknown {
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

export function applyExternalProfileToForm(profile: ExternalPlayerProfile): PlayerForm {
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

export function externalProfileKey(profile: ExternalPlayerProfile): string {
  return `${profile.source}-${profile.externalId || profile.fideId || profile.nationalId || profile.name}`;
}

export function importPreviewMessages(row: PlayerImportPreviewRow): string[] {
  return [...row.blockingIssues, ...row.warnings];
}

export function settingsToForm(tournament?: Tournament): SettingsForm {
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

export function formToSettings(form: SettingsForm) {
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

export function moveTiebreak(list: number[], index: number, direction: -1 | 1): number[] {
  const target = index + direction;
  if (target < 0 || target >= list.length) {
    return list;
  }

  const copy = [...list];
  const [item] = copy.splice(index, 1);
  copy.splice(target, 0, item);
  return copy;
}


