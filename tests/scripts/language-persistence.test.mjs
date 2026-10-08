import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { acceptStoredLanguage, selectAndStoreLanguage } from '../../src/SchachTurnierManager.WebApp/src/i18n/language-persistence.ts';
import { subscribeStoredLanguage } from '../../src/SchachTurnierManager.WebApp/src/i18n/language-preference.ts';
import { de } from '../../src/SchachTurnierManager.WebApp/src/i18n/locales/de.ts';
import { en } from '../../src/SchachTurnierManager.WebApp/src/i18n/locales/en.ts';
import { es } from '../../src/SchachTurnierManager.WebApp/src/i18n/locales/es.ts';
const languages = ['de','en','es','fr','it','pt','nl','pl','cs','sv','da','hu','ru','uk','tr','ar','zh','ja'];

test('failed selection survives pageshow and stale storage, then accepts a fresh external preference', () => {
  let stored = 'de', current = 'de', pending = null, sessionOnly = false;
  const events = new Map();
  const storage = { getItem() { return stored; }, setItem() { throw Error('synthetic denied write'); } };
  const target = { localStorage: storage, addEventListener(name, fn) { events.set(name, fn); }, removeEventListener(name) { events.delete(name); } };
  const dispose = subscribeStoredLanguage(target, 'stm.language', languages, (lang, source) => {
    if (!acceptStoredLanguage(lang, source, pending)) return;
    current = lang; pending = null; sessionOnly = false;
  });
  sessionOnly = selectAndStoreLanguage('ar', languages, lang => { current = lang; }, lang => storage.setItem('stm.language', lang)) === 'session-only';
  pending = { stored };
  events.get('pageshow')();
  events.get('storage')({ key: 'stm.language', storageArea: storage });
  assert.equal(current, 'ar'); assert.equal(sessionOnly, true);
  stored = 'es'; events.get('storage')({ key: 'stm.language', storageArea: storage });
  assert.equal(current, 'es'); assert.equal(sessionOnly, false);
  dispose(); assert.equal(events.size, 0);
});
for (const language of languages) test(`explicit ${language} selection updates session before persistence`, () => {
  const calls = [];
  const result = selectAndStoreLanguage(language, languages,
    value => calls.push(['select', value]), value => calls.push(['store', value]));
  assert.equal(result, 'stored');
  assert.deepEqual(calls, [['select', language], ['store', language]]);
});
for (const candidate of [null, undefined, '', 'EN', 'en-US', ' en ', '__proto__', 'constructor', {}, 42]) {
  test(`unsupported selection ${JSON.stringify(candidate)} has no effect`, () => {
    const denied = () => { throw Error('Unexpected access'); };
    assert.equal(selectAndStoreLanguage(candidate, languages, denied, denied), 'ignored');
  });
}
for (const failure of [new Error('PRIVATE synthetic failure'), null, 0, 'PRIVATE', { get message() { throw Error('Do not read'); } }]) {
  test(`any failed storage write keeps the language without exposing its error ${typeof failure}`, () => {
    let selected = 'de';
    const result = selectAndStoreLanguage('es', languages, value => { selected = value; }, () => { throw failure; });
    assert.equal(result, 'session-only'); assert.equal(selected, 'es');
  });
}
test('rendering callback errors remain errors and never touch storage', () => {
  let writes = 0;
  assert.throws(() => selectAndStoreLanguage('en', languages, () => { throw Error('state failure'); }, () => { writes++; }), /state failure/);
  assert.equal(writes, 0);
});
test('a later successful selection clears session-only status', () => {
  let current = 'de', unavailable = true;
  const choose = lang => selectAndStoreLanguage(lang, languages, value => { current = value; }, () => { if (unavailable) throw Error(); });
  assert.equal(choose('es'), 'session-only'); assert.equal(current, 'es');
  unavailable = false; assert.equal(choose('en'), 'stored'); assert.equal(current, 'en');
});
test('frozen supported language list is not mutated', () => {
  const supported = Object.freeze(['de','en']);
  assert.equal(selectAndStoreLanguage('de', supported, () => {}, () => {}), 'stored');
  assert.deepEqual(supported, ['de','en']);
});
test('empty allowlist rejects before callbacks', () => {
  assert.equal(selectAndStoreLanguage('de', [], () => { throw Error(); }, () => { throw Error(); }), 'ignored');
});
for (const [name, dictionary] of Object.entries({de, en, es})) test(`${name} supplies an explicit nonempty session-only message`, () => {
  assert.equal(typeof dictionary['language.sessionOnly'], 'string');
  assert.ok(dictionary['language.sessionOnly'].trim().length > 20);
  assert.doesNotMatch(dictionary['language.sessionOnly'], /<[^>]*>|\{[^}]*\}/);
});
const source = readFileSync(new URL('../../src/SchachTurnierManager.WebApp/src/i18n/index.tsx', import.meta.url), 'utf8');
test('provider actually uses the tested helper and exposes the warning state', () => {
  assert.match(source, /const result = selectAndStoreLanguage\(/);
  assert.match(source, /if \(result !== 'ignored'\) setLanguageIsSessionOnly\(result === 'session-only'\)/);
  assert.match(source, /\[lang, languageIsSessionOnly\]/);
});
test('warning uses a unique description and polite live region without dialogs', () => {
  assert.match(source, /const persistenceHintId = useId\(\)/);
  assert.match(source, /aria-describedby=\{languageIsSessionOnly \? persistenceHintId : undefined\}/);
  assert.match(source, /role="status" aria-live="polite" aria-atomic="true"/);
  assert.match(source, /languageIsSessionOnly \? t\('language.sessionOnly'\) : ''/);
  assert.doesNotMatch(source, /\balert\(|\bconfirm\(|window\.open|location\.reload/);
});
