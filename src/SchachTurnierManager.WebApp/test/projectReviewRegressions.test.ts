import { test } from 'node:test';
import assert from 'node:assert/strict';
import { setImmediate } from 'node:timers/promises';
import { createTournamentEditorGuard } from '../src/lib/tournamentEditorGuard.ts';
import { backupImportSummary, createBackupImportGuard } from '../src/lib/backupImportGuard.ts';
import { resultOptions } from '../src/lib/tournamentOptions.ts';
import { appCallback, appHandler, appJsx, hasAppHandler, deferred } from './appSourceHarness.ts';

const A = '00000000-0000-0000-0000-000000000001';
const B = '00000000-0000-0000-0000-000000000002';
const noop = () => {};
const tournament = (id = A, rounds: unknown[] = []) => ({ id, name: `Tournament ${id === A ? 'A' : 'B'}`, rounds, settings: {}, players: [] });

function selectionHandler(setSelectedIdState: (id: string) => void, bindings: Record<string, any> = {}) {
  let selectedId = A;
  return appCallback('setSelectedId', {
    projectionLoader: { disposed: false, select(id: string) { const changed = id !== selectedId; selectedId = id; return changed; } },
    playerEditorGuard: createTournamentEditorGuard(A), pairingEditorGuard: createTournamentEditorGuard(A),
    settingsEditorGuard: createTournamentEditorGuard(A), chess960Guard: createTournamentEditorGuard(A),
    importPreviewGuard: { inputs: {}, update: noop }, cancelBackupImport: noop, closeChess960Dialog: noop,
    setEditingPlayerId: noop, setPlayerForm: noop, emptyPlayerForm: {}, setPairingEdits: noop, setExternalDuplicateChecks: noop,
    setImportPreview: noop, setConfirmWarningImport: noop, setPairingQualityReports: noop, setNextRoundPreview: noop,
    setIsNextRoundPreviewDialogOpen: noop, setPendingResultChange: noop, setLastResultChange: noop,
    setBoardDiceModal: noop, setActionConfirm: noop, setError: noop, setSelectedIdState, ...bindings,
  });
}

function backupHarness(existing: unknown[] | Promise<unknown[]> = [], response = Promise.resolve(tournament())) {
  const guard = createBackupImportGuard();
  const state = { text: JSON.stringify(tournament()), selectedId: A, pending: null as any, busy: false, error: null as any };
  const writes: any[] = [], reads: string[] = [];
  function render() {
    const env: Record<string, any> = {
      backupJson: state.text, backupImportGuard: guard, backupImportPending: state.pending, backupImportSummary,
      setBackupJson: (value: string) => { state.text = value; },
      setError: (value: unknown) => { state.error = value; },
      setBackupImportPending: (value: unknown) => { state.pending = value; },
      setBackupImportBusy: (value: boolean) => { state.busy = value; },
      requestJson: async (url: string, init?: { body?: string }) => {
        if (!init?.body) { reads.push(url); return existing; }
        writes.push({ url, ...JSON.parse(init.body) }); return response;
      },
      setSelectedId: select,
      setStatus: noop, refresh: async () => {},
      reportActionFailure: (_label: string, error: unknown) => { state.error = error; },
      lang: 'de',
    };
    for (const name of ['commitBackupImport', 'confirmBackupImport', 'cancelBackupImport', 'updateBackupJson', 'importTournamentJson']) {
      if (hasAppHandler(name)) env[name] = appHandler(name, env);
    }
    return env;
  }
  const select = selectionHandler(id => { state.selectedId = id; }, { cancelBackupImport: () => render().cancelBackupImport() });
  return { state, guard, writes, reads, select, render };
}

