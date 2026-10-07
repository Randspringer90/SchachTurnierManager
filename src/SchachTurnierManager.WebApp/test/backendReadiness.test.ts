// Tests for the backend readiness state machine.
//
// The UI used to fire exactly one /api/health call on mount. If the local
// backend was not up yet - the normal case for the operator start, where the
// browser opens before Kestrel is listening - the chip stayed on "checking"
// forever, the first list load failed with a raw message and nothing ever
// retried. The state machine below fixes the sequence and is kept free of React
// so the timing rules can be asserted without a browser.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  canOperate,
  describeReadiness,
  isStartupWindowExhausted,
  nextProbeDelayMs,
  readinessAfterProbe,
  startupBudgetMs,
  startupProbeDelaysMs,
  steadyProbeIntervalMs,
} from '../src/lib/backendReadiness.ts';

test('a slow start stays "starting" and only then becomes unreachable', () => {
  let failed = 0;
  for (let i = 0; i < startupProbeDelaysMs.length; i++) {
    failed += 1;
    const readiness = readinessAfterProbe(false, failed);
    if (failed < startupProbeDelaysMs.length) {
      assert.equal(readiness, 'starting', `attempt ${failed} is still inside the start window`);
    } else {
      assert.equal(readiness, 'unreachable', 'after the last attempt the verdict has to be honest');
    }
  }
});

test('a successful probe reports online regardless of earlier failures', () => {
  assert.equal(readinessAfterProbe(true, 0), 'online');
  assert.equal(readinessAfterProbe(true, 99), 'online');
});

test('the backoff grows, never shrinks and never reaches zero', () => {
  let previous = 0;
  for (let attempt = 0; attempt < startupProbeDelaysMs.length; attempt++) {
    const delay = nextProbeDelayMs(attempt);
    assert.ok(delay > 0, 'a zero delay would be a busy loop');
    assert.ok(delay >= previous, `delay must not shrink at attempt ${attempt}`);
    previous = delay;
  }
});

test('after the start window the polling calms down instead of hammering the server', () => {
  const afterWindow = nextProbeDelayMs(startupProbeDelaysMs.length);
  assert.equal(afterWindow, steadyProbeIntervalMs);
  assert.equal(nextProbeDelayMs(startupProbeDelaysMs.length + 50), steadyProbeIntervalMs);
  assert.ok(steadyProbeIntervalMs >= 5000, 'no aggressive polling load on a tournament laptop');
});

test('the start window is long enough for a cold local backend but stays finite', () => {
  const budget = startupBudgetMs();
  assert.ok(budget >= 8000, 'a cold SQLite start plus JIT easily takes several seconds');
  assert.ok(budget <= 60000, 'but the user must not stare at a spinner forever');
  assert.ok(isStartupWindowExhausted(startupProbeDelaysMs.length));
  assert.ok(!isStartupWindowExhausted(startupProbeDelaysMs.length - 1));
});

test('a negative attempt count cannot skip the first delay', () => {
  assert.equal(nextProbeDelayMs(-1), startupProbeDelaysMs[0]);
});

test('operating is only allowed once the backend actually answered', () => {
  assert.ok(canOperate('online'));
  assert.ok(!canOperate('starting'), 'a click during startup lands in a half loaded state');
  assert.ok(!canOperate('unreachable'));
});

test('online shows no banner, the other states explain themselves', () => {
  assert.equal(describeReadiness('online', 'de'), null);

  const starting = describeReadiness('starting', 'de');
  assert.ok(starting);
  assert.equal(starting!.tone, 'info');
  assert.equal(starting!.retryLabel, null, 'during startup a retry button would only invite double starts');

  const unreachable = describeReadiness('unreachable', 'de');
  assert.ok(unreachable);
  assert.equal(unreachable!.tone, 'error');
  assert.ok(unreachable!.retryLabel, 'a new attempt must be possible without restarting the browser');
});

test('no readiness text leaks a host, a port or a proxy value', () => {
  for (const lang of ['de', 'en']) {
    for (const state of ['starting', 'unreachable'] as const) {
      const notice = describeReadiness(state, lang)!;
      const text = `${notice.title} ${notice.detail} ${notice.retryLabel ?? ''}`;
      assert.doesNotMatch(text, /127\.0\.0\.1|localhost|:\d{4}|proxy|http:\/\//i, `${state}/${lang} leaks infrastructure`);
    }
  }
});

test('the readiness texts are localized', () => {
  assert.notEqual(describeReadiness('starting', 'de')!.title, describeReadiness('starting', 'en')!.title);
  assert.notEqual(describeReadiness('unreachable', 'de')!.detail, describeReadiness('unreachable', 'en')!.detail);
  assert.equal(describeReadiness('starting')!.title, describeReadiness('starting', 'de')!.title, 'German is the default');
});
