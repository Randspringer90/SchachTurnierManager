import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { subscribeStoredLanguage } from '../../src/SchachTurnierManager.WebApp/src/i18n/language-preference.ts';

const supported = ['de', 'en', 'es', 'fr', 'it', 'pt', 'nl', 'pl', 'cs', 'sv', 'da', 'hu', 'ru', 'uk', 'tr', 'ar', 'zh', 'ja'];
function fixture(initial = null, shared = new Map()) {
  if (initial !== null) shared.set('stm.language', initial);
  const listeners = new Map(); let reads = 0, denied = false, getterDenied = false;
  const storage = {
    getItem(key) { reads++; if (denied) throw Error('PRIVATE storage error'); return shared.get(key) ?? null; },
    setItem() { throw Error('Unexpected write'); }, removeItem() { throw Error('Unexpected removal'); }, clear() { throw Error('Unexpected clear'); },
  };
  const target = {
    get localStorage() { if (getterDenied) throw Error('PRIVATE getter error'); return storage; },
    addEventListener(name, fn) { if (!listeners.has(name)) listeners.set(name, new Set()); listeners.get(name).add(fn); },
    removeEventListener(name, fn) { listeners.get(name)?.delete(fn); },
  };
  const emit = (name, event = {}) => { for (const fn of [...(listeners.get(name) ?? [])]) fn(event); };
  const storageEvent = (key = 'stm.language', area = storage, more = {}) => emit('storage', { key, storageArea: area, ...more });
  const changes = [];
  const start = (languages = supported) => subscribeStoredLanguage(target, 'stm.language', languages, value => changes.push(value));
  return { target, storage, shared, listeners, changes, start, storageEvent, emit,
    reads: () => reads, denyRead: value => { denied = value; }, denyGetter: value => { getterDenied = value; } };
}

