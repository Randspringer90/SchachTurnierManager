import { test } from 'node:test';
import assert from 'node:assert/strict';
import { formatOptions, scoringOptions } from '../src/lib/tournamentOptions.ts';
import { sourceFunction } from './appSourceHarness.ts';

const twzOf = sourceFunction(new URL('../src/lib/playerForms.ts', import.meta.url), 'twzOf');
test('participant TWZ follows the tournament preference and ignores nonpositive ratings', () => {
  const player = { rating: { manualTwz: null, dwz: 1800, elo: 2000, rapidElo: 2100, blitzElo: 1900 } };
  assert.equal(twzOf(player, 0), 1800);
  assert.equal(twzOf(player, 1), 2000);
  assert.equal(twzOf(player, 2), 2100);
  assert.equal(twzOf({ rating: { ...player.rating, manualTwz: 2200 } }, 2), 2200);
  assert.equal(twzOf({ rating: { manualTwz: 0, dwz: 1800, elo: 2000 } }, 0), 1800);
  assert.equal(twzOf({ rating: { manualTwz: -1, dwz: 0, elo: 2000 } }, 0), 2000);
  assert.equal(twzOf({ rating: { manualTwz: 0, dwz: null, elo: null } }, 2), 0);
});
const helpers = Object.fromEntries(['assistantNumber', 'recommendedSwissRounds', 'assistantScenarioRoundMinutes']
  .map(name => [name, sourceFunction(new URL('../src/lib/assistant.ts', import.meta.url), name)]));
const recommend = sourceFunction(new URL('../src/lib/tournamentAssistant.ts', import.meta.url), 'buildTournamentAssistantRecommendation', {
  ...helpers, formatOptions, scoringOptions, assistantScenarioOptions: [{ value: 'club-night', label: 'Club' }],
});
for (const players of [3, 4, 5, 6, 7, 8]) test(`round-robin plan for ${players} players covers all rounds and physical boards`, () => {
  const result = recommend({ playerCount: String(players), availableMinutes: '300', boardCount: String(Math.floor(players / 2)),
    scenario: 'club-night', rated: false, chess960: false, needsQr: false });
  assert.equal(result.format, 0);
  assert.equal(result.plannedRounds, players % 2 ? players : players - 1);
  assert.equal(result.estimatedBoards, Math.floor(players / 2));
  assert.equal(result.estimatedTotalMinutes, result.plannedRounds * result.estimatedRoundMinutes + 20);
  assert.equal(result.warnings.some((warning: string) => warning.includes('Brett(er) benötigt')), false);
});
