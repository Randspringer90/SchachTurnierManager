// Regression tests for the request timeout of the API client.
//
// Reproduced in a real headless Firefox against the portable build: when the
// local backend process is stopped while the page stays open, the next
// `fetch('/api/tournaments', {method:'POST'})` neither resolves nor rejects.
// The Firefox smoke recorded `fetch:start` and then nothing at all - so
// `createTournament` never reached its catch block, no message appeared, no
// loading state appeared, and "Jetzt anlegen" looked like a dead button.
//
// Every request therefore carries an upper bound now. A hung call has to end in
// a typed ApiTimeoutError with an actionable message.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  ApiTimeoutError,
  ApiUnreachableError,
  defaultRequestTimeoutMs,
  describeApiError,
  healthProbeTimeoutMs,
  pairingRequestTimeoutMs,
  isApiTransportError,
  requestJson,
  requestText,
} from '../src/api/client.ts';

const originalFetch = globalThis.fetch;

test('pairing has a finite budget beyond the maximum configured FIDE search', () => {
  assert.equal(pairingRequestTimeoutMs, 130000);
  assert.ok(healthProbeTimeoutMs < defaultRequestTimeoutMs);
});

test('an already aborted caller is propagated before fetch starts', async () => {
  const caller = new AbortController(); caller.abort();
  let sawAborted = false;
  await withFetch((async (_url: RequestInfo | URL, init?: RequestInit) => {
    sawAborted = init?.signal?.aborted === true;
    throw new DOMException('synthetic cancellation', 'AbortError');
  }) as typeof fetch, async () => {
    await assert.rejects(requestJson('/synthetic', { signal: caller.signal }), { name: 'AbortError' });
  });
  assert.equal(sawAborted, true);
});

function withFetch(stub: typeof globalThis.fetch, run: () => Promise<void>): Promise<void> {
  globalThis.fetch = stub;
  return run().finally(() => {
    globalThis.fetch = originalFetch;
  });
}

/** A fetch that never settles unless its abort signal fires - the observed Firefox behaviour. */
function hangingFetch(): typeof globalThis.fetch {
  return ((_url: string, init?: RequestInit) =>
    new Promise((_resolve, reject) => {
      init?.signal?.addEventListener('abort', () => {
        reject(new DOMException('The operation was aborted.', 'AbortError'));
      });
    })) as typeof globalThis.fetch;
}

test('a request that never settles ends in ApiTimeoutError instead of hanging forever', async () => {
  await withFetch(hangingFetch(), async () => {
    const error = await requestJson('/api/tournaments', { method: 'POST', timeoutMs: 40 }).then(
      () => null,
      (ex: unknown) => ex,
    );
    assert.ok(error instanceof ApiTimeoutError, 'a hung request must be typed as a timeout');
    assert.equal((error as ApiTimeoutError).url, '/api/tournaments');
    assert.equal((error as ApiTimeoutError).timeoutMs, 40);
  });
});

test('requestText is bounded by the same timeout', async () => {
  await withFetch(hangingFetch(), async () => {
    const error = await requestText('/api/tournaments/x/export/json', { timeoutMs: 40 }).then(
      () => null,
      (ex: unknown) => ex,
    );
    assert.ok(error instanceof ApiTimeoutError);
  });
});

test('the timeout message is actionable and leaks no browser internals', () => {
  const de = describeApiError(new ApiTimeoutError('/api/tournaments', 15000), 'de');
  const en = describeApiError(new ApiTimeoutError('/api/tournaments', 15000), 'en');

  for (const message of [de, en]) {
    assert.doesNotMatch(message, /AbortError|NetworkError|TypeError|127\.0\.0\.1|localhost|:\d{4}/i);
    assert.ok(message.length > 30, 'the message has to actually explain something');
  }
  assert.notEqual(de, en, 'the message is localized');
  assert.notEqual(
    de,
    describeApiError(new ApiUnreachableError('/api/tournaments'), 'de'),
    'a timeout and a refused connection need different advice',
  );
});

test('both transport failures are recognisable as such, business errors are not', () => {
  assert.ok(isApiTransportError(new ApiTimeoutError('/api/health', 100)));
  assert.ok(isApiTransportError(new ApiUnreachableError('/api/health')));
  assert.ok(!isApiTransportError(new Error('Turniername darf nicht leer sein.')));
  assert.ok(!isApiTransportError('Turniername darf nicht leer sein.'));
});

