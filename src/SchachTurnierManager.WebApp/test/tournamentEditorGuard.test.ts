import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createTournamentEditorGuard } from '../src/lib/tournamentEditorGuard.ts';

test('a draft with a shared player ID cannot be submitted to another tournament', () => {
  const guard = createTournamentEditorGuard('A');
  const draft = guard.capture('A');
  guard.select('B');
  assert.equal(guard.advance(draft), null);
  assert.equal(guard.capture('A'), null);
  assert.ok(guard.advance(guard.capture('B')));
});
test('a stale pairing handler cannot reuse matching round and board keys in B', () => {
  const guard = createTournamentEditorGuard('A'), draft = guard.capture('A');
  guard.select('B');
  assert.equal(guard.isCurrent(draft), false);
  assert.equal(guard.advance(draft), null);
});
test('late save and external apply replies cannot clear or repopulate the next tournament editor', async () => {
  const guard = createTournamentEditorGuard('A');
  const operation = guard.advance(guard.capture('A'));
  const reply = Promise.resolve({ name: 'A response' });
  guard.select('B');
  let draft = { name: 'B draft' };
  const response = await reply;
  if (guard.isCurrent(operation)) draft = response;
  assert.deepEqual(draft, { name: 'B draft' });
});
test('returning to A never revalidates its old edit or response', () => {
  const guard = createTournamentEditorGuard('A'), old = guard.advance(guard.capture('A'));
  guard.select('B'); guard.select('A');
  assert.equal(guard.isCurrent(old), false);
  assert.equal(guard.advance(old), null);
});
test('newer typing prevents an old save response from clearing the new draft', () => {
  const guard = createTournamentEditorGuard('A'), save = guard.advance(guard.capture('A'));
  const newDraft = guard.advance(guard.capture('A'));
  assert.equal(guard.isCurrent(save), false);
  assert.equal(guard.isCurrent(newDraft), true);
});
test('two requests answered in reverse order accept only the newest operation', () => {
  const guard = createTournamentEditorGuard('A'), first = guard.advance(guard.capture('A'));
  const second = guard.advance(guard.capture('A'));
  assert.equal(guard.isCurrent(second), true);
  assert.equal(guard.isCurrent(first), false);
});
test('unchanged edit and save completes and can be consumed exactly once', () => {
  const guard = createTournamentEditorGuard('A'), draft = guard.advance(guard.capture('A'));
  const save = guard.advance(draft);
  assert.equal(guard.isCurrent(save), true);
  assert.equal(guard.advance(draft), null);
  guard.invalidate();
  assert.equal(guard.isCurrent(save), false);
});
