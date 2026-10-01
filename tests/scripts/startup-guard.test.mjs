import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';

const web = new URL('../../src/SchachTurnierManager.WebApp/', import.meta.url);
const source = readFileSync(new URL('public/startup-guard.js', web), 'utf8');
const html = readFileSync(new URL('index.html', web), 'utf8');
const css = readFileSync(new URL('public/startup-guard.css', web), 'utf8');

function harness(options = {}) {
  const root = { childElementCount: options.mounted ? 1 : 0 };
  const panel = { hidden: true, dataset: {} };
  const heading = { textContent: 'loading heading' };
  const message = { textContent: 'loading message' };
  const elements = { root, 'stm-startup-status': panel, 'stm-startup-heading': heading, 'stm-startup-message': message };
  if (options.missing) delete elements[options.missing];
  const events = new Map(); const timers = new Map(); const observers = [];
  let nextTimer = 0; let forbiddenCalls = 0;
  const forbidden = () => { forbiddenCalls++; throw Error('Unexpected side effect'); };
  const win = {
    addEventListener(name, fn, capture = false) {
      const list = events.get(name) ?? []; list.push({ fn, capture }); events.set(name, list);
    },
    removeEventListener(name, fn, capture = false) {
      events.set(name, (events.get(name) ?? []).filter(item => item.fn !== fn || item.capture !== capture));
    },
    setTimeout(fn, delay) { const id = ++nextTimer; timers.set(id, { fn, delay }); return id; },
    clearTimeout(id) { timers.delete(id); },
    location: { reload: forbidden }, fetch: forbidden,
  };
  for (const key of ['localStorage', 'sessionStorage', 'navigator', 'caches']) {
    Object.defineProperty(win, key, { get: forbidden });
  }
  const document = { getElementById: id => elements[id] ?? null };
  class Observer {
    constructor(fn) { this.fn = fn; this.connected = false; observers.push(this); }
    observe(target, config) { assert.equal(target, root); assert.equal(config.childList, true); this.connected = true; }
    disconnect() { this.connected = false; }
  }
  const context = { window: win, document, MutationObserver: options.noObserver ? undefined : Observer, fetch: forbidden };
  function run(code = source) { runInNewContext(code, context, { timeout: 1000 }); }
  function emit(name, event = {}) { for (const item of [...(events.get(name) ?? [])]) item.fn(event); }
  function mount() { root.childElementCount++; for (const observer of observers) if (observer.connected) observer.fn([]); }
  function tick() { for (const [id, timer] of [...timers]) { timers.delete(id); timer.fn(); } }
  return { root, panel, heading, message, events, timers, observers, win, document, run, emit, mount, tick,
    sideEffects: () => forbiddenCalls, listeners: () => [...events.values()].reduce((sum, list) => sum + list.length, 0) };
}

