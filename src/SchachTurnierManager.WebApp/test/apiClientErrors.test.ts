// Regression tests for the transport error handling of the API client.
// The UI used to surface the raw browser text
// "NetworkError when attempting to fetch resource" whenever the local backend
// was not up yet (start order, restart, closed server). That message is
// meaningless for an end user, so transport failures are now translated into
// ApiUnreachableError and rendered through describeApiError.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import {
  ApiUnreachableError,
  ApiResponseError,
  describeApiError,
  requestJson,
  requestText,
} from '../src/api/client.ts';

const originalFetch = globalThis.fetch;

test('every coded domain/application rule has English feedback that does not echo server details', () => {
  const domainDirectory = new URL('../../SchachTurnierManager.Domain/Services/', import.meta.url);
  const sources = [
    readFileSync(new URL('../../SchachTurnierManager.Application/TournamentService.cs', import.meta.url), 'utf8'),
    ...readdirSync(domainDirectory).filter(name => name.endsWith('.cs'))
      .map(name => readFileSync(new URL(name, domainDirectory), 'utf8')),
  ];
  const codes = new Set(sources.flatMap(source => [...source.matchAll(/\.WithErrorCode\("([A-Z][A-Z0-9_]*)"\)/g)].map(match => match[1])));
  assert.ok(codes.size > 1, 'the producer contract must cover multiple real validation rules');
  for (const code of codes) {
    const detail = 'synthetic-original-server-detail';
    const error = new ApiResponseError(400, detail, code);
    assert.notEqual(describeApiError(error, 'en'), detail, `English translation missing for ${code}`);
    assert.equal(describeApiError(error, 'de'), detail, `original detail changed for ${code}`);
  }
});

test('tournament validation codes keep English feedback readable and preserve the German detail', async () => {
  const originalDetail = 'Turniername darf nicht leer sein.';
  await withFetch(() => Promise.resolve(jsonResponse({ code: 'TOURNAMENT_NAME_REQUIRED', error: originalDetail }, { status: 400 })), async () => {
    const error = await requestJson('/api/tournaments').catch(value => value);
    assert.equal(describeApiError(error, 'en'), 'Enter a tournament name.');
    assert.equal(describeApiError(error, 'de'), originalDetail);
  });
});

test('explicit API error codes have English feedback without reflecting rejected input', () => {
  const program = readFileSync(new URL('../../SchachTurnierManager.WebApi/Program.cs', import.meta.url), 'utf8');
  const codes = new Set([...program.matchAll(/\bcode\s*=\s*"([A-Z][A-Z0-9_]*)"/g)].map(match => match[1]));
  assert.ok(codes.has('EXTERNAL_SOURCE_INVALID'));
  for (const code of codes) {
    const detail = 'synthetic-rejected-input';
    assert.notEqual(describeApiError(new ApiResponseError(400, detail, code), 'en'), detail, `English API error missing for ${code}`);
  }
});

test('structured FIDE errors are localized without parsing or echoing response text', async () => {
  await withFetch(() => Promise.resolve(jsonResponse({ code: 'FIDE_LIST_INVALID', error: 'synthetic-private-message-marker' }, { status: 400 })), async () => {
    const error = await requestJson('/api/external-players/fide/catalog').catch(value => value);
    assert.match(describeApiError(error, 'en'), /standard TXT list/i);
    assert.match(describeApiError(error, 'de'), /Standard-TXT-Liste/);
    assert.doesNotMatch(describeApiError(error, 'en'), /synthetic-private-message-marker/);
  });
});
test('access denial gives a useful localized connection explanation', () => {
  assert.match(describeApiError(new ApiResponseError(403, 'HTTP 403'), 'en'), /connection/i);
  assert.match(describeApiError(new ApiResponseError(403, 'HTTP 403'), 'de'), /Verbindung/);
});

function withFetch(stub: typeof globalThis.fetch, run: () => Promise<void>): Promise<void> {
  globalThis.fetch = stub;
  return run().finally(() => {
    globalThis.fetch = originalFetch;
  });
}

function jsonResponse(body: unknown, init: ResponseInit = {}): Response {
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
    ...init,
  });
}

test('a refused connection surfaces as ApiUnreachableError, not as a raw TypeError', async () => {
  await withFetch(
    () => Promise.reject(new TypeError('NetworkError when attempting to fetch resource')),
    async () => {
      const error = await requestJson('/api/tournaments', { method: 'POST' }).then(
        () => null,
        (ex: unknown) => ex,
      );
      assert.ok(error instanceof ApiUnreachableError, 'transport failure must be typed');
      assert.equal((error as ApiUnreachableError).url, '/api/tournaments');
      assert.ok(
        (error as ApiUnreachableError).cause instanceof TypeError,
        'the original fetch failure stays attached for diagnostics',
      );
    },
  );
});

test('requestText reports the same typed error for transport failures', async () => {
  await withFetch(
    () => Promise.reject(new TypeError('Failed to fetch')),
    async () => {
      const error = await requestText('/api/health').then(
        () => null,
        (ex: unknown) => ex,
      );
      assert.ok(error instanceof ApiUnreachableError);
    },
  );
});

test('the user-facing text explains the cause and never leaks the browser wording', () => {
  const de = describeApiError(new ApiUnreachableError('/api/tournaments'), 'de');
  const en = describeApiError(new ApiUnreachableError('/api/tournaments'), 'en');

  for (const message of [de, en]) {
    assert.doesNotMatch(message, /NetworkError|Failed to fetch|TypeError/i, 'no raw browser wording');
    assert.ok(message.length > 30, 'the message has to actually explain something');
  }
  assert.match(de, /Server/i);
  assert.match(en, /server/i);
  assert.notEqual(de, en, 'the message is localized');
});

test('German stays the default when no language is passed', () => {
  assert.equal(
    describeApiError(new ApiUnreachableError('/api/health')),
    describeApiError(new ApiUnreachableError('/api/health'), 'de'),
  );
});

test('business errors from the backend are passed through unchanged', async () => {
  await withFetch(
    () => Promise.resolve(jsonResponse({ error: 'Turniername ist bereits vergeben.' }, { status: 409 })),
    async () => {
      const error = await requestJson('/api/tournaments', { method: 'POST' }).then(
        () => null,
        (ex: unknown) => ex,
      );
      assert.ok(error instanceof Error);
      assert.ok(!(error instanceof ApiUnreachableError), 'an HTTP status is not a transport failure');
      assert.equal(describeApiError(error, 'de'), 'Turniername ist bereits vergeben.');
    },
  );
});

test('an HTTP error without a JSON body still yields a status message', async () => {
  await withFetch(
    () => Promise.resolve(new Response('<html>500</html>', { status: 500 })),
    async () => {
      const error = await requestJson('/api/tournaments').then(
        () => null,
        (ex: unknown) => ex,
      );
      assert.ok(error instanceof Error);
      assert.equal(describeApiError(error, 'de'), 'HTTP 500');
    },
  );
});

test('a successful response is still parsed as JSON', async () => {
  await withFetch(
    () => Promise.resolve(jsonResponse([{ id: 't1' }])),
    async () => {
      const data = await requestJson<{ id: string }[]>('/api/tournaments');
      assert.deepEqual(data, [{ id: 't1' }]);
    },
  );
});
