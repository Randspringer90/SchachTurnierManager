// Regression tests for the reset/delete flow that used to rely on chained
// native browser dialogs (window.confirm + window.prompt). In Firefox the
// second dialog of the chain could be suppressed, which aborted the delete
// silently and left a stale selection behind. The flow is now driven by an
// in-app dialog whose decision logic lives in src/lib/destructiveActions.ts.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  canConfirmDeletion,
  canDispatchDestructiveAction,
  selectNextTournamentId,
} from '../src/lib/destructiveActions.ts';
import type { DestructiveDialogState } from '../src/lib/destructiveActions.ts';

function dialog(overrides: Partial<DestructiveDialogState> = {}): DestructiveDialogState {
  return {
    action: 'delete',
    tournamentId: 't1',
    tournamentName: 'Vereinsmeisterschaft 2026',
    busy: false,
    error: null,
    ...overrides,
  };
}

test('deletion stays blocked until the tournament name matches verbatim', () => {
  const name = 'Vereinsmeisterschaft 2026';
  assert.equal(canConfirmDeletion('', name), false, 'empty input must not confirm');
  assert.equal(canConfirmDeletion('Vereinsmeisterschaft', name), false, 'prefix must not confirm');
  assert.equal(canConfirmDeletion('vereinsmeisterschaft 2026', name), false, 'case must match');
  assert.equal(canConfirmDeletion(' Vereinsmeisterschaft 2026', name), false, 'no whitespace tolerance');
  assert.equal(canConfirmDeletion(name, name), true, 'exact name confirms');
});

test('deletion cannot be confirmed for a tournament without a name', () => {
  assert.equal(canConfirmDeletion('', ''), false);
});

test('successful delete selects the next remaining tournament', () => {
  const remaining = [{ id: 't2' }, { id: 't3' }];
  assert.equal(selectNextTournamentId(remaining, 't1'), 't2');
});

test('a stale list still containing the deleted id never re-selects it', () => {
  const stale = [{ id: 't1' }, { id: 't2' }];
  assert.equal(selectNextTournamentId(stale, 't1'), 't2', 'deleted id is filtered out');
});

test('deleting the last tournament yields a clean empty selection', () => {
  assert.equal(selectNextTournamentId([], 't1'), '');
  assert.equal(selectNextTournamentId([{ id: 't1' }], 't1'), '', 'only the deleted entry left');
});

test('a request in flight blocks a second dispatch (double click / double submit)', () => {
  assert.equal(canDispatchDestructiveAction(dialog()), true);
  assert.equal(canDispatchDestructiveAction(dialog({ busy: true })), false);
  assert.equal(canDispatchDestructiveAction(null), false, 'closed dialog dispatches nothing');
});

test('a backend error leaves the dialog dispatchable again without losing context', () => {
  const failed = dialog({ busy: false, error: 'Löschen fehlgeschlagen: 500' });
  assert.equal(canDispatchDestructiveAction(failed), true, 'retry is possible');
  assert.equal(failed.tournamentId, 't1', 'target is preserved for the retry');
});

test('reset uses the same guarded dispatch path as delete', () => {
  assert.equal(canDispatchDestructiveAction(dialog({ action: 'reset' })), true);
  assert.equal(canDispatchDestructiveAction(dialog({ action: 'reset', busy: true })), false);
});
