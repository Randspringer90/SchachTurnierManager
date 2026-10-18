export type BackupImportRequest = Readonly<{ generation: number; payload: string }>;

// The server accepts case-insensitive JSON property names. Reject ambiguous
// aliases so a confirmation for id A cannot deserialize into id B on the server.
export function backupImportSummary(value: unknown): { id: string; roundCount: number } | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const entries = Object.entries(value);
  const ids = entries.filter(([key]) => key.toLowerCase() === 'id');
  const rounds = entries.filter(([key]) => key.toLowerCase() === 'rounds');
  if (ids.length !== 1 || rounds.length !== 1) return null;
  const id = ids[0][1];
  if (typeof id !== 'string' || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)
      || /^0{8}-0{4}-0{4}-0{4}-0{12}$/.test(id) || !Array.isArray(rounds[0][1])) return null;
  return { id: id.toLowerCase(), roundCount: rounds[0][1].length };
}

// A reviewed JSON snapshot may authorize exactly one write. Editing, cancelling
// or changing the selected tournament revokes both replies and confirmations.
export function createBackupImportGuard() {
  let generation = 0;
  let current: BackupImportRequest | null = null;
  let dispatched = false;
  const isCurrent = (request: BackupImportRequest | null): request is BackupImportRequest =>
    request !== null && request === current && request.generation === generation;
  return {
    isCurrent,
    begin(payload: string): BackupImportRequest | null {
      if (current) return null;
      current = Object.freeze({ generation: ++generation, payload });
      dispatched = false;
      return current;
    },
    dispatch(request: BackupImportRequest): boolean {
      if (!isCurrent(request) || dispatched) return false;
      dispatched = true;
      return true;
    },
    finish(request: BackupImportRequest): boolean {
      if (!isCurrent(request)) return false;
      current = null;
      return true;
    },
    invalidate(): void { generation++; current = null; dispatched = false; },
  };
}
