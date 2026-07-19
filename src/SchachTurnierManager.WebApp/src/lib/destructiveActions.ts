/**
 * Pure decision helpers for the destructive tournament actions (reset / delete).
 *
 * Keeping these out of the React component makes the Firefox regression
 * (native confirm/prompt chain) testable without a DOM.
 */

export type DestructiveAction = 'reset' | 'delete';

export type DestructiveDialogState = {
  action: DestructiveAction;
  tournamentId: string;
  tournamentName: string;
  busy: boolean;
  error: string | null;
};

/** The delete button stays disabled until the name matches verbatim. */
export function canConfirmDeletion(typedName: string, tournamentName: string): boolean {
  return typedName === tournamentName && tournamentName.length > 0;
}

/**
 * Picks the tournament to select after `deletedId` was removed.
 *
 * `remaining` is the freshly loaded server list. The deleted id is filtered out
 * defensively so a stale list can never re-select the tournament that no longer
 * exists, which previously caused follow-up requests against a dead id.
 */
export function selectNextTournamentId(
  remaining: ReadonlyArray<{ id: string }>,
  deletedId: string
): string {
  return remaining.find(item => item.id !== deletedId)?.id ?? '';
}

/** True when a confirmed action may be dispatched (guards double clicks). */
export function canDispatchDestructiveAction(state: DestructiveDialogState | null): boolean {
  return state !== null && !state.busy;
}
