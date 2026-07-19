// Characterization tests for the extracted tournament-assistant helpers
// (STM-FE-013). They lock in the CURRENT behaviour so future refactors of the
// UI monolith cannot silently change planning output. Run with `npm test`
// (node's built-in runner + native TypeScript type stripping, no extra deps).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  assistantNumber,
  recommendedSwissRounds,
  assistantScenarioRoundMinutes,
} from '../src/lib/assistant.ts';

test('assistantNumber clamps and rounds within [min,max]', () => {
  assert.equal(assistantNumber('10', 12, 2, 512), 10);
  assert.equal(assistantNumber('10.6', 12, 2, 512), 11, 'rounds to nearest integer');
  assert.equal(assistantNumber('1', 12, 2, 512), 2, 'clamps to min');
  assert.equal(assistantNumber('9999', 12, 2, 512), 512, 'clamps to max');
});

test('assistantNumber falls back only on genuinely non-numeric input', () => {
  // Number('abc') and Number('NaN') are NaN -> fallback is used.
  assert.equal(assistantNumber('abc', 7, 2, 512), 7);
  assert.equal(assistantNumber('NaN', 3, 2, 512), 3);
  // But Number('') === 0 (finite!), so an empty field clamps to min, NOT fallback.
  // Documented here so the surprising edge is locked in, not accidentally "fixed".
  assert.equal(assistantNumber('', 12, 2, 512), 2);
  assert.equal(assistantNumber('   ', 12, 2, 512), 2, 'whitespace also coerces to 0');
});

test('recommendedSwissRounds maps field size to rounds (current behaviour)', () => {
  assert.equal(recommendedSwissRounds(4), 3);
  assert.equal(recommendedSwissRounds(8), 5);
  assert.equal(recommendedSwissRounds(16), 5); // NOTE: same as <=8 today (see review)
  assert.equal(recommendedSwissRounds(32), 6);
  assert.equal(recommendedSwissRounds(64), 7);
  assert.equal(recommendedSwissRounds(65), 9);
  assert.equal(recommendedSwissRounds(200), 9);
});

test('recommendedSwissRounds boundaries are inclusive at the upper edge', () => {
  assert.equal(recommendedSwissRounds(1), 3);
  assert.equal(recommendedSwissRounds(9), 5);
  assert.equal(recommendedSwissRounds(17), 6);
  assert.equal(recommendedSwissRounds(33), 7);
});

test('assistantScenarioRoundMinutes returns per-scenario minutes with a default', () => {
  const base = { playerCount: '12', availableMinutes: '180', boardCount: '6', rated: false, chess960: false, needsQr: false };
  assert.equal(assistantScenarioRoundMinutes({ ...base, scenario: 'blitz' }), 12);
  assert.equal(assistantScenarioRoundMinutes({ ...base, scenario: 'youth' }), 18);
  assert.equal(assistantScenarioRoundMinutes({ ...base, scenario: 'chess960' }), 22);
  assert.equal(assistantScenarioRoundMinutes({ ...base, scenario: 'open' }), 30);
  assert.equal(assistantScenarioRoundMinutes({ ...base, scenario: 'team' }), 35);
  assert.equal(assistantScenarioRoundMinutes({ ...base, scenario: 'club-night' }), 20);
});
