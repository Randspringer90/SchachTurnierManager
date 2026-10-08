// Guard tests: no operator action may fail silently.
//
// The manual Firefox run reported "many buttons do nothing". The audit found two
// causes in the app shell, both invisible to the existing unit tests:
//
//   1. Several `async` handlers called the API without a `try/catch`. A failing
//      request became an unhandled promise rejection - no message, no status
//      change, no console output for the operator. The button looked dead.
//   2. Startup errors were rendered with the raw `Error.message` instead of
//      `describeApiError`, which is exactly the raw browser wording that
//      STM-UX-014 had already removed from the create flow.
//
// These are structural properties of the source, so they are asserted
// structurally - a component test would only cover the handlers someone
// remembered to wire up.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const srcRoot = fileURLToPath(new URL('../src', import.meta.url));

function sourceFiles(dir: string): string[] {
  return readdirSync(dir, { withFileTypes: true }).flatMap(entry => {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) {
      return sourceFiles(full);
    }
    return /\.tsx?$/.test(entry.name) ? [full] : [];
  });
}

const sources = sourceFiles(srcRoot).map(path => ({ path, text: readFileSync(path, 'utf8') }));

/** Body of a function, located by brace matching from its declaration. */
function functionBody(text: string, declarationIndex: number): string {
  const open = text.indexOf('{', declarationIndex);
  assert.notEqual(open, -1, 'a function declaration always has a body');
  let depth = 0;
  for (let i = open; i < text.length; i++) {
    const char = text[i];
    if (char === '{') {
      depth++;
    } else if (char === '}') {
      depth--;
      if (depth === 0) {
        return text.slice(open, i + 1);
      }
    }
  }
  throw new Error('unbalanced braces while scanning a function body');
}

type Handler = { file: string; name: string; body: string };

/** All `async function name(...)` declarations across the frontend sources. */
function asyncHandlers(): Handler[] {
  const handlers: Handler[] = [];
  for (const file of sources) {
    const pattern = /\basync function\s+([A-Za-z0-9_]+)\s*\(/g;
    let match: RegExpExecArray | null;
    while ((match = pattern.exec(file.text)) !== null) {
      handlers.push({ file: file.path, name: match[1], body: functionBody(file.text, match.index) });
    }
  }
  return handlers;
}

/** Handlers that talk to the backend and therefore can fail at any moment. */
function apiHandlers(): Handler[] {
  return asyncHandlers().filter(handler => /await\s+request(Json|Text)\s*[<(]/.test(handler.body));
}

test('the scan actually finds the API handlers it is supposed to guard', () => {
  const handlers = apiHandlers();
  assert.ok(handlers.length >= 15, `expected the app shell handlers, found ${handlers.length}`);
  const names = handlers.map(handler => handler.name);
  for (const expected of ['createTournament', 'savePlayer', 'saveSettings', 'setPlayerStatus']) {
    assert.ok(names.includes(expected), `${expected} must be part of the scan`);
  }
});

test('every API handler reports its failure instead of rejecting silently', () => {
  const offenders = apiHandlers()
    .filter(handler => !/\bcatch\s*(\(|\{)/.test(handler.body))
    .map(handler => `${handler.name} (${handler.file})`);

  assert.deepEqual(
    offenders,
    [],
    'an async handler without catch turns a backend failure into a dead-looking button',
  );
});

test('every API handler surfaces the failure to the user, not only to the console', () => {
  const offenders = apiHandlers()
    .filter(handler => !/\b(setError|reportActionFailure|setLocalError|setDestructiveDialog)\s*\(/.test(handler.body))
    .map(handler => `${handler.name} (${handler.file})`);

  assert.deepEqual(offenders, [], 'a caught error that is never rendered is still a silent failure');
});

test('no rejection handler falls back to the raw Error.message of a transport failure', () => {
  const offenders: string[] = [];
  for (const file of sources) {
    file.text.split(/\r?\n/).forEach((line, index) => {
      if (/\.catch\(/.test(line) && /instanceof Error \? \w+\.message/.test(line)) {
        offenders.push(`${file.path}:${index + 1}`);
      }
    });
  }

  assert.deepEqual(
    offenders,
    [],
    'transport failures must go through describeApiError, otherwise the raw browser wording returns',
  );
});

test('the create-tournament flow blocks a second submit while a request is in flight', () => {
  const shell = sources.find(file => file.path.endsWith(join('app', 'App.tsx')))!;
  const declaration = shell.text.indexOf('async function createTournament');
  assert.notEqual(declaration, -1);
  const body = functionBody(shell.text, declaration);

  assert.match(body, /createTournamentInFlight\.current/, 'a ref guard is needed: state updates lag behind a double click');
  assert.match(body, /setCreatingTournament\(true\)/);
  assert.match(body, /finally\s*\{/, 'the busy flag has to be released on every path');

  // Two rapid submits used to create two identical tournaments; reproduced in
  // the Firefox smoke against the portable build.
  const guardIndex = body.indexOf('createTournamentInFlight.current');
  const requestIndex = body.indexOf('requestJson');
  assert.ok(guardIndex < requestIndex, 'the guard has to run before the request is sent');
});

test('the submit button is disabled while the tournament is being created', () => {
  const shell = sources.find(file => file.path.endsWith(join('app', 'App.tsx')))!;
  assert.match(
    shell.text,
    /type="submit" disabled=\{[^}]*creatingTournament[^}]*\}/,
    'the visible button state must follow the in-flight guard',
  );
});

test('a transport failure makes the backend chip honest instead of leaving it green', () => {
  const shell = sources.find(file => file.path.endsWith(join('app', 'App.tsx')))!;
  const declaration = shell.text.indexOf('function reportActionFailure');
  assert.notEqual(declaration, -1, 'the shared failure exit must exist');
  const body = functionBody(shell.text, declaration);

  assert.match(body, /isApiTransportError/, 'only transport failures may flip the readiness state');
  assert.match(body, /setBackendReadiness\('unreachable'\)/);
  assert.match(body, /setHealth\(null\)/, 'a stale "online" chip after a failed call is a lie');
});
