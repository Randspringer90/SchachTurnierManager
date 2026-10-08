// Pure planning helpers for the tournament assistant.
// Extracted from main.tsx (STM-FE-013) so the recommendation logic is unit
// testable without rendering the UI. Behaviour is unchanged.
import type { TournamentAssistantForm } from '../api/contracts';

export function assistantNumber(value: string, fallback: number, min: number, max: number): number {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    return fallback;
  }

  return Math.min(max, Math.max(min, Math.round(parsed)));
}

export function recommendedSwissRounds(playerCount: number): number {
  if (playerCount <= 4) return 3;
  if (playerCount <= 8) return 5;
  if (playerCount <= 16) return 5;
  if (playerCount <= 32) return 6;
  if (playerCount <= 64) return 7;
  return 9;
}

export function assistantScenarioRoundMinutes(form: TournamentAssistantForm): number {
  switch (form.scenario) {
    case 'blitz': return 12;
    case 'youth': return 18;
    case 'chess960': return 22;
    case 'open': return 30;
    case 'team': return 35;
    default: return 20;
  }
}
