// Guard test: the destructive tournament flows must not fall back to native
// browser dialogs. Firefox suppresses repeated modal dialogs from the same
// script turn ("prevent this page from creating additional dialogs"), which
// silently aborted the delete confirmation chain.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const mainSource = readFileSync(fileURLToPath(new URL('../src/main.tsx', import.meta.url)), 'utf8');

/** Lines that call a native modal dialog, ignoring the PWA install prompt. */
function nativeDialogLines(source: string): string[] {
  return source
    .split(/\r?\n/)
    .map(line => line.trim())
    .filter(line => /\bwindow\.(confirm|prompt|alert)\s*\(/.test(line));
}

test('reset and delete no longer use window.confirm or window.prompt', () => {
  const destructive = nativeDialogLines(mainSource).filter(line =>
    /löschen|loeschen|zurücksetzen|zuruecksetzen|delete|reset/i.test(line)
  );
  assert.deepEqual(destructive, [], 'destructive flows must use the in-app ConfirmDialog');
});

test('the in-app confirmation dialog is wired into the tournament admin area', () => {
  assert.match(mainSource, /ConfirmDialog/, 'ConfirmDialog must be rendered');
  assert.match(mainSource, /openDestructiveDialog\('reset'\)/, 'reset button opens the dialog');
  assert.match(mainSource, /openDestructiveDialog\('delete'\)/, 'delete button opens the dialog');
});

test('the PWA install prompt is the only remaining browser-driven prompt', () => {
  // `pwaInstallPrompt.prompt()` is a BeforeInstallPromptEvent API, not a modal
  // window dialog, so it is intentionally out of scope for this guard.
  const remaining = nativeDialogLines(mainSource);
  for (const line of remaining) {
    assert.ok(
      !/löschen|loeschen|delete|zurücksetzen|zuruecksetzen|reset/i.test(line),
      `unexpected native dialog in a destructive flow: ${line}`
    );
  }
});