test('a new backup import explicitly forbids replacing an existing ID', async () => {
  const h = backupHarness(); await h.render().importTournamentJson();
  assert.equal(h.writes.length, 1); assert.equal(h.writes[0].overwriteExisting, false);
});
test('an existing backup target needs a separate explicit confirmation before any write', async () => {
  const h = backupHarness([tournament(A, [{ roundNumber: 1 }, { roundNumber: 2 }])]);
  await h.render().importTournamentJson();
  assert.equal(h.writes.length, 0); assert.ok(h.state.pending);
  assert.equal(h.state.pending.tournamentName, 'Tournament A');
  assert.equal(h.state.pending.existingRoundCount, 2);
  await h.render().confirmBackupImport();
  assert.equal(h.writes.length, 1); assert.equal(h.writes[0].overwriteExisting, true);
});
test('cancelling a replacement makes its captured confirmation inert', async () => {
  const h = backupHarness([tournament()]); await h.render().importTournamentJson();
  assert.ok(h.state.pending); const old = h.render();
  old.cancelBackupImport(); await old.confirmBackupImport();
  assert.equal(h.writes.length, 0);
});
test('editing the JSON revokes the old confirmation and cannot substitute its payload', async () => {
  const h = backupHarness([tournament()]); await h.render().importTournamentJson();
  assert.ok(h.state.pending); const old = h.render();
  old.updateBackupJson(JSON.stringify(tournament(B))); await old.confirmBackupImport();
  assert.equal(h.writes.length, 0);
});
test('repeated confirmation dispatches the immutable backup snapshot exactly once', async () => {
  const h = backupHarness([tournament()]);
  await h.render().importTournamentJson(); assert.ok(h.state.pending);
  const old = h.render(); const first = old.confirmBackupImport(); const second = old.confirmBackupImport();
  await Promise.all([first, second]);
  assert.equal(h.writes.length, 1); assert.equal(h.writes[0].tournament.id, A);
});
test('replacement confirmation displays the current target, round counts and explicit data loss warning', async () => {
  const h = backupHarness([tournament(A, [{}, {}])]); await h.render().importTournamentJson();
  const dialog = appJsx('backupImportPending.request.generation', 'ConfirmDialog', {
    ConfirmDialog: 'ConfirmDialog', backupImportPending: h.state.pending, backupImportBusy: false,
    lang: 'de', confirmBackupImport: noop, cancelBackupImport: noop,
  });
  assert.equal(dialog.props.requireTypedConfirmation, 'Tournament A');
  assert.ok(dialog.props.description.includes('Tournament A'));
  assert.ok(dialog.props.consequences.some((text: string) => text.includes('2 Runde(n). Backup: 0 Runde(n).')));
  assert.ok(dialog.props.consequences.some((text: string) => text.includes('Ergebnisse') && text.includes('verloren')));
  assert.equal(dialog.props.key, h.state.pending.request.generation);
});
test('a captured backup confirmation is revoked by the real A -> B -> A selection callback', async () => {
  const h = backupHarness([tournament()]); await h.render().importTournamentJson();
  const captured = h.render(); h.select(B); h.select(A); await captured.confirmBackupImport();
  assert.equal(h.writes.length, 0); assert.equal(h.state.pending, null);
});
for (const action of ['cancel', 'edit', 'selection']) test(`a late backup preflight cannot write after ${action}`, async () => {
  const preflight = deferred<any[]>(), h = backupHarness(preflight.promise);
  const rendered = h.render(), pending = rendered.importTournamentJson();
  if (action === 'cancel') rendered.cancelBackupImport();
  if (action === 'edit') rendered.updateBackupJson(JSON.stringify(tournament(B)));
  if (action === 'selection') { h.select(B); h.select(A); }
  preflight.resolve([]); await pending;
  assert.equal(h.writes.length, 0); assert.equal(h.state.busy, false); assert.equal(h.state.pending, null);
});
test('a late import completion cannot change a new selection or clear a new import operation', async () => {
  const response = deferred<any>(), h = backupHarness([], response.promise);
  const pending = h.render().importTournamentJson(); await setImmediate();
  assert.equal(h.writes.length, 1); h.select(B);
  const next = h.guard.begin(JSON.stringify(tournament(B))); h.state.busy = true;
  response.resolve(tournament()); await pending;
  assert.equal(h.state.selectedId, B); assert.equal(h.state.busy, true); assert.equal(h.guard.isCurrent(next), true);
});
test('a failed import clears its confirmation and may be retried without carrying overwrite consent', async () => {
  const response = deferred<any>(), h = backupHarness([tournament()], response.promise);
  await h.render().importTournamentJson(); const pending = h.render().confirmBackupImport();
  response.reject(new Error('import failed')); await pending;
  assert.equal(h.state.pending, null); assert.equal(h.state.busy, false); assert.ok(h.state.error);
  await h.render().importTournamentJson();
  assert.equal(h.writes.length, 1); assert.ok(h.state.pending);
});
test('a stale backup error cannot replace the error of a newer view', async () => {
  const response = deferred<any[]>(), h = backupHarness(response.promise), pending = h.render().importTournamentJson();
  h.select(B); h.state.error = 'newer error'; response.reject(new Error('old read failed')); await pending;
  assert.equal(h.state.error, 'newer error'); assert.equal(h.state.busy, false);
});
for (const invalid of [null, [], {}, { id: A, rounds: {} }, { id: 'not-a-guid', rounds: [] },
  { id: '00000000-0000-0000-0000-000000000000', rounds: [] }, { id: A, Id: B, rounds: [] }, { id: A, rounds: [], Rounds: [{}] }]) {
  test(`invalid or ambiguous backup cannot select an overwrite target: ${JSON.stringify(invalid)}`, async () => {
    const h = backupHarness([tournament()]); h.state.text = JSON.stringify(invalid);
    await h.render().importTournamentJson();
    assert.equal(h.reads.length, 0); assert.equal(h.writes.length, 0); assert.ok(h.state.error);
  });
}
test('an unambiguous PascalCase backup still matches the existing server target', async () => {
  const h = backupHarness([tournament()]); h.state.text = JSON.stringify({ Id: A.toUpperCase(), Rounds: [{}] });
  await h.render().importTournamentJson();
  assert.equal(h.writes.length, 0); assert.equal(h.state.pending.backupRoundCount, 1);
});

