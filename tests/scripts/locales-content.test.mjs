import test from 'node:test';
import assert from 'node:assert/strict';
import { de } from '../../src/SchachTurnierManager.WebApp/src/i18n/locales/de.ts';

// This delivery covers the established UI shell. Later feature keys may still
// use the provider's existing fallback until their own translation is reviewed.
const coveredKeys = [
  'app.title', 'hero.eyebrow', 'hero.subtitle',
  'backend.title', 'backend.checking', 'backend.online', 'backend.offline',
  'language.label', 'operator.backend', 'operator.tournament',
  'operator.noTournament', 'operator.round', 'operator.openResults',
  'operator.active', 'operator.inactive', 'operator.lastBackup',
  'operator.backupRecommended', 'operator.backupCurrent', 'operator.backupNone',
  'operator.nextStep', 'common.save', 'common.cancel', 'common.delete',
  'common.edit', 'common.close', 'common.export', 'common.import',
  'common.print', 'common.search', 'common.loading', 'common.error',
  'common.yes', 'common.no',
];
const languages = ['de', 'en', 'es', 'fr', 'it', 'pt', 'nl', 'pl', 'cs', 'sv', 'da', 'hu', 'ru', 'uk', 'tr', 'ar', 'zh', 'ja'];
const placeholders = value => [...value.matchAll(/\{([^{}]+)\}/g)].map(match => match[1]).sort();

test('covered keys are unique and still part of the canonical base', () => {
  assert.equal(new Set(coveredKeys).size, coveredKeys.length);
  for (const key of coveredKeys) assert.ok(Object.hasOwn(de, key), key);
});

for (const language of languages) {
  test(`${language}: shell text is explicit, nonempty and compatible with the base`, async () => {
    const url = new URL(`../../src/SchachTurnierManager.WebApp/src/i18n/locales/${language}.ts`, import.meta.url);
    const dictionary = (await import(url.href))[language];
    assert.ok(dictionary && typeof dictionary === 'object');
    for (const key of coveredKeys) {
      assert.ok(Object.hasOwn(dictionary, key), `Missing ${language}/${key}`);
      const value = dictionary[key];
      assert.equal(typeof value, 'string', key);
      assert.equal(value, value.trim(), key);
      assert.ok(value.length > 0, key);
      assert.doesNotMatch(value, /[\u0000-\u001f\u007f\u202a-\u202e\u2066-\u2069\ufffd]/u, key);
      assert.doesNotMatch(value, /<\/?[a-z][^>]*>/i, key);
      assert.deepEqual(placeholders(value), placeholders(de[key]), key);
    }
    for (const key of Object.keys(dictionary)) assert.ok(Object.hasOwn(de, key), `Unknown ${language}/${key}`);
    assert.equal(dictionary['app.title'], 'SchachTurnierManager');
    assert.notEqual(dictionary['common.yes'], dictionary['common.no']);
    assert.notEqual(dictionary['common.save'], dictionary['common.delete']);
    assert.notEqual(dictionary['backend.online'], dictionary['backend.offline']);
    assert.notEqual(dictionary['operator.active'], dictionary['operator.inactive']);
  });
}

for (const language of ['ar', 'ja', 'zh', 'ru', 'uk']) {
  test(`${language}: representative action uses the intended script`, async () => {
    const dictionary = (await import(new URL(`../../src/SchachTurnierManager.WebApp/src/i18n/locales/${language}.ts`, import.meta.url)))[language];
    const scripts = { ar: /\p{Script=Arabic}/u, ja: /[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}]/u,
      zh: /\p{Script=Han}/u, ru: /\p{Script=Cyrillic}/u, uk: /\p{Script=Cyrillic}/u };
    assert.equal(typeof dictionary['common.save'], 'string');
    assert.match(dictionary['common.save'], scripts[language]);
  });
}