test('empty app displays a loading status without changing the app root', () => {
  const h = harness(); h.run(); assert.equal(h.panel.hidden, false); assert.equal(h.panel.dataset.state, 'loading');
  assert.equal(h.root.childElementCount, 0); assert.equal(h.heading.textContent, 'loading heading');
});
test('already mounted app never displays fallback', () => {
  const h = harness({ mounted: true }); h.run(); assert.equal(h.panel.hidden, true);
  assert.equal(h.panel.dataset.state, 'mounted'); assert.equal(h.listeners(), 0); assert.equal(h.timers.size, 0);
});
test('one finite 15 second deadline is scheduled', () => {
  const h = harness(); h.run(); assert.equal(h.timers.size, 1); assert.equal([...h.timers.values()][0].delay, 15000);
});
test('deadline with empty root gives recovery guidance', () => {
  const h = harness(); h.run(); h.tick(); assert.equal(h.panel.dataset.state, 'recovery');
  assert.match(h.message.textContent, /Turnierrechner/); assert.equal(h.root.childElementCount, 0);
});
test('normal render hides fallback and releases resources', () => {
  const h = harness(); h.run(); h.mount(); assert.equal(h.panel.hidden, true); assert.equal(h.listeners(), 0);
  assert.equal(h.timers.size, 0); assert.equal(h.observers[0].connected, false);
});
test('late render after deadline recovers without reload', () => {
  const h = harness(); h.run(); h.tick(); h.mount(); assert.equal(h.panel.hidden, true);
  assert.equal(h.panel.dataset.state, 'mounted'); assert.equal(h.sideEffects(), 0);
});
for (const [label, target] of [['script', () => ({ tagName: 'SCRIPT' })], ['runtime', h => h.win], ['document', h => h.document]]) {
  test(`${label} startup error displays only fixed recovery text`, () => {
    const h = harness(); h.run(); h.emit('error', { target: target(h), message: 'PRIVATE-SYNTHETIC-DETAIL' });
    assert.equal(h.panel.dataset.state, 'recovery'); assert.equal(h.message.textContent.includes('PRIVATE'), false);
  });
}
for (const tagName of ['IMG', 'LINK', 'VIDEO']) {
  test(`${tagName} resource error alone is not an app failure`, () => {
    const h = harness(); h.run(); h.emit('error', { target: { tagName } }); assert.equal(h.panel.dataset.state, 'loading');
  });
}
test('rejection values are never inspected or rendered', () => {
  const h = harness(); h.run(); const event = {};
  Object.defineProperty(event, 'reason', { get() { throw Error('Private rejection read'); } });
  h.emit('unhandledrejection', event); assert.equal(h.panel.dataset.state, 'recovery');
});
test('runtime error details and prevention methods are never touched', () => {
  const h = harness(); h.run(); const event = { target: h.win, preventDefault() { throw Error('Suppressed error'); } };
  for (const key of ['message', 'filename', 'error']) Object.defineProperty(event, key, { get() { throw Error('Private error read'); } });
  h.emit('error', event); assert.equal(h.panel.dataset.state, 'recovery');
});
test('first app content wins over a concurrent error', () => {
  const h = harness(); h.run(); h.root.childElementCount = 1; h.emit('error', { target: h.win });
  assert.equal(h.panel.hidden, true); assert.equal(h.panel.dataset.state, 'mounted');
});
test('already queued deadline cannot overwrite the mounted state', () => {
  const h = harness(); h.run(); const delayed = [...h.timers.values()][0].fn;
  h.mount(); delayed(); assert.equal(h.panel.dataset.state, 'mounted'); assert.equal(h.panel.hidden, true);
});
test('duplicate execution does not add timers or listeners', () => {
  const h = harness(); h.run(); h.run(); assert.equal(h.timers.size, 1); assert.equal(h.listeners(), 3); assert.equal(h.observers.length, 1);
});
test('execution after successful mount stays inactive', () => {
  const h = harness(); h.run(); h.mount(); h.run(); assert.equal(h.listeners(), 0); assert.equal(h.timers.size, 0);
});
for (const missing of ['root', 'stm-startup-status', 'stm-startup-heading', 'stm-startup-message']) {
  test(`missing ${missing} leaves the application untouched`, () => {
    const h = harness({ missing }); h.run(); assert.equal(h.listeners(), 0); assert.equal(h.timers.size, 0);
  });
}
test('observer-less browser checks mount on load', () => {
  const h = harness({ noObserver: true }); h.run(); h.root.childElementCount = 1; h.emit('load'); assert.equal(h.panel.hidden, true);
});
test('observer-less browser checks mount at deadline', () => {
  const h = harness({ noObserver: true }); h.run(); h.root.childElementCount = 1; h.tick(); assert.equal(h.panel.hidden, true);
});
test('no app content at load is not a confirmed failure', () => {
  const h = harness(); h.run(); h.emit('load'); assert.equal(h.panel.dataset.state, 'loading');
});
test('repeated failures are idempotent and never reload or access storage', () => {
  const h = harness(); h.run(); h.emit('unhandledrejection'); const expected = h.message.textContent;
  h.emit('unhandledrejection'); h.emit('error', { target: h.win }); h.tick();
  assert.equal(h.message.textContent, expected); assert.equal(h.sideEffects(), 0);
});
test('error listener captures module-resource errors', () => {
  const h = harness(); h.run(); assert.equal(h.events.get('error')[0].capture, true);
});
test('post-mount errors are left to application error handling', () => {
  const h = harness(); h.run(); h.mount(); h.emit('error', { target: h.win }); h.emit('unhandledrejection');
  assert.equal(h.panel.hidden, true); assert.equal(h.panel.dataset.state, 'mounted');
});
test('no-op negative control would leave the root blank', () => {
  const h = harness(); h.run(''); assert.equal(h.panel.hidden, true); assert.equal(h.listeners(), 0); assert.equal(h.root.childElementCount, 0);
});
test('HTML includes separate visible noscript guidance', () => {
  assert.match(html, /<noscript><section[^>]*>[\s\S]*JavaScript[\s\S]*<\/noscript>/);
  const noscript = html.match(/<noscript>([\s\S]*?)<\/noscript>/)[1]; assert.equal(/\bhidden\b/.test(noscript), false);
});
test('recovery remains hidden when the guard itself cannot be fetched', () => {
  assert.match(html, /<section id="stm-startup-status"[^>]*\bhidden\b/);
});
test('loading and failure text has a polite, atomic status region', () => {
  assert.match(html, /id="stm-startup-message"[^>]*role="status"[^>]*aria-live="polite"[^>]*aria-atomic="true"/);
});
test('retry is a manual same-origin link, without inline handlers', () => {
  assert.match(html, /<a href="\/">Startseite erneut/); assert.equal(/\bonclick\s*=/.test(html), false);
});
test('classic deferred guard is listed before the main module', () => {
  assert.match(html, /<script defer src="\/startup-guard.js"><\/script>/);
  assert.ok(html.indexOf('/startup-guard.js') < html.indexOf('/src/main.tsx'));
  assert.match(html, /<div id="root"><\/div>/);
});
test('fallback styling respects hidden and keyboard focus', () => {
  assert.match(css, /\.stm-startup-status\[hidden\]/); assert.match(css, /:focus-visible/);
  assert.match(css, /#root:not\(:empty\) \+ \.stm-startup-status/);
});
test('fallback code contains no root or HTML-content writer', () => {
  assert.doesNotMatch(source, /innerHTML|outerHTML|replaceChildren|document\.write/);
});