function chessHarness() {
  const guard = createTournamentEditorGuard(A), requests: any[] = [];
  const state = { id: A, round: null as any, token: guard.capture(A), rolling: false, errors: [] as unknown[], confirm: null as any, refreshes: [] as string[] };
  function render(response: Promise<any>) {
    const env: Record<string, any> = {
      selectedTournament: tournament(state.id), chess960Guard: guard, chess960EditorToken: guard.capture(state.id),
      chess960DialogToken: state.token, chess960DialogRound: state.round,
      chess960Rolling: state.rolling, setError: (value: unknown) => state.errors.push(value),
      setChess960Rolling: (value: boolean) => { state.rolling = value; }, setDiceSpin: noop,
      setTimeout: (callback: () => void) => callback(), requestJson: (url: string, init: any) => {
        requests.push({ url, ...JSON.parse(init.body) }); return response;
      }, setDiceFace: noop, diceFaceGlyphs: ['K'], setChess960DialogRound: (value: unknown) => { state.round = value; },
      setChess960DialogToken: (value: any) => { state.token = value; },
      setChess960HasRolled: noop, setBackupRecommended: noop, setStatus: noop, setActionConfirm: (value: any) => { state.confirm = value; },
      refresh: async (id: string) => { state.refreshes.push(id); }, describeApiError: String, lang: 'de',
    };
    for (const name of ['closeChess960Dialog', 'openChess960Dice', 'rollChess960', 'performChess960Roll']) if (hasAppHandler(name)) env[name] = appHandler(name, env);
    return env;
  }
  const select = selectionHandler(id => { state.id = id; }, { chess960Guard: guard,
    closeChess960Dialog: () => render(Promise.resolve({})).closeChess960Dialog() });
  return { guard, state, requests, select, render };
}
for (const roundTrip of [false, true]) test(`late Chess960 response is ignored after A -> B${roundTrip ? ' -> A' : ''}`, async () => {
  const h = chessHarness(), response = deferred<any>();
  const pending = h.render(response.promise).rollChess960({ roundNumber: 1, pairings: [] }, false);
  h.select(B); if (roundTrip) h.select(A);
  response.resolve({ roundNumber: 1, pairings: [{ whitePlayerId: 'A player' }] }); await pending;
  assert.equal(h.state.round, null);
});
test('a Chess960 response cannot reopen a manually closed dialog', async () => {
  const h = chessHarness(), response = deferred<any>(), original = h.render(response.promise);
  const pending = original.rollChess960({ roundNumber: 1, pairings: [] }, false);
  assert.equal(typeof original.closeChess960Dialog, 'function'); original.closeChess960Dialog();
  response.resolve({ roundNumber: 1, pairings: [] }); await pending;
  assert.equal(h.state.round, null);
});
test('an old Chess960 finalizer cannot clear the busy state of the newer tournament', async () => {
  const h = chessHarness(), old = deferred<any>(), next = deferred<any>();
  const first = h.render(old.promise).rollChess960({ roundNumber: 1, pairings: [] }, false);
  h.select(B); h.state.token = h.guard.capture(B);
  const second = h.render(next.promise).rollChess960({ roundNumber: 1, pairings: [] }, false);
  old.resolve({ roundNumber: 1, pairings: [] }); await first;
  assert.equal(h.state.rolling, true);
  next.resolve({ roundNumber: 1, pairings: [] }); await second;
  assert.equal(h.state.rolling, false);
});
test('the current Chess960 result updates its own dialog and refreshes its own tournament', async () => {
  const h = chessHarness(), updated = { roundNumber: 1, pairings: [{ chess960StartPosition: { positionNumber: 7 } }] };
  await h.render(Promise.resolve(updated)).rollChess960({ roundNumber: 1, pairings: [] }, false);
  assert.equal(h.state.round, updated); assert.deepEqual(h.state.refreshes, [A]);
  assert.equal(h.requests[0].url, `/api/tournaments/${A}/rounds/1/chess960/start-positions`);
  assert.equal(h.requests[0].overwriteExisting, false); assert.equal(h.state.rolling, false);
});
test('reopening another Chess960 dialog for the same tournament revokes the old response', async () => {
  const h = chessHarness(), response = deferred<any>(), old = h.render(response.promise);
  const pending = old.rollChess960({ roundNumber: 1, pairings: [] }, false);
  const newerRound = { roundNumber: 2, pairings: [] }; h.render(Promise.resolve({})).openChess960Dice(newerRound);
  response.resolve({ roundNumber: 1, pairings: [] }); await pending;
  assert.equal(h.state.round, newerRound); assert.equal(h.state.rolling, false);
});
test('an old Chess960 open callback cannot revive a round after A -> B -> A', () => {
  const h = chessHarness(), old = h.render(Promise.resolve({})); h.select(B); h.select(A);
  old.openChess960Dice({ roundNumber: 1, pairings: [] });
  assert.equal(h.state.round, null);
});
test('the same Chess960 roll callback may dispatch only once', async () => {
  const h = chessHarness(), response = deferred<any>(), rendered = h.render(response.promise);
  const first = rendered.rollChess960({ roundNumber: 1, pairings: [] }, false);
  const second = rendered.rollChess960({ roundNumber: 1, pairings: [] }, false);
  assert.equal(h.requests.length, 1); response.resolve({ roundNumber: 1, pairings: [] });
  await Promise.all([first, second]);
});
test('a Chess960 overwrite confirmation cannot write after A -> B -> A', async () => {
  const h = chessHarness(), rendered = h.render(Promise.resolve({}));
  rendered.performChess960Roll({ roundNumber: 1, pairings: [{ chess960StartPosition: { positionNumber: 7 } }] });
  assert.ok(h.state.confirm); const captured = h.state.confirm;
  h.select(B); h.select(A); await captured.run();
  assert.equal(h.requests.length, 0); assert.equal(h.state.round, null);
});
test('a current Chess960 overwrite confirmation sends its round and consent exactly once', async () => {
  const h = chessHarness(), updated = { roundNumber: 2, pairings: [{ chess960StartPosition: { positionNumber: 8 } }] };
  h.render(Promise.resolve(updated)).performChess960Roll({ roundNumber: 2, pairings: [{ chess960StartPosition: { positionNumber: 7 } }] });
  assert.equal(h.requests.length, 0); const confirmed = h.state.confirm;
  await confirmed.run(); await confirmed.run();
  assert.equal(h.requests.length, 1); assert.equal(h.requests[0].overwriteExisting, true);
  assert.equal(h.requests[0].url, `/api/tournaments/${A}/rounds/2/chess960/start-positions`);
  assert.equal(h.state.round, updated);
});
test('cancelling Chess960 also revokes a captured overwrite confirmation', async () => {
  const h = chessHarness(), rendered = h.render(Promise.resolve({}));
  rendered.performChess960Roll({ roundNumber: 1, pairings: [{ chess960StartPosition: { positionNumber: 7 } }] });
  const captured = h.state.confirm; rendered.closeChess960Dialog(); await captured.run();
  assert.equal(h.requests.length, 0);
});
test('cancelling only the overwrite overlay revokes its callback and keeps the Chess960 dialog usable', async () => {
  const h = chessHarness(), round = { roundNumber: 1, pairings: [{ chess960StartPosition: { positionNumber: 7 } }] };
  h.state.round = round;
  const rendered = h.render(Promise.resolve(round)); rendered.performChess960Roll(round);
  const captured = h.state.confirm;
  const dialog = appJsx('destructive={actionConfirm.destructive}', 'ConfirmDialog', {
    ConfirmDialog: 'ConfirmDialog', actionConfirm: captured, actionConfirmBusy: false, lang: 'de',
    actionConfirmInFlight: { current: null },
    confirmActionDialog: noop,
    setActionConfirm: (value: any) => { h.state.confirm = typeof value === 'function' ? value(h.state.confirm) : value; },
  });
  dialog.props.onCancel(); await captured.run();
  assert.equal(h.requests.length, 0); assert.equal(h.state.round, round);
  assert.equal(h.guard.isCurrent(h.state.token), true);
  h.render(Promise.resolve(round)).performChess960Roll(round); await h.state.confirm.run();
  assert.equal(h.requests.length, 1); assert.equal(h.requests[0].overwriteExisting, true);
});
test('a stale Chess960 error is silent, while a current failure ends its busy state', async () => {
  const h = chessHarness(), old = deferred<any>(), current = deferred<any>();
  const first = h.render(old.promise).rollChess960({ roundNumber: 1, pairings: [] }, false);
  h.select(B); h.state.token = h.guard.capture(B);
  const second = h.render(current.promise).rollChess960({ roundNumber: 1, pairings: [] }, false);
  old.reject(new Error('old error')); await first;
  assert.equal(h.state.errors.filter(Boolean).length, 0); assert.equal(h.state.rolling, true);
  current.reject(new Error('current error')); await second;
  assert.equal(h.state.errors.filter(Boolean).length, 1); assert.equal(h.state.rolling, false);
});
test('finishing an old action confirmation preserves the newer dialog', async () => {
  const response = deferred<void>(), old = { run: () => response.promise }, next = { run: async () => {} };
  let current: any = old;
  const confirm = appHandler('confirmActionDialog', {
    actionConfirm: old, actionConfirmBusy: false, actionConfirmInFlight: { current: null }, setActionConfirmBusy: noop,
    setActionConfirm: (value: any) => { current = typeof value === 'function' ? value(current) : value; },
  });
  const pending = confirm(); current = next; response.resolve(); await pending;
  assert.equal(current, next);
});
test('duplicate confirmation callbacks cannot release the busy state of the active operation', async () => {
  const response = deferred<void>(); let calls = 0, busy = false;
  const pendingAction = { run: () => ++calls === 1 ? response.promise : Promise.resolve() };
  const confirm = appHandler('confirmActionDialog', {
    actionConfirm: pendingAction, actionConfirmBusy: false, actionConfirmInFlight: { current: null },
    setActionConfirmBusy: (value: boolean) => { busy = value; }, setActionConfirm: noop,
  });
  const first = confirm(); await confirm(); const busyBeforeCompletion = busy;
  response.resolve(); await first;
  assert.equal(calls, 1); assert.equal(busyBeforeCompletion, true); assert.equal(busy, false);
});
test('an old cancel callback cannot abandon a confirmation that has started running', () => {
  const pending = { run: async () => {} }; let current: any = pending;
  const dialog = appJsx('destructive={actionConfirm.destructive}', 'ConfirmDialog', {
    ConfirmDialog: 'ConfirmDialog', actionConfirm: pending, actionConfirmBusy: false, lang: 'de',
    actionConfirmInFlight: { current: pending }, confirmActionDialog: noop,
    setActionConfirm: (value: any) => { current = typeof value === 'function' ? value(current) : value; },
  });
  dialog.props.onCancel(); assert.equal(current, pending);
});

