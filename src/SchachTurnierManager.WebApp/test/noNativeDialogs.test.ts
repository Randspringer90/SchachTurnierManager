// Guard test: the destructive tournament flows must not fall back to native
// browser dialogs. Firefox suppresses repeated modal dialogs from the same
// script turn ("prevent this page from creating additional dialogs"), which
// silently aborted the delete confirmation chain.
//
// The scan covers the whole frontend source tree so the regression cannot
// reappear in a newly extracted module either.
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
const appShell = sources.find(file => file.path.endsWith(join('app', 'App.tsx')));

/** Lines calling a native modal dialog, with their file for a useful message. */
function nativeDialogLines(): Array<{ path: string; line: string }> {
  return sources.flatMap(file =>
    file.text
      .split(/\r?\n/)
      .map(line => line.trim())
      .filter(line => /\bwindow\.(confirm|prompt|alert)\s*\(/.test(line))
      .map(line => ({ path: file.path, line }))
  );
}

const DESTRUCTIVE = /löschen|loeschen|zurücksetzen|zuruecksetzen|delete|reset/i;

test('the frontend sources are discoverable and the app shell is extracted', () => {
  assert.ok(sources.length > 5, 'expected a modular source tree');
  assert.ok(appShell, 'src/app/App.tsx must exist');
});

test('no destructive flow uses window.confirm, window.prompt or window.alert', () => {
  const offenders = nativeDialogLines().filter(entry => DESTRUCTIVE.test(entry.line));
  assert.deepEqual(
    offenders,
    [],
    'destructive flows must use the in-app ConfirmDialog'
  );
});

test('the in-app confirmation dialog is wired into the tournament admin area', () => {
  const text = appShell!.text;
  assert.match(text, /ConfirmDialog/, 'ConfirmDialog must be rendered');
  assert.match(text, /openDestructiveDialog\('reset'\)/, 'reset button opens the dialog');
  assert.match(text, /openDestructiveDialog\('delete'\)/, 'delete button opens the dialog');
});

test('main.tsx is a bootstrap only and holds no application logic', () => {
  const main = sources.find(file => file.path.endsWith(join('src', 'main.tsx')));
  assert.ok(main, 'src/main.tsx must exist');
  const lineCount = main!.text.split(/\r?\n/).filter(line => line.trim() !== '').length;
  assert.ok(lineCount < 60, `main.tsx should stay a thin bootstrap, has ${lineCount} code lines`);
  assert.doesNotMatch(main!.text, /React\.useState/, 'no component state belongs in the bootstrap');
});
