import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createPlayerImportPreviewGuard } from '../src/lib/playerImportPreview.ts';

const identity = { tournamentId: 'A', content: 'Name\nCSV A', replaceExisting: false };
const preview = { replaceExisting: false, hasBlockingIssues: false };
const deferred = <T>() => {
  let resolve!: (value: T) => void;
  let reject!: (error: Error) => void;
  const promise = new Promise<T>((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
};
function setup() {
  const guard = createPlayerImportPreviewGuard<typeof preview>(identity);
  let active: typeof preview | null = null;
  const request = (wait: ReturnType<typeof deferred<typeof preview>>) => {
    const capture = guard.begin(guard.inputs)!;
    active = null;
    const done = wait.promise.then(value => {
      if (guard.accept(capture, value)) active = value;
    });
    return { capture, done };
  };
  return { guard, request, get active() { return active; } };
}
test('CSV A reply after choosing CSV B never activates A', async () => {
  const s = setup(), wait = deferred<typeof preview>();
  const a = s.request(wait);
  s.guard.update({ ...identity, content: 'Name\nCSV B' });
  wait.resolve(preview); await a.done;
  assert.equal(s.active, null); assert.equal(a.capture.signal.aborted, true);
  assert.equal(s.guard.matches(s.guard.inputs, preview), false);
});
test('tournament A reply after choosing tournament B cannot authorize B', async () => {
  const s = setup(), wait = deferred<typeof preview>();
  const a = s.request(wait);
  s.guard.update({ ...identity, tournamentId: 'B' });
  wait.resolve(preview); await a.done;
  assert.equal(s.active, null); assert.equal(s.guard.matches(s.guard.inputs, preview), false);
});
test('changing replace after a successful preview revokes import authorization', async () => {
  const s = setup(), wait = deferred<typeof preview>();
  const a = s.request(wait); wait.resolve(preview); await a.done;
  assert.equal(s.guard.matches(identity, s.active), true);
  s.guard.update({ ...identity, replaceExisting: true });
  assert.equal(s.guard.matches(s.guard.inputs, s.active), false);
});
test('reverse response order retains only the newest preview generation', async () => {
  const s = setup(), one = deferred<typeof preview>(), two = deferred<typeof preview>();
  const first = s.request(one), second = s.request(two);
  const latest = { ...preview }; two.resolve(latest); await second.done;
  one.resolve(preview); await first.done;
  assert.equal(s.active, latest); assert.equal(s.guard.matches(identity, latest), true);
  assert.equal(s.guard.matches(identity, preview), false);
});
test('unchanged preview authorizes the identical import payload; consume revokes it', async () => {
  const s = setup(), wait = deferred<typeof preview>();
  const a = s.request(wait); wait.resolve(preview); await a.done;
  let imports = 0;
  if (s.guard.matches(identity, s.active)) { imports++; s.guard.invalidate(); }
  assert.equal(imports, 1); assert.equal(s.guard.matches(identity, s.active), false);
});
test('input A -> B -> A still discards the old A response', async () => {
  const s = setup(), wait = deferred<typeof preview>(); const a = s.request(wait);
  s.guard.update({ ...identity, content: 'B' }); s.guard.update(identity);
  wait.resolve(preview); await a.done; assert.equal(s.active, null);
});
test('a stale closure and a server response for a different replace option are rejected', () => {
  const s = setup(); s.guard.update({ ...identity, tournamentId: 'B' });
  assert.equal(s.guard.begin(identity), null);
  const request = s.guard.begin(s.guard.inputs)!;
  assert.equal(s.guard.accept(request, { ...preview, replaceExisting: true }), false);
});
test('unmount invalidates pending requests even when producers ignore abort', async () => {
  const s = setup(), wait = deferred<typeof preview>(); const a = s.request(wait);
  s.guard.invalidate(); wait.resolve(preview); await a.done;
  assert.equal(s.guard.isCurrent(a.capture), false); assert.equal(s.active, null);
});
