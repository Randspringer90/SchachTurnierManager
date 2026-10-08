export type PlayerImportIdentity = Readonly<{
  tournamentId: string;
  content: string;
  replaceExisting: boolean;
}>;

type PreviewRequest = PlayerImportIdentity & Readonly<{ generation: number; signal: AbortSignal }>;

const sameIdentity = (left: PlayerImportIdentity, right: PlayerImportIdentity): boolean =>
  left.tournamentId === right.tournamentId && left.content === right.content &&
  left.replaceExisting === right.replaceExisting;

// Exact content comparison avoids fingerprint collisions. Input changes invalidate
// synchronously, including A -> B -> A, even if a producer ignores cancellation.
export function createPlayerImportPreviewGuard<T extends { replaceExisting: boolean }>(initial: PlayerImportIdentity) {
  let inputs = { ...initial };
  let generation = 0;
  let controller = new AbortController();
  let accepted: { request: PreviewRequest; preview: T } | null = null;
  const invalidate = (): void => {
    controller.abort();
    controller = new AbortController();
    generation++;
    accepted = null;
  };
  const isCurrent = (request: PreviewRequest): boolean =>
    request.generation === generation && !request.signal.aborted && sameIdentity(request, inputs);
  return {
    get inputs(): PlayerImportIdentity { return { ...inputs }; },
    invalidate,
    update(next: PlayerImportIdentity): void {
      if (sameIdentity(next, inputs)) return;
      inputs = { ...next };
      invalidate();
    },
    begin(next: PlayerImportIdentity): PreviewRequest | null {
      // A stale event closure must never revert the current input identity.
      if (!next.tournamentId || !sameIdentity(next, inputs)) return null;
      invalidate();
      return Object.freeze({ ...inputs, generation, signal: controller.signal });
    },
    isCurrent,
    accept(request: PreviewRequest, preview: T): boolean {
      if (!isCurrent(request) || preview.replaceExisting !== request.replaceExisting) return false;
      accepted = { request, preview };
      return true;
    },
    matches(next: PlayerImportIdentity, preview: T | null): boolean {
      return accepted !== null && accepted.preview === preview && isCurrent(accepted.request) &&
        sameIdentity(next, accepted.request);
    },
  };
}