for (const language of supported) test(`stored supported language ${language} propagates`, () => {
  const f = fixture(); const stop = f.start(); f.shared.set('stm.language', language); f.storageEvent();
  assert.deepEqual(f.changes, [language]); stop();
});
for (const value of [null, '', 'EN', 'en-US', ' english ', '__proto__', 'constructor', '<script>', 42]) test(`invalid preference ${JSON.stringify(value)} stays local`, () => {
  const f = fixture(); f.start(); f.shared.set('stm.language', value); f.storageEvent(); assert.deepEqual(f.changes, []);
});
test('initial reconciliation closes the render-effect gap', () => {
  const f = fixture('es'); f.start(); assert.deepEqual(f.changes, ['es']);
});
test('reads current value rather than an old queued event', () => {
  const f = fixture('de'); f.start(); f.shared.set('stm.language', 'es'); f.storageEvent('stm.language', f.storage, { newValue: 'en', oldValue: 'de' });
  assert.deepEqual(f.changes, ['de', 'es']);
});
test('does not read event values, URLs or unrelated storage keys', () => {
  const f = fixture(); f.start(); f.shared.set('stm.language', 'fr');
  const event = { key: 'stm.language', storageArea: f.storage };
  for (const key of ['newValue', 'oldValue', 'url']) Object.defineProperty(event, key, { get() { throw Error('Unneeded data read'); } });
  f.emit('storage', event); assert.deepEqual(f.changes, ['fr']);
  const before = f.reads(); f.storageEvent('private.other'); assert.equal(f.reads(), before);
});
test('sessionStorage and unspecified storage area are ignored', () => {
  const f = fixture(); f.start(); f.shared.set('stm.language', 'es'); f.storageEvent('stm.language', {}); f.storageEvent('stm.language', null);
  assert.deepEqual(f.changes, []);
});
test('removing or clearing a preference keeps this session language', () => {
  const f = fixture('de'); f.start(); f.shared.delete('stm.language'); f.storageEvent(); f.storageEvent(null);
  assert.deepEqual(f.changes, ['de']);
});
test('queued clear cannot undo a newer valid setting', () => {
  const f = fixture(); f.start(); f.shared.set('stm.language', 'ar'); f.storageEvent(null); assert.deepEqual(f.changes, ['ar']);
});
test('pageshow reconciles preferences after returning from page cache', () => {
  const f = fixture('de'); f.start(); f.shared.set('stm.language', 'ja'); f.emit('pageshow'); assert.deepEqual(f.changes, ['de', 'ja']);
});
test('denied storage getter does not prevent subscription or later recovery', () => {
  const f = fixture('es'); f.denyGetter(true); const stop = f.start(); f.storageEvent(); assert.deepEqual(f.changes, []);
  f.denyGetter(false); f.emit('pageshow'); assert.deepEqual(f.changes, ['es']); stop();
});
test('denied getItem keeps current state and can recover later', () => {
  const f = fixture('de'); f.start(); f.denyRead(true); f.shared.set('stm.language', 'es'); f.storageEvent(); assert.deepEqual(f.changes, ['de']);
  f.denyRead(false); f.storageEvent(); assert.deepEqual(f.changes, ['de', 'es']);
});
test('cleanup removes both subscriptions and queued handlers become inert', () => {
  const f = fixture(); const stop = f.start(); const pending = [...f.listeners.get('storage')][0];
  stop(); stop(); f.shared.set('stm.language', 'es'); pending({ key: 'stm.language', storageArea: f.storage }); f.emit('pageshow');
  assert.deepEqual(f.changes, []); assert.equal(f.listeners.get('storage').size, 0); assert.equal(f.listeners.get('pageshow').size, 0);
});
test('React strict-mode setup-cleanup-setup retains only the current listener', () => {
  const f = fixture(); f.start()(); const stop = f.start(); f.shared.set('stm.language', 'es'); f.storageEvent();
  assert.deepEqual(f.changes, ['es']); assert.equal(f.listeners.get('storage').size, 1); stop();
});
test('two tabs converge without any storage write or event feedback', () => {
  const shared = new Map(); const a = fixture(null, shared), b = fixture(null, shared); a.start(); b.start();
  shared.set('stm.language', 'es'); a.storageEvent(); b.storageEvent();
  assert.deepEqual(a.changes, ['es']); assert.deepEqual(b.changes, ['es']);
  shared.set('stm.language', 'de'); a.storageEvent(); b.storageEvent();
  assert.deepEqual(a.changes, ['es', 'de']); assert.deepEqual(b.changes, ['es', 'de']);
});
test('supported list is snapshotted, not mutated or subsequently broadened', () => {
  const languages = ['de']; const f = fixture(); f.start(languages); languages.push('es'); f.shared.set('stm.language', 'es'); f.storageEvent();
  assert.deepEqual(f.changes, []); assert.deepEqual(languages, ['de', 'es']);
});
test('undefined browser and empty supported list are safe no-ops', () => {
  subscribeStoredLanguage(undefined, 'stm.language', supported, () => { throw Error(); })();
  const f = fixture('de'); f.start([]); assert.deepEqual(f.changes, []);
});
test('consumer exceptions during initial reconciliation clean up before rethrow', () => {
  const f = fixture('de'); assert.throws(() => subscribeStoredLanguage(f.target, 'stm.language', supported, () => { throw Error('consumer'); }), /consumer/);
  assert.equal(f.listeners.get('storage').size, 0); assert.equal(f.listeners.get('pageshow').size, 0);
});
test('wiring uses React state directly, keeping the existing persistence and RTL effects', () => {
  const source = readFileSync(new URL('../../src/SchachTurnierManager.WebApp/src/i18n/index.tsx', import.meta.url), 'utf8');
  assert.match(source, /useEffect\(\(\) => subscribeStoredLanguage\(/);
  assert.match(source, /LANGUAGES\.map\(language => language\.code\),\s*setLangState,/);
  assert.match(source, /localStorage\.setItem\(STORAGE_KEY, next\)/);
  assert.match(source, /document\.documentElement\.dir = info\?\.rtl/);
});
test('partially failed listener installation is rolled back', () => {
  const f = fixture('de'); const add = f.target.addEventListener.bind(f.target);
  f.target.addEventListener = (name, fn) => { if (name === 'pageshow') throw Error('listener failure'); add(name, fn); };
  assert.throws(() => f.start(), /listener failure/);
  assert.equal(f.listeners.get('storage').size, 0);
});
