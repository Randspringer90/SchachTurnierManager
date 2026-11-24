import test from 'node:test';
import assert from 'node:assert/strict';
import { de } from '../../src/SchachTurnierManager.WebApp/src/i18n/locales/de.ts';
import { en } from '../../src/SchachTurnierManager.WebApp/src/i18n/locales/en.ts';
import { translateText } from '../../src/SchachTurnierManager.WebApp/src/i18n/core.ts';

// Operator areas beyond the demo path must provide their own English copy.
const expectations = {
  'workflow.auditJournal': 'Audit journal',
  'workflow.dangerousActions': 'Dangerous actions',
  'workflow.checkImport': 'Check import',
  'workflow.tieBreakOrder': 'Tie-break order',
  'workflow.correctionsAndInterventions': 'Corrections and interventions',
};
for (const [key, expected] of Object.entries(expectations)) {
  test(`${key}: English operator workflow does not fall back to German`, () => {
    assert.equal(Object.hasOwn(de, key), true);
    assert.equal(Object.hasOwn(en, key), true);
    assert.equal(translateText(key, [en, de]), expected);
  });
}
test('every canonical DE key has a nonempty English translation with matching placeholders', () => {
  for (const [key, value] of Object.entries(de)) {
    assert.equal(typeof en[key], 'string', key);
    assert.ok(en[key].trim().length > 0, key);
    const params = text => [...text.matchAll(/\{([^{}]+)\}/g)].map(x => x[1]).sort();
    assert.deepEqual(params(en[key]), params(value), key);
  }
});
