import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { installFingerprintUi } from '../../src/SchachTurnierManager.WebApp/public/backup-fingerprint/ui.mjs';
function dom(ids) {
 const elements=Object.fromEntries(ids.map(id=>[id,{value:'',textContent:'',hidden:true,disabled:false,files:[],listeners:new Map(),addEventListener(name,fn){this.listeners.set(name,fn);},removeEventListener(name){this.listeners.delete(name);},fire(name){return this.listeners.get(name)?.();}}]));
 return {elements,getElementById:id=>elements[id]};
}
const deferred=()=>{let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b;});return {promise,resolve,reject};};
const ids=['file','expected','start','clear','status','result','hash'];
const sample={hash:'a'.repeat(64),bytes:3,comparison:'MATCH'};
const install=installFingerprintUi;
function setup(compute=async()=>sample){const d=dom(ids); const dispose=install(d,compute); return {d,e:d.elements,dispose};}
test('initial state is idle and empty',()=>{const {e}=setup();assert.equal(e.start.disabled,false);assert.equal(e.result.hidden,true);assert.notEqual(e.status.textContent,'');});
test('successful operation displays result',async()=>{const {e}=setup();await e.start.fire('click');assert.equal(e.result.hidden,false);assert.equal(e.start.disabled,false);});
test('double click while pending computes once',async()=>{let calls=0;const wait=deferred();const {e}=setup(()=>{calls++;return wait.promise;});const first=e.start.fire('click');await e.start.fire('click');assert.equal(calls,1);wait.resolve(sample);await first;});
test('reset during pending read suppresses stale result',async()=>{const wait=deferred();const {e}=setup(()=>wait.promise);const first=e.start.fire('click');e.clear.fire('click');wait.resolve(sample);await first;assert.equal(e.result.hidden,true);});
test('file change invalidates old read',async()=>{const wait=deferred();const {e}=setup(()=>wait.promise);const first=e.start.fire('click');e['file'].fire('change');wait.resolve(sample);await first;assert.equal(e.result.hidden,true);});
test('old failure does not overwrite newer success',async()=>{const wait=deferred();let calls=0;const {e}=setup(()=>++calls===1?wait.promise:Promise.resolve(sample));const first=e.start.fire('click');e['file'].fire('change');await e.start.fire('click');const status=e.status.textContent;wait.reject(Error('PRIVATE-SYNTHETIC'));await first;assert.equal(e.status.textContent,status);assert.equal(e.result.hidden,false);});
test('new operation hides old output until it finishes',async()=>{const wait=deferred();let calls=0;const {e}=setup(()=>++calls===1?Promise.resolve(sample):wait.promise);await e.start.fire('click');const second=e.start.fire('click');assert.equal(e.result.hidden,true);wait.resolve(sample);await second;assert.equal(e.result.hidden,false);});
test('unknown errors never disclose input payload',async()=>{const {e}=setup(async()=>{throw Error('PRIVATE-SYNTHETIC<img>');});await e.start.fire('click');assert.equal(e.status.textContent.includes('PRIVATE'),false);assert.equal(e.result.hidden,true);assert.equal(e.start.disabled,false);});
test('prototype-like error codes do not render prototype values',async()=>{const {e}=setup(async()=>{throw Error('__proto__');});await e.start.fire('click');assert.equal(e.status.textContent.includes('[object'),false);});
test('dispose invalidates pending results and removes listeners',async()=>{const wait=deferred();const {e,dispose}=setup(()=>wait.promise);const pending=e.start.fire('click');dispose();wait.resolve(sample);await pending;assert.equal(e.result.hidden,true);assert.equal(e.start.listeners.size,0);});
const folder=new URL('../../src/SchachTurnierManager.WebApp/public/backup-fingerprint/',import.meta.url);
const html=readFileSync(new URL('index.html',folder),'utf8');
const source=readFileSync(new URL('ui.mjs',folder),'utf8');
test('UI is available from main entry',()=>{const entry=readFileSync(new URL('../../src/SchachTurnierManager.WebApp/index.html',import.meta.url),'utf8');assert.ok(entry.includes('/backup-fingerprint/index.html'));});
test('all production DOM ids exist once',()=>{for(const id of ids)assert.equal(html.split('id="'+id+'"').length-1,1,id);});
test('CSP blocks connection and form submission',()=>{assert.ok(html.includes("connect-src 'none'"));assert.ok(html.includes("form-action 'none'"));});
test('status region accessible and only same-origin local scripts',()=>{assert.match(html,/role="status"/);assert.match(html,/aria-live="polite"/);assert.match(html,/src="\.\/app.mjs"/);});
test('no raw HTML writer in controller',()=>assert.doesNotMatch(source,/innerHTML|outerHTML|document\.write|eval\(/));

test('edited expected hash invalidates a pending calculation',async()=>{const wait=deferred();const {e}=setup(()=>wait.promise);const run=e.start.fire('click');e.expected.fire('input');wait.resolve(sample);await run;assert.equal(e.result.hidden,true);});
for(const code of ['FILE_REQUIRED','TOO_LARGE','INVALID_HASH','FILE_CHANGED','CRYPTO_UNAVAILABLE'])test('known error '+code,async()=>{const {e}=setup(async()=>{throw Error(code);});await e.start.fire('click');assert.equal(e.result.hidden,true);assert.notEqual(e.status.textContent,'');});
test('mismatch explicitly warns',async()=>{const {e}=setup(async()=>({...sample,comparison:'MISMATCH'}));await e.start.fire('click');assert.match(e.status.textContent,/weicht ab/);});