function settingsHarness() {
  const guard = createTournamentEditorGuard(A), requests: any[] = [];
  const state = { selected: A, draft: { plannedRounds: '6', tiebreaks: [0, 99] }, error: null as any, refreshes: [] as string[] };
  const select = selectionHandler(id => { state.selected = id; }, { settingsEditorGuard: guard });
  function render(response: Promise<any>) {
    const env: Record<string, any> = {
      selectedTournament: tournament(state.selected), settingsForm: state.draft,
      settingsEditorGuard: guard, settingsEditorToken: guard.capture(state.selected),
      setSettingsForm: (value: any) => { state.draft = typeof value === 'function' ? value(state.draft) : value; },
      setError: (value: any) => { state.error = value; },
      requestJson: (url: string, init: any) => { requests.push({ url, ...JSON.parse(init.body) }); return response; },
      formToSettings: (value: unknown) => value, setSelectedId: select, setStatus: noop,
      settingsToForm: (value: any) => value.settings, refresh: async (id: string) => { state.refreshes.push(id); },
      reportActionFailure: (_label: string, error: any) => { state.error = error; },
    };
    for (const name of ['updateSettingsForm', 'toggleTiebreak', 'saveSettings']) env[name] = appHandler(name, env);
    return env;
  }
  return { state, guard, select, requests, render };
}
for (const roundTrip of [false, true]) test(`late settings save preserves the new draft after A -> B${roundTrip ? ' -> A' : ''}`, async () => {
  const h = settingsHarness(), response = deferred<any>();
  const pending = h.render(response.promise).saveSettings({ preventDefault: noop });
  h.select(B); if (roundTrip) h.select(A); h.state.draft = { plannedRounds: '9', tiebreaks: [0, 99] };
  response.resolve(tournament()); await pending;
  assert.equal(h.state.selected, roundTrip ? A : B); assert.equal(h.state.draft.plannedRounds, '9');
  assert.equal(h.state.refreshes.length, 0);
});
test('a real settings input edit revokes a save response for the same tournament', async () => {
  const h = settingsHarness(), response = deferred<any>();
  const pending = h.render(response.promise).saveSettings({ preventDefault: noop });
  const input = appJsx('value={settingsForm.plannedRounds}', 'input', h.render(Promise.resolve({})));
  input.props.onChange({ target: { value: '9' } });
  response.resolve({ ...tournament(), settings: { plannedRounds: '6' } }); await pending;
  assert.equal(h.state.draft.plannedRounds, '9'); assert.equal(h.state.refreshes.length, 0);
});
test('a newer settings save owns the response even when the earlier save finishes last', async () => {
  const h = settingsHarness(), old = deferred<any>(), current = deferred<any>();
  const first = h.render(old.promise).saveSettings({ preventDefault: noop });
  h.render(Promise.resolve({})).updateSettingsForm({ plannedRounds: '9', tiebreaks: [0, 99] });
  const second = h.render(current.promise).saveSettings({ preventDefault: noop });
  current.resolve({ ...tournament(), settings: { plannedRounds: '9', tiebreaks: [0, 99] } }); await second;
  old.resolve({ ...tournament(), settings: { plannedRounds: '6', tiebreaks: [0, 99] } }); await first;
  assert.equal(h.state.draft.plannedRounds, '9'); assert.deepEqual(h.state.refreshes, [A]);
  assert.equal(h.requests[1].settings.plannedRounds, '9');
});
test('an old settings error is suppressed after the draft changes, while a current error is reported', async () => {
  const h = settingsHarness(), old = deferred<any>(), current = deferred<any>();
  const first = h.render(old.promise).saveSettings({ preventDefault: noop });
  h.render(Promise.resolve({})).toggleTiebreak(1, true); old.reject(new Error('old error')); await first;
  assert.equal(h.state.error, null);
  const second = h.render(current.promise).saveSettings({ preventDefault: noop });
  current.reject(new Error('current error')); await second;
  assert.equal(h.state.error.message, 'current error');
});

