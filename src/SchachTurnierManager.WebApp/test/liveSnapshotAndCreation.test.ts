import test from 'node:test';
import assert from 'node:assert/strict';
import { appEffect, appHandler, sourceFunction } from './appSourceHarness.ts';
import { emptySettingsForm, defaultTiebreaks } from '../src/lib/tournamentOptions.ts';
const formsUrl = new URL('../src/lib/playerForms.ts', import.meta.url);
const numberOrNull = sourceFunction(formsUrl, 'numberOrNull');
const formToSettings = sourceFunction(formsUrl, 'formToSettings', { numberOrNull });
const settingsToForm = sourceFunction(formsUrl, 'settingsToForm', { emptySettingsForm, defaultTiebreaks });

test('the recommended draft reaches the real create payload without editing an existing tournament', async () => {
  let draft = { ...emptySettingsForm }, existingEdits = 0, payload: any;
  const recommendation = { format: 1, scoringSystem: 1, plannedRounds: 7 };
  appHandler('applyAssistantRecommendation', {
    assistantRecommendation: recommendation, setFormat() {},
    newTournamentSettingsForm: draft, setNewTournamentSettingsForm(value: any) { draft = value; },
    settingsForm: { ...emptySettingsForm, plannedRounds: '3' },
    settingsEditorGuard: { invalidate() { existingEdits++; } }, setSettingsForm() { existingEdits++; },
    defaultTiebreaks, setNewTournamentName() {}, assistantScenarioOptions: [], assistantForm: {},
    setStatus() {}, setActiveMainTab() {}, setIsCreateTournamentOpen() {},
  })();
  assert.equal(existingEdits, 0);
  assert.equal(draft.plannedRounds, '7');
  await appHandler('createTournament', {
    creatingTournament: false, createTournamentInFlight: { current: false }, setCreatingTournament() {},
    setError() {}, requestJson: async (_url: string, init: any) => { payload = JSON.parse(init.body); return { id: 'synthetic', name: 'Test' }; },
    newTournamentName: 'Test', newTournamentSettingsForm: draft, emptySettingsForm, formToSettings,
    format: 1, pairingStrategy: 1, swissInitialColour: 0, setSelectedId() {}, setIsCreateTournamentOpen() {},
    setActiveMainTab() {}, setStatus() {}, lang: 'de', refresh: async () => {}, reportActionFailure(_label: string, ex: unknown) { throw ex; },
  })({ preventDefault() {} });
  assert.equal(payload.settings.plannedRounds, 7);
  assert.equal(payload.settings.scoringSystem, 1);
  assert.equal(payload.settings.swissInitialColour, 0);
});

test('same tournament changes refresh all derived projections; unchanged polling does not', () => {
  const calls: string[] = [];
  const bindings: any = { selectedTournament: { id: 'A', settings: {}, players: [], rounds: [] },
    loadDerived: async (id: string) => { calls.push(id); }, setError() {}, describeApiError() {}, lang: 'de' };
  const previous = appEffect('loadDerived(selectedTournament.id)', bindings);
  previous.run();
  const unchanged = appEffect('loadDerived(selectedTournament.id)', { ...bindings, selectedTournament: structuredClone(bindings.selectedTournament) });
  assert.ok(previous.dependencies.every((value, i) => Object.is(value, unchanged.dependencies[i])));
  for (const change of [{ settings: { plannedRounds: 5 } }, { players: [{ id: 'P', name: 'Changed' }] }, { rounds: [{ roundNumber: 1 }] }]) {
    const changed = appEffect('loadDerived(selectedTournament.id)', { ...bindings, selectedTournament: { ...bindings.selectedTournament, ...change } });
    assert.ok(changed.dependencies.some((value, i) => !Object.is(value, previous.dependencies[i])));
    changed.run();
  }
  assert.deepEqual(calls, ['A', 'A', 'A', 'A']);
});

test('server settings refresh clean forms and preserve unsaved inputs', () => {
  const initial: any = { id: 'A', settings: formToSettings(emptySettingsForm) };
  const baseline: any = { current: { id: 'A', form: settingsToForm(initial) } };
  let draft = settingsToForm(initial);
  const changed = { ...initial, settings: { ...initial.settings, plannedRounds: 9 } };
  const render = () => appEffect('setSettingsForm', {
    selectedTournament: changed, settingsSource: baseline, settingsToForm,
    setSettingsForm(value: any) { draft = typeof value === 'function' ? value(draft) : value; },
  });
  render().run(); assert.equal(draft.plannedRounds, '9');
  draft = { ...draft, plannedRounds: '11' };
  changed.settings.plannedRounds = 12;
  render().run(); assert.equal(draft.plannedRounds, '11');
});
