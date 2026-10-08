import test from 'node:test';
import assert from 'node:assert/strict';
import { inspectBrowser } from '../../src/SchachTurnierManager.WebApp/public/browser-check/core.js';

function environment() {
  const unused = () => { throw Error('API must not be invoked'); };
  function Binary() {} Binary.prototype.arrayBuffer = unused; Binary.prototype.stream = unused;
  return {
    isSecureContext: true, File: unused, Blob: Binary, TextEncoder: unused, TextDecoder: unused,
    ReadableStream: unused, AbortController: unused,
    crypto: { subtle: { digest: unused } }, navigator: { serviceWorker: { register: unused } },
  };
}

test('complete surface is detected without invoking any browser API', () => {
  const report = inspectBrowser(environment());
  assert.equal(report.executionVerified, false); assert.equal(report.schemaVersion, 1);
  assert.equal(Object.keys(report.checks).length, 10);
  assert.ok(Object.values(report.checks).every(value => value === 'available'));
  assert.ok(Object.values(report.features).every(value => value === 'available'));
});
for (const [key, expected] of [
  ['File', 'fileObjects'], ['Blob', 'arrayBuffer'], ['TextEncoder', 'textEncoder'],
  ['TextDecoder', 'textDecoder'], ['ReadableStream', 'readableStream'], ['AbortController', 'abortController'],
  ['crypto', 'sha256Interface'], ['navigator', 'serviceWorkerInterface'],
]) test(`missing ${key} is reported without crashing unrelated checks`, () => {
  const env = environment(); delete env[key]; const report = inspectBrowser(env);
  assert.equal(report.checks[expected], 'missing'); assert.equal(report.checks.secureContext, 'available');
});
for (const key of ['File', 'Blob', 'TextEncoder', 'TextDecoder', 'ReadableStream', 'AbortController', 'crypto', 'navigator']) test(`denied ${key} getter remains unknown`, () => {
  const env = environment(); Object.defineProperty(env, key, { get() { throw Error('PRIVATE'); } });
  const output = JSON.stringify(inspectBrowser(env)); assert.ok(output.includes('unknown')); assert.ok(!output.includes('PRIVATE'));
});
test('insecure context prevents PWA/checksum prerequisites even if interfaces appear', () => {
  const env = environment(); env.isSecureContext = false; const result = inspectBrowser(env);
  assert.equal(result.checks.sha256Interface, 'available'); assert.equal(result.features.backupChecksum, 'missing');
  assert.equal(result.features.serviceWorkerPrerequisites, 'missing'); assert.equal(result.features.localBackupTools, 'available');
});
for (const value of [undefined, null, 'true', 1]) test(`unknown context ${JSON.stringify(value)} is not a positive result`, () => {
  const env = environment(); env.isSecureContext = value; const result = inspectBrowser(env);
  assert.equal(result.checks.secureContext, 'unknown'); assert.equal(result.features.backupChecksum, 'unknown');
});
test('separate Blob capabilities do not imply each other', () => {
  const env = environment(); delete env.Blob.prototype.stream; const result = inspectBrowser(env);
  assert.equal(result.features.localBackupTools, 'available'); assert.equal(result.features.streamingRatingSearch, 'missing');
});
test('missing function is not accepted merely because a property exists', () => {
  const env = environment(); env.crypto.subtle.digest = true; env.navigator.serviceWorker.register = 'yes';
  const result = inspectBrowser(env); assert.equal(result.checks.sha256Interface, 'missing'); assert.equal(result.checks.serviceWorkerInterface, 'missing');
});
test('nested property denial is isolated and not leaked', () => {
  const env = environment(); Object.defineProperty(env.crypto, 'subtle', { get() { throw Error('PRIVATE'); } });
  const result = inspectBrowser(env); assert.equal(result.checks.sha256Interface, 'unknown'); assert.equal(result.features.backupChecksum, 'unknown');
  assert.equal(result.features.localBackupTools, 'available');
});
test('identity, storage, permission, connection and window APIs are untouched', () => {
  const env = environment();
  const deny = { get() { throw Error('Sensitive read'); } };
  for (const key of ['userAgent', 'platform', 'hardwareConcurrency', 'deviceMemory', 'languages', 'permissions', 'clipboard', 'geolocation', 'mediaDevices']) Object.defineProperty(env.navigator, key, deny);
  for (const key of ['localStorage', 'sessionStorage', 'caches', 'location', 'screen', 'fetch', 'open']) Object.defineProperty(env, key, deny);
  assert.ok(Object.values(inspectBrowser(env).features).every(value => value === 'available'));
});
test('result schema is fixed and does not copy arbitrary properties', () => {
  const env = environment(); env.privateData = 'PRIVATE'; env.navigator.extra = 'PRIVATE';
  const result = inspectBrowser(env);
  assert.deepEqual(Object.keys(result).sort(), ['checks', 'executionVerified', 'features', 'schemaVersion']);
  assert.ok(!JSON.stringify(result).includes('PRIVATE'));
});
test('undefined environment is handled without global access', () => {
  const result = inspectBrowser(undefined); assert.equal(result.checks.secureContext, 'unknown');
  assert.equal(result.features.localBackupTools, 'missing'); assert.equal(result.executionVerified, false);
});
test('checks are repeatable and do not mutate the supplied surface', () => {
  const env = Object.freeze(environment()); assert.deepEqual(inspectBrowser(env), inspectBrowser(env));
});
