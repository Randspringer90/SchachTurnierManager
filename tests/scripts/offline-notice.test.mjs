import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { readNetworkHint, subscribeNetworkHint } from '../../src/SchachTurnierManager.WebApp/public/offline-notice/state.js';
import { installOfflineNotice } from '../../src/SchachTurnierManager.WebApp/public/offline-notice/ui.js';

function browser(value = true) {
  const target = new EventTarget();
  let current = value, reads = 0, blocked = false;
  const navigator = { get onLine() { reads++; if (blocked) throw Error('PRIVATE'); return current; } };
  Object.defineProperty(target, 'navigator', { get: () => navigator });
  const installed = new Map();
  const add = target.addEventListener.bind(target), remove = target.removeEventListener.bind(target);
  target.addEventListener = (name, callback) => {
    if (!installed.has(name)) installed.set(name, new Set());
    installed.get(name).add(callback); add(name, callback);
  };
  target.removeEventListener = (name, callback) => { installed.get(name)?.delete(callback); remove(name, callback); };
  return { target, installed, navigator, set(value) { current = value; }, deny(value) { blocked = value; },
    fire(name) { target.dispatchEvent(new Event(name)); }, reads: () => reads,
    count: () => [...installed.values()].reduce((sum, list) => sum + list.size, 0) };
}
function setup(value = true, options = {}) {
  const b = browser(value);
  const panel = { hidden: true }, text = { textContent: '' }, dismiss = new EventTarget();
  const root = { sentinel: 'unchanged' }, element = { lang: options.lang ?? 'de' };
  const nodes = { 'stm-offline-notice': panel, 'stm-offline-message': text, 'stm-offline-dismiss': dismiss, root };
  if (options.missing) delete nodes[options.missing];
  const observers = [];
  if (!options.noObserver) b.target.MutationObserver = class {
    constructor(callback) { this.callback = callback; this.connected = false; observers.push(this); }
    observe(target, settings) { assert.equal(target, element); assert.deepEqual(settings.attributeFilter, ['lang']); this.connected = true; }
    disconnect() { this.connected = false; }
  };
  const document = { documentElement: element, getElementById: id => nodes[id] ?? null };
  const start = () => installOfflineNotice(document, b.target);
  return { ...b, document, panel, text, dismiss, root, observers, start,
    close() { dismiss.dispatchEvent(new Event('click')); },
    language(lang) { element.lang = lang; for (const observer of observers) if (observer.connected) observer.callback([]); } };
}
for (const [value, expected] of [[false,'offline'],[true,'online-hint'],[null,'unknown'],[undefined,'unknown'],[0,'unknown'],['false','unknown']]) {
  test(`connectivity ${JSON.stringify(value)} is interpreted strictly`, () => assert.equal(readNetworkHint({navigator:{onLine:value}}), expected));
}
test('unavailable navigator does not leak its error', () => {
  assert.equal(readNetworkHint({ get navigator() { throw Error('PRIVATE'); } }), 'unknown');
  assert.equal(readNetworkHint(undefined), 'unknown');
});
test('subscriber uses real EventTarget and deduplicates unchanged hints', () => {
  const b = browser(true), values = []; const stop = subscribeNetworkHint(b.target, value => values.push(value));
  b.set(false); b.fire('offline'); b.fire('offline'); b.fire('pageshow');
  b.set(true); b.fire('online'); assert.deepEqual(values, ['online-hint','offline','online-hint']); stop();
});
test('queued offline event cannot override the current online reading', () => {
  const b = browser(true), values = []; subscribeNetworkHint(b.target, value => values.push(value));
  b.fire('offline'); assert.deepEqual(values, ['online-hint']);
});
test('storage, permissions, identities, network requests and navigation are untouched', () => {
  const f = setup(false);
  const deny = { get() { throw Error('Forbidden access'); } };
  for (const property of ['localStorage','sessionStorage','caches','fetch','location','open','Notification','setTimeout','setInterval']) Object.defineProperty(f.target, property, deny);
  for (const property of ['userAgent','languages','permissions','connection','clipboard','geolocation']) Object.defineProperty(f.navigator, property, deny);
  const stop = f.start(); assert.equal(f.panel.hidden, false); f.set(true); f.fire('online'); stop();
});
test('initial online hint does not show a false success banner', () => {
  const f = setup(true); f.start(); assert.equal(f.panel.hidden, true); assert.equal(f.text.textContent, '');
});
test('initial unknown state remains quiet, not green', () => {
  const f = setup(null); f.start(); assert.equal(f.panel.hidden, true); assert.equal(f.text.textContent, '');
});
test('initial offline state immediately warns without touching the app root', () => {
  const f = setup(false); f.start(); assert.equal(f.panel.hidden, false); assert.match(f.text.textContent, /offline/);
  assert.deepEqual(f.root, {sentinel:'unchanged'});
});
test('reconnection keeps a caution instead of claiming data was saved', () => {
  const f = setup(false); f.start(); f.set(true); f.fire('online');
  assert.equal(f.panel.hidden, false); assert.match(f.text.textContent, /noch nicht/);
});
test('unknown reading after offline is not treated as recovery', () => {
  const f = setup(false); f.start(); f.deny(true); f.fire('pageshow');
  assert.match(f.text.textContent, /nicht feststellbar/); assert.doesNotMatch(f.text.textContent, /PRIVATE/);
});
test('dismissal stays in effect for repeated same-state events', () => {
  const f = setup(false); f.start(); f.close(); f.fire('offline'); f.fire('pageshow');
  assert.equal(f.panel.hidden, true); assert.equal(f.text.textContent, '');
});
test('a new disconnection can warn after an earlier dismissal', () => {
  const f = setup(false); f.start(); f.close(); f.set(true); f.fire('online'); f.close();
  f.set(false); f.fire('offline'); assert.equal(f.panel.hidden, false); assert.match(f.text.textContent, /offline/);
});
test('restoring a page rechecks the current state', () => {
  const f = setup(true); f.start(); f.set(false); f.fire('pageshow'); assert.equal(f.panel.hidden, false);
});
for (const [lang, phrase] of [['de','Der Browser'],['en','The browser'],['es','El navegador'],['es-AR','El navegador'],['fr','The browser'],['__proto__','The browser']]) {
  test(`notice language ${lang} uses fixed text and correct language attribution`, () => {
    const f = setup(false,{lang}); f.start(); assert.match(f.text.textContent, new RegExp(phrase));
    assert.equal(f.panel.lang, lang.startsWith('es') ? 'es' : lang === 'de' ? 'de' : 'en');
    assert.equal(f.panel.dir, 'ltr');
  });
}
test('visible notice follows language changes without claiming a network change', () => {
  const f = setup(false); f.start(); const reads = f.reads(); f.language('es');
  assert.match(f.text.textContent, /^El navegador/); assert.equal(f.reads(), reads);
});
test('language changes do not resurrect a dismissed notice', () => {
  const f = setup(false); f.start(); f.close(); f.language('en'); assert.equal(f.panel.hidden, true);
});
test('missing MutationObserver still provides event-based warnings', () => {
  const f = setup(true,{noObserver:true}); f.start(); f.set(false); f.fire('offline'); assert.equal(f.panel.hidden, false);
});
test('duplicate installation does not add listeners', () => {
  const f = setup(false); const a = f.start(), b = f.start(); assert.equal(a, b); assert.equal(f.count(), 3); assert.equal(f.observers.length,1);
});
test('cleanup removes listeners and pending callbacks are inert', () => {
  const f = setup(false); const stop = f.start(); const queued = [...f.installed.get('offline')][0];
  stop(); stop(); queued(); f.observers[0].callback([]); f.close();
  assert.equal(f.count(),0); assert.equal(f.panel.hidden,true); assert.equal(f.text.textContent,'');
  assert.equal(f.observers[0].connected,false);
});
test('a disposed controller can be installed again', () => {
  const f = setup(false); const a = f.start(); a(); const b = f.start(); assert.notEqual(a,b); assert.equal(f.panel.hidden,false); b();
});
for (const missing of ['stm-offline-notice','stm-offline-message','stm-offline-dismiss']) test(`missing ${missing} is a no-op`, () => {
  const f = setup(false,{missing}); f.start()(); assert.equal(f.count(),0);
});
test('undefined target causes no subscription', () => {
  const f=setup(); installOfflineNotice(f.document,undefined)(); assert.equal(f.count(),0);
});
test('partly installed network listeners are removed if setup fails', () => {
  const f=setup(); const add=f.target.addEventListener;
  f.target.addEventListener=(name,callback)=>{if(name==='offline')throw Error('setup');add(name,callback);};
  assert.throws(()=>f.start(),/setup/); assert.equal(f.count(),0); assert.equal(f.panel.hidden,true);
});
test('consumer errors during initial state are not mistaken for missing connectivity', () => {
  const b=browser(false); assert.throws(()=>subscribeNetworkHint(b.target,()=>{throw Error('consumer');}),/consumer/); assert.equal(b.count(),0);
});
test('observer setup failure cleans up the already installed controller', () => {
  const f=setup(false); f.target.MutationObserver=class {observe(){throw Error('observer');} disconnect(){}};
  assert.throws(()=>f.start(),/observer/); assert.equal(f.count(),0); assert.equal(f.panel.hidden,true);
});
const base=new URL('../../src/SchachTurnierManager.WebApp/',import.meta.url);
const html=readFileSync(new URL('index.html',base),'utf8');
const css=readFileSync(new URL('public/offline-notice/style.css',base),'utf8');
test('entry integrates a hidden inline notice before root, not a new page/window',()=>{
  assert.match(html,/<section id="stm-offline-notice"[^>]+hidden>/);
  assert.ok(html.indexOf('id="stm-offline-notice"')<html.indexOf('id="root"'));
  assert.match(html,/src="\/offline-notice\/main.js"/);
  assert.match(html,/id="stm-offline-message" role="status" aria-live="polite"/);
  assert.doesNotMatch(html,/onclick=|target="_blank"/);
});
test('notice is keyboard-accessible, respects hidden and does not cover the UI',()=>{
  assert.match(html,/id="stm-offline-dismiss" type="button"/);
  assert.match(css,/:focus-visible/);assert.match(css,/\[hidden\]/);assert.doesNotMatch(css,/position:\s*(fixed|absolute)/);
});
