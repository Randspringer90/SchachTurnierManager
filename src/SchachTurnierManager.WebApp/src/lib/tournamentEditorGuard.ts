export type TournamentEditorToken = Readonly<{ tournamentId: string; generation: number }>;

// Tokens belong to a rendered draft. Selection changes, draft changes and new
// requests revoke earlier handlers and responses, even for A -> B -> A.
export function createTournamentEditorGuard(initialTournamentId = '') {
  let tournamentId = initialTournamentId;
  let generation = 0;
  const isCurrent = (token: TournamentEditorToken | null): token is TournamentEditorToken =>
    token !== null && token.tournamentId === tournamentId && token.generation === generation;
  const capture = (id: string): TournamentEditorToken | null =>
    id && id === tournamentId ? Object.freeze({ tournamentId, generation }) : null;
  return {
    capture,
    isCurrent,
    select(id: string): void {
      if (id !== tournamentId) { tournamentId = id; generation++; }
    },
    invalidate(): void { generation++; },
    advance(token: TournamentEditorToken | null): TournamentEditorToken | null {
      if (!isCurrent(token)) return null;
      generation++;
      return capture(tournamentId);
    },
  };
}
