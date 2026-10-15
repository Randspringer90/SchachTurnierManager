// STM-SEC-003: a broken backup file must not echo its own content into the UI.
// V8 quotes parts of the input in some JSON.parse messages ("Max" is not valid
// JSON), so the operator message keeps only a location, never the raw text.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { describeJsonParseFailure } from '../src/lib/jsonParseError.ts';

function parseFailure(text: string): unknown {
  try {
    JSON.parse(text);
  } catch (error) {
    return error;
  }
  throw new Error('expected JSON.parse to fail');
}

test('content quoted by the engine never reaches the message', () => {
  for (const text of ['Max Mustermann', 'SYNTHETIC_PRIVATE_DETAIL', '{"name": "SYNTHETIC_PRIVATE_DETAIL" x}']) {
    const message = describeJsonParseFailure(parseFailure(text), 'de');
    assert.doesNotMatch(message, /Max|Mustermann|SYNTHETIC_PRIVATE_DETAIL/);
    assert.match(message, /kein gültiges JSON/);
  }
});

test('line and column are reported when the engine provides them', () => {
  const message = describeJsonParseFailure(parseFailure('{\n  "a": 1,\n}'), 'de');
  assert.match(message, /Zeile 3, Spalte 1/);
  assert.match(describeJsonParseFailure(parseFailure('{\n  "a": 1,\n}'), 'en'), /line 3, column 1/);
});

test('empty input and non-Error values get the fixed text without location', () => {
  assert.equal(describeJsonParseFailure(parseFailure(''), 'de'), 'Die Datei ist kein gültiges JSON.');
  assert.equal(describeJsonParseFailure('SYNTHETIC_PRIVATE_DETAIL', 'en'), 'The file is not valid JSON.');
  assert.equal(describeJsonParseFailure({ message: 'x at position 3 (line 9 column 9)' }, 'de'), 'Die Datei ist kein gültiges JSON.');
});

test('the backup import shows the location-only message, not the raw parser text', async () => {
  const { readFile } = await import('node:fs/promises');
  const app = await readFile(new URL('../src/app/App.tsx', import.meta.url), 'utf8');
  const start = app.indexOf('async function importTournamentJson()');
  assert.ok(start > 0);
  const body = app.slice(start, app.indexOf('/api/tournaments/import', start));
  assert.match(body, /describeJsonParseFailure\(ex, lang\)/);
  assert.doesNotMatch(body, /ex\.message|String\(ex\)/);
});

test('hostile message getters are tolerated', () => {
  const hostile = new SyntaxError('x');
  Object.defineProperty(hostile, 'message', { get() { throw new Error('read'); } });
  assert.equal(describeJsonParseFailure(hostile, 'de'), 'Die Datei ist kein gültiges JSON.');
});
