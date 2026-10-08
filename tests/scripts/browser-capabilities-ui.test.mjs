import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { installBrowserCheck } from '../../src/SchachTurnierManager.WebApp/public/browser-check/ui.js';
import { inspectBrowser } from '../../src/SchachTurnierManager.WebApp/public/browser-check/core.js';
const ids = ['check', 'reset', 'output', 'checks', 'features', 'status'];
function element(tagName = 'DIV') {
  const listeners = new Map();
  return { tagName, textContent: '', hidden: false, children: [], listeners,
    replaceChildren(...nodes) { this.children = nodes; }, append(...nodes) { this.children.push(...nodes); },
    addEventListener(name, fn) { listeners.set(name, fn); }, removeEventListener(name) { listeners.delete(name); },
    fire(name) { return listeners.get(name)?.(); },
  };
}
function setup(inspect = inspectBrowser) {
  const nodes = Object.fromEntries(ids.map(id => [id, element()]));
  const document = { getElementById: id => nodes[id], createElement: tag => element(tag) };
  const dispose = installBrowserCheck(document, {}, inspect); return { nodes, dispose };
}
test('opening the page does not start inspection', () => {
  let count = 0; const { nodes } = setup(() => { count++; }); assert.equal(count, 0); assert.equal(nodes.output.hidden, true);
});
test('one click inspects once and renders the fixed complete table', () => {
  let count = 0; const { nodes } = setup(env => { count++; return inspectBrowser(env); });
  nodes.check.fire('click'); assert.equal(count, 1); assert.equal(nodes.checks.children.length, 10);
  assert.equal(nodes.features.children.length, 4); assert.equal(nodes.output.hidden, false);
});
test('repeat clicks replace rather than accumulate results', () => {
  const { nodes } = setup(); nodes.check.fire('click'); nodes.check.fire('click'); assert.equal(nodes.checks.children.length, 10);
});
test('reset clears output without reading the environment', () => {
  let count = 0; const { nodes } = setup(env => { count++; return inspectBrowser(env); });
  nodes.check.fire('click'); nodes.reset.fire('click'); assert.equal(count, 1); assert.equal(nodes.checks.children.length, 0); assert.equal(nodes.output.hidden, true);
});
test('errors hide previous results without raw error output', () => {
  let count = 0; const { nodes } = setup(env => { if (count++ > 0) throw Error('PRIVATE'); return inspectBrowser(env); });
  nodes.check.fire('click'); nodes.check.fire('click'); assert.equal(nodes.output.hidden, true); assert.equal(nodes.checks.children.length, 0);
  assert.ok(!nodes.status.textContent.includes('PRIVATE'));
});
test('unknown or prototype-like status codes use fixed text', () => {
  const { nodes } = setup(() => ({ checks: { secureContext: '__proto__' }, features: {} }));
  nodes.check.fire('click'); assert.equal(nodes.checks.children[0].children[1].textContent, 'Nicht feststellbar');
});
test('available feature is not labeled as executed or installed', () => {
  const { nodes } = setup(() => ({ checks: {}, features: { backupChecksum: 'available' } }));
  nodes.check.fire('click'); assert.match(nodes.features.children[1].textContent, /nicht gepr/);
  assert.match(nodes.status.textContent, /keine Funktions/);
});
test('disposal removes listeners and queued callbacks become inert', () => {
  let count = 0; const { nodes, dispose } = setup(env => { count++; return inspectBrowser(env); });
  const queued = nodes.check.listeners.get('click'); dispose(); dispose(); queued();
  assert.equal(count, 0); assert.equal(nodes.check.listeners.size, 0); assert.equal(nodes.reset.listeners.size, 0);
});
const base = new URL('../../src/SchachTurnierManager.WebApp/', import.meta.url);
const html = readFileSync(new URL('public/browser-check/index.html', base), 'utf8');
const ui = readFileSync(new URL('public/browser-check/ui.js', base), 'utf8');
test('all controller elements are present exactly once', () => { for (const id of ids) assert.equal(html.split(`id="${id}"`).length - 1, 1); });
test('page forbids requests and forms and does not use inline code', () => {
  assert.ok(html.includes("connect-src 'none'")); assert.ok(html.includes("form-action 'none'")); assert.match(html, /src="\.\/main.js"/);
  assert.doesNotMatch(html, /onclick=|javascript:/);
});
test('entry link, accessible output and no-JavaScript guidance exist', () => {
  assert.match(readFileSync(new URL('index.html', base), 'utf8'), /href="\/browser-check\/index.html"/);
  assert.match(html, /role="status"/); assert.match(html, /scope="col"/); assert.match(html, /<noscript>/);
});
test('UI emits text without HTML injection, navigation or logging', () => {
  assert.doesNotMatch(ui, /innerHTML|outerHTML|document\.write|window\.open|console\.|location\./);
});
