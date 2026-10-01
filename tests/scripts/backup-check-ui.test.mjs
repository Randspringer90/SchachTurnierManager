import test from 'node:test';
import assert from 'node:assert/strict';
import { mountBackupCheck } from '../../src/SchachTurnierManager.WebApp/public/backup-check/app.mjs';
import { readFileSync } from 'node:fs';

const bytes = name => new TextEncoder().encode(JSON.stringify({ id: '10000000-0000-0000-0000-000000000001', name, createdOn: '2026-10-01', settings: {}, players: [], rounds: [], auditJournal: [] }));
function dom() {
  class Element {
    constructor(tag = 'div') { this.tagName = tag; this.textContent = ''; this.children = []; this.handlers = new Map(); this.value = ''; this.files = []; }
    addEventListener(name, action) { this.handlers.set(name, action); }
    replaceChildren() { this.children = []; this.textContent = ''; }
    append(child) { this.children.push(child); }
    focus() { document.activeElement = this; }
    dispatch(name) { return this.handlers.get(name)?.(); }
  }
  const elements = Object.fromEntries(['backup-file', 'status', 'summary', 'issues', 'reset'].map(id => [id, new Element()]));
  const document = { querySelector: selector => elements[selector.slice(1)], createElement: tag => new Element(tag), activeElement: null };
  mountBackupCheck(document);
  const choose = async (content, options = {}) => {
    elements['backup-file'].files = [{ size: content.length, arrayBuffer: async () => content.buffer, ...options }];
    return elements['backup-file'].dispatch('change');
  };
  return { document, elements, choose };
}

test('mount registers only file selection and reset handlers', () => {
  const { elements } = dom(); assert.deepEqual([...elements['backup-file'].handlers.keys()], ['change']); assert.deepEqual([...elements.reset.handlers.keys()], ['click']);
});
test('file preview is rendered as literal text', async () => {
  const { elements, choose } = dom(); await choose(bytes('<img src=x onerror=alert(1)>'));
  assert.match(elements.status.textContent, /ohne Befund/); assert.equal(elements.summary.children.length, 1);
  assert.equal(elements.summary.children[0].tagName, 'p'); assert.match(elements.summary.children[0].textContent, /<img/);
});
test('invalid JSON clears previous successful summary', async () => {
  const { elements, choose } = dom(); await choose(bytes('Synthetic')); await choose(new TextEncoder().encode('{invalid'));
  assert.equal(elements.summary.children.length, 0); assert.match(elements.issues.children[0].textContent, /gueltiges JSON/);
});
test('size is checked before file contents are read', async () => {
  const { elements, choose } = dom(); let read = false;
  await choose(new Uint8Array(), { size: 5 * 1024 * 1024 + 1, arrayBuffer: async () => { read = true; } });
  assert.equal(read, false); assert.match(elements.status.textContent, /5 MiB/);
});
test('file read failure is bounded and does not expose raw error', async () => {
  const { elements, choose } = dom(); await choose(new Uint8Array(), { arrayBuffer: async () => { throw Error('DO_NOT_REPORT'); } });
  assert.match(elements.status.textContent, /nicht gelesen/); assert.doesNotMatch(elements.status.textContent, /DO_NOT_REPORT/);
});
test('reset clears selected file and returns focus', async () => {
  const { document, elements, choose } = dom(); await choose(bytes('Synthetic')); elements['backup-file'].value = 'selected';
  elements.reset.dispatch('click'); assert.equal(elements['backup-file'].value, ''); assert.equal(elements.summary.children.length, 0);
  assert.equal(document.activeElement, elements['backup-file']);
});
test('latest selection wins when reads complete out of order', async () => {
  const { elements, choose } = dom(); let finish;
  const first = choose(bytes('Old'), { arrayBuffer: () => new Promise(resolve => { finish = resolve; }) });
  await choose(bytes('Latest')); finish(bytes('Old').buffer); await first;
  assert.match(elements.summary.children[0].textContent, /Latest/); assert.doesNotMatch(elements.summary.children[0].textContent, /Old/);
});
test('reset invalidates an in-flight read', async () => {
  const { elements, choose } = dom(); let finish;
  const pending = choose(bytes('Old'), { arrayBuffer: () => new Promise(resolve => { finish = resolve; }) });
  elements.reset.dispatch('click'); finish(bytes('Old').buffer); await pending;
  assert.equal(elements.summary.children.length, 0); assert.match(elements.status.textContent, /Ansicht geleert/);
});
test('late failed read cannot replace a newer success', async () => {
  const { elements, choose } = dom(); let fail;
  const pending = choose(bytes('Old'), { arrayBuffer: () => new Promise((resolve, reject) => { fail = reject; }) });
  await choose(bytes('Latest')); fail(Error('old read failed')); await pending;
  assert.match(elements.status.textContent, /ohne Befund/);
});
test('empty selection clears prior view', async () => {
  const { elements, choose } = dom(); await choose(bytes('Synthetic')); elements['backup-file'].files = [];
  await elements['backup-file'].dispatch('change'); assert.equal(elements.summary.children.length, 0); assert.match(elements.status.textContent, /keine Datei/);
});
test('page has labeled inputs, live status and restrictive source policy', () => {
  const html = readFileSync(new URL('../../src/SchachTurnierManager.WebApp/public/backup-check/index.html', import.meta.url), 'utf8');
  assert.match(html, /label for="backup-file"/); assert.match(html, /aria-live="polite"/); assert.match(html, /connect-src 'none'/);
  assert.match(html, /form-action 'none'/); assert.match(html, /script type="module" src="\.\/app.mjs"/);
});
test('adapter source has no HTML insertion, network or persistent storage calls', () => {
  const source = readFileSync(new URL('../../src/SchachTurnierManager.WebApp/public/backup-check/app.mjs', import.meta.url), 'utf8');
  for (const forbidden of ['innerHTML', 'insertAdjacentHTML', 'fetch(', 'XMLHttpRequest', 'localStorage', 'sessionStorage', 'indexedDB']) assert.ok(!source.includes(forbidden));
});
