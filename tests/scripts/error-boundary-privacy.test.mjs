import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { runInNewContext } from 'node:vm';

// Execute the actual TSX class with a small React element adapter. This tests
// lifecycle/handler/render contracts, not React reconciliation or a real browser.
const projectRequire = createRequire(new URL('../../src/SchachTurnierManager.WebApp/package.json', import.meta.url));
const ts = projectRequire('typescript'); // Already declared by the WebApp; no extra dependency.
const source = readFileSync(new URL('../../src/SchachTurnierManager.WebApp/src/components/ErrorBoundary.tsx', import.meta.url), 'utf8');
const compiled = ts.transpileModule(source, { fileName: 'ErrorBoundary.tsx', reportDiagnostics: true,
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022,
    jsx: ts.JsxEmit.React, esModuleInterop: true } });
assert.equal((compiled.diagnostics ?? []).filter(item => item.category === ts.DiagnosticCategory.Error).length, 0);

function harness() {
  const logs = []; let reloads = 0, forbidden = 0;
  const deny = () => { forbidden++; throw Error('Unexpected browser action'); };
  const React = {
    Component: class { constructor(props) { this.props = props; } },
    createElement(type, props, ...children) { return { type, props: { ...props, children } }; },
  };
  const window = { location: { reload() { reloads++; } }, open: deny, fetch: deny };
  for (const key of ['localStorage', 'sessionStorage', 'navigator']) Object.defineProperty(window, key, { get: deny });
  const module = { exports: {} };
  runInNewContext(compiled.outputText, {
    module, exports: module.exports,
    require(name) { assert.equal(name, 'react', 'the fallback must not depend on an i18n provider or backend'); return React; },
    window, console: { error: (...args) => logs.push(args) },
    fetch: deny, setTimeout: deny, setInterval: deny,
  }, { timeout: 1000, filename: 'compiled-ErrorBoundary.js' });
  const Boundary = module.exports.ErrorBoundary;
  return { Boundary, logs, reloads: () => reloads, forbidden: () => forbidden,
    failed(error = new Error('SYNTHETIC_PRIVATE_DETAIL')) {
      const boundary = new Boundary({ children: 'normal-content' });
      boundary.state = Boundary.getDerivedStateFromError(error);
      return boundary;
    } };
}
function elements(node) {
  if (!node || typeof node !== 'object') return [];
  return [node, ...(node.props?.children ?? []).flat(Infinity).flatMap(elements)];
}
function text(node) {
  if (typeof node === 'string' || typeof node === 'number') return String(node);
  if (!node || typeof node !== 'object') return '';
  return (node.props?.children ?? []).flat(Infinity).map(text).join(' ');
}
const normalized = node => text(node).replace(/\s+/g, ' ');

test('normal render preserves the exact child and does not call browser APIs', () => {
  const h = harness(), child = { marker: 'normal-child' }, boundary = new h.Boundary({ children: child });
  assert.equal(boundary.render(), child); assert.equal(h.reloads(), 0); assert.equal(h.logs.length, 0); assert.equal(h.forbidden(), 0);
});
for (const [label, value] of [['Error', new Error('SYNTHETIC_PRIVATE_DETAIL')], ['string', 'SYNTHETIC_PRIVATE_DETAIL'],
  ['object', { privateValue: 'SYNTHETIC_PRIVATE_DETAIL' }], ['null', null], ['undefined', undefined], ['number', 42], ['symbol', Symbol('private')]]) {
  test(`thrown ${label} is not retained in state or rendered`, () => {
    const h = harness(), boundary = h.failed(value);
    assert.equal(JSON.stringify(boundary.state), '{"hasError":true}');
    assert.doesNotMatch(normalized(boundary.render()), /SYNTHETIC_PRIVATE_DETAIL/);
  });
}
test('hostile exception getters, prototype and string conversions are never consulted', () => {
  const h = harness();
  const untrusted = new Proxy({}, { get() { throw Error('Exception inspected'); }, getPrototypeOf() { throw Error('Prototype inspected'); } });
  assert.doesNotThrow(() => h.failed(untrusted).render());
  const value = { toString() { throw Error('Stringification executed'); } };
  assert.doesNotThrow(() => h.failed(value).render());
});
test('the diagnostic contains one fixed reference and no exception argument', () => {
  const h = harness(), error = new Error('SYNTHETIC_PRIVATE_DETAIL'), boundary = h.failed(error);
  boundary.componentDidCatch(error);
  assert.equal(h.logs.length, 1); assert.equal(h.logs[0].length, 1);
  assert.equal(h.logs[0][0], '[SchachTurnierManager] UI_RENDER_FAILURE');
  assert.equal(h.logs[0].includes(error), false);
});
test('logging does not inspect an unusual thrown value', () => {
  const h = harness(), boundary = h.failed();
  const value = new Proxy({}, { get() { throw Error('Read'); }, getPrototypeOf() { throw Error('Read'); } });
  assert.doesNotThrow(() => boundary.componentDidCatch(value));
  assert.equal(h.logs[0].length, 1); assert.equal(typeof h.logs[0][0], 'string');
});
test('fallback has a stable support reference without raw details', () => {
  const h = harness(), view = h.failed().render();
  assert.match(normalized(view), /UI_RENDER_FAILURE/);
  assert.equal(elements(view).some(element => element.type === 'pre'), false);
});
test('fallback states uncertainty about saving instead of guaranteeing stored data safety', () => {
  const h = harness(), visible = normalized(h.failed().render());
  assert.doesNotMatch(visible, /are not affected|sind davon nicht betroffen/);
  assert.match(visible, /nicht feststellen/); assert.match(visible, /cannot determine/);
});
test('reload or leaving the page warns about unsaved input in both languages', () => {
  const h = harness(), visible = normalized(h.failed().render());
  assert.match(visible, /Ungespeicherte Eingaben/); assert.match(visible, /Unsaved input/);
  assert.match(visible, /Neuladen/); assert.match(visible, /reload/i);
});
test('recoverable actions are manual and cannot retry a mutation automatically', () => {
  const h = harness(), view = h.failed().render();
  assert.equal(h.reloads(), 0); assert.equal(h.forbidden(), 0);
  const buttons = elements(view).filter(element => element.type === 'button');
  assert.equal(buttons.length, 1); assert.equal(buttons[0].props.type, 'button');
  buttons[0].props.onClick(); assert.equal(h.reloads(), 1); assert.equal(h.forbidden(), 0);
});
test('local recovery link is fixed, same-tab and available without the i18n context', () => {
  const h = harness(), links = elements(h.failed().render()).filter(element => element.type === 'a');
  assert.equal(links.length, 1); assert.equal(links[0].props.href, '/backup-reader/index.html');
  assert.equal(links[0].props.target, undefined); assert.equal(links[0].props.onClick, undefined);
  assert.match(text(links[0]), /Sicherung/); assert.match(text(links[0]), /backup/i);
});
test('existing alert and reload styling contracts remain available', () => {
  const h = harness(), nodes = elements(h.failed().render());
  assert.equal(nodes[0].props.role, 'alert'); assert.equal(nodes[0].props.className, 'app-error-boundary');
  assert.ok(nodes.some(node => node.props?.className === 'app-error-boundary__reload'));
});
test('repeated fallback renders neither log nor initiate an action', () => {
  const h = harness(), boundary = h.failed(); boundary.render(); boundary.render();
  assert.equal(h.logs.length, 0); assert.equal(h.reloads(), 0); assert.equal(h.forbidden(), 0);
});