test('a caller abort is passed through and never mislabelled as a backend failure', async () => {
  await withFetch(hangingFetch(), async () => {
    const controller = new AbortController();
    const pending = requestJson('/api/tournaments', { signal: controller.signal }).then(
      () => null,
      (ex: unknown) => ex,
    );
    controller.abort();
    const error = await pending;
    assert.ok(!(error instanceof ApiTimeoutError), 'the caller cancelled, the backend did not time out');
    assert.ok(!(error instanceof ApiUnreachableError), 'a deliberate abort is not a transport failure');
  });
});

test('a refused connection is still an ApiUnreachableError, not a timeout', async () => {
  await withFetch(
    () => Promise.reject(new TypeError('NetworkError when attempting to fetch resource')),
    async () => {
      const error = await requestJson('/api/tournaments', { timeoutMs: 5000 }).then(
        () => null,
        (ex: unknown) => ex,
      );
      assert.ok(error instanceof ApiUnreachableError);
      assert.ok(!(error instanceof ApiTimeoutError));
    },
  );
});

test('the JSON content type survives caller supplied headers', async () => {
  let seen: Record<string, string> | undefined;
  await withFetch(
    ((_url: string, init?: RequestInit) => {
      seen = init?.headers as Record<string, string>;
      return Promise.resolve(new Response('{}', { status: 200, headers: { 'Content-Type': 'application/json' } }));
    }) as typeof globalThis.fetch,
    async () => {
      await requestJson('/api/tournaments', { method: 'POST', headers: { 'X-Test': '1' } });
    },
  );
  assert.equal(seen?.['Content-Type'], 'application/json', 'own headers must not drop the content type');
  assert.equal(seen?.['X-Test'], '1');
});

test('the internal timeout option never reaches fetch as a request field', async () => {
  let seen: RequestInit | undefined;
  await withFetch(
    ((_url: string, init?: RequestInit) => {
      seen = init;
      return Promise.resolve(new Response('{}', { status: 200, headers: { 'Content-Type': 'application/json' } }));
    }) as typeof globalThis.fetch,
    async () => {
      await requestJson('/api/health', { timeoutMs: 1000 });
    },
  );
  assert.ok(seen && !('timeoutMs' in seen), 'timeoutMs is a client option, not part of the HTTP request');
});

/**
 * Headers arrive at once, but the body stalls until the request signal aborts - like a
 * server that stops mid-response. Real fetch aborts the body stream with the signal.
 */
function stalledBodyFetch(contentType: string): typeof globalThis.fetch {
  return ((_url: string, init?: RequestInit) => {
    const body = new ReadableStream<Uint8Array>({
      start(controller) {
        controller.enqueue(new TextEncoder().encode(contentType === 'application/json' ? '{"partial":' : 'partial'));
        init?.signal?.addEventListener('abort', () => controller.error(new DOMException('The operation was aborted.', 'AbortError')));
      },
    });
    return Promise.resolve(new Response(body, { status: 200, headers: { 'Content-Type': contentType } }));
  }) as typeof globalThis.fetch;
}

test('requestJson keeps the deadline while the response body is read (PR #55 review)', async () => {
  await withFetch(stalledBodyFetch('application/json'), async () => {
    const error = await requestJson('/api/tournaments', { timeoutMs: 40 }).then(() => null, (ex: unknown) => ex);
    assert.ok(error instanceof ApiTimeoutError, 'a stalled body must end in a typed timeout');
  });
});

test('requestText keeps the deadline while the response body is read (PR #55 review)', async () => {
  await withFetch(stalledBodyFetch('text/plain'), async () => {
    const error = await requestText('/api/tournaments/x/export/json', { timeoutMs: 40 }).then(() => null, (ex: unknown) => ex);
    assert.ok(error instanceof ApiTimeoutError, 'a stalled body must end in a typed timeout');
  });
});

test('the default budget is finite, generous enough for a pairing run and stricter for health probes', () => {
  assert.ok(defaultRequestTimeoutMs >= 5000, 'a weak tournament laptop needs air for pairing and import');
  assert.ok(defaultRequestTimeoutMs <= 60000, 'but nobody waits a minute at a wrong-looking button');
  assert.ok(healthProbeTimeoutMs < defaultRequestTimeoutMs, 'the cyclic probe must not block the readiness loop');
});