test('the rendered result selector has no Bye choice on an ordinary two-player board', () => {
  const rendered = appJsx("t('rounds.result')", 'select', {
    pairing: { isBye: false, result: { kind: 0 }, boardNumber: 1 }, round: { roundNumber: 1 }, roundClosed: false,
    t: (key: string) => key, lang: 'de', resultOptions, requestResultChange: noop,
    resultOptionsForPairing: (isBye: boolean) => resultOptions.filter(option => isBye || option.value !== 7),
  });
  assert.equal(rendered.children.some((option: any) => option.props.value === 7), false);
});
test('manual pairing controls are disabled when the tournament forbids overrides', () => {
  const rendered = appJsx('manual-pairing-disclosure', 'details', {
    selectedTournament: { ...tournament(), settings: { allowManualPairingOverrides: false } },
    round: { roundNumber: 1 }, pairing: { boardNumber: 1 }, roundClosed: false, manualPairingDisabled: true,
    edit: { whitePlayerId: 'w', blackPlayerId: 'b', notes: '' }, lang: 'de', updatePairingEdit: noop, saveManualPairing: noop,
  });
  const controls: any[] = [];
  function visit(node: any) { if (!node || typeof node !== 'object') return;
    if (['select', 'input', 'button'].includes(node.type)) controls.push(node);
    node.children?.forEach(visit);
  }
  visit(rendered); assert.equal(controls.length, 4); assert.ok(controls.every(control => control.props.disabled));
});
test('the result handler also rejects Bye on a normal board and preserves ordinary result changes', () => {
  let pending: any = null;
  const change = appHandler('requestResultChange', {
    selectedTournament: tournament(A, [{ roundNumber: 1, pairings: [{ boardNumber: 1, isBye: false }] }]),
    resultReturnFocusRef: { current: null }, setPendingResultChange: (value: any) => { pending = value; },
  });
  change(1, 1, 7, 0); assert.equal(pending, null);
  change(1, 1, 1, 0); assert.equal(pending.result, 1); assert.equal(pending.tournamentId, A);
});
for (const allowed of [false, true]) test(`the manual pairing handler honors allowManualPairingOverrides=${allowed}`, async () => {
  const round = { roundNumber: 1, pairings: [] }, pairing = { boardNumber: 1 }, guard = createTournamentEditorGuard(A);
  const writes: any[] = [];
  const save = appHandler('saveManualPairing', {
    selectedTournament: { ...tournament(), settings: { allowManualPairingOverrides: allowed } },
    pairingEditorGuard: guard, pairingEditorToken: guard.capture(A), pairingEdit: () => ({ whitePlayerId: 'w', blackPlayerId: 'b', notes: '' }),
    setPairingEdits: noop, setError: noop, setStatus: noop, refresh: async () => {},
    requestJson: async (url: string, init: any) => { writes.push({ url, ...JSON.parse(init.body) }); return round; },
    reportActionFailure: (_label: string, error: unknown) => { throw error; },
  });
  await save(round, pairing); assert.equal(writes.length, allowed ? 1 : 0);
});
