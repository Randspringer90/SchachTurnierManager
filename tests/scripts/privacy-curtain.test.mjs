import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { installPrivacyCurtain } from '../../src/SchachTurnierManager.WebApp/public/privacy-curtain/controller.js';
function fixture(missing) {
  const nodes = Object.fromEntries(['root','stm-privacy-controls','stm-privacy-toggle','stm-privacy-status'].map(id => {
    const attrs = new Map(), listeners = new Map();
    return [id, { id, disabled: true, textContent: '', isConnected: true, attrs, listeners, focusCount: 0,
      setAttribute(k,v) { attrs.set(k,v); }, getAttribute(k) { return attrs.get(k) ?? null; },
      hasAttribute(k) { return attrs.has(k); }, removeAttribute(k) { attrs.delete(k); },
      addEventListener(k, fn) { listeners.set(k, fn); }, removeEventListener(k) { listeners.delete(k); },
      focus() { this.focusCount++; }, contains(node) { return node?.parent === this; },
      click() { listeners.get('click')?.(); },
    }];
  }));
  if (missing) delete nodes[missing];
  const document = { getElementById: id => nodes[id], activeElement: null };
  for (const name of ['localStorage','cookie','location','defaultView']) Object.defineProperty(document, name, {get(){throw Error('Forbidden access');}});
  return {document, nodes, root:nodes.root, button:nodes['stm-privacy-toggle'], status:nodes['stm-privacy-status']};
}
test('startup never hides content and enables the explicit control', () => {
  const f=fixture();installPrivacyCurtain(f.document);assert.equal(f.root.hasAttribute('hidden'),false);assert.equal(f.button.disabled,false);assert.equal(f.button.getAttribute('aria-expanded'),'true');
});
test('user can hide and show without replacing root content', () => {
  const f=fixture();f.root.value='unsaved synthetic text';installPrivacyCurtain(f.document);f.button.click();
  assert.equal(f.root.getAttribute('hidden'),'');assert.equal(f.root.getAttribute('data-stm-concealed'),'true');assert.equal(f.button.getAttribute('aria-expanded'),'false');
  f.button.click();assert.equal(f.root.hasAttribute('hidden'),false);assert.equal(f.root.hasAttribute('data-stm-concealed'),false);assert.equal(f.root.value,'unsaved synthetic text');
});
test('content stays concealed through unrelated data updates', () => {
  const f=fixture();installPrivacyCurtain(f.document);f.button.click();f.root.childData='new result';assert.equal(f.root.hasAttribute('hidden'),true);
});
test('focus leaves hidden content and can be restored', () => {
  const f=fixture();const child={parent:f.root,isConnected:true,focusCount:0,focus(){this.focusCount++;}};f.document.activeElement=child;
  installPrivacyCurtain(f.document);f.button.click();assert.equal(f.button.focusCount,1);f.button.click();assert.equal(child.focusCount,1);
});
test('detached field does not receive focus after showing', () => {
  const f=fixture();const child={parent:f.root,isConnected:true,focus(){throw Error('Detached');}};f.document.activeElement=child;
  installPrivacyCurtain(f.document);f.button.click();child.isConnected=false;assert.doesNotThrow(()=>f.button.click());
});
test('failed optional focus does not undo the curtain', () => {
  const f=fixture();f.button.focus=()=>{throw Error('focus');};installPrivacyCurtain(f.document);assert.doesNotThrow(()=>f.button.click());assert.equal(f.root.hasAttribute('hidden'),true);
});
for(const hidden of ['', 'until-found', 'hidden'])test('pre-existing hidden state is not owned: '+hidden,()=>{
  const f=fixture();f.root.setAttribute('hidden',hidden);const dispose=installPrivacyCurtain(f.document);f.button.click();dispose();assert.equal(f.root.getAttribute('hidden'),hidden);assert.equal(f.root.hasAttribute('data-stm-concealed'),false);
});
test('double installation creates one toggle and one teardown', () => {
  const f=fixture();const first=installPrivacyCurtain(f.document),second=installPrivacyCurtain(f.document);assert.equal(first,second);assert.equal(f.button.listeners.size,1);f.button.click();assert.equal(f.root.hasAttribute('hidden'),true);
});
test('dispose restores only its own hidden state and disables unavailable control', () => {
  const f=fixture();const dispose=installPrivacyCurtain(f.document);const queued=f.button.listeners.get('click');f.button.click();dispose();dispose();queued();assert.equal(f.root.hasAttribute('hidden'),false);assert.equal(f.button.disabled,true);assert.equal(f.button.listeners.size,0);
});
test('reinstall after teardown works', () => {
  const f=fixture();installPrivacyCurtain(f.document)();installPrivacyCurtain(f.document);f.button.click();assert.equal(f.root.hasAttribute('hidden'),true);
});
for(const missing of ['root','stm-privacy-controls','stm-privacy-toggle','stm-privacy-status'])test('missing '+missing+' has no effect',()=>{
  const f=fixture(missing);assert.doesNotThrow(()=>installPrivacyCurtain(f.document)());assert.equal(f.button?.listeners.size ?? 0,0);
});
test('source has no timer, navigation, window or storage action',()=>{
  const text=readFileSync(new URL('../../src/SchachTurnierManager.WebApp/public/privacy-curtain/controller.js',import.meta.url),'utf8');
  assert.doesNotMatch(text,/setTimeout|setInterval|fetch\(|window\.open|localStorage|sessionStorage|innerHTML/);
});
test('markup starts usable and exposes the limitation, not a security promise',()=>{
  const html=readFileSync(new URL('../../src/SchachTurnierManager.WebApp/index.html',import.meta.url),'utf8');
  assert.match(html,/id="stm-privacy-toggle"[^>]+disabled/);assert.match(html,/keine Zugangssperre/);assert.match(html,/<div id="root"><\/div>/);assert.match(html,/role="status"/);
});
test('CSS enforces hiding instead of a translucent overlay',()=>{
  const css=readFileSync(new URL('../../src/SchachTurnierManager.WebApp/public/privacy-curtain/style.css',import.meta.url),'utf8');assert.match(css,/#root\[data-stm-concealed="true"\] \{ display: none !important; \}/);
});
